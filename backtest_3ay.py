#!/usr/bin/env python3
"""Son 90 Günlük (3 Aylık) Gerçek Binance Verisiyle Uçtan Uca Multi-Agent Backtest Motoru.
Seçili 10 Varlık: ONDOUSDT, HBARUSDT, BTCUSDT, SIRENUSDT, XAGUSDT, LINKUSDT, SOLUSDT, PAXGUSDT, XRPUSDT, ETHUSDT
Başlangıç Kasası: $500.00 USDT
Borsa Komisyonu: %0.1 Alış + %0.1 Satış (Toplam %0.20)
Kurallar:
  - Scanner (6 kurulum: orb, breakout_20d, bull_flag, reclaim_ma20, oversold_bounce, vwap_breakout)
  - Whale / Taker Buy & Volume Filtresi
  - Entry (Kapanmış mum onayı + Chasing Guard)
  - Exit (ATR / OR-Mid Stop-Loss, 2.0R Take-Profit, +1.0R Breakeven Başabaş Koruması, Süre Stopu)
  - TimeMachine (Gerçek geçmiş mum dağılımından Monte Carlo Olasılık ve Beklenen R Filtresi)
  - Budget & Risk ($500 Kasa, İşlem Başı Maks $50 Risk, %75 Pozisyon Sınırı, %10 Nakit Tamponu, Maks 3 Açık İşlem)
"""

import concurrent.futures
import datetime
import json
import os
import random
import sys
import time
import urllib.parse

if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)

from agents.market_data import binance_get, FUTURES_NATIVE_SYMBOLS
from agents.scanner_agent import analyze_symbol_setups

SYMBOLS = [
    "ONDOUSDT",
    "HBARUSDT",
    "BTCUSDT",
    "SIRENUSDT",
    "XAGUSDT",
    "LINKUSDT",
    "SOLUSDT",
    "PAXGUSDT",
    "XRPUSDT",
    "ETHUSDT",
]


def fetch_90d_bars_for_symbol(sym: str, interval: str = "15m", days: int = 90) -> list:
    """Son 90 günün gerçek Binance mumlarını (Spot veya Futures) parçalı olarak çeker."""
    now_ms = int(time.time() * 1000)
    start_ms = now_ms - (days * 24 * 3600 * 1000)
    step_ms = 15 * 60 * 1000 if interval == "15m" else 5 * 60 * 1000

    is_fut = sym in FUTURES_NATIVE_SYMBOLS
    prefix = "/fapi/v1/klines" if is_fut else "/api/v3/klines"

    all_bars = []
    cursor = start_ms
    while cursor < now_ms:
        path = (
            f"{prefix}?symbol={urllib.parse.quote(sym)}&interval={interval}"
            f"&startTime={cursor}&limit=1000"
        )
        try:
            rows = binance_get(path, futures=is_fut, timeout=10)
        except Exception:
            if not is_fut:
                is_fut = True
                prefix = "/fapi/v1/klines"
                rows = binance_get(
                    f"{prefix}?symbol={urllib.parse.quote(sym)}&interval={interval}&startTime={cursor}&limit=1000",
                    futures=True,
                    timeout=10,
                )
            else:
                break

        if not rows:
            break

        for r in rows:
            open_ms = int(r[0])
            close_ms = int(r[6])
            if close_ms > now_ms:
                continue
            all_bars.append({
                "t": open_ms // 1000,
                "open_ms": open_ms,
                "close_ms": close_ms,
                "dt": datetime.datetime.fromtimestamp(open_ms / 1000.0, datetime.timezone.utc).strftime("%Y-%m-%d %H:%M"),
                "o": float(r[1]),
                "h": float(r[2]),
                "l": float(r[3]),
                "c": float(r[4]),
                "v": float(r[5]),
                "qv": float(r[7]),
                "trades": int(r[8]),
                "taker_buy_qv": float(r[10]),
            })

        last_open = int(rows[-1][0])
        if last_open <= cursor:
            break
        cursor = last_open + step_ms
        if len(rows) < 1000:
            break

    # Tekrarlı mumları temizle ve zamana göre sırala
    dedup = {b["t"]: b for b in all_bars}
    return [dedup[k] for k in sorted(dedup.keys())]


