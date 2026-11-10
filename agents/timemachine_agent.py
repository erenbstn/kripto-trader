#!/usr/bin/env python3
"""6. Ajan: Zaman Makinesi (TimeMachine Agent) - day-trader-skill/trader-timemachine karşılığı.
Bir kuruş bile riske atmadan önce planlanan işlemi coinin kendi geçmiş 5 dakikalık mumlarından
10.000 kez yeniden oynatır (Monte Carlo Simülasyonu) VE aynı kuralı geçmiş seanslarda
gerçekten çalıştırarak (Historical Replay) dürüst olasılıkları hesaplar:
  - p_target:  Önce hedefe (Take-Profit) ulaşma olasılığı
  - p_stop:    Önce stopa (Stop-Loss) değme olasılığı (aynı mumda ikisine de değerse muhafazakar olarak STOP sayılır!)
  - p_neither: Süre sonunda (max_hold_bars) hala açık kalma olasılığı
  - p_green:   İşlemin karda bitme olasılığı
  - avg_R:     10.000 senaryonun ortalama R getirisi
  - verdict:   Net karar ("Güçlü Hedef Eğilimi", "Hedef Eğilimli", "Başabaşa Yakın / Yazı-Tura", "Stop Eğilimli")
  - approved:  Otonom modda simülasyon pozitif beklentiye sahipse True, değilse False (VETO).
"""

import datetime
import json
import os
import random
import statistics
from .market_data import fetch_klines, normalize_symbol

COIN_FLIP_THRESHOLD = 0.04
STRONG_THRESHOLD = 0.14


class TimeMachineError(Exception):
    pass


def _pct(sorted_arr: list, q: float) -> float:
    if not sorted_arr:
        return 0.0
    idx = min(len(sorted_arr) - 1, max(0, int(q * len(sorted_arr))))
    return sorted_arr[idx]


def build_ratio_pool(bars: list, session_len: int = 48):
    """Geçmiş 5dk mumları seans dilimlerine göre (o/pc, h/pc, l/pc, c/pc) oran havuzuna dönüştürür."""
    if len(bars) < 60:
        raise TimeMachineError(f"TimeMachine için en az 60 geçmiş mum gerekli (mevcut: {len(bars)})")

    pool = [[] for _ in range(session_len)]
    all_ratios = []
    # Son mum (giriş mumu) hariç geçmiş mumlardan havuz oluştur
    hist = bars[:-1]
    for i in range(1, len(hist)):
        pc = hist[i - 1]["c"]
        if pc <= 0:
            continue
        b = hist[i]
        ratio_tuple = (b["o"] / pc, b["h"] / pc, b["l"] / pc, b["c"] / pc)
        slot = i % session_len
        pool[slot].append(ratio_tuple)
        all_ratios.append(ratio_tuple)

    for s in range(session_len):
        if not pool[s]:
            pool[s] = all_ratios
    return pool


