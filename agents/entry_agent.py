#!/usr/bin/env python3
"""4. Ajan: Giriş Zamanlayıcı Ajan (Entry Timer Agent) - day-trader-skill/trader-entry karşılığı.
Temel Kural:
  - Asla kapanmamış bir mumun iğnesiyle (wick) işleme girmez!
  - Kırılım seviyesinin (ORB High veya Seviye) üzerinde TAMAMLANMIŞ / KAPANMIŞ bir mum arar.
  - Sonucu `data/entry.json` dosyasına yazar.
"""

import datetime
import json
import os
from .market_data import fetch_klines, normalize_symbol
from .scanner_agent import session_orb_bars, compute_atr, wilder_rsi


def check_entry(
    symbol: str,
    setup: str = "orb",
    level: float = None,
    interval: str = "5m",
    or_minutes: int = 15,
    min_volume_x: float = 0.0,
    bars: list = None,
    forming: dict = None,
    write_path: str = "data/entry.json",
) -> dict:
    """Sembolün giriş koşulunu (WAITING / TRIGGERED / EXPIRED) mum bazında denetler."""
    sym = normalize_symbol(symbol)
    if bars is None:
        kdata = fetch_klines(sym, interval=interval, limit=120)
        bars = kdata["bars"]
        forming = kdata["forming"]

    now_iso = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    if len(bars) < 20:
        return {
            "created_by": "entry_agent",
            "symbol": sym,
            "setup": setup,
            "status": "no-data",
            "reason": "Yeterli kapanmış mum verisi yok",
            "checked_at": now_iso,
        }

    orb = session_orb_bars(bars, or_minutes=or_minutes)
    last_bar = bars[-1]
    closes = [b["c"] for b in bars]
    rsi_val = wilder_rsi(closes, 14) or 50.0
    atr_val = compute_atr(bars, 14)

    avg_vol = sum(b["qv"] for b in bars[-21:-1]) / 20.0 if len(bars) >= 21 else last_bar["qv"]
    vol_x = (last_bar["qv"] / avg_vol) if avg_vol > 0 else 1.0

    if setup == "orb" and orb:
        ref_level = level if level is not None else orb["or_high"]
        or_high = orb["or_high"]
        or_low = orb["or_low"]
    else:
        ref_level = level if level is not None else max(b["c"] for b in bars[-21:-1])
        ref_slice = bars[-4:-1] if len(bars) >= 4 else bars[-3:]
        or_high = orb["or_high"] if orb else max(b["h"] for b in ref_slice)
        or_low = orb["or_low"] if orb else min(b["l"] for b in ref_slice)

    # Kapanmış son mum seviyenin üzerinde mi?
    triggered = False
    reason = ""
    if last_bar["c"] > ref_level:
        if min_volume_x > 0 and vol_x < min_volume_x:
            triggered = False
            reason = f"Son mum {ref_level:.6g} üzerinde kapattı ({last_bar['c']:.6g}) ancak hacim yetersiz ({vol_x:.2f}x < {min_volume_x:.2f}x)"
        elif rsi_val > 82.0:
            triggered = False
            reason = f"RSI aşırı alım bölgesinde ({rsi_val:.1f} > 82): Tepen alma riskine karşı beklendi"
        else:
            triggered = True
            pct_over = ((last_bar["c"] / ref_level) - 1.0) * 100.0
            reason = (
                f"ONAYLANDI: {last_bar['dt']} mumu (bar #{len(bars)-1}) {ref_level:.6g} seviyesinin "
                f"%{pct_over:+.2f} üzerinde {last_bar['c']:.6g} fiyatından KAPANDI (Hacim: {vol_x:.2f}x)"
            )
    else:
        gap_pct = ((last_bar["c"] / ref_level) - 1.0) * 100.0
        reason = f"BEKLİYOR: Son kapanmış mum {last_bar['c']:.6g}, kırılım seviyesi {ref_level:.6g} ({gap_pct:+.2f}%)"
        if forming and forming["c"] > ref_level:
            reason += f" | Canlı mum şu an {forming['c']:.6g} seviyesinde ama henüz KAPANMADI (iğne tuzağına karşı kapanış bekleniyor)."

    doc = {
        "created_by": "entry_agent",
        "symbol": sym,
        "setup": setup,
        "side": "buy",
        "date": last_bar["dt"][:10],
        "status": "triggered" if triggered else "waiting",
        "time": last_bar["dt"][11:],
        "bar_start": last_bar["dt"],
        "bar_index": len(bars) - 1,
        "price": round(last_bar["c"], 6),
        "level": round(ref_level, 6),
        "interval": interval,
        "volume_x": round(vol_x, 2),
        "rsi": round(rsi_val, 1),
        "atr": round(atr_val, 6),
        "opening_range": {
            "high": round(or_high, 6),
            "low": round(or_low, 6),
            "minutes": or_minutes,
        },
        "forming_price": round(forming["c"], 6) if forming else None,
        "reason": reason,
        "checked_at": now_iso,
    }

    if write_path and triggered:
        os.makedirs(os.path.dirname(write_path) or ".", exist_ok=True)
        with open(write_path, "w", encoding="utf-8") as fh:
            json.dump(doc, fh, indent=2, ensure_ascii=False)
            fh.write("\n")

    return doc