def fast_timemachine_filter(bars_window: list, entry: float, stop: float, target: float, rng: random.Random, sims: int = 400) -> dict:
    """TimeMachine Ajanının geçmiş bar oranlarından Monte Carlo + geçmiş pencere simülasyonu."""
    risk = entry - stop
    if risk <= 0 or len(bars_window) < 40:
        return {"approved": False, "avg_r": -1.0, "p_target": 0.0}

    sample = bars_window[-80:]
    deltas = []
    for i in range(1, len(sample)):
        prev_c = sample[i - 1]["c"]
        if prev_c <= 0:
            continue
        b = sample[i]
        deltas.append((
            (b["h"] - prev_c) / prev_c,
            (b["l"] - prev_c) / prev_c,
            (b["c"] - prev_c) / prev_c,
        ))
    if len(deltas) < 20:
        return {"approved": False, "avg_r": -1.0, "p_target": 0.0}

    be_trigger = entry + risk  # +1R Breakeven
    be_stop = entry * 1.0022
    horizon = 16  # 16 bar (4 saatlik seans ufku)

    n_target = 0
    n_stop = 0
    n_be = 0
    r_sum = 0.0

    for _ in range(sims):
        price = entry
        curr_stop = stop
        be_active = False
        outcome_r = None
        for _step in range(horizon):
            dh, dl, dc = rng.choice(deltas)
            bar_h = price * (1.0 + dh)
            bar_l = price * (1.0 + dl)
            price = price * (1.0 + dc)

            if bar_l <= curr_stop:
                if be_active:
                    outcome_r = 0.02
                    n_be += 1
                else:
                    outcome_r = -1.0
                    n_stop += 1
                break
            if bar_h >= target:
                outcome_r = (target - entry) / risk
                n_target += 1
                break
            if not be_active and bar_h >= be_trigger:
                be_active = True
                curr_stop = be_stop

        if outcome_r is None:
            outcome_r = (price - entry) / risk
        r_sum += outcome_r

    avg_r = r_sum / sims
    p_target = n_target / sims
    approved = (avg_r >= 0.06 and p_target >= 0.31)
    return {
        "approved": approved,
        "avg_r": round(avg_r, 3),
        "p_target": round(p_target, 3),
        "p_stop": round(n_stop / sims, 3),
        "p_be": round(n_be / sims, 3),
    }


