#!/usr/bin/env python3
"""10. Ajan: Canlı Pozisyon ve Fiyat Alarm Takipçisi (Alerts & Live Position Monitor Agent)
day-trader-skill/trader-alerts/alerts.py karşılığıdır.
- Açık olan tüm sanal pozisyonları gerçek zamanlı izler.
- Fiyat +1R (breakeven_trigger) seviyesine ulaştığında Stop-Loss'u otomatik olarak
  giriş fiyatına (komisyon üstüne) çeker ve bildirim üretir!
- Fiyat Stop-Loss'a veya Take-Profit'e değdiğinde ya da maksimum tutma süresi (flat_by)
  dolduğunda pozisyonu otomatik kapatır ve bildirim listesi döndürür.
"""

import datetime
from .broker_agent import load_portfolio, close_paper_position, recalc_portfolio_stats, _atomic_write_json
from .market_data import get_live_prices, fetch_klines


def monitor_open_positions(
    config: dict,
    portfolio_path: str = "data/portfolio.json",
    log_path: str = "data/broker_log.json",
    live_prices_override: dict = None,
    bar_extremes_override: dict = None,
) -> dict:
    """Açık pozisyonları kontrol eder; kapanan pozisyonları ve breakeven güncellemelerini döndürür."""
    pf = load_portfolio(config, path=portfolio_path)
    positions = list(pf.get("positions") or [])
    if not positions:
        return {"closed_events": [], "breakeven_events": [], "portfolio": pf}

    syms = [p["symbol"] for p in positions]
    live_prices = live_prices_override if live_prices_override is not None else get_live_prices(syms)

    now_utc = datetime.datetime.now(datetime.timezone.utc)
    now_iso = now_utc.strftime("%Y-%m-%dT%H:%M:%SZ")

    closed_events = []
    breakeven_events = []
    changed = False

    for pos in positions:
        sym = pos["symbol"]
        cur_price = live_prices.get(sym)
        if cur_price is None or cur_price <= 0:
            continue

        # Son mumun en yüksek / en düşük değerlerini de kontrol et (iki kontrol arasında iğne atıp döndüyse yakala)
        bar_high = cur_price
        bar_low = cur_price
        if bar_extremes_override and sym in bar_extremes_override:
            bar_high = max(cur_price, float(bar_extremes_override[sym].get("high", cur_price)))
            bar_low = min(cur_price, float(bar_extremes_override[sym].get("low", cur_price)))

        stop_p = float(pos["stop_loss"])
        target_p = float(pos["take_profit"])
        be_trig = pos.get("breakeven_trigger")
        entry_p = float(pos["entry_price"])

        # 1. Önce STOP kontrolü (day-trader-skill muhafazakar kuralı)
        if bar_low <= stop_p or cur_price <= stop_p:
            fill_price = stop_p if bar_low <= stop_p else cur_price
            reason = "BREAKEVEN_STOP (Başabaş Stop)" if pos.get("breakeven_moved") else "STOP_LOSS (Zarar Kes)"
            res = close_paper_position(
                symbol=sym,
                exit_price=fill_price,
                reason=reason,
                config=config,
                portfolio_path=portfolio_path,
                log_path=log_path,
            )
            closed_events.append(res["trade"])
            pf = res["portfolio"]
            continue

        # 2. TARGET (Kar Al) kontrolü
        if bar_high >= target_p or cur_price >= target_p:
            fill_price = target_p if bar_high >= target_p else cur_price
            res = close_paper_position(
                symbol=sym,
                exit_price=fill_price,
                reason="TAKE_PROFIT (Hedef Geldi 🎯)",
                config=config,
                portfolio_path=portfolio_path,
                log_path=log_path,
            )
            closed_events.append(res["trade"])
            pf = res["portfolio"]
            continue

        # 3. Süre Sınırı (flat_by / Time Stop) kontrolü
        flat_by_str = pos.get("flat_by")
        if flat_by_str and now_iso >= flat_by_str:
            res = close_paper_position(
                symbol=sym,
                exit_price=cur_price,
                reason="TIME_EXIT (Seans / Süre Doldu ⏰)",
                config=config,
                portfolio_path=portfolio_path,
                log_path=log_path,
            )
            closed_events.append(res["trade"])
            pf = res["portfolio"]
            continue

        # 4. +1R Breakeven ve İz Süren Kâr Kilidi (Trailing Profit Lock) kontrolü
        if be_trig and (bar_high >= float(be_trig) or cur_price >= float(be_trig)):
            risk_u = max(abs(float(be_trig) - entry_p), entry_p * 0.004)
            # +1R geçildiğinde en az +0.35R net kârı kilitle, fiyat yükseldikçe 1.0R geriden iz sür (Trailing Stop)
            peak_p = max(bar_high, cur_price)
            locked_stop = max(entry_p * 1.0022, entry_p + 0.35 * risk_u, peak_p - 1.0 * risk_u)
            new_stop = round(locked_stop, 6)
            if new_stop > stop_p * 1.0005 and new_stop < cur_price:
                was_already_moved = bool(pos.get("breakeven_moved"))
                pos["stop_loss"] = new_stop
                pos["breakeven_moved"] = True
                changed = True
                if not was_already_moved:
                    breakeven_events.append({
                        "symbol": sym,
                        "current_price": cur_price,
                        "old_stop": stop_p,
                        "new_stop": new_stop,
                        "entry_price": entry_p,
                    })

    if changed or live_prices:
        pf = load_portfolio(config, path=portfolio_path)
        if changed:
            # breakeven güncellemesini kaydet
            for p in pf["positions"]:
                for b_ev in breakeven_events:
                    if p["symbol"] == b_ev["symbol"]:
                        p["stop_loss"] = b_ev["new_stop"]
                        p["breakeven_moved"] = True
        recalc_portfolio_stats(pf, live_prices)
        _atomic_write_json(portfolio_path, pf)

    return {
        "closed_events": closed_events,
        "breakeven_events": breakeven_events,
        "portfolio": pf,
    }