def simulate_monte_carlo(
    pool: list,
    entry: float,
    stop: float,
    target: float,
    bars_to_replay: int = 48,
    replays: int = 10000,
    seed: int = 19,
    window: int = 2,
    side: str = "buy",
) -> dict:
    """day-trader-skill/timemachine.py ile birebir aynı Monte Carlo motoru.
    Her adımda önce STOP kontrol edilir, sonra TARGET (muhafazakar kural).
    """
    is_long = side == "buy"
    risk = (entry - stop) if is_long else (stop - entry)
    if risk <= 0:
        raise TimeMachineError("Risk 0 veya negatif olamaz")
    r_target = round(((target - entry) if is_long else (entry - target)) / risk, 4)

    session_len = len(pool)
    rng = random.Random(seed)
    choice = rng.choice
    randint = rng.randint

    outcomes = []
    closes = []
    sample_paths = []

    for n in range(replays):
        p = entry
        outcome = None
        keep_path = n < 50
        path = [entry]

        for step in range(bars_to_replay):
            slot = (step + randint(-window, window)) % session_len if window > 0 else (step % session_len)
            o_r, h_r, l_r, c_r = choice(pool[slot])
            hi = p * h_r
            lo = p * l_r
            cl = p * c_r

            if outcome is None:
                if is_long:
                    if lo <= stop:
                        outcome = "stop"  # Aynı mumda ikisine de değerse STOP sayılır
                    elif hi >= target:
                        outcome = "target"
                else:
                    if hi >= stop:
                        outcome = "stop"
                    elif lo <= target:
                        outcome = "target"
            p = cl
            if keep_path:
                path.append(round(p, 6))

        outcomes.append(outcome or "close")
        closes.append(p)
        if keep_path:
            sample_paths.append(path)

    cnt_target = outcomes.count("target")
    cnt_stop = outcomes.count("stop")
    cnt_close = outcomes.count("close")
    green = sum(
        1 for o, p in zip(outcomes, closes)
        if o == "target" or (o == "close" and (p > entry if is_long else p < entry))
    )

    r_values = [
        r_target if o == "target" else -1.0 if o == "stop" else (((p - entry) if is_long else (entry - p)) / risk)
        for o, p in zip(outcomes, closes)
    ]

    srt = sorted(closes)
    return {
        "replays": replays,
        "seed": seed,
        "window": window,
        "bars_left": bars_to_replay,
        "p_target": round(cnt_target / replays, 4),
        "p_stop": round(cnt_stop / replays, 4),
        "p_neither": round(cnt_close / replays, 4),
        "p_green": round(green / replays, 4),
        "median_close": round(_pct(srt, 0.50), 6),
        "p5_close": round(_pct(srt, 0.05), 6),
        "p95_close": round(_pct(srt, 0.95), 6),
        "avg_R": round(statistics.mean(r_values), 3),
        "r_at_target": r_target,
        "sample_paths": sample_paths[:10],
    }