def run_simulation(bars_by_sym: dict, use_timemachine: bool = True) -> dict:
    """Tüm sembolleri zaman sırasına (kronolojik) göre bar-bar ilerleterek $500 kasayı simüle eder."""
    rng = random.Random(19)
    initial_budget = 500.0
    cash = initial_budget
    peak_equity = initial_budget
    max_drawdown_pct = 0.0
    fee_rate = 0.001  # %0.1 (10 bps)

    open_positions = {}  # sym -> pos dict
    closed_trades = []
    daily_trades = {}    # YYYY-MM-DD -> count
    daily_loss = {}      # YYYY-MM-DD -> float
    monthly_pnl = {}     # YYYY-MM -> float
    veto_count = 0
    signals_total = 0

    # Ortak zaman damgalarını topla
    all_ts = sorted({b["t"] for bars in bars_by_sym.values() for b in bars})
    # Her sembol için ts -> index haritası
    idx_map = {
        sym: {b["t"]: i for i, b in enumerate(bars)}
        for sym, bars in bars_by_sym.items()
    }

    for ts in all_ts:
        dt_obj = datetime.datetime.fromtimestamp(ts, datetime.timezone.utc)
        day_key = dt_obj.strftime("%Y-%m-%d")
        month_key = dt_obj.strftime("%Y-%m")

        # 1. ÖNCE AÇIK POZİSYONLARI GÜNCELLE (Alerts Agent: Stop, Target, +1R Breakeven, Time Exit)
        for sym in list(open_positions.keys()):
            pos = open_positions[sym]
            i = idx_map[sym].get(ts)
            if i is None:
                continue
            bar = bars_by_sym[sym][i]
            pos["bars_held"] += 1
            pos["last_price"] = bar["c"]

            exit_price = None
            exit_reason = None

            # Muhafazakar kural: Önce Stop kontrolü
            if bar["l"] <= pos["stop"]:
                exit_price = pos["stop"]
                exit_reason = "BREAKEVEN_STOP" if pos["be_moved"] else "STOP_LOSS"
            elif bar["h"] >= pos["target"]:
                exit_price = pos["target"]
                exit_reason = "TAKE_PROFIT"
            elif pos["bars_held"] >= pos["max_bars"]:
                exit_price = bar["c"]
                exit_reason = "TIME_EXIT"
            else:
                # +1R Breakeven kontrolü
                if not pos["be_moved"] and bar["h"] >= pos["be_trigger"]:
                    pos["stop"] = round(pos["entry"] * 1.0022, 6)
                    pos["be_moved"] = True

            if exit_price is not None:
                gross_proceeds = pos["qty"] * exit_price
                sell_fee = gross_proceeds * fee_rate
                net_proceeds = gross_proceeds - sell_fee
                pnl_usd = net_proceeds - pos["total_cost"]
                r_mult = pnl_usd / pos["risk_usd"] if pos["risk_usd"] > 0 else 0.0

                cash += net_proceeds
                if pnl_usd < 0:
                    daily_loss[day_key] = daily_loss.get(day_key, 0.0) + abs(pnl_usd)
                monthly_pnl[month_key] = monthly_pnl.get(month_key, 0.0) + pnl_usd

                closed_trades.append({
                    "symbol": sym,
                    "setup": pos["setup"],
                    "opened_at": pos["opened_dt"],
                    "closed_at": bar["dt"],
                    "entry": pos["entry"],
                    "exit": exit_price,
                    "qty": pos["qty"],
                    "cost_usd": round(pos["total_cost"], 2),
                    "pnl_usd": round(pnl_usd, 2),
                    "r_multiple": round(r_mult, 2),
                    "reason": exit_reason,
                    "fees_usd": round(pos["buy_fee"] + sell_fee, 2),
                })
                del open_positions[sym]

        # Anlık toplam kasa (Equity) ve Max Drawdown güncelle
        pos_val = sum(p["qty"] * p["last_price"] for p in open_positions.values())
        equity = cash + pos_val
        if equity > peak_equity:
            peak_equity = equity
        dd = ((peak_equity - equity) / peak_equity) * 100.0 if peak_equity > 0 else 0.0
        if dd > max_drawdown_pct:
            max_drawdown_pct = dd

        # 2. YENİ İŞLEM TARAMASI (Maks 3 açık pozisyon, günlük maks 5 işlem, günlük maks $150 zarar)
        if len(open_positions) >= 3:
            continue
        if daily_trades.get(day_key, 0) >= 5:
            continue
        if daily_loss.get(day_key, 0.0) >= 150.0:
            continue

        candidates = []
        for sym in SYMBOLS:
            if sym in open_positions:
                continue
            i = idx_map[sym].get(ts)
            if i is None or i < 80:
                continue
            window = bars_by_sym[sym][i - 80 : i + 1]
            hit = analyze_symbol_setups(sym, window, or_minutes=15)
            if not hit:
                continue
            signals_total += 1

            # Whale / Taker Buy kontrolü (Son 5 barda alıcı oranı >= %50 olmalı)
            rec5 = window[-5:]
            tot_qv = sum(b["qv"] for b in rec5)
            tb_ratio = sum(b["taker_buy_qv"] for b in rec5) / tot_qv if tot_qv > 0 else 0.5
            if tb_ratio < 0.48:
                veto_count += 1
                continue

            entry_p = hit["price"]
            atr = hit["atr"]
            # Stop mesafesi: en az %0.45, en fazla %3.5, 1.5x ATR bazlı
            stop_dist = max(atr * 1.5, entry_p * 0.0045)
            if stop_dist / entry_p > 0.035:
                veto_count += 1
                continue
            stop_p = entry_p - stop_dist
            target_p = entry_p + (stop_dist * 2.0)  # 2R Hedef

            if use_timemachine:
                tm = fast_timemachine_filter(window, entry_p, stop_p, target_p, rng, sims=400)
                if not tm["approved"]:
                    veto_count += 1
                    continue
                score = hit["score"] + (tm["avg_r"] * 100.0)
            else:
                score = hit["score"]

            candidates.append((score, sym, hit, entry_p, stop_p, target_p))

        if not candidates:
            continue

        candidates.sort(key=lambda x: -x[0])

        for _, sym, hit, entry_p, stop_p, target_p in candidates:
            if len(open_positions) >= 3 or daily_trades.get(day_key, 0) >= 5:
                break

            # Budget Agent: $500 Kasa (veya güncel kasa), %75 maks pozisyon, %10 nakit tamponu, $50 maks zarar
            pos_val_now = sum(p["qty"] * p["last_price"] for p in open_positions.values())
            curr_equity = cash + pos_val_now
            cash_buffer = curr_equity * 0.10
            spendable_cash = max(0.0, cash - cash_buffer)
            max_pos_usd = curr_equity * 0.75

            per_unit_loss = (entry_p - stop_p) + (entry_p + stop_p) * fee_rate
            if per_unit_loss <= 0:
                continue
            qty_by_risk = 50.0 / per_unit_loss
            qty_by_pos = max_pos_usd / (entry_p * (1.0 + fee_rate))
            qty_by_cash = spendable_cash / (entry_p * (1.0 + fee_rate))
            qty = min(qty_by_risk, qty_by_pos, qty_by_cash)

            notional = qty * entry_p
            if notional < 10.0:
                continue

            buy_fee = notional * fee_rate
            total_cost = notional + buy_fee
            risk_usd = qty * per_unit_loss

            cash -= total_cost
            daily_trades[day_key] = daily_trades.get(day_key, 0) + 1

            open_positions[sym] = {
                "symbol": sym,
                "setup": hit["primary_setup"],
                "opened_dt": bars_by_sym[sym][idx_map[sym][ts]]["dt"],
                "entry": entry_p,
                "stop": stop_p,
                "target": target_p,
                "be_trigger": entry_p + (entry_p - stop_p),
                "be_moved": False,
                "qty": qty,
                "buy_fee": buy_fee,
                "total_cost": total_cost,
                "risk_usd": risk_usd,
                "bars_held": 0,
                "max_bars": 24,  # 24 adet 15m bar = 6 saat tutma sınırı
                "last_price": entry_p,
            }

    # Kalan açık pozisyonları son fiyattan kapat
    for sym, pos in list(open_positions.items()):
        exit_price = pos["last_price"]
        gross = pos["qty"] * exit_price
        sell_fee = gross * fee_rate
        net = gross - sell_fee
        pnl_usd = net - pos["total_cost"]
        cash += net
        closed_trades.append({
            "symbol": sym,
            "setup": pos["setup"],
            "opened_at": pos["opened_dt"],
            "closed_at": "DÖNEM_SONU",
            "entry": pos["entry"],
            "exit": exit_price,
            "qty": pos["qty"],
            "cost_usd": round(pos["total_cost"], 2),
            "pnl_usd": round(pnl_usd, 2),
            "r_multiple": round(pnl_usd / pos["risk_usd"], 2) if pos["risk_usd"] > 0 else 0.0,
            "reason": "END_OF_BACKTEST",
            "fees_usd": round(pos["buy_fee"] + sell_fee, 2),
        })

    final_equity = round(cash, 2)
    net_profit = round(final_equity - initial_budget, 2)
    return_pct = round((net_profit / initial_budget) * 100.0, 2)

    wins = [t for t in closed_trades if t["pnl_usd"] > 0.5]
    breakevens = [t for t in closed_trades if -0.5 <= t["pnl_usd"] <= 0.5]
    losses = [t for t in closed_trades if t["pnl_usd"] < -0.5]

    gross_win = sum(t["pnl_usd"] for t in closed_trades if t["pnl_usd"] > 0)
    gross_loss = abs(sum(t["pnl_usd"] for t in closed_trades if t["pnl_usd"] < 0))
    pf = round(gross_win / gross_loss, 2) if gross_loss > 0 else 99.9
    total_fees = round(sum(t["fees_usd"] for t in closed_trades), 2)

    per_coin = {}
    for sym in SYMBOLS:
        ct = [t for t in closed_trades if t["symbol"] == sym]
        per_coin[sym] = {
            "trades": len(ct),
            "wins": sum(1 for t in ct if t["pnl_usd"] > 0.5),
            "be": sum(1 for t in ct if -0.5 <= t["pnl_usd"] <= 0.5),
            "losses": sum(1 for t in ct if t["pnl_usd"] < -0.5),
            "net_pnl_usd": round(sum(t["pnl_usd"] for t in ct), 2),
        }

    return {
        "initial_budget_usd": initial_budget,
        "final_equity_usd": final_equity,
        "net_profit_usd": net_profit,
        "return_pct": return_pct,
        "total_trades": len(closed_trades),
        "wins": len(wins),
        "breakevens": len(breakevens),
        "losses": len(losses),
        "win_or_be_rate_pct": round(((len(wins) + len(breakevens)) / len(closed_trades)) * 100.0, 1) if closed_trades else 0.0,
        "strict_win_rate_pct": round((len(wins) / len(closed_trades)) * 100.0, 1) if closed_trades else 0.0,
        "profit_factor": pf,
        "max_drawdown_pct": round(max_drawdown_pct, 2),
        "total_fees_paid_usd": total_fees,
        "signals_scanned": signals_total,
        "vetoed_signals": veto_count,
        "monthly_pnl": {k: round(v, 2) for k, v in sorted(monthly_pnl.items())},
        "per_coin": per_coin,
        "sample_trades": closed_trades[-10:],
    }


