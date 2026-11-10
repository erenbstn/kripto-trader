#!/usr/bin/env python3
"""Canlı Kripto Veri Sağlayıcısı (Binance Public Market Data CDN + API + Yahoo Fallback).
Hiçbir API anahtarı veya harici kütüphane (pip) gerektirmez.
"""

import datetime
import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request

UA = "Mozilla/5.0 (compatible; kripto-multi-agent/2.0)"
BINANCE_SPOT_HOSTS = (
    "https://data-api.binance.vision",
    "https://api.binance.com",
    "https://api1.binance.com",
    "https://api2.binance.com",
)
BINANCE_FUTURES_HOSTS = (
    "https://fapi.binance.com",
)
YAHOO_HOSTS = (
    "https://query2.finance.yahoo.com",
    "https://query1.finance.yahoo.com",
)

INTERVAL_MS = {
    "1m": 60 * 1000,
    "5m": 5 * 60 * 1000,
    "15m": 15 * 60 * 1000,
    "1h": 60 * 60 * 1000,
    "4h": 4 * 60 * 60 * 1000,
    "1d": 24 * 60 * 60 * 1000,
}

STABLE_BASES = {
    "USDC", "FDUSD", "TUSD", "USDP", "DAI", "BUSD", "USDE", "EUR", "EURITE",
    "XUSD", "USD1", "RLUSD", "PYUSD", "USDT"
}


class MarketDataError(Exception):
    pass


def normalize_symbol(sym: str) -> str:
    tr_map = str.maketrans("ıİğĞüÜşŞöÖçÇ", "IIGGUUSSOOCC")
    s = str(sym or "").translate(tr_map).strip().upper().replace("-", "").replace("/", "")
    if not s:
        raise MarketDataError("Boş sembol")
    if not s.endswith("USDT"):
        s += "USDT"
    return s


def to_yahoo_crypto(sym: str) -> str:
    s = normalize_symbol(sym)
    base = s[:-4] if s.endswith("USDT") else s
    return f"{base}-USD"


def http_get_json(url: str, timeout: int = 15):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        raw = resp.read().decode("utf-8", "replace")
        return json.loads(raw)


FUTURES_NATIVE_SYMBOLS = {"SIRENUSDT", "XAGUSDT"}


def binance_get(path: str, futures: bool = False, timeout: int = 10):
    hosts = BINANCE_FUTURES_HOSTS if futures else BINANCE_SPOT_HOSTS
    last_err = None
    for host in hosts:
        try:
            return http_get_json(host + path, timeout=timeout)
        except urllib.error.HTTPError as exc:
            last_err = exc
            # HTTP 400 = Sembol Spot'ta yok (Futures'ta var), diğer Spot sunucularını denemeye gerek yok
            if exc.code == 400:
                break
            continue
        except (urllib.error.URLError, OSError, ValueError) as exc:
            last_err = exc
            continue
    raise MarketDataError(f"Binance verisi alınamadı ({path}): {last_err}")


def fetch_klines(symbol: str, interval: str = "5m", limit: int = 500, now_ms: int = None, offline_bars=None):
    """Sembol için mum verilerini döndürür:
    {
      "symbol": "BTCUSDT",
      "interval": "5m",
      "bars": [...tamamlanmış/kapanmış mumlar...],
      "forming": {...henüz kapanmamış canlı mum veya None...},
      "last_price": float,
      "source": "binance" | "yahoo" | "offline"
    }
    day-trader-skill kuralı: Kapanmamış (forming) mum asla kırılım onayı olarak sayılmaz!
    """
    sym = normalize_symbol(symbol)
    if offline_bars is not None:
        return _process_offline_bars(sym, interval, offline_bars, now_ms)

    step_ms = INTERVAL_MS.get(interval, 5 * 60 * 1000)
    curr_ms = now_ms if now_ms is not None else int(time.time() * 1000)

    endpoints = (
        ((True, "/fapi/v1/klines", "binance_futures"), (False, "/api/v3/klines", "binance"))
        if sym in FUTURES_NATIVE_SYMBOLS
        else ((False, "/api/v3/klines", "binance"), (True, "/fapi/v1/klines", "binance_futures"))
    )

    for is_futures, api_prefix, src_name in endpoints:
        try:
            path = f"{api_prefix}?symbol={urllib.parse.quote(sym)}&interval={interval}&limit={min(limit, 1000)}"
            rows = binance_get(path, futures=is_futures)
            closed_bars = []
            forming_bar = None
            for r in rows:
                open_ms = int(r[0])
                close_ms = int(r[6])
                bar = {
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
                }
                if close_ms <= curr_ms:
                    closed_bars.append(bar)
                else:
                    forming_bar = bar
            if not closed_bars and not forming_bar:
                continue
            last_price = forming_bar["c"] if forming_bar else (closed_bars[-1]["c"] if closed_bars else 0.0)
            return {
                "symbol": sym,
                "interval": interval,
                "bars": closed_bars,
                "forming": forming_bar,
                "last_price": last_price,
                "source": src_name,
            }
        except MarketDataError:
            continue

    return _fetch_yahoo_fallback(sym, interval, limit, curr_ms, step_ms)


