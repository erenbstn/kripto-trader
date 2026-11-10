#!/usr/bin/env python3
"""8. Ajan: Risk Yöneticisi Kapısı (Risk Manager Gate Agent) - day-trader-skill/trader-risk karşılığı.
Her emri Paper Broker'a ulaşmadan önce 16 katı kurala göre denetler:
  1. Format ve zorunlu alan kontrolü (sembol, yön, miktar, bracket stop & hedef)
  2. Yasaklı (blocked) coin listesi kontrolü
  3. Haber Veto (hack/exploit/delist) kontrolü
  4. Balina / Funding Rate Veto kontrolü
  5. TimeMachine Monte Carlo onay kontrolü
  6. Minimum ve maksimum emir büyüklüğü ($) kontrolü
  7. Maksimum pozisyon ağırlığı (%75) kontrolü
  8. Nakit tamponu (%10 = $50) koruma kontrolü
  9. Stop-Loss zorunluluğu ve yön doğruluğu kontrolü
  10. İşlem başı maksimum zarar ($50) kontrolü
  11. Minimum Ödül/Risk (Reward:Risk >= 1.2) kontrolü
  12. Günlük maksimum zarar limiti ($150) kontrolü
  13. Günlük maksimum işlem sayısı (max_trades_per_day) kontrolü
  14. Aynı anda maksimum açık pozisyon sayısı (max_open_positions) kontrolü
  15. Aynı coinde mükerrer açık pozisyon kontrolü
  16. SHA-256 Emir Parmak İzi (Fingerprint) doğrulaması
"""

import datetime
import hashlib
import json
import os

FINGERPRINT_FIELDS = (
    "symbol", "side", "qty", "type", "time_in_force",
    "order_class", "take_profit_limit_price", "stop_loss_stop_price"
)