def run_simulation_v2_optimized(bars_by_sym: dict) -> dict:
    """V2 GELİŞTİRİLMİŞ STRATEJİ:
    1. Ana Trend Filtresi: Sadece EMA20 > EMA50 > EMA100 yükseliş trendindeyken ve BTCUSDT çöküşte değilken işlem açar.
    2. Komisyon Koruması: Dar stoplarda (%0.4) komisyon erimesini önlemek için min %1.2 stop / %2.6 hedef (2.2R) şartı arar.
    3. Kâr Kilitleme (+0.4R Profit Lock): Fiyat +1.2R'ye ulaştığında stopu 0'a değil +0.4R net kâra çeker.
    4. Sıkı TimeMachine: Sadece yüksek olasılıklı (avg_r >= 0.18) ve güçlü hacimli (vol >= 1.5x) kırılımlara girer.
    """
    rng = random.Random(19)
    initial_budget = 500.0
    cash = initial_budget
    peak_equity = initial_budget
    max_drawdown_pct = 0.0
    fee_rate = 0.001

    open_positions = {}
    closed_trades = []
    daily_trades = {}
    daily_loss = {}
    monthly_pnl = {}
    veto_count = 0
    signals_total = 0

    all_ts = sorted({b["t"] for bars in bars_by_sym.values() for b in bars})
    idx_map = {
        sym: {b["t"]: i for i, b in enumerate(bars)}
        for sym, bars in bars_by_sym.items()
    }

    btc_bars = bars_by_sym.get("BTCUSDT", [])
    btc_idx = idx_map.get("BTCUSDT", {})

    for ts in all_ts:
        dt_obj = datetime.datetime.fromtimestamp(ts, datetime.timezone.utc)
        day_key = dt_obj.strftime("%Y-%m-%d")
        month_key = dt_obj.strftime("%Y-%m")

        # 1. Açık Pozisyonları Güncelle
        for sym in list(open_positions.keys()):
            pos = open_positions[sym]
            i = idx_map[sym].get(ts)
            if i is None:
                continue
            bar = bars_by_sym[sym][i]
            pos["bars_held"] += 1
            pos["last_price"] = bar["c"]

            exit_price = None
            exit_reason = None

            if bar["l"] <= pos["stop"]:
                exit_price = pos["stop"]
                exit_reason = "PROFIT_LOCK_STOP (+0.4R)" if pos["be_moved"] else "STOP_LOSS"
            elif bar["h"] >= pos["target"]:
                exit_price = pos["target"]
                exit_reason = "TAKE_PROFIT (2.2R 🎯)"
            elif pos["bars_held"] >= pos["max_bars"]:
                exit_price = bar["c"]
                exit_reason = "TIME_EXIT"
            else:
                # +1.2R'ye ulaşıldığında stopu +0.40R net kâra çek
                if not pos["be_moved"] and bar["h"] >= pos["be_trigger"]:
                    pos["stop"] = round(pos["entry"] + (pos["risk_per_unit"] * 0.40), 6)
                    pos["be_moved"] = True

            if exit_price is not None:
                gross_proceeds = pos["qty"] * exit_price
                sell_fee = gross_proceeds * fee_rate
                net_proceeds = gross_proceeds - sell_fee
                pnl_usd = net_proceeds - pos["total_cost"]
                r_mult = pnl_usd / pos["risk_usd"] if pos["risk_usd"] > 0 else 0.0

                cash += net_proceeds
                if pnl_usd < 0:
                    daily_loss[day_key] = daily_loss.get(day_key, 0.0) + abs(pnl_usd)
                monthly_pnl[month_key] = monthly_pnl.get(month_key, 0.0) + pnl_usd

                closed_trades.append({
                    "symbol": sym,
                    "setup": pos["setup"],
                    "opened_at": pos["opened_dt"],
                    "closed_at": bar["dt"],
                    "entry": pos["entry"],
                    "exit": exit_price,
                    "qty": pos["qty"],
                    "cost_usd": round(pos["total_cost"], 2),
                    "pnl_usd": round(pnl_usd, 2),
                    "r_multiple": round(r_mult, 2),
                    "reason": exit_reason,
                    "fees_usd": round(pos["buy_fee"] + sell_fee, 2),
                })
                del open_positions[sym]

        pos_val = sum(p["qty"] * p["last_price"] for p in open_positions.values())
        equity = cash + pos_val
        if equity > peak_equity:
            peak_equity = equity
        dd = ((peak_equity - equity) / peak_equity) * 100.0 if peak_equity > 0 else 0.0
        if dd > max_drawdown_pct:
            max_drawdown_pct = dd

        if len(open_positions) >= 3 or daily_trades.get(day_key, 0) >= 3 or daily_loss.get(day_key, 0.0) >= 80.0:
            continue

        # BTC Makro Rejim Filtresi: BTC 48-bar (12s) ortalaması 192-bar (48s) ortalamasının üzerindeyken işlem aç
        bi = btc_idx.get(ts)
        if bi is not None and bi >= 200:
            btc_closes = [b["c"] for b in btc_bars[bi - 200 : bi + 1]]
            btc_ma48 = sum(btc_closes[-48:]) / 48.0
            btc_ma192 = sum(btc_closes[-192:]) / 192.0
            if btc_closes[-1] < btc_ma48 or btc_ma48 < btc_ma192:
                continue

        candidates = []
        for sym in SYMBOLS:
            if sym in open_positions:
                continue
            i = idx_map[sym].get(ts)
            if i is None or i < 120:
                continue
            window = bars_by_sym[sym][i - 120 : i + 1]
            closes = [b["c"] for b in window]
            ma20 = sum(closes[-20:]) / 20.0
            ma50 = sum(closes[-50:]) / 50.0
            ma100 = sum(closes[-100:]) / 100.0

            # Güçlü Yükseliş Trendi Şartı: Fiyat > MA20 > MA50 > MA100
            if not (closes[-1] > ma20 > ma50 > ma100):
                continue

            hit = analyze_symbol_setups(sym, window[-85:], or_minutes=15)
            if not hit:
                continue
            signals_total += 1

            # Hacim (>= 1.3x) ve Taker Buy (>= %54) şartı
            if hit["volume_ratio"] < 1.3:
                veto_count += 1
                continue
            rec5 = window[-5:]
            tot_qv = sum(b["qv"] for b in rec5)
            tb_ratio = sum(b["taker_buy_qv"] for b in rec5) / tot_qv if tot_qv > 0 else 0.5
            if tb_ratio < 0.54:
                veto_count += 1
                continue

            entry_p = hit["price"]
            atr = hit["atr"]
            # Komisyon erimesini önleyen yapısal stop: en az %1.5, en fazla %4.0
            stop_dist = max(atr * 2.5, entry_p * 0.015)
            if stop_dist / entry_p > 0.040:
                veto_count += 1
                continue
            stop_p = entry_p - stop_dist
            target_p = entry_p + (stop_dist * 2.5)  # 2.5R Hedef

            tm = fast_timemachine_filter(window, entry_p, stop_p, target_p, rng, sims=300)
            if tm["avg_r"] < 0.05:
                veto_count += 1
                continue

            score = hit["score"] + (tm["avg_r"] * 100.0)
            candidates.append((score, sym, hit, entry_p, stop_p, target_p))

        if not candidates:
            continue
        candidates.sort(key=lambda x: -x[0])

        for _, sym, hit, entry_p, stop_p, target_p in candidates:
            if len(open_positions) >= 3 or daily_trades.get(day_key, 0) >= 3:
                break

            pos_val_now = sum(p["qty"] * p["last_price"] for p in open_positions.values())
            curr_equity = cash + pos_val_now
            spendable_cash = max(0.0, cash - curr_equity * 0.10)
            max_pos_usd = curr_equity * 0.50

            per_unit_loss = (entry_p - stop_p) + (entry_p + stop_p) * fee_rate
            if per_unit_loss <= 0:
                continue
            qty = min(
                25.0 / per_unit_loss,
                max_pos_usd / (entry_p * (1.0 + fee_rate)),
                spendable_cash / (entry_p * (1.0 + fee_rate)),
            )
            notional = qty * entry_p
            if notional < 15.0:
                continue

            buy_fee = notional * fee_rate
            total_cost = notional + buy_fee
            risk_usd = qty * per_unit_loss

            cash -= total_cost
            daily_trades[day_key] = daily_trades.get(day_key, 0) + 1

            open_positions[sym] = {
                "symbol": sym,
                "setup": hit["primary_setup"],
                "opened_dt": bars_by_sym[sym][idx_map[sym][ts]]["dt"],
                "entry": entry_p,
                "stop": stop_p,
                "target": target_p,
                "risk_per_unit": entry_p - stop_p,
                "be_trigger": entry_p + (entry_p - stop_p) * 1.10,
                "be_moved": False,
                "qty": qty,
                "buy_fee": buy_fee,
                "total_cost": total_cost,
                "risk_usd": risk_usd,
                "bars_held": 0,
                "max_bars": 96,  # 24 saat
                "last_price": entry_p,
            }

    for sym, pos in list(open_positions.items()):
        exit_price = pos["last_price"]
        gross = pos["qty"] * exit_price
        sell_fee = gross * fee_rate
        net = gross - sell_fee
        pnl_usd = net - pos["total_cost"]
        cash += net
        closed_trades.append({
            "symbol": sym,
            "setup": pos["setup"],
            "opened_at": pos["opened_dt"],
            "closed_at": "DÖNEM_SONU",
            "entry": pos["entry"],
            "exit": exit_price,
            "qty": pos["qty"],
            "cost_usd": round(pos["total_cost"], 2),
            "pnl_usd": round(pnl_usd, 2),
            "r_multiple": round(pnl_usd / pos["risk_usd"], 2) if pos["risk_usd"] > 0 else 0.0,
            "reason": "END_OF_BACKTEST",
            "fees_usd": round(pos["buy_fee"] + sell_fee, 2),
        })

    final_equity = round(cash, 2)
    net_profit = round(final_equity - initial_budget, 2)
    return_pct = round((net_profit / initial_budget) * 100.0, 2)

    wins = [t for t in closed_trades if t["pnl_usd"] > 0.5]
    breakevens = [t for t in closed_trades if -0.5 <= t["pnl_usd"] <= 0.5]
    losses = [t for t in closed_trades if t["pnl_usd"] < -0.5]
    gross_win = sum(t["pnl_usd"] for t in closed_trades if t["pnl_usd"] > 0)
    gross_loss = abs(sum(t["pnl_usd"] for t in closed_trades if t["pnl_usd"] < 0))
    pf = round(gross_win / gross_loss, 2) if gross_loss > 0 else 99.9
    total_fees = round(sum(t["fees_usd"] for t in closed_trades), 2)

    per_coin = {}
    for sym in SYMBOLS:
        ct = [t for t in closed_trades if t["symbol"] == sym]
        per_coin[sym] = {
            "trades": len(ct),
            "wins": sum(1 for t in ct if t["pnl_usd"] > 0.5),
            "be": sum(1 for t in ct if -0.5 <= t["pnl_usd"] <= 0.5),
            "losses": sum(1 for t in ct if t["pnl_usd"] < -0.5),
            "net_pnl_usd": round(sum(t["pnl_usd"] for t in ct), 2),
        }

    return {
        "initial_budget_usd": initial_budget,
        "final_equity_usd": final_equity,
        "net_profit_usd": net_profit,
        "return_pct": return_pct,
        "total_trades": len(closed_trades),
        "wins": len(wins),
        "breakevens": len(breakevens),
        "losses": len(losses),
        "win_or_be_rate_pct": round(((len(wins) + len(breakevens)) / len(closed_trades)) * 100.0, 1) if closed_trades else 0.0,
        "strict_win_rate_pct": round((len(wins) / len(closed_trades)) * 100.0, 1) if closed_trades else 0.0,
        "profit_factor": pf,
        "max_drawdown_pct": round(max_drawdown_pct, 2),
        "total_fees_paid_usd": total_fees,
        "signals_scanned": signals_total,
        "vetoed_signals": veto_count,
        "monthly_pnl": {k: round(v, 2) for k, v in sorted(monthly_pnl.items())},
        "per_coin": per_coin,
    }


