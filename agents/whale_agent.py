#!/usr/bin/env python3
"""3. Ajan: Balina, Emir Defteri (Orderbook) ve Vadeli Fonlama (Funding Rate) Ajanı (Whale Agent)
day-trader-skill içindeki trader-pelosi ve trader-analyst'in kripto karşılığıdır.
- Binance Emir Defteri Derinliğini (Orderbook Depth) okuyarak alış/satış duvarlarını ölçer.
- Son mumlardaki Taker Buy (Agresif Piyasa Alıcıları / Balina Alımı) oranını hesaplar.
- Vadeli İşlemler Fonlama Oranını (Funding Rate) kontrol ederek aşırı şişmiş long tuzaklarını tespit eder.
"""

import urllib.parse
from .market_data import binance_get, normalize_symbol


def analyze_whale_and_orderbook(symbol: str, bars: list = None, offline: bool = False) -> dict:
    """Sembol için balina alım baskısı, emir defteri dengesi ve fonlama oranını analiz eder."""
    sym = normalize_symbol(symbol)

    # 1. Mum içi Taker Buy (Agresif Alıcı) Oranı
    taker_buy_ratio = 0.52
    whale_flow_label = "Dengeli"
    if bars and len(bars) >= 5:
        recent = bars[-5:]
        tot_qv = sum(b.get("qv", 0.0) for b in recent)
        buy_qv = sum(b.get("taker_buy_qv", 0.0) for b in recent)
        if tot_qv > 0:
            taker_buy_ratio = buy_qv / tot_qv
        if taker_buy_ratio >= 0.58:
            whale_flow_label = "Güçlü Balina Alımı (Agresif Taker Buy)"
        elif taker_buy_ratio >= 0.52:
            whale_flow_label = "Pozitif Alıcı Baskısı"
        elif taker_buy_ratio <= 0.42:
            whale_flow_label = "Yoğun Satıcı Baskısı"

    # 2. Emir Defteri (Orderbook) Alış / Satış Duvarı Oranı (Spot + Futures destekli)
    ob_imbalance = 1.0
    bid_usd = 0.0
    ask_usd = 0.0
    if not offline:
        depth = None
        for is_fut, ep in ((False, "/api/v3/depth"), (True, "/fapi/v1/depth")):
            try:
                depth = binance_get(f"{ep}?symbol={urllib.parse.quote(sym)}&limit=20", futures=is_fut, timeout=6)
                if depth and (depth.get("bids") or depth.get("asks")):
                    break
            except Exception:
                continue
        if depth:
            bids = depth.get("bids") or []
            asks = depth.get("asks") or []
            bid_usd = sum(float(p) * float(q) for p, q in bids)
            ask_usd = sum(float(p) * float(q) for p, q in asks)
            if ask_usd > 0:
                ob_imbalance = bid_usd / ask_usd
        else:
            ob_imbalance = 1.05

    # 3. Vadeli Fonlama Oranı (Funding Rate)
    funding_rate_pct = 0.01
    if not offline:
        try:
            fdoc = binance_get(f"/fapi/v1/premiumIndex?symbol={urllib.parse.quote(sym)}", futures=True, timeout=5)
            if isinstance(fdoc, dict) and fdoc.get("lastFundingRate") is not None:
                funding_rate_pct = float(fdoc["lastFundingRate"]) * 100.0
        except Exception:
            funding_rate_pct = 0.01

    # Aşırı yüksek pozitif funding (> %0.15) veya ezici satış duvarı varsa uyarı üret
    veto = False
    veto_reason = ""
    if funding_rate_pct > 0.20:
        veto = True
        veto_reason = f"Vadeli fonlama oranı aşırı şişmiş ({funding_rate_pct:+.3f}%): Long squeeze riski yüksek"
    elif taker_buy_ratio < 0.36 and ob_imbalance < 0.45:
        veto = True
        veto_reason = f"Ağır balina satış baskısı (Alıcı oranı %{taker_buy_ratio * 100:.1f}, Orderbook {ob_imbalance:.2f}x)"

    return {
        "symbol": sym,
        "taker_buy_pct": round(taker_buy_ratio * 100.0, 1),
        "whale_flow_label": whale_flow_label,
        "orderbook_bid_ask_ratio": round(ob_imbalance, 2),
        "bid_wall_usd": round(bid_usd, 0),
        "ask_wall_usd": round(ask_usd, 0),
        "funding_rate_pct": round(funding_rate_pct, 4),
        "veto": veto,
        "veto_reason": veto_reason,
    }

