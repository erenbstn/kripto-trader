#!/usr/bin/env python3
"""5. Ajan: Çıkış Planlayıcı Ajan (Exit Planner Agent) - day-trader-skill/trader-exit karşılığı.
İşleme girmeden ÖNCE Stop-Loss, Take-Profit, +1R Breakeven (Başabaş) seviyesi ve
Maksimum Tutma Süresini belirler.
- Çok dar stopları (< %0.20, spread ve komisyon gürültüsü içinde kalacakları) reddeder.
- Çok geniş stopları (> %6.0) ATR tabanlı makul seviyeye çeker veya reddeder.
- Planı `data/plan.json` dosyasına yazar.
"""

import datetime
import json
import os


class ExitPlanError(Exception):
    pass


def _smart_round(val: float, ref_price: float) -> float:
    if ref_price >= 1000:
        return round(val, 2)
    if ref_price >= 10:
        return round(val, 3)
    if ref_price >= 1:
        return round(val, 4)
    if ref_price >= 0.01:
        return round(val, 6)
    return round(val, 8)


def build_exit_plan(
    entry_doc: dict,
    config: dict,
    stop_rule: str = "auto",
    target_r: float = None,
    write_path: str = "data/plan.json",
) -> dict:
    """Tetiklenmiş bir giriş sinyalinden (entry_doc) tam çıkış planı oluşturur."""
    if not entry_doc or entry_doc.get("status") != "triggered":
        raise ExitPlanError("Giriş sinyali henüz onaylanmadı (status != triggered)")

    sym = entry_doc["symbol"]
    entry_price = float(entry_doc["price"])
    if entry_price <= 0:
        raise ExitPlanError(f"Geçersiz giriş fiyatı: {entry_price}")

    orr = entry_doc.get("opening_range") or {}
    or_high = float(orr.get("high") or entry_price)
    or_low = float(orr.get("low") or (entry_price * 0.99))
    atr = float(entry_doc.get("atr") or (entry_price * 0.005))

    target_r_val = float(target_r if target_r is not None else config.get("default_target_r", 2.0))
    breakeven_r = float(config.get("breakeven_at_r", 1.0))
    max_hold_minutes = int(config.get("max_hold_minutes", 240))

    # Stop seviyesini belirle (day-trader-skill kuralları: or_mid, or_low, atr:1.5, pct:X)
    if stop_rule == "auto":
        or_mid = (or_high + or_low) / 2.0
        dist_mid_pct = (entry_price - or_mid) / entry_price if entry_price > 0 else 0
        if 0.003 <= dist_mid_pct <= 0.035:
            raw_stop = or_mid
            chosen_rule = "or_mid"
            stop_label = "Açılış Aralığı Orta Noktası (OR-Mid)"
        elif 0.003 <= ((entry_price - or_low) / entry_price) <= 0.04:
            raw_stop = or_low
            chosen_rule = "or_low"
            stop_label = "Açılış Aralığı Dip Seviyesi (OR-Low)"
        else:
            atr_dist = max(atr * 1.8, entry_price * 0.006)
            atr_dist = min(atr_dist, entry_price * 0.035)
            raw_stop = entry_price - atr_dist
            chosen_rule = "atr"
            stop_label = "1.8x ATR(14) Volatilite Stopu"
    elif stop_rule == "or_mid":
        raw_stop = (or_high + or_low) / 2.0
        chosen_rule = "or_mid"
        stop_label = "Açılış Aralığı Orta Noktası (OR-Mid)"
    elif stop_rule == "or_low":
        raw_stop = or_low
        chosen_rule = "or_low"
        stop_label = "Açılış Aralığı Dip Seviyesi (OR-Low)"
    elif stop_rule.startswith("pct:"):
        pct_val = float(stop_rule.split(":", 1)[1])
        raw_stop = entry_price * (1.0 - pct_val / 100.0)
        chosen_rule = "pct"
        stop_label = f"Girişin %{pct_val:.2f} Altı"
    else:
        atr_dist = max(atr * 1.8, entry_price * 0.006)
        raw_stop = entry_price - atr_dist
        chosen_rule = "atr"
        stop_label = "1.8x ATR(14) Volatilite Stopu"

    # Kriptoda komisyon + spread gürültüsüne takılmamak için minimum %0.35 stop mesafesi garantisi
    min_stop_dist = entry_price * 0.0035
    if (entry_price - raw_stop) < min_stop_dist:
        raw_stop = entry_price - max(min_stop_dist, atr * 1.5)
        stop_label += " (Min %0.35 Spread Koruması Eklendi)"

    stop_price = _smart_round(raw_stop, entry_price)
    if stop_price >= entry_price:
        raise ExitPlanError(f"Stop fiyatı ({stop_price}) giriş fiyatının ({entry_price}) altında olmalı")

    risk_per_unit = entry_price - stop_price
    risk_pct = (risk_per_unit / entry_price) * 100.0
    if risk_pct < 0.15:
        raise ExitPlanError(f"Stop mesafesi çok dar (%{risk_pct:.2f}): Normal piyasa dalgalanmasında stop olur.")

    target_price = _smart_round(entry_price + (risk_per_unit * target_r_val), entry_price)
    breakeven_trigger = _smart_round(entry_price + (risk_per_unit * breakeven_r), entry_price)
    reward_risk = round((target_price - entry_price) / risk_per_unit, 2)

    now_utc = datetime.datetime.now(datetime.timezone.utc)
    flat_by_dt = now_utc + datetime.timedelta(minutes=max_hold_minutes)

    plan = {
        "created_by": "exit_agent",
        "symbol": sym,
        "side": "buy",
        "date": entry_doc.get("date") or now_utc.strftime("%Y-%m-%d"),
        "setup": entry_doc.get("setup", "orb"),
        "interval": entry_doc.get("interval", "5m"),
        "entry": _smart_round(entry_price, entry_price),
        "entry_time": entry_doc.get("time", now_utc.strftime("%H:%M")),
        "entry_bar": entry_doc.get("bar_index", 0),
        "opening_range": orr,
        "stop": stop_price,
        "stop_rule": chosen_rule,
        "stop_label": stop_label,
        "stop_pct": round(risk_pct, 3),
        "target": target_price,
        "target_r": target_r_val,
        "target_label": f"{target_r_val:g}R Hedef ({target_r_val:g}x Risk)",
        "breakeven_trigger": breakeven_trigger,
        "breakeven_at_r": breakeven_r,
        "risk_per_share": _smart_round(risk_per_unit, entry_price),
        "reward_risk": reward_risk,
        "max_hold_minutes": max_hold_minutes,
        "max_hold_bars": max(6, max_hold_minutes // 5),
        "flat_by": flat_by_dt.strftime("%Y-%m-%d %H:%M UTC"),
        "created_at": now_utc.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "note": "Stop ve hedef işleme girmeden önce kilitlendi. +1R karda stop otomatik olarak girişe (Breakeven) çekilir.",
    }

    if write_path:
        os.makedirs(os.path.dirname(write_path) or ".", exist_ok=True)
        with open(write_path, "w", encoding="utf-8") as fh:
            json.dump(plan, fh, indent=2, ensure_ascii=False)
            fh.write("\n")

    return plan

