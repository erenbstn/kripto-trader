#!/usr/bin/env python3
"""7. Ajan: Bütçe ve Pozisyon Boyutlandırma Ajanı (Budget Manager Agent)
day-trader-skill/trader-budget/size.py karşılığıdır.
Kullanıcı Ayarı:
  - Başlangıç Sahte Bakiyesi (budget): $500.00
  - İşlem Başı Maksimum Risk (max_loss_per_trade_usd): $50.00 (dosyadaki varsayılan)
  - Nakit Tamponu (cash_buffer_pct): %10 ($50 her zaman nakitte kalır)
  - Maksimum Pozisyon Büyüklüğü (max_position_pct): %75 ($375)
  - Borsa Komisyonu (fee_bps): %0.1 alış + %0.1 satış dahil edilerek net risk hesaplanır.
  - Kripto kesirli alıma (fractional: true) uygun olduğu için BTC, ETH, SOL, altcoinlerde
    tam riske uygun hassas miktar (qty) hesaplanır ve `data/orders.json` dosyasına yazılır.
"""

import datetime
import json
import os


class BudgetError(Exception):
    pass


def _round_qty(qty: float, price: float) -> float:
    if price >= 10000:
        return round(qty, 5)
    if price >= 100:
        return round(qty, 4)
    if price >= 1:
        return round(qty, 3)
    if price >= 0.01:
        return round(qty, 1)
    return float(int(qty))


