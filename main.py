#!/usr/bin/env python3
"""Kripto Multi-Agent 7/24 Otonom Günlük Trade Orkestratörü (Masaüstü & Termux Uyumlu).

Kullanım:
    python main.py                  # 7/24 otonom döngüyü başlatır (yalnızca yerel bildirim)
    python main.py run              # 7/24 otonom döngüyü başlatır (yalnızca yerel bildirim)
    python main.py once             # Tek bir tarama ve pozisyon kontrol döngüsü çalıştırır
    python main.py analyze BTCUSDT  # Tek bir coini tüm 11 ajanla derinlemesine analiz eder
    python main.py status           # $500 sahte kasanın güncel bakiye ve pozisyon durumunu gösterir
    python main.py demo             # Uçtan uca 11 ajanlı canlı veri simülasyon demosunu çalıştırır
"""

import argparse
import datetime
import json
import os
import sys
import time

# Windows konsolunda Türkçe karakter ve emoji (UTF-8) desteği
if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)

from agents.market_data import fetch_klines, normalize_symbol
from agents.scanner_agent import scan_market, analyze_symbol_setups, SETUP_LABELS
from agents.news_agent import check_symbol_news
from agents.whale_agent import analyze_whale_and_orderbook
from agents.entry_agent import check_entry
from agents.exit_agent import build_exit_plan, ExitPlanError
from agents.timemachine_agent import run_timemachine, TimeMachineError
from agents.budget_agent import size_position, BudgetError
from agents.risk_agent import check_order_risk
from agents.broker_agent import (
    load_portfolio,
    reset_portfolio,
    execute_paper_buy,
)
from agents.alerts_agent import monitor_open_positions
from agents.notifier import (
    LocalNotifier,
    format_trade_opened,
    format_trade_closed,
    format_breakeven_moved,
    format_portfolio_summary,
)


def load_config(config_path: str = None) -> dict:
    path = config_path or os.path.join(BASE_DIR, "config.json")
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def save_config(config: dict, config_path: str = None):
    path = config_path or os.path.join(BASE_DIR, "config.json")
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(config, fh, indent=2, ensure_ascii=False)
        fh.write("\n")


class MultiAgentOrchestrator:
    def __init__(self, config_path: str = None):
        self.config_path = config_path or os.path.join(BASE_DIR, "config.json")
        self.data_dir = os.path.join(BASE_DIR, "data")
        os.makedirs(self.data_dir, exist_ok=True)
        self.portfolio_path = os.path.join(self.data_dir, "portfolio.json")
        self.log_path = os.path.join(self.data_dir, "broker_log.json")
        self.config = load_config(self.config_path)
        self.notifier = LocalNotifier(self.data_dir, echo=False)
        self.paused = not bool(self.config.get("autonomous", True))
        self.last_scan_time = None
        self.last_scan_hits = 0

    def log(self, msg: str):
        ts = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{ts}] {msg}", flush=True)

    def notify(self, text: str, kind: str = "info"):
        self.notifier.push(text, kind=kind)

    def is_symbol_allowed(self, sym: str) -> bool:
        ns = normalize_symbol(sym)
        allowed = {normalize_symbol(w) for w in (self.config.get("watchlist_symbols") or [])}
        return (not allowed) or (ns in allowed)

    def evaluate_candidate_pipeline(self, hit: dict, pf: dict, execute_if_pass: bool = True) -> dict:
        """Tek bir aday coin için 11 ajanlı karar hunisini (News -> Whale -> Entry -> Exit -> TimeMachine -> Budget -> Risk -> Broker) çalıştırır."""
        sym = normalize_symbol(hit["symbol"])
        if not self.is_symbol_allowed(sym):
            return {"symbol": sym, "stage": "whitelist", "status": "blocked", "reason": f"{sym} izin verilen 10 kripto listesinde değil"}
        interval = self.config.get("interval", "5m")
        or_minutes = int(self.config.get("or_minutes", 15))

        kdata = fetch_klines(sym, interval=interval, limit=600)
        bars = kdata["bars"]
        forming = kdata["forming"]
        live_price = kdata["last_price"]

        # 2. Ajan: News & Sentiment
        news_doc = check_symbol_news(sym, fetch_live=True)
        if news_doc["veto"]:
            msg = f"⛔ [NEWS VETO] {sym}: {news_doc['veto_reason']}"
            self.log(msg)
            if (self.config.get("notifications") or {}).get("notify_on_veto"):
                self.notify(f"⛔ <b>HABER VETO ({sym})</b>\n{news_doc['veto_reason']}")
            return {"symbol": sym, "stage": "news", "status": "veto", "reason": news_doc["veto_reason"]}

        # 3. Ajan: Whale & Derivatives
        whale_doc = analyze_whale_and_orderbook(sym, bars=bars)
        if whale_doc["veto"]:
            msg = f"⛔ [WHALE VETO] {sym}: {whale_doc['veto_reason']}"
            self.log(msg)
            return {"symbol": sym, "stage": "whale", "status": "veto", "reason": whale_doc["veto_reason"]}

        # 4. Ajan: Entry Timer (Kapanmış mum onayı)
        entry_doc = check_entry(
            symbol=sym,
            setup=hit.get("primary_setup", "orb"),
            level=hit.get("level"),
            interval=interval,
            or_minutes=or_minutes,
            bars=bars,
            forming=forming,
            write_path=os.path.join(self.data_dir, "entry.json"),
        )
        if entry_doc.get("status") != "triggered":
            return {"symbol": sym, "stage": "entry", "status": "waiting", "reason": entry_doc.get("reason")}

        # 5. Ajan: Exit Planner (Stop-Loss & Take-Profit)
        try:
            plan_doc = build_exit_plan(
                entry_doc=entry_doc,
                config=self.config,
                stop_rule="auto",
                write_path=os.path.join(self.data_dir, "plan.json"),
            )
        except ExitPlanError as exc:
            return {"symbol": sym, "stage": "exit", "status": "rejected", "reason": str(exc)}

        # 6. Ajan: TimeMachine (10,000 Monte Carlo Simülasyonu + Geçmiş Seans Backtest)
        try:
            tm_doc = run_timemachine(
                plan=plan_doc,
                config=self.config,
                bars=bars,
                write_path=os.path.join(self.data_dir, "timemachine.json"),
            )
        except TimeMachineError as exc:
            return {"symbol": sym, "stage": "timemachine", "status": "rejected", "reason": str(exc)}

        if not tm_doc.get("approved"):
            self.log(f"🎲 [TIMEMACHINE VETO] {sym}: {tm_doc['verdict']}")
            if (self.config.get("notifications") or {}).get("notify_on_veto"):
                self.notify(
                    f"🎲 <b>TIMEMACHINE SİMÜLASYONU ELEME YAPTI: {sym}</b>\n"
                    f"• Kurulum: {', '.join(hit.get('setup_labels', []))}\n"
                    f"• Giriş: ${plan_doc['entry']:.6g} | Stop: ${plan_doc['stop']:.6g} | Hedef: ${plan_doc['target']:.6g}\n"
                    f"• Sonuç: {tm_doc['verdict']}\n"
                    f"• <i>Olasılık avantajı yetersiz olduğu için sahte bakiye riske atılmadı.</i>"
                )
            return {"symbol": sym, "stage": "timemachine", "status": "veto", "reason": tm_doc["verdict"], "timemachine": tm_doc}

        # 7. Ajan: Budget Manager ($500 Bakiye ve $50 Maks Risk ile Boyutlandırma)
        try:
            budget_doc = size_position(
                plan=plan_doc,
                config=self.config,
                portfolio=pf,
                live_price=live_price,
                write_path=os.path.join(self.data_dir, "orders.json"),
            )
        except BudgetError as exc:
            return {"symbol": sym, "stage": "budget", "status": "rejected", "reason": str(exc)}

        if budget_doc.get("refusal") or not budget_doc.get("orders"):
            return {"symbol": sym, "stage": "budget", "status": "rejected", "reason": budget_doc.get("refusal")}

        order = budget_doc["orders"][0]

        # 8. Ajan: Risk Manager Gate (16 Kural Denetimi)
        risk_doc = check_order_risk(
            order=order,
            config=self.config,
            portfolio=pf,
            news_report=news_doc,
            whale_report=whale_doc,
            timemachine_report=tm_doc,
            write_path=os.path.join(self.data_dir, "risk.json"),
        )
        if risk_doc.get("verdict") != "PASS":
            reason_str = "; ".join(risk_doc.get("reasons", []))
            self.log(f"🛡️ [RISK BLOCK] {sym}: {reason_str}")
            return {"symbol": sym, "stage": "risk", "status": "blocked", "reason": reason_str, "risk": risk_doc}

        if not execute_if_pass:
            return {
                "symbol": sym,
                "stage": "ready",
                "status": "pass",
                "news": news_doc,
                "whale": whale_doc,
                "entry": entry_doc,
                "plan": plan_doc,
                "timemachine": tm_doc,
                "budget": budget_doc,
                "risk": risk_doc,
            }

        # 9. Ajan: Autonomous Paper Broker (Sanal İşlemi Aç)
        exec_res = execute_paper_buy(
            order=order,
            risk_doc=risk_doc,
            config=self.config,
            timemachine_doc=tm_doc,
            portfolio_path=self.portfolio_path,
            log_path=self.log_path,
        )
        pos = exec_res["position"]
        updated_pf = exec_res["portfolio"]
        self.log(
            f"🚀 [İŞLEM AÇILDI] {sym} | Miktar: {pos['qty']} | Giriş: ${pos['entry_price']:.6g} | "
            f"Stop: ${pos['stop_loss']:.6g} | Hedef: ${pos['take_profit']:.6g} | Kasa: ${updated_pf['total_equity']:.2f}"
        )
        if (self.config.get("notifications") or {}).get("notify_on_trade_open", True):
            self.notify(format_trade_opened(pos, updated_pf))

        return {
            "symbol": sym,
            "stage": "executed",
            "status": "opened",
            "position": pos,
            "portfolio": updated_pf,
            "timemachine": tm_doc,
        }

    def run_monitor_step(self) -> dict:
        """Açık pozisyonları izler; Stop/Hedef/Breakeven/Süre kapanışlarını yönetir ve yerel bildirim üretir."""
        mon = monitor_open_positions(
            config=self.config,
            portfolio_path=self.portfolio_path,
            log_path=self.log_path,
        )
        pf = mon["portfolio"]
        for b_ev in mon.get("breakeven_events", []):
            self.log(f"🔒 [BREAKEVEN] {b_ev['symbol']} stop girişe çekildi -> ${b_ev['new_stop']:.6g}")
            if (self.config.get("notifications") or {}).get("notify_on_breakeven", True):
                self.notify(format_breakeven_moved(b_ev))

        for closed_trade in mon.get("closed_events", []):
            self.log(
                f"🎯 [İŞLEM KAPANDI] {closed_trade['symbol']} | Neden: {closed_trade['exit_reason']} | "
                f"PnL: ${closed_trade['pnl_usd']:+.2f} ({closed_trade['r_multiple']:+.2f}R) | "
                f"Yeni Kasa: ${pf['total_equity']:.2f}"
            )
            if (self.config.get("notifications") or {}).get("notify_on_trade_close", True):
                self.notify(format_trade_closed(closed_trade, pf))

        return mon

    def run_scan_step(self) -> dict:
        """Piyasayı tarar ve uygun sinyallerde otonom işlem hunisini çalıştırır."""
        pf = load_portfolio(self.config, path=self.portfolio_path)
        open_syms = {p["symbol"] for p in pf.get("positions", [])}
        max_open = int(self.config.get("max_open_positions", 3))

        scan_doc = scan_market(
            self.config,
            write_path=os.path.join(self.data_dir, "watchlist.json"),
        )
        self.last_scan_time = datetime.datetime.now().strftime("%H:%M:%S")
        hits = scan_doc.get("hits") or []
        self.last_scan_hits = len(hits)
        self.log(f"🔍 Piyasa tarandı: {scan_doc['scanned']} coin kontrol edildi, {len(hits)} kurulum (setup) bulundu.")

        opened = []
        evaluated = []

        if self.paused:
            self.log("⏸️ Otonom işlem açma duraklatılmış durumda (Sadece açık pozisyonlar izleniyor).")
            return {"scan": scan_doc, "opened": [], "evaluated": []}

        for hit in hits:
            pf = load_portfolio(self.config, path=self.portfolio_path)
            if len(pf.get("positions", [])) >= max_open:
                break
            if hit["symbol"] in open_syms:
                continue

            res = self.evaluate_candidate_pipeline(hit, pf, execute_if_pass=True)
            evaluated.append(res)
            if res.get("status") == "opened":
                opened.append(res["position"])
                open_syms.add(hit["symbol"])

        return {"scan": scan_doc, "opened": opened, "evaluated": evaluated}

    def analyze_single_symbol(self, symbol: str) -> dict:
        """Seçilen bir sembolü tüm ajanlarla analiz eder (aktif kırılım olmasa bile varsayımsal plan + TimeMachine çalıştırır)."""
        sym = normalize_symbol(symbol)
        interval = self.config.get("interval", "5m")
        kdata = fetch_klines(sym, interval=interval, limit=600)
        bars = kdata["bars"]
        price = kdata["last_price"]

        setup_hit = analyze_symbol_setups(sym, bars, or_minutes=int(self.config.get("or_minutes", 15)))
        news_doc = check_symbol_news(sym, fetch_live=True)
        whale_doc = analyze_whale_and_orderbook(sym, bars=bars)

        entry_doc = check_entry(
            symbol=sym,
            setup=setup_hit["primary_setup"] if setup_hit else "orb",
            level=setup_hit["level"] if setup_hit else (price * 0.999),
            interval=interval,
            bars=bars,
            forming=kdata["forming"],
            write_path=None,
        )
        # Analiz modunda TimeMachine'i görmek için varsayımsal triggered kopyası oluştur
        sim_entry = dict(entry_doc, status="triggered", price=price)
        plan_doc = build_exit_plan(sim_entry, self.config, stop_rule="auto", write_path=None)
        tm_doc = run_timemachine(plan_doc, self.config, bars=bars, write_path=None)
        pf = load_portfolio(self.config, path=self.portfolio_path)
        budget_doc = size_position(plan_doc, self.config, portfolio=pf, live_price=price, write_path=None)

        mc = tm_doc["mc"]
        hist = tm_doc["history"]
        setup_str = ", ".join(setup_hit["setup_labels"]) if setup_hit else "Henüz net kırılım yok (Varsayımsal Giriş Analizi)"

        report_text = (
            f"🔬 <b>11 AJANLI DERİN ANALİZ: {sym}</b>\n"
            "━━━━━━━━━━━━━━━━━━━━━━\n"
            f"💵 <b>Güncel Fiyat:</b> ${price:.6g}\n"
            f"📊 <b>1. Scanner:</b> {setup_str}\n"
            f"📰 <b>2. News & Fear/Greed:</b> {news_doc['fear_greed']['value']} ({news_doc['fear_greed']['classification']}) "
            f"| Veto: {'⛔ EVET' if news_doc['veto'] else '✅ Temiz'}\n"
            f"🐋 <b>3. Whale & Orderbook:</b> {whale_doc['whale_flow_label']} (Alıcı: %{whale_doc['taker_buy_pct']}) "
            f"| Emir Defteri: {whale_doc['orderbook_bid_ask_ratio']}x | Funding: %{whale_doc['funding_rate_pct']:+.4f}\n"
            f"⏱️ <b>4. Entry Timer:</b> {entry_doc['status'].upper()} — {entry_doc['reason']}\n"
            f"📐 <b>5. Exit Planı:</b> Stop: ${plan_doc['stop']:.6g} ({plan_doc['stop_label']}) | "
            f"Hedef: ${plan_doc['target']:.6g} ({plan_doc['reward_risk']}R)\n"
            "━━━━━━━━━━━━━━━━━━━━━━\n"
            f"🎲 <b>6. TimeMachine (10,000 Monte Carlo Simülasyonu):</b>\n"
            f"  • Önce Hedef: <b>%{mc['p_target']*100:.1f}</b> | Önce Stop: <b>%{mc['p_stop']*100:.1f}</b>\n"
            f"  • Süre Sonu Açık: %{mc['p_neither']*100:.1f} | Karda Bitme (Green): %{mc['p_green']*100:.1f}\n"
            f"  • Ortalama R: <b>{mc['avg_R']:+.3f}R</b>\n"
            f"  • Geçmiş Gerçek Seanslar ({hist['sessions']} seans): {hist['triggered']} kez tetiklendi "
            f"({hist['target']} Hedef, {hist['stop']} Stop, Ort. R: {hist['avg_R']:+.3f})\n"
            f"  • Karar: <b>{tm_doc['verdict']}</b>\n"
            "━━━━━━━━━━━━━━━━━━━━━━\n"
            f"💰 <b>7. Budget ($500 Kasa / $50 Maks Risk):</b>\n"
            f"  • Alınacak Miktar: {budget_doc['qty']} adet (${budget_doc['notional_usd']:.2f})\n"
            f"  • Stopta Maks. Zarar: -${budget_doc['max_loss_usd']:.2f} | Hedefte Net Kar: +${budget_doc['expected_profit_usd']:.2f}"
        )

        return {
            "symbol": sym,
            "price": price,
            "setup_hit": setup_hit,
            "news": news_doc,
            "whale": whale_doc,
            "entry": entry_doc,
            "plan": plan_doc,
            "timemachine": tm_doc,
            "budget": budget_doc,
            "report_text": report_text,
        }

    def run_forever(self):
        """7/24 kesintisiz çalışan ana döngü (Termux ve Masaüstü için optimize edilmiştir)."""
        pf = load_portfolio(self.config, path=self.portfolio_path)
        self.log("============================================================")
        self.log("🚀 KRİPTO MULTI-AGENT 7/24 OTONOM SİSTEM BAŞLATILDI")
        self.log(f"💰 Başlangıç Sahte Bakiye: ${pf['initial_budget']:.2f} | Güncel Equity: ${pf['total_equity']:.2f}")
        self.log(f"🛡️ İşlem Başı Maks. Risk: ${self.config.get('max_loss_per_trade_usd', 50):.2f}")
        self.log("🔔 Bildirimler yalnızca yereldir (data/notifications.jsonl); dış servis yok.")
        self.log("============================================================")

        scan_every = int(self.config.get("scan_interval_seconds", 60))
        mon_every = int(self.config.get("monitor_interval_seconds", 15))
        last_scan_ts = 0.0
        last_mon_ts = 0.0

        try:
            while True:
                now_ts = time.time()
                # 2. Açık pozisyonları izle (her 15 saniyede bir)
                if now_ts - last_mon_ts >= mon_every:
                    try:
                        self.run_monitor_step()
                    except Exception as exc:
                        self.log(f"⚠️ Pozisyon izleme hatası: {exc}")
                    last_mon_ts = time.time()

                # 3. Piyasayı tara ve yeni fırsatları değerlendir (her 60 saniyede bir)
                if now_ts - last_scan_ts >= scan_every:
                    try:
                        self.run_scan_step()
                    except Exception as exc:
                        self.log(f"⚠️ Tarama döngüsü hatası: {exc}")
                    last_scan_ts = time.time()

                time.sleep(2)
        except KeyboardInterrupt:
            self.log("🛑 Sistem kullanıcı tarafından durduruldu.")