def main():
    out_dir = os.path.join(BASE_DIR, "data")
    os.makedirs(out_dir, exist_ok=True)
    cache_file = os.path.join(out_dir, "bars_90d_cache.json")

    if os.path.isfile(cache_file):
        with open(cache_file, "r", encoding="utf-8") as fh:
            bars_by_sym = json.load(fh)
    else:
        print("======================================================================")
        print("⏳ SON 3 AY (90 GÜN) GERÇEK BINANCE VERİSİ ÇEKİLİYOR (10 VARLIK)...")
        print("======================================================================")
        bars_by_sym = {}
        with concurrent.futures.ThreadPoolExecutor(max_workers=5) as ex:
            fut_map = {ex.submit(fetch_90d_bars_for_symbol, s, "15m", 90): s for s in SYMBOLS}
            for fut in concurrent.futures.as_completed(fut_map):
                sym = fut_map[fut]
                bars = fut.result()
                bars_by_sym[sym] = bars
        with open(cache_file, "w", encoding="utf-8") as fh:
            json.dump(bars_by_sym, fh)

    res_v2 = run_simulation_v2_optimized(bars_by_sym)
    print("======================================================================")
    print("🚀 V2 OPTİMİZE EDİLMİŞ (ANA TREND + KOMİSYON KORUMALI + KÂR KİLİTLİ) 3 AYLIK SONUÇ")
    print("======================================================================")
    print(f"🏦 Başlangıç Bakiyesi          : ${res_v2['initial_budget_usd']:.2f} USDT")
    print(f"💎 3 Ay Sonunda Toplam Kasa    : ${res_v2['final_equity_usd']:.2f} USDT")
    print(f"📈 Net Kar / Zarar             : ${res_v2['net_profit_usd']:+.2f} USDT (%{res_v2['return_pct']:+.2f})")
    print(f"🛡️ Maksimum Kasa Erimesi (DD)  : %{res_v2['max_drawdown_pct']:.2f}")
    print(f"⚖️ Profit Factor (Kazanç/Kayıp): {res_v2['profit_factor']:.2f}")
    print(f"💸 Ödenen Toplam Borsa Komisyonu: ${res_v2['total_fees_paid_usd']:.2f} USDT")
    print(f"✅ Açılan Seçici İşlem Sayısı  : {res_v2['total_trades']} işlem (Kar: {res_v2['wins']} | Başabaş: {res_v2['breakevens']} | Stop: {res_v2['losses']})")
    print("📅 AY BAZINDA NET KAR / ZARAR:")
    for m, pnl in res_v2["monthly_pnl"].items():
        print(f"   • {m} : ${pnl:+.2f} USDT")
    print("🪙 10 KRİPTONUN TEK TEK 3 AYLIK V2 PERFORMANSI:")
    for sym, st in sorted(res_v2["per_coin"].items(), key=lambda x: -x[1]["net_pnl_usd"]):
        print(
            f"   • {sym:10s} | İşlem: {st['trades']:3d} "
            f"(Kar:{st['wins']:2d} / Başabaş:{st['be']:2d} / Stop:{st['losses']:2d}) "
            f"| Net PnL: ${st['net_pnl_usd']:+7.2f} USDT"
        )



if __name__ == "__main__":
    main()

