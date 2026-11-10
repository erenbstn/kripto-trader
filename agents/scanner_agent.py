#!/usr/bin/env python3
"""1. Ajan: Kripto Grafik Tarayıcı (Scanner Agent) - day-trader-skill/trader-scanner karşılığı.
7/24 Kripto piyasasında 5 dakikalık ve seanslık grafiklerde kurallara uyan kurulumları (setup) tarar:
  - orb:            Seans Açılış Aralığı Kırılımı (Opening Range Breakout - 4 saatlik / günlük seans ilk 15dk)
  - breakout_20d:   Son 20 mumun en yüksek kapanış ve tepe seviyesinin hacimli kırılımı
  - bull_flag:      Güçlü yükseliş direği sonrasında dar (%2.5 altı) bayrak sıkışması ve yukarı kırılım
  - reclaim_ma20:   20 periyotluk ortalamanın (MA20) altından üstüne hacimli geçiş
  - oversold_bounce:Wilder RSI(14) < 32 aşırı satım bölgesinden dönüş mumu
  - vwap_breakout:  Seans VWAP seviyesinin hacimli yukarı kırılımı
"""

import datetime
import json
import os
import time
from .market_data import fetch_klines, get_24h_tickers, discover_top_usdt_pairs, normalize_symbol


SETUP_LABELS = {
    "orb": "Açılış Aralığı Kırılımı (ORB)",
    "breakout_20d": "20-Bar Zirve Kırılımı",
    "bull_flag": "Boğa Bayrağı (Bull Flag) Kırılımı",
    "reclaim_ma20": "MA20 Ortalamasını Geri Kazanım",
    "oversold_bounce": "RSI Aşırı Satım Tepkisi (Oversold Bounce)",
    "vwap_breakout": "VWAP + Hacim Kırılımı",
}


def wilder_rsi(closes: list, period: int = 14):
    """day-trader-skill'deki orijinal Wilder RSI(14) hesaplaması."""
    if len(closes) < period + 1:
        return None
    gains = [max(0.0, closes[i] - closes[i - 1]) for i in range(1, len(closes))]
    losses = [max(0.0, closes[i - 1] - closes[i]) for i in range(1, len(closes))]
    avg_g = sum(gains[:period]) / period
    avg_l = sum(losses[:period]) / period
    for i in range(period, len(gains)):
        avg_g = (avg_g * (period - 1) + gains[i]) / period
        avg_l = (avg_l * (period - 1) + losses[i]) / period
    if avg_l == 0:
        return 100.0
    return 100.0 - (100.0 / (1.0 + avg_g / avg_l))


def compute_atr(bars: list, period: int = 14) -> float:
    """Son `period` mumun Gerçek Ortalama Aralığı (ATR)."""
    if not bars:
        return 0.0
    trs = []
    prev_c = None
    for b in bars:
        tr = b["h"] - b["l"]
        if prev_c is not None:
            tr = max(tr, abs(b["h"] - prev_c), abs(b["l"] - prev_c))
        trs.append(tr)
        prev_c = b["c"]
    use = trs[-period:]
    return sum(use) / len(use) if use else 0.0


def session_orb_bars(bars: list, or_minutes: int = 15, bar_minutes: int = 5):
    """7/24 Kriptoda en güncel 4 saatlik seansın (00:00, 04:00, 08:00, 12:00, 16:00, 20:00 UTC)
    ilk `or_minutes` (varsayılan 15 dk = 3 adet 5dk mum) açılış aralığını (Opening Range) bulur.
    Eğer seans henüz yeni başladıysa (3 mumdan az olduysa), bir önceki 4 saatlik seansı baz alır.
    """
    n_or = max(1, or_minutes // bar_minutes)
    if len(bars) < n_or + 2:
        return None

    last_bar = bars[-1]
    last_dt = datetime.datetime.fromtimestamp(last_bar["t"], datetime.timezone.utc)
    session_hour = (last_dt.hour // 4) * 4
    session_start = last_dt.replace(hour=session_hour, minute=0, second=0, microsecond=0)
    session_start_ts = int(session_start.timestamp())

    s_bars = [b for b in bars if b["t"] >= session_start_ts]
    if len(s_bars) <= n_or:
        # Yeni 4s seans henüz OR aralığını tamamlamadıysa bir önceki 4s seansa bak
        prev_start_ts = session_start_ts - 4 * 3600
        s_bars = [b for b in bars if b["t"] >= prev_start_ts]

    if len(s_bars) <= n_or:
        s_bars = bars[-min(len(bars), 36):]

    or_slice = s_bars[:n_or]
    after_slice = s_bars[n_or:]
    if not or_slice or not after_slice:
        return None

    or_high = max(b["h"] for b in or_slice)
    or_low = min(b["l"] for b in or_slice)
    or_vol_avg = sum(b["qv"] for b in or_slice) / len(or_slice)
    return {
        "or_high": or_high,
        "or_low": or_low,
        "or_mid": (or_high + or_low) / 2.0,
        "or_minutes": or_minutes,
        "or_vol_avg": or_vol_avg,
        "session_bars": s_bars,
        "after_bars": after_slice,
    }


def analyze_symbol_setups(symbol: str, bars: list, or_minutes: int = 15):
    """Tek bir kripto paritesinin kapanmış mumları üzerinde tüm kurulumları (setups) denetler."""
    if len(bars) < 30:
        return None

    closes = [b["c"] for b in bars]
    highs = [b["h"] for b in bars]
    lows = [b["l"] for b in bars]
    qvols = [b["qv"] for b in bars]

    last = bars[-1]
    prev = bars[-2]
    c_last = last["c"]
    c_prev = prev["c"]

    rsi_now = wilder_rsi(closes, 14)
    rsi_prev = wilder_rsi(closes[:-1], 14)
    atr_14 = compute_atr(bars, 14)

    ma20_now = sum(closes[-20:]) / 20.0
    ma20_prev = sum(closes[-21:-1]) / 20.0
    hi20_close = max(closes[-21:-1])
    hi20_high = max(highs[-21:-1])
    avg_vol_20 = sum(qvols[-21:-1]) / 20.0 if sum(qvols[-21:-1]) > 0 else 1.0
    vol_ratio = last["qv"] / avg_vol_20

    # VWAP (son 24 bar = 2 saatlik intraday VWAP)
    vwap_slice = bars[-24:]
    tot_v = sum(b["v"] for b in vwap_slice)
    vwap = sum(((b["h"] + b["l"] + b["c"]) / 3.0) * b["v"] for b in vwap_slice) / tot_v if tot_v > 0 else c_last

    # Bull Flag: 15 bar öncesinden 5 bar öncesine en az %1.8 yükseliş direği + son 5 bar dar sıkışma + son bar yukarı kırılım
    pole_run = (closes[-6] / closes[-16]) - 1.0 if closes[-16] > 0 else 0.0
    flag_high = max(highs[-6:-1])
    flag_low = min(lows[-6:-1])
    flag_range = (flag_high - flag_low) / c_last if c_last > 0 else 1.0

    # ORB (Opening Range Breakout)
    orb_info = session_orb_bars(bars, or_minutes=or_minutes)

    setups = []
    primary_level = hi20_high
    or_high = None
    or_low = None

    # 1. ORB Kırılımı: Son kapanmış mum (veya son 2 mum içinde) OR High üzerinde kapattıysa
    if orb_info and orb_info["or_high"] > orb_info["or_low"]:
        oh = orb_info["or_high"]
        ol = orb_info["or_low"]
        or_high, or_low = oh, ol
        # Son mum ORB seviyesini yukarı kırdıysa veya üzerinde güçlü kapattıysa (%0.02 ile %2.0 arası)
        pct_over_orb = (c_last / oh - 1.0) * 100.0
        if c_last > oh and (c_prev <= oh * 1.003 or len(orb_info["after_bars"]) <= 6) and 0.01 <= pct_over_orb <= 2.5:
            setups.append("orb")
            primary_level = oh

    # 2. 20-Bar Zirve Kırılımı
    if c_last > hi20_close and c_prev <= hi20_close and vol_ratio >= 1.1:
        setups.append("breakout_20d")
        if "orb" not in setups:
            primary_level = hi20_close

    # 3. Bull Flag Kırılımı
    if pole_run >= 0.018 and flag_range <= 0.022 and c_last > flag_high:
        setups.append("bull_flag")
        if not setups or setups[-1] == "bull_flag":
            primary_level = flag_high

    # 4. MA20 Reclaim (20 ortalama geri kazanımı + hacim)
    if c_prev < ma20_prev and c_last > ma20_now and vol_ratio >= 1.15 and c_last > last["o"]:
        setups.append("reclaim_ma20")
        if len(setups) == 1:
            primary_level = ma20_now

    # 5. RSI Oversold Bounce (RSI < 32 sonrası güçlü yeşil dönüş mumu)
    if rsi_prev is not None and rsi_prev < 32.0 and c_last > c_prev and c_last > last["o"]:
        setups.append("oversold_bounce")
        if len(setups) == 1:
            primary_level = c_prev

    # 6. VWAP + Hacim Kırılımı
    if c_prev <= vwap and c_last > vwap and vol_ratio >= 1.4 and (rsi_now or 50) < 74:
        setups.append("vwap_breakout")
        if len(setups) == 1:
            primary_level = vwap

    if not setups:
        return None

    # Aşırı şişmiş mumları (RSI > 82) filtrele
    if rsi_now is not None and rsi_now > 82.0:
        return None

    # Kalite puanı (Birden fazla setup çakışması + hacim oranı)
    score = len(setups) * 25.0 + min(vol_ratio * 15.0, 45.0)
    if "orb" in setups:
        score += 15.0
    if "bull_flag" in setups or "breakout_20d" in setups:
        score += 10.0

    # Eğer ORB yoksa son 15dk (3 mum) aralığını referans OR olarak ata
    if or_high is None or or_low is None:
        ref_bars = bars[-4:-1] if len(bars) >= 4 else bars[-3:]
        or_high = max(b["h"] for b in ref_bars)
        or_low = min(b["l"] for b in ref_bars)
        if or_high <= or_low:
            or_low = c_last - max(atr_14 * 1.5, c_last * 0.008)

    return {
        "symbol": symbol,
        "setups": setups,
        "setup_labels": [SETUP_LABELS.get(s, s) for s in setups],
        "primary_setup": setups[0],
        "price": round(c_last, 6),
        "level": round(primary_level, 6),
        "or_high": round(or_high, 6),
        "or_low": round(or_low, 6),
        "atr": round(atr_14, 6),
        "rsi": round(rsi_now, 1) if rsi_now is not None else 50.0,
        "ma20": round(ma20_now, 6),
        "vwap": round(vwap, 6),
        "volume_ratio": round(vol_ratio, 2),
        "bar_time": last["dt"],
        "bar_index": len(bars) - 1,
        "score": round(score, 1),
    }


def scan_market(config: dict, symbols: list = None, write_path: str = "data/watchlist.json", offline_data: dict = None):
    """Tüm izleme listesindeki kripto paritelerini tarar ve en güçlü sinyalleri sıralar."""
    interval = config.get("interval", "5m")
    or_minutes = int(config.get("or_minutes", 15))
    blocked = {normalize_symbol(s) for s in (config.get("blocked") or [])}

    if not symbols:
        symbols = config.get("watchlist_symbols") or [
            "ONDOUSDT", "HBARUSDT", "BTCUSDT", "SIRENUSDT", "XAGUSDT",
            "LINKUSDT", "SOLUSDT", "PAXGUSDT", "XRPUSDT", "ETHUSDT",
        ]

    norm_syms = []
    for s in symbols:
        ns = normalize_symbol(s)
        if ns not in blocked and ns not in norm_syms:
            norm_syms.append(ns)

    hits = []
    failed = {}
    scanned = 0

    for sym in norm_syms:
        try:
            off_bars = (offline_data or {}).get(sym)
            kdata = fetch_klines(sym, interval=interval, limit=120, offline_bars=off_bars)
            bars = kdata["bars"]
            if len(bars) < 30:
                continue
            scanned += 1
            hit = analyze_symbol_setups(sym, bars, or_minutes=or_minutes)
            if hit:
                hits.append(hit)
            if not offline_data:
                time.sleep(0.08)
        except Exception as exc:
            failed[sym] = str(exc)

    hits.sort(key=lambda h: (-h["score"], -h["volume_ratio"], h["symbol"]))

    doc = {
        "created_by": "scanner_agent",
        "as_of": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "interval": interval,
        "requested": len(norm_syms),
        "scanned": scanned,
        "failed_count": len(failed),
        "hits_count": len(hits),
        "hits": hits,
        "note": "Tarama sonucu kural eşleşmesidir; işlem kararı News, Whale, TimeMachine ve Risk ajanlarından geçtikten sonra verilir.",
    }

    if write_path:
        os.makedirs(os.path.dirname(write_path) or ".", exist_ok=True)
        with open(write_path, "w", encoding="utf-8") as fh:
            json.dump(doc, fh, indent=2, ensure_ascii=False)
            fh.write("\n")

    return doc