def size_position(
    plan: dict,
    config: dict,
    portfolio: dict = None,
    live_price: float = None,
    write_path: str = "data/orders.json",
) -> dict:
    """Planlanan işlemi 4 bütçe sınırına göre boyutlandırır; en küçük (en güvenli) sınırı seçer."""
    if not isinstance(plan, dict) or not plan.get("symbol"):
        raise BudgetError("Geçerli bir çıkış planı (plan.json) bulunamadı")

    sym = str(plan["symbol"]).upper()
    entry_plan = float(plan["entry"])
    stop = float(plan["stop"])
    target = float(plan["target"])

    # Fiyat plan zamanından beri yükseldiyse riski daha yüksek olan güncel fiyattan ölç (day-trader-skill kuralı)
    ref_entry = max(entry_plan, float(live_price)) if live_price and live_price > entry_plan else entry_plan

    if stop >= ref_entry:
        raise BudgetError(f"Stop ({stop}) giriş fiyatının ({ref_entry}) altında değil")
    if target <= ref_entry:
        raise BudgetError(f"Hedef ({target}) giriş fiyatının ({ref_entry}) üzerinde değil (hareket zaten gerçekleşmiş)")

    budget = float(config.get("budget", 500.0))
    buf_pct = float(config.get("cash_buffer_pct", 10.0))
    max_pos_pct = float(config.get("max_position_pct", 75.0))
    max_order_usd = float(config.get("max_order_usd", 4000.0))
    min_order_usd = float(config.get("min_order_usd", 5.0))
    max_loss_usd = float(config.get("max_loss_per_trade_usd", 50.0))
    min_rr = float(config.get("min_reward_risk", 1.0))
    fee_rate = float(config.get("fee_bps", 10.0)) / 10000.0  # 0.001 (%0.1)

    # Portföydeki güncel toplam bakiye ve nakit
    current_cash = float(portfolio.get("cash", budget)) if portfolio else budget
    total_equity = float(portfolio.get("total_equity", budget)) if portfolio else budget

    cash_buffer = round(total_equity * (buf_pct / 100.0), 2)
    available_cash = max(0.0, round(current_cash - cash_buffer, 2))

    # Birim başı fiyat riski + alış/satış komisyon etkisi
    price_risk_per_unit = ref_entry - stop
    fee_per_unit_roundtrip = (ref_entry + stop) * fee_rate
    effective_risk_per_unit = price_risk_per_unit + fee_per_unit_roundtrip
    reward_per_unit = (target - ref_entry) - ((ref_entry + target) * fee_rate)
    reward_risk = round(reward_per_unit / effective_risk_per_unit, 2) if effective_risk_per_unit > 0 else 0.0

    # 4 Sınır (En küçük olan kazanır)
    lim_loss_qty = max_loss_usd / effective_risk_per_unit if effective_risk_per_unit > 0 else 0.0
    lim_pos_usd = round(total_equity * (max_pos_pct / 100.0), 2)
    lim_pos_qty = lim_pos_usd / (ref_entry * (1.0 + fee_rate))
    lim_ord_qty = max_order_usd / (ref_entry * (1.0 + fee_rate))
    lim_cash_qty = available_cash / (ref_entry * (1.0 + fee_rate))

    limits = [
        {
            "name": "max_loss",
            "label": "İşlem Başı Maks. Zarar Sınırı",
            "usd_limit": max_loss_usd,
            "qty": _round_qty(lim_loss_qty, ref_entry),
            "detail": f"${max_loss_usd:.2f} maks risk / ${effective_risk_per_unit:.4g} birim risk (komisyon dahil)",
        },
        {
            "name": "position_cap",
            "label": "Maks. Pozisyon Oranı Sınırı",
            "usd_limit": lim_pos_usd,
            "qty": _round_qty(lim_pos_qty, ref_entry),
            "detail": f"Kasanın %{max_pos_pct:g}'i = ${lim_pos_usd:.2f}",
        },
        {
            "name": "max_order",
            "label": "Maks. Emir Tutarı Sınırı",
            "usd_limit": max_order_usd,
            "qty": _round_qty(lim_ord_qty, ref_entry),
            "detail": f"${max_order_usd:.2f} üst limit",
        },
        {
            "name": "cash",
            "label": "Kullanılabilir Nakit (Tampon Sonrası)",
            "usd_limit": available_cash,
            "qty": _round_qty(lim_cash_qty, ref_entry),
            "detail": f"${current_cash:.2f} nakit - ${cash_buffer:.2f} (%{buf_pct:g} tampon) = ${available_cash:.2f}",
        },
    ]

    best = min(limits, key=lambda x: x["qty"])
    for l in limits:
        l["binds"] = (l["name"] == best["name"])

    qty = max(0.0, best["qty"])
    notional_usd = round(qty * ref_entry, 2)
    entry_fee_usd = round(notional_usd * fee_rate, 4)
    total_cost_usd = round(notional_usd + entry_fee_usd, 2)
    max_loss_at_stop = round(qty * effective_risk_per_unit, 2)
    expected_profit_at_target = round(qty * reward_per_unit, 2)

    refusal = None
    if qty <= 0 or notional_usd < min_order_usd:
        refusal = (
            f"Hesaplanan emir tutarı (${notional_usd:.2f}), minimum emir sınırının (${min_order_usd:.2f}) altında "
            f"(Belirleyici sınır: {best['label']} - {best['detail']})."
        )
    elif reward_risk < min_rr:
        refusal = (
            f"Komisyon sonrası Ödül/Risk oranı ({reward_risk:.2f}), minimum sınırın ({min_rr:.2f}) altında."
        )

    order = None
    if not refusal:
        order = {
            "symbol": sym,
            "side": "buy",
            "qty": str(qty),
            "qty_num": qty,
            "notional_usd": notional_usd,
            "entry_fee_usd": entry_fee_usd,
            "total_cost_usd": total_cost_usd,
            "type": "market",
            "time_in_force": "gtc",
            "order_class": "bracket",
            "take_profit_limit_price": str(target),
            "stop_loss_stop_price": str(stop),
            "why": (
                f"{sym} ({plan.get('setup', 'orb')}): {qty} adet (${notional_usd:.2f}), "
                f"{best['label']} ile boyutlandırıldı (Stopta maks zarar: ${max_loss_at_stop:.2f}, "
                f"Hedefte net kar: +${expected_profit_at_target:.2f})"
            ),
            "plan": {
                "entry": ref_entry,
                "stop": stop,
                "target": target,
                "breakeven_trigger": plan.get("breakeven_trigger"),
                "risk_per_share": round(effective_risk_per_unit, 6),
                "reward_risk": reward_risk,
                "max_loss": max_loss_at_stop,
                "expected_profit": expected_profit_at_target,
                "setup": plan.get("setup", "orb"),
                "entry_time": plan.get("entry_time"),
                "flat_by": plan.get("flat_by"),
                "max_hold_minutes": plan.get("max_hold_minutes", 240),
            },
        }

    result = {
        "created_by": "budget_agent",
        "created_at": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "symbol": sym,
        "entry": ref_entry,
        "stop": stop,
        "target": target,
        "qty": qty,
        "notional_usd": notional_usd,
        "total_cost_usd": total_cost_usd,
        "max_loss_usd": max_loss_at_stop,
        "expected_profit_usd": expected_profit_at_target,
        "reward_risk": reward_risk,
        "bound_by": best["label"],
        "limits": limits,
        "refusal": refusal,
        "orders": [order] if order else [],
    }

    if write_path and order:
        os.makedirs(os.path.dirname(write_path) or ".", exist_ok=True)
        with open(write_path, "w", encoding="utf-8") as fh:
            json.dump(result, fh, indent=2, ensure_ascii=False)
            fh.write("\n")

    return result