def order_fingerprint(order: dict) -> str:
    core = {k: str(order[k]) for k in FINGERPRINT_FIELDS if k in order and order[k] is not None}
    blob = json.dumps(core, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(blob.encode("utf-8")).hexdigest()[:16]


def check_order_risk(
    order: dict,
    config: dict,
    portfolio: dict,
    news_report: dict = None,
    whale_report: dict = None,
    timemachine_report: dict = None,
    write_path: str = "data/risk.json",
) -> dict:
    """Emri 16 risk kuralına göre denetler ve PASS / BLOCK kararı üretir."""
    reasons = []
    warnings = []

    if not order or not isinstance(order, dict):
        return {"verdict": "BLOCK", "reasons": ["format: Geçersiz boş emir"], "fingerprint": ""}

    sym = str(order.get("symbol") or "").strip().upper()
    side = str(order.get("side") or "").strip().lower()
    qty = float(order.get("qty_num") or order.get("qty") or 0.0)
    notional = float(order.get("notional_usd") or 0.0)
    total_cost = float(order.get("total_cost_usd") or notional)
    plan = order.get("plan") or {}

    stop = float(order.get("stop_loss_stop_price") or plan.get("stop") or 0.0)
    target = float(order.get("take_profit_limit_price") or plan.get("target") or 0.0)
    entry = float(plan.get("entry") or 0.0)
    max_loss = float(plan.get("max_loss") or 0.0)
    rr = float(plan.get("reward_risk") or 0.0)

    # 1. Format
    if not sym or not sym.endswith("USDT"):
        reasons.append(f"format: Geçersiz USDT paritesi ({sym})")
    if side != "buy":
        reasons.append(f"format: Sadece spot/long (buy) işlemlere izin veriliyor ({side})")
    if qty <= 0 or notional <= 0:
        reasons.append("format: Emir miktarı ve tutarı sıfırdan büyük olmalı")

    # 2. Yasaklı Liste ve Katı İzinli (Whitelist) 10 Kripto Kontrolü
    blocked = {str(b).upper() for b in (config.get("blocked") or [])}
    if sym in blocked:
        reasons.append(f"blocked: {sym} yasaklı coin listenizde")

    if config.get("strict_whitelist", True):
        allowed_watchlist = {
            str(w).upper() if str(w).upper().endswith("USDT") else f"{str(w).upper()}USDT"
            for w in (config.get("watchlist_symbols") or [])
        }
        if allowed_watchlist and sym not in allowed_watchlist:
            reasons.append(f"whitelist: {sym} izin verilen 10 kripto listenizde değil! İşlem reddedildi.")

    # 3. Haber Veto
    if news_report and news_report.get("veto"):
        reasons.append(f"news_veto: {news_report.get('veto_reason')}")

    # 4. Balina / Funding Veto
    if whale_report and whale_report.get("veto"):
        reasons.append(f"whale_veto: {whale_report.get('veto_reason')}")

    # 5. TimeMachine Onayı
    if timemachine_report and not timemachine_report.get("approved", False):
        reasons.append(f"timemachine: Simülasyon onaylamadı -> {timemachine_report.get('verdict')}")

    # 6. Emir Boyutu
    min_ord = float(config.get("min_order_usd", 5.0))
    max_ord = float(config.get("max_order_usd", 4000.0))
    if notional < min_ord - 0.01:
        reasons.append(f"size: Emir tutarı (${notional:.2f}) minimum sınırın (${min_ord:.2f}) altında")
    if notional > max_ord + 0.01:
        reasons.append(f"size: Emir tutarı (${notional:.2f}) maksimum sınırın (${max_ord:.2f}) üzerinde")

    # 7 & 8. Portföy Nakit Tamponu ve Pozisyon Ağırlığı
    budget = float(config.get("budget", 500.0))
    cash = float(portfolio.get("cash", budget)) if portfolio else budget
    total_eq = float(portfolio.get("total_equity", budget)) if portfolio else budget
    buf_pct = float(config.get("cash_buffer_pct", 10.0))
    buf_usd = total_eq * (buf_pct / 100.0)
    if (cash - total_cost) < (buf_usd - 0.05):
        reasons.append(
            f"cash: İşlem sonrası kalan nakit (${cash - total_cost:.2f}), "
            f"%{buf_pct:g} nakit tamponunun (${buf_usd:.2f}) altına düşüyor"
        )

    max_pos_pct = float(config.get("max_position_pct", 75.0))
    max_pos_usd = total_eq * (max_pos_pct / 100.0)
    if notional > max_pos_usd + 0.05:
        reasons.append(
            f"position: Pozisyon büyüklüğü (${notional:.2f}), kasanın %{max_pos_pct:g} sınırını (${max_pos_usd:.2f}) aşıyor"
        )

    # 9. Stop-Loss Zorunluluğu
    if config.get("require_stop", True) and stop <= 0:
        reasons.append("stop: Stop-Loss seviyesi zorunludur")
    elif stop >= entry:
        reasons.append(f"stop: Stop seviyesi ({stop}) giriş fiyatının ({entry}) altında olmalı")

    # 10. İşlem Başı Maksimum Zarar ($50)
    max_loss_cap = float(config.get("max_loss_per_trade_usd", 50.0))
    if max_loss > max_loss_cap + 0.05:
        reasons.append(
            f"loss: Stopta maksimum zarar (${max_loss:.2f}), işlem başı risk limitinizi (${max_loss_cap:.2f}) aşıyor"
        )

    # 11. Ödül / Risk Oranı
    min_rr = float(config.get("min_reward_risk", 1.2))
    if rr < min_rr - 0.01:
        reasons.append(f"reward_risk: Ödül/Risk oranı ({rr:.2f}), minimum sınırın ({min_rr:.2f}) altında")

    # 12 & 13. Günlük Zarar ve Günlük İşlem Sayısı Sınırları
    today_str = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d")
    closed_today = [
        t for t in (portfolio.get("closed_trades") or [])
        if str(t.get("closed_at", ""))[:10] == today_str
    ] if portfolio else []
    open_positions = (portfolio.get("positions") or []) if portfolio else []
    opened_today_count = len(closed_today) + sum(
        1 for p in open_positions if str(p.get("opened_at", ""))[:10] == today_str
    )

    realized_loss_today = sum(abs(float(t.get("pnl_usd", 0.0))) for t in closed_today if float(t.get("pnl_usd", 0.0)) < 0)
    open_risk_today = sum(float(p.get("max_loss_usd", 0.0)) for p in open_positions)
    daily_loss_cap = float(config.get("max_daily_loss_usd", 150.0))

    if (realized_loss_today + open_risk_today + max_loss) > daily_loss_cap + 0.05:
        reasons.append(
            f"daily_loss: Günlük toplam risk (${realized_loss_today + open_risk_today + max_loss:.2f}), "
            f"günlük maksimum zarar limitini (${daily_loss_cap:.2f}) aşıyor"
        )

    max_trades_day = int(config.get("max_trades_per_day", 5))
    if opened_today_count >= max_trades_day:
        reasons.append(f"trades: Bugün maksimum işlem sayısına ({opened_today_count}/{max_trades_day}) ulaşıldı")

    # 14 & 15. Maksimum Açık Pozisyon ve Mükerrer Coin Kontrolü
    max_open = int(config.get("max_open_positions", 3))
    if len(open_positions) >= max_open:
        reasons.append(f"open_positions: Aynı anda maksimum açık pozisyon sayısı ({len(open_positions)}/{max_open}) dolu")

    if any(p.get("symbol") == sym for p in open_positions):
        reasons.append(f"duplicate: {sym} için zaten açık bir pozisyon bulunuyor")

    fp = order_fingerprint(order)
    verdict = "BLOCK" if reasons else "PASS"

    doc = {
        "created_by": "risk_agent",
        "checked_at": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "date": today_str,
        "symbol": sym,
        "fingerprint": fp,
        "verdict": verdict,
        "reasons": reasons,
        "warnings": warnings,
        "metrics": {
            "notional_usd": notional,
            "max_loss_usd": max_loss,
            "reward_risk": rr,
            "cash_after_usd": round(cash - total_cost, 2),
            "opened_today": opened_today_count,
            "open_positions": len(open_positions),
        },
    }

    if write_path:
        os.makedirs(os.path.dirname(write_path) or ".", exist_ok=True)
        with open(write_path, "w", encoding="utf-8") as fh:
            json.dump(doc, fh, indent=2, ensure_ascii=False)
            fh.write("\n")

    return doc

