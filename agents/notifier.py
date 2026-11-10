#!/usr/bin/env python3
"""11. Ajan: Yerel Bildirim Ajanı (Local Notifier).

Hiçbir dış mesajlaşma servisine bağlanmaz, ağ isteği yapmaz, anahtar/token kullanmaz.
Bildirimler yalnızca yerelde tutulur:
  - konsola yazılır,
  - `data/notifications.jsonl` dosyasına (satır başına bir JSON) eklenir.
Mobil uygulamada aynı olaylar cihazın kendi yerel bildirimlerine dönüşür.
"""

import datetime
import json
import os
import re

_TAG_RE = re.compile(r"</?(?:b|i|u|code|pre)>", re.I)


def plain(text: str) -> str:
    """Eski biçimlendirme etiketlerini temizler."""
    return _TAG_RE.sub("", str(text or ""))


class LocalNotifier:
    def __init__(self, data_dir: str = "data", echo: bool = True, max_lines: int = 2000):
        self.path = os.path.join(data_dir, "notifications.jsonl")
        self.echo = echo
        self.max_lines = max_lines

    def push(self, text: str, kind: str = "info", symbol: str = None) -> dict:
        ev = {
            "ts": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "kind": kind,
            "symbol": symbol,
            "text": plain(text),
        }
        try:
            os.makedirs(os.path.dirname(self.path) or ".", exist_ok=True)
            with open(self.path, "a", encoding="utf-8") as fh:
                fh.write(json.dumps(ev, ensure_ascii=False) + "\n")
            self._trim()
        except OSError:
            pass
        if self.echo:
            print(f"[BİLDİRİM/{kind}] {ev['text']}", flush=True)
        return ev

    def _trim(self):
        with open(self.path, encoding="utf-8") as fh:
            lines = fh.readlines()
        if len(lines) > self.max_lines:
            with open(self.path, "w", encoding="utf-8") as fh:
                fh.writelines(lines[-self.max_lines:])

    def recent(self, n: int = 20) -> list:
        if not os.path.isfile(self.path):
            return []
        with open(self.path, encoding="utf-8") as fh:
            lines = fh.readlines()[-n:]
        out = []
        for ln in lines:
            try:
                out.append(json.loads(ln))
            except ValueError:
                continue
        return out


def format_trade_opened(pos: dict, pf: dict) -> str:
    return (
        f"{pos['symbol']} sinyal açıldı · Giriş {pos['entry_price']:.6g} · "
        f"Stop {pos['stop_loss']:.6g} · Hedef {pos['take_profit']:.6g}"
    )


def format_trade_closed(trade: dict, pf: dict) -> str:
    return (
        f"{trade['symbol']} kapandı · {trade['exit_reason']} · "
        f"%{trade['pnl_pct']:+.2f} · {trade['r_multiple']:+.2f}R"
    )


def format_breakeven_moved(ev: dict) -> str:
    return (
        f"{ev['symbol']} stop girişe çekildi · Yeni stop {ev['new_stop']:.6g} · "
        f"fiyat {ev['current_price']:.6g}"
    )


def format_portfolio_summary(pf: dict) -> str:
    st = pf.get("stats") or {}
    pos_list = pf.get("positions") or []
    lines = [
        "SANAL PORTFÖY VE BAKİYE DURUMU",
        "----------------------------------------",
        f"Başlangıç Bakiyesi: ${pf.get('initial_budget', 500):.2f} USDT",
        f"Kullanılabilir Nakit: ${pf.get('cash', 0):.2f} USDT",
        f"Açık Pozisyon Değeri: ${pf.get('positions_value', 0):.2f} USDT",
        f"Açık Pozisyon Anlık PnL: ${pf.get('unrealized_pnl', 0):+.2f} USDT",
        f"TOPLAM KASA (EQUITY): ${pf.get('total_equity', 0):.2f} USDT",
        "----------------------------------------",
        f"Toplam Net Kar/Zarar: ${st.get('total_pnl_usd', 0):+.2f} (%{st.get('total_return_pct', 0):+.2f})",
        f"Kapanan İşlem: {st.get('total_trades', 0)} ({st.get('wins', 0)} kazanç / {st.get('losses', 0)} kayıp)",
        f"Kazanma Oranı: %{st.get('win_rate_pct', 0):.1f}",
        f"Ortalama R: {st.get('avg_r', 0):+.2f}R | Profit Factor: {st.get('profit_factor', 0):.2f}",
        f"Maksimum Düşüş: %{st.get('max_drawdown_pct', 0):.2f}",
    ]
    if pos_list:
        lines.append("----------------------------------------")
        lines.append(f"Açık Pozisyonlar ({len(pos_list)}):")
        for p in pos_list:
            lines.append(
                f"  {p['symbol']}: Giriş ${p['entry_price']:.6g} | Şimdi ${p['current_price']:.6g} "
                f"| PnL ${p['unrealized_pnl_usd']:+.2f} (%{p['unrealized_pnl_pct']:+.2f}) "
                f"| Stop ${p['stop_loss']:.6g} | Hedef ${p['take_profit']:.6g}"
            )
    lines.append("Yatırım tavsiyesi değildir. Sanal (kağıt) portföydür; gerçek emir açılmaz.")
    return "\n".join(lines)