def _fetch_yahoo_fallback(sym: str, interval: str, limit: int, curr_ms: int, step_ms: int):
    ysym = to_yahoo_crypto(sym)
    y_int = "5m" if interval in ("5m", "15m") else ("1m" if interval == "1m" else "1d")
    y_rng = "60d" if y_int == "5m" and limit > 288 else ("5d" if y_int in ("1m", "5m") else "6mo")
    path = f"/v8/finance/chart/{urllib.parse.quote(ysym)}?range={y_rng}&interval={y_int}"
    last_err = None
    for host in YAHOO_HOSTS:
        try:
            doc = http_get_json(host + path)
            res = (doc.get("chart") or {}).get("result") or []
            if not res:
                continue
            r0 = res[0]
            ts_list = r0.get("timestamp") or []
            q = ((r0.get("indicators") or {}).get("quote") or [{}])[0]
            opens = q.get("open") or []
            highs = q.get("high") or []
            lows = q.get("low") or []
            closes = q.get("close") or []
            vols = q.get("volume") or []
            closed_bars = []
            forming_bar = None
            for i, ts in enumerate(ts_list):
                c = closes[i] if i < len(closes) else None
                if ts is None or c is None:
                    continue
                open_ms = int(ts) * 1000
                close_ms = open_ms + step_ms - 1
                o = opens[i] if i < len(opens) and opens[i] is not None else c
                h = highs[i] if i < len(highs) and highs[i] is not None else c
                l = lows[i] if i < len(lows) and lows[i] is not None else c
                v = vols[i] if i < len(vols) and vols[i] is not None else 0.0
                bar = {
                    "t": int(ts),
                    "open_ms": open_ms,
                    "close_ms": close_ms,
                    "dt": datetime.datetime.fromtimestamp(int(ts), datetime.timezone.utc).strftime("%Y-%m-%d %H:%M"),
                    "o": float(o),
                    "h": float(h),
                    "l": float(l),
                    "c": float(c),
                    "v": float(v),
                    "qv": float(v) * float(c),
                    "trades": 0,
                    "taker_buy_qv": float(v) * float(c) * 0.5,
                }
                if close_ms <= curr_ms:
                    closed_bars.append(bar)
                else:
                    forming_bar = bar
            closed_bars = closed_bars[-limit:]
            last_price = forming_bar["c"] if forming_bar else (closed_bars[-1]["c"] if closed_bars else 0.0)
            return {
                "symbol": sym,
                "interval": interval,
                "bars": closed_bars,
                "forming": forming_bar,
                "last_price": last_price,
                "source": "yahoo",
            }
        except Exception as exc:
            last_err = exc
    raise MarketDataError(f"{sym} için ne Binance ne de Yahoo verisi alınabildi: {last_err}")


def _process_offline_bars(sym: str, interval: str, bars: list, now_ms: int = None):
    step_ms = INTERVAL_MS.get(interval, 5 * 60 * 1000)
    closed_bars = []
    forming_bar = None
    for b in bars:
        open_ms = int(b.get("open_ms") or (int(b["t"]) * 1000))
        close_ms = int(b.get("close_ms") or (open_ms + step_ms - 1))
        item = {
            "t": open_ms // 1000,
            "open_ms": open_ms,
            "close_ms": close_ms,
            "dt": b.get("dt") or datetime.datetime.fromtimestamp(open_ms / 1000.0, datetime.timezone.utc).strftime("%Y-%m-%d %H:%M"),
            "o": float(b["o"]),
            "h": float(b["h"]),
            "l": float(b["l"]),
            "c": float(b["c"]),
            "v": float(b.get("v", 1000.0)),
            "qv": float(b.get("qv", float(b.get("v", 1000.0)) * float(b["c"]))),
            "trades": int(b.get("trades", 100)),
            "taker_buy_qv": float(b.get("taker_buy_qv", float(b.get("v", 1000.0)) * float(b["c"]) * 0.55)),
        }
        if now_ms is None or close_ms <= now_ms:
            closed_bars.append(item)
        elif open_ms <= now_ms < close_ms:
            forming_bar = item
    last_price = forming_bar["c"] if forming_bar else (closed_bars[-1]["c"] if closed_bars else 0.0)
    return {
        "symbol": sym,
        "interval": interval,
        "bars": closed_bars,
        "forming": forming_bar,
        "last_price": last_price,
        "source": "offline",
    }


def get_24h_tickers(symbols: list = None):
    """24 saatlik fiyat değişimi, hacim ve son fiyat bilgilerini döndürür (Spot + Futures destekli)."""
    rows = binance_get("/api/v3/ticker/24hr")
    wanted = {normalize_symbol(s) for s in symbols} if symbols else None
    out = {}
    for r in rows:
        s = r.get("symbol", "")
        if not s.endswith("USDT"):
            continue
        if wanted and s not in wanted:
            continue
        base = s[:-4]
        if base in STABLE_BASES or any(s.endswith(x) for x in ("UPUSDT", "DOWNUSDT", "BULLUSDT", "BEARUSDT")):
            continue
        out[s] = {
            "symbol": s,
            "price": float(r.get("lastPrice") or 0.0),
            "open_24h": float(r.get("openPrice") or 0.0),
            "high_24h": float(r.get("highPrice") or 0.0),
            "low_24h": float(r.get("lowPrice") or 0.0),
            "pct_24h": float(r.get("priceChangePercent") or 0.0),
            "volume_base": float(r.get("volume") or 0.0),
            "quote_volume_usd": float(r.get("quoteVolume") or 0.0),
            "trades_24h": int(r.get("count") or 0),
        }
    if wanted and len(out) < len(wanted):
        try:
            frows = binance_get("/fapi/v1/ticker/24hr", futures=True)
            for r in frows:
                s = r.get("symbol", "")
                if s in wanted and s not in out:
                    out[s] = {
                        "symbol": s,
                        "price": float(r.get("lastPrice") or 0.0),
                        "open_24h": float(r.get("openPrice") or 0.0),
                        "high_24h": float(r.get("highPrice") or 0.0),
                        "low_24h": float(r.get("lowPrice") or 0.0),
                        "pct_24h": float(r.get("priceChangePercent") or 0.0),
                        "volume_base": float(r.get("volume") or 0.0),
                        "quote_volume_usd": float(r.get("quoteVolume") or 0.0),
                        "trades_24h": int(r.get("count") or 0),
                    }
        except Exception:
            pass
    return out


def get_live_prices(symbols: list = None) -> dict:
    """Sembol -> anlık fiyat sözlüğü döndürür (Spot + Futures destekli)."""
    wanted = {normalize_symbol(s) for s in symbols} if symbols else None
    out = {}
    try:
        rows = binance_get("/api/v3/ticker/price")
        for r in rows:
            s = r.get("symbol", "")
            if wanted and s not in wanted:
                continue
            if s.endswith("USDT"):
                out[s] = float(r.get("price") or 0.0)
    except MarketDataError:
        pass

    if wanted and len(out) < len(wanted):
        try:
            frows = binance_get("/fapi/v1/ticker/price", futures=True)
            for r in frows:
                s = r.get("symbol", "")
                if s in wanted and s not in out:
                    out[s] = float(r.get("price") or 0.0)
        except Exception:
            pass

    if wanted and len(out) < len(wanted):
        for ns in wanted:
            if ns not in out:
                try:
                    k = fetch_klines(ns, "5m", limit=5)
                    if k["last_price"] > 0:
                        out[ns] = k["last_price"]
                except Exception:
                    pass
    return out


def discover_top_usdt_pairs(top_n: int = 25, min_quote_vol_usd: float = 15_000_000.0) -> list:
    """En yüksek 24 saatlik USDT hacmine sahip likit kripto paritelerini bulur."""
    tickers = get_24h_tickers()
    cands = [v for v in tickers.values() if v["quote_volume_usd"] >= min_quote_vol_usd and v["price"] > 0]
    cands.sort(key=lambda x: -x["quote_volume_usd"])
    return [c["symbol"] for c in cands[:top_n]]