def replay_historical_sessions(bars: list, plan: dict, session_bars: int = 48) -> dict:
    """Geçmiş veriyi 4 saatlik (48 bar) pencerelere bölerek aynı ORB/Breakout kuralını
    gerçek geçmiş seanslar üzerinde test eder (Backtest).
    """
    or_bars = max(2, int((plan.get("opening_range") or {}).get("minutes", 15)) // 5)
    target_r = float(plan.get("target_r", 2.0))
    stop_pct = float(plan.get("stop_pct", 0.8)) / 100.0

    hist_bars = bars[:-1]
    total_windows = len(hist_bars) // session_bars
    trades = []

    for w in range(total_windows):
        chunk = hist_bars[w * session_bars : (w + 1) * session_bars]
        if len(chunk) < or_bars + 6:
            continue
        oh = max(b["h"] for b in chunk[:or_bars])
        ol = min(b["l"] for b in chunk[:or_bars])
        trig_idx = next((i for i in range(or_bars, len(chunk) - 2) if chunk[i]["c"] > oh), None)
        if trig_idx is None:
            continue

        e_price = chunk[trig_idx]["c"]
        if plan.get("stop_rule") == "or_mid" and (oh + ol) / 2.0 < e_price:
            s_price = (oh + ol) / 2.0
        elif plan.get("stop_rule") == "or_low" and ol < e_price:
            s_price = ol
        else:
            s_price = e_price * (1.0 - max(stop_pct, 0.004))

        risk = e_price - s_price
        if risk <= 0:
            continue
        t_price = e_price + target_r * risk

        outcome = None
        for b in chunk[trig_idx + 1 :]:
            if b["l"] <= s_price:
                outcome = "stop"
                break
            if b["h"] >= t_price:
                outcome = "target"
                break

        close_end = chunk[-1]["c"]
        r_mult = target_r if outcome == "target" else (-1.0 if outcome == "stop" else (close_end - e_price) / risk)
        trades.append({
            "window": w + 1,
            "dt": chunk[trig_idx]["dt"],
            "entry": round(e_price, 6),
            "stop": round(s_price, 6),
            "target": round(t_price, 6),
            "outcome": outcome or "close",
            "R": round(r_mult, 2),
        })

    return {
        "sessions": total_windows,
        "triggered": len(trades),
        "target": sum(1 for t in trades if t["outcome"] == "target"),
        "stop": sum(1 for t in trades if t["outcome"] == "stop"),
        "close": sum(1 for t in trades if t["outcome"] == "close"),
        "green": sum(1 for t in trades if t["R"] > 0),
        "avg_R": round(statistics.mean(t["R"] for t in trades), 3) if trades else 0.0,
        "trades": trades[-10:],
    }


def evaluate_verdict(mc: dict, min_avg_r: float = 0.05):
    """Simülasyon sonucunu R-çarpanına göre başabaş (break-even) oranıyla kıyaslar."""
    pt = mc["p_target"]
    ps = mc["p_stop"]
    r_target = mc.get("r_at_target") or 1.0
    even_share = 1.0 / (1.0 + r_target)  # Örn: 1R için %50, 2R için %33.3

    if (pt + ps) <= 0:
        return "Hedef veya Stopa Ulaşmadı (Nötr)", False, 0.0, even_share

    win_share = pt / (pt + ps)
    diff = win_share - even_share
    avg_r = mc["avg_R"]

    if diff >= STRONG_THRESHOLD:
        head = "Güçlü Hedef Eğilimi (Pozitif Edge)"
    elif diff >= COIN_FLIP_THRESHOLD:
        head = "Hedef Eğilimli (Pozitif Beklenti)"
    elif diff > -COIN_FLIP_THRESHOLD:
        head = "Başabaşa Yakın / Yazı-Tura (Coin Flip)"
    elif diff > -STRONG_THRESHOLD:
        head = "Stop Eğilimli (Negatif Beklenti)"
    else:
        head = "Güçlü Stop Eğilimi (Yüksek Risk)"

    verdict_text = (
        f"{head}: {r_target:g}R hedefte başabaş için gereken %{even_share*100:.0f}, "
        f"simülasyonda gerçekleşen %{win_share*100:.1f} (Hedef: %{pt*100:.1f} vs Stop: %{ps*100:.1f} | Ortalama R: {avg_r:+.3f})"
    )

    # Otonom onay kriteri: Ortalama R >= min_avg_r VE (win_share >= even_share veya p_green >= 0.53)
    approved = (avg_r >= min_avg_r) and (diff >= -0.01 or mc["p_green"] >= 0.54)
    return verdict_text, approved, round(win_share, 4), round(even_share, 4)


def run_timemachine(
    plan: dict,
    config: dict,
    bars: list = None,
    write_path: str = "data/timemachine.json",
) -> dict:
    """Planlanan işlem için 10.000 Monte Carlo + Geçmiş Seans Backtest çalıştırır."""
    sym = normalize_symbol(plan["symbol"])
    interval = plan.get("interval", "5m")

    if bars is None:
        kdata = fetch_klines(sym, interval=interval, limit=1000)
        bars = kdata["bars"]

    bars_left = int(plan.get("max_hold_bars", 48))
    replays = int(config.get("timemachine_replays", 10000))
    seed = int(config.get("timemachine_seed", 19))
    min_avg_r = float(config.get("timemachine_min_avg_r", 0.05))

    pool = build_ratio_pool(bars, session_len=bars_left)
    mc = simulate_monte_carlo(
        pool=pool,
        entry=float(plan["entry"]),
        stop=float(plan["stop"]),
        target=float(plan["target"]),
        bars_to_replay=bars_left,
        replays=replays,
        seed=seed,
        window=2,
        side=plan.get("side", "buy"),
    )
    history = replay_historical_sessions(bars, plan, session_bars=bars_left)
    verdict_text, approved, win_share, even_share = evaluate_verdict(mc, min_avg_r=min_avg_r)

    doc = {
        "created_by": "timemachine_agent",
        "created_at": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "symbol": sym,
        "bars_analyzed": len(bars),
        "plan": plan,
        "mc": mc,
        "history": history,
        "verdict": verdict_text,
        "win_share_of_decided": win_share,
        "breakeven_share_needed": even_share,
        "approved": approved,
    }

    if write_path:
        os.makedirs(os.path.dirname(write_path) or ".", exist_ok=True)
        with open(write_path, "w", encoding="utf-8") as fh:
            json.dump(doc, fh, indent=2, ensure_ascii=False)
            fh.write("\n")

    return doc