def main(argv=None):
    ap = argparse.ArgumentParser(description="Kripto Multi-Agent 7/24 Otonom Day-Trading Sistemi")
    ap.add_argument("cmd", nargs="?", default="run", choices=["run", "once", "analyze", "status", "demo", "reset"])
    ap.add_argument("symbol", nargs="?", default="BTCUSDT", help="Analiz edilecek sembol (örn. BTCUSDT, SOLUSDT)")
    ap.add_argument("--config", default=os.path.join(BASE_DIR, "config.json"))
    ap.add_argument("--budget", type=float, default=500.0, help="Sıfırlama için yeni bakiye ($)")
    args = ap.parse_args(argv)

    orch = MultiAgentOrchestrator(config_path=args.config)

    if args.cmd == "run":
        orch.run_forever()
        return 0

    if args.cmd == "once":
        orch.run_monitor_step()
        orch.run_scan_step()
        pf = load_portfolio(orch.config, path=orch.portfolio_path)
        print("\n" + format_portfolio_summary(pf).replace("<b>", "").replace("</b>", ""))
        return 0

    if args.cmd == "analyze":
        res = orch.analyze_single_symbol(args.symbol)
        clean = res["report_text"].replace("<b>", "").replace("</b>", "").replace("<i>", "").replace("</i>", "")
        print(clean)
        return 0

    if args.cmd == "status":
        orch.run_monitor_step()
        pf = load_portfolio(orch.config, path=orch.portfolio_path)
        print(format_portfolio_summary(pf).replace("<b>", "").replace("</b>", ""))
        return 0

    if args.cmd == "reset":
        orch.config["budget"] = args.budget
        save_config(orch.config, orch.config_path)
        pf = reset_portfolio(new_budget=args.budget, path=orch.portfolio_path)
        print(f"Sanal portföy sıfırlandı: Yeni bakiye ${pf['cash']:.2f} USDT")
        return 0

    if args.cmd == "demo":
        print("============================================================")
        print("🧪 KRİPTO MULTI-AGENT 11 AJANLI UÇTAN UCA CANLI VERİ DEMOSU")
        print("============================================================")
        res = orch.analyze_single_symbol(args.symbol or "BTCUSDT")
        clean = res["report_text"].replace("<b>", "").replace("</b>", "").replace("<i>", "").replace("</i>", "")
        print(clean)
        print("\n------------------------------------------------------------")
        pf = load_portfolio(orch.config, path=orch.portfolio_path)
        print(format_portfolio_summary(pf).replace("<b>", "").replace("</b>", ""))
        return 0

    return 0


if __name__ == "__main__":
    sys.exit(main())

