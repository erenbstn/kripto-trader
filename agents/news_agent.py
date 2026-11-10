#!/usr/bin/env python3
"""2. Ajan: Kripto Haber, Duyarlılık (Fear & Greed) ve Güvenlik Veto Ajanı (News Agent)
day-trader-skill/trader-news karşılığıdır.
- CoinDesk, CoinTelegraph ve Yahoo Finance Crypto RSS akışlarını okur.
- Alternative.me Kripto Korku ve Açgözlülük Endeksini (Fear & Greed Index) çeker.
- Coin üzerinde 'hack', 'exploit', 'delist', 'bankrupt', 'halt', 'sec lawsuit' gibi
  kritik tehlike haberi varsa işlemi otomatik VETO eder!
"""

import datetime
import json
import os
import re
import urllib.request
import xml.etree.ElementTree as ET
from .market_data import UA, normalize_symbol

RSS_FEEDS = [
    ("CoinTelegraph", "https://cointelegraph.com/rss"),
    ("CoinDesk", "https://www.coindesk.com/arc/outboundfeeds/rss/"),
    ("YahooCrypto", "https://feeds.finance.yahoo.com/rss/2.0/headline?s=BTC-USD,ETH-USD,SOL-USD&region=US&lang=en-US"),
]
FNG_URL = "https://api.alternative.me/fng/?limit=1"

DANGER_KEYWORDS = [
    ("hack_exploit", r"\bhack(?:ed|s|ing)?\b|\bexploit(?:ed|s)?\b|\bdrained\b|\bstolen\b|\bbridge attack\b"),
    ("delist_halt", r"\bdelist(?:ed|ing|s)?\b|\bhalt(?:ed|s)?\b|\bsuspend(?:ed|s)? withdrawals\b"),
    ("insolvency", r"\bbankrupt(?:cy)?\b|\binsolven(?:t|cy)\b|\bdefault(?:ed)?\b"),
    ("regulatory_ban", r"\bsec charges\b|\bdoj indictment\b|\bfraud charges\b"),
]

POSITIVE_KEYWORDS = [
    ("etf_institutional", r"\betf (?:inflow|approval|approved|filing)\b|\binstitutional\b|\btreasury\b"),
    ("partnership_upgrade", r"\bpartnership\b|\bmainnet\b|\bupgrade\b|\blisting\b|\blaunch(?:es|ed)?\b"),
    ("macro_bullish", r"\brate cut\b|\binflation cools\b|\ball-time high\b"),
]

COIN_NAMES = {
    "ONDO": ["ondo", "ondo finance"],
    "HBAR": ["hedera", "hbar"],
    "BTC": ["bitcoin", "btc"],
    "SIREN": ["siren", "sirenprotocol"],
    "XAG": ["silver", "xag"],
    "LINK": ["chainlink", "link"],
    "SOL": ["solana", "sol"],
    "PAXG": ["pax gold", "paxg", "gold"],
    "XRP": ["xrp", "ripple"],
    "ETH": ["ethereum", "eth", "ether"],
}


def fetch_fear_and_greed(timeout: int = 8) -> dict:
    """Kripto Korku ve Açgözlülük Endeksini döndürür (0-100)."""
    try:
        req = urllib.request.Request(FNG_URL, headers={"User-Agent": UA})
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            doc = json.loads(resp.read().decode("utf-8", "replace"))
            data = (doc.get("data") or [{}])[0]
            val = int(data.get("value") or 50)
            cls = data.get("value_classification") or "Neutral"
            return {"value": val, "classification": cls}
    except Exception:
        return {"value": 50, "classification": "Neutral"}


def _fetch_rss_items(timeout: int = 8) -> list:
    items = []
    for source_name, url in RSS_FEEDS:
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                xml_bytes = resp.read()
            root = ET.fromstring(xml_bytes)
            for it in list(root.iter("item"))[:25]:
                title = ""
                desc = ""
                link = ""
                for child in it:
                    tag = child.tag.rsplit("}", 1)[-1].lower()
                    if tag == "title":
                        title = (child.text or "").strip()
                    elif tag == "description":
                        desc = (child.text or "").strip()
                    elif tag == "link":
                        link = (child.text or "").strip()
                if title:
                    items.append({"source": source_name, "title": title, "summary": desc[:240], "link": link})
        except Exception:
            continue
    return items


def check_symbol_news(symbol: str, offline_headlines: list = None, fetch_live: bool = True) -> dict:
    """Sembolle ilgili haberleri ve piyasa duyarlılığını analiz eder.
    Kritik tehlike varsa `veto = True` döndürür.
    """
    sym = normalize_symbol(symbol)
    base = sym[:-4] if sym.endswith("USDT") else sym
    aliases = COIN_NAMES.get(base, [base.lower()])

    if offline_headlines is not None:
        raw_items = offline_headlines
        fng = {"value": 55, "classification": "Greed"}
    elif fetch_live:
        raw_items = _fetch_rss_items()
        fng = fetch_fear_and_greed()
    else:
        raw_items = []
        fng = {"value": 50, "classification": "Neutral"}

    matched = []
    danger_hits = []
    positive_hits = []

    patterns = [re.compile(r"\b" + re.escape(a) + r"\b", re.I) for a in aliases]

    for it in raw_items:
        text = f"{it.get('title', '')} {it.get('summary', '')}"
        if any(p.search(text) for p in patterns):
            d_tags = [label for label, rx in DANGER_KEYWORDS if re.search(rx, text, re.I)]
            p_tags = [label for label, rx in POSITIVE_KEYWORDS if re.search(rx, text, re.I)]
            entry = {
                "source": it.get("source", "RSS"),
                "title": it.get("title", ""),
                "danger_tags": d_tags,
                "positive_tags": p_tags,
                "link": it.get("link", ""),
            }
            matched.append(entry)
            if d_tags:
                danger_hits.append(entry)
            if p_tags:
                positive_hits.append(entry)

    veto = len(danger_hits) > 0
    veto_reason = ""
    if veto:
        first_d = danger_hits[0]
        veto_reason = f"Kritik riskli haber tespit edildi ({', '.join(first_d['danger_tags'])}): {first_d['title']}"

    sentiment_score = 0
    if positive_hits:
        sentiment_score += min(len(positive_hits) * 15, 30)
    if danger_hits:
        sentiment_score -= 100

    return {
        "symbol": sym,
        "base": base,
        "fear_greed": fng,
        "matched_count": len(matched),
        "headlines": matched[:5],
        "positive_count": len(positive_hits),
        "danger_count": len(danger_hits),
        "sentiment_score": sentiment_score,
        "veto": veto,
        "veto_reason": veto_reason,
        "checked_at": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }

