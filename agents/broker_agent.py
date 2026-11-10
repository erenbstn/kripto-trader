#!/usr/bin/env python3
"""9. Ajan: Otonom Sahte Bakiye (Paper Trading) Broker ve Portföy Motoru (Broker Agent)
day-trader-skill/trader-broker/ticket.py karşılığıdır.
- Başlangıç sahte bakiyesini ($500.00 USDT) yönetir.
- Risk ajanından PASS alan emirleri gerçekçi %0.1 komisyon keserek sanal cüzdanda açar.
- Pozisyon kapandığında (Take-Profit, Stop-Loss, Breakeven Stop, Süre Sonu veya Manuel)
  net Kar/Zarar ($ ve %), R çarpanı, Win Rate, Profit Factor ve Max Drawdown hesaplar.
- Tüm verileri atomik olarak `data/portfolio.json` ve `data/broker_log.json` dosyalarında saklar.
"""

import datetime
import json
import os
from .risk_agent import order_fingerprint


class BrokerError(Exception):
    pass


def _atomic_write_json(path: str, data: dict):
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2, ensure_ascii=False)
        fh.write("\n")
    os.replace(tmp, path)


def load_portfolio(config: dict, path: str = "data/portfolio.json") -> dict:
    budget = float(config.get("budget", 500.0))
    if os.path.isfile(path):
        try:
            with open(path, encoding="utf-8") as fh:
                pf = json.load(fh)
                pf.setdefault("initial_budget", budget)
                pf.setdefault("cash", budget)
                pf.setdefault("positions", [])
                pf.setdefault("closed_trades", [])
                pf.setdefault("peak_equity", max(budget, float(pf.get("total_equity", budget))))
                recalc_portfolio_stats(pf)
                return pf
        except Exception:
            pass

    pf = {
        "created_at": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "paper": True,
        "initial_budget": budget,
        "cash": budget,
        "positions_value": 0.0,
        "unrealized_pnl": 0.0,
        "total_equity": budget,
        "peak_equity": budget,
        "positions": [],
        "closed_trades": [],
        "stats": {
            "total_trades": 0,
            "wins": 0,
            "losses": 0,
            "win_rate_pct": 0.0,
            "realized_pnl_usd": 0.0,
            "total_pnl_usd": 0.0,
            "total_return_pct": 0.0,
            "avg_r": 0.0,
            "profit_factor": 0.0,
            "max_drawdown_pct": 0.0,
            "total_fees_usd": 0.0,
        },
    }
    _atomic_write_json(path, pf)
    return pf


def reset_portfolio(new_budget: float = 500.0, path: str = "data/portfolio.json") -> dict:
    if os.path.isfile(path):
        os.remove(path)
    return load_portfolio({"budget": new_budget}, path=path)


def recalc_portfolio_stats(pf: dict, live_prices: dict = None) -> dict:
    """Portföyün anlık değerini, açık pozisyon PnL'ini ve geçmiş işlem istatistiklerini günceller."""
    live_prices = live_prices or {}
    pos_val = 0.0
    unrealized = 0.0

    for p in pf.get("positions", []):
        sym = p["symbol"]
        cur_p = float(live_prices.get(sym) or p.get("current_price") or p["entry_price"])
        p["current_price"] = cur_p
        qty = float(p["qty"])
        mkt_val = round(qty * cur_p, 2)
        cost_usd = float(p["cost_usd"])
        u_pnl = round(mkt_val - cost_usd, 2)
        u_pct = round((u_pnl / cost_usd) * 100.0, 2) if cost_usd > 0 else 0.0
        p["market_value_usd"] = mkt_val
        p["unrealized_pnl_usd"] = u_pnl
        p["unrealized_pnl_pct"] = u_pct
        pos_val += mkt_val
        unrealized += u_pnl

    cash = round(float(pf.get("cash", 0.0)), 2)
    init_b = float(pf.get("initial_budget", 500.0))
    total_eq = round(cash + pos_val, 2)
    peak_eq = max(float(pf.get("peak_equity", init_b)), total_eq)

    pf["positions_value"] = round(pos_val, 2)
    pf["unrealized_pnl"] = round(unrealized, 2)
    pf["total_equity"] = total_eq
    pf["peak_equity"] = peak_eq

    closed = pf.get("closed_trades", [])
    n_trades = len(closed)
    wins = [t for t in closed if float(t.get("pnl_usd", 0.0)) > 0]
    losses = [t for t in closed if float(t.get("pnl_usd", 0.0)) <= 0]
    gross_win = sum(float(t["pnl_usd"]) for t in wins)
    gross_loss = abs(sum(float(t["pnl_usd"]) for t in losses))
    realized_pnl = round(sum(float(t.get("pnl_usd", 0.0)) for t in closed), 2)
    total_fees = round(
        sum(float(t.get("fees_usd", 0.0)) for t in closed)
        + sum(float(p.get("entry_fee_usd", 0.0)) for p in pf.get("positions", [])),
        2,
    )
    avg_r = round(sum(float(t.get("r_multiple", 0.0)) for t in closed) / n_trades, 2) if n_trades > 0 else 0.0
    pf_ratio = round(gross_win / gross_loss, 2) if gross_loss > 0 else (99.9 if gross_win > 0 else 0.0)

    dd_pct = round(((peak_eq - total_eq) / peak_eq) * 100.0, 2) if peak_eq > 0 else 0.0
    prev_max_dd = float((pf.get("stats") or {}).get("max_drawdown_pct", 0.0))
    max_dd = max(prev_max_dd, dd_pct)

    total_pnl = round(total_eq - init_b, 2)
    total_ret_pct = round((total_pnl / init_b) * 100.0, 2) if init_b > 0 else 0.0

    pf["stats"] = {
        "total_trades": n_trades,
        "wins": len(wins),
        "losses": len(losses),
        "win_rate_pct": round((len(wins) / n_trades) * 100.0, 1) if n_trades > 0 else 0.0,
        "realized_pnl_usd": realized_pnl,
        "total_pnl_usd": total_pnl,
        "total_return_pct": total_ret_pct,
        "avg_r": avg_r,
        "profit_factor": pf_ratio,
        "max_drawdown_pct": max_dd,
        "total_fees_usd": total_fees,
    }
    return pf


def execute_paper_buy(
    order: dict,
    risk_doc: dict,
    config: dict,
    timemachine_doc: dict = None,
    portfolio_path: str = "data/portfolio.json",
    log_path: str = "data/broker_log.json",
) -> dict:
    """Risk kontrolünden PASS almış emri sanal cüzdanda (Paper Trading) açar."""
    if not risk_doc or risk_doc.get("verdict") != "PASS":
        raise BrokerError("Risk kontrolünden PASS almayan hiçbir emir açılamaz!")

    fp_order = order_fingerprint(order)
    if risk_doc.get("fingerprint") != fp_order:
        raise BrokerError("Emir parmak izi (fingerprint) risk onayı ile eşleşmiyor!")

    pf = load_portfolio(config, path=portfolio_path)
    sym = str(order["symbol"]).upper()
    if any(p.get("symbol") == sym for p in pf["positions"]):
        raise BrokerError(f"{sym} için zaten açık bir pozisyon var")

    qty = float(order["qty_num"])
    plan = order.get("plan") or {}
    entry_price = float(plan["entry"])
    stop_price = float(order["stop_loss_stop_price"])
    target_price = float(order["take_profit_limit_price"])
    fee_rate = float(config.get("fee_bps", 10.0)) / 10000.0

    cost_usd = round(qty * entry_price, 2)
    entry_fee = round(cost_usd * fee_rate, 4)
    total_deduct = round(cost_usd + entry_fee, 2)

    if pf["cash"] < total_deduct:
        raise BrokerError(f"Yetersiz nakit bakiye (${pf['cash']:.2f} < ${total_deduct:.2f})")

    now_utc = datetime.datetime.now(datetime.timezone.utc)
    max_hold_min = int(plan.get("max_hold_minutes", config.get("max_hold_minutes", 240)))
    expire_utc = now_utc + datetime.timedelta(minutes=max_hold_min)

    tm_summary = None
    if timemachine_doc and timemachine_doc.get("mc"):
        mc = timemachine_doc["mc"]
        tm_summary = {
            "p_target_pct": round(mc["p_target"] * 100.0, 1),
            "p_stop_pct": round(mc["p_stop"] * 100.0, 1),
            "p_green_pct": round(mc["p_green"] * 100.0, 1),
            "avg_R": mc["avg_R"],
            "verdict": timemachine_doc.get("verdict", ""),
        }

    pos_id = f"{sym}-{int(now_utc.timestamp())}"
    position = {
        "id": pos_id,
        "symbol": sym,
        "side": "buy",
        "setup": plan.get("setup", "orb"),
        "qty": qty,
        "entry_price": entry_price,
        "current_price": entry_price,
        "initial_stop": stop_price,
        "stop_loss": stop_price,
        "take_profit": target_price,
        "breakeven_trigger": plan.get("breakeven_trigger"),
        "breakeven_moved": False,
        "risk_per_unit": float(plan.get("risk_per_share", entry_price - stop_price)),
        "max_loss_usd": float(plan.get("max_loss", 0.0)),
        "expected_profit_usd": float(plan.get("expected_profit", 0.0)),
        "reward_risk": float(plan.get("reward_risk", 1.5)),
        "cost_usd": cost_usd,
        "entry_fee_usd": entry_fee,
        "market_value_usd": cost_usd,
        "unrealized_pnl_usd": 0.0,
        "unrealized_pnl_pct": 0.0,
        "opened_at": now_utc.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "flat_by": expire_utc.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "timemachine": tm_summary,
        "fingerprint": fp_order,
    }

    pf["cash"] = round(pf["cash"] - total_deduct, 2)
    pf["positions"].append(position)
    recalc_portfolio_stats(pf, {sym: entry_price})
    _atomic_write_json(portfolio_path, pf)

    _append_broker_log(
        log_path,
        {
            "at": now_utc.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "event": "OPEN_POSITION",
            "position_id": pos_id,
            "symbol": sym,
            "qty": qty,
            "entry_price": entry_price,
            "stop_loss": stop_price,
            "take_profit": target_price,
            "cost_usd": cost_usd,
            "cash_after": pf["cash"],
            "total_equity": pf["total_equity"],
        },
    )
    return {"position": position, "portfolio": pf}


def close_paper_position(
    symbol: str,
    exit_price: float,
    reason: str,
    config: dict,
    portfolio_path: str = "data/portfolio.json",
    log_path: str = "data/broker_log.json",
) -> dict:
    """Açık bir sanal pozisyonu kapatır, komisyonu düşer, bakiyeyi ve istatistikleri günceller."""
    pf = load_portfolio(config, path=portfolio_path)
    sym = str(symbol).upper()
    pos = next((p for p in pf["positions"] if p["symbol"] == sym), None)
    if not pos:
        raise BrokerError(f"{sym} için kapatılacak açık pozisyon bulunamadı")

    qty = float(pos["qty"])
    entry_price = float(pos["entry_price"])
    exit_p = float(exit_price)
    fee_rate = float(config.get("fee_bps", 10.0)) / 10000.0

    gross_proceeds = round(qty * exit_p, 2)
    exit_fee = round(gross_proceeds * fee_rate, 4)
    net_proceeds = round(gross_proceeds - exit_fee, 2)

    cost_usd = float(pos["cost_usd"])
    entry_fee = float(pos.get("entry_fee_usd", 0.0))
    total_fees = round(entry_fee + exit_fee, 4)

    net_pnl_usd = round(net_proceeds - cost_usd - entry_fee, 2)
    net_pnl_pct = round((net_pnl_usd / cost_usd) * 100.0, 2) if cost_usd > 0 else 0.0

    initial_risk_usd = float(pos.get("max_loss_usd") or (qty * abs(entry_price - float(pos["initial_stop"]))))
    r_multiple = round(net_pnl_usd / initial_risk_usd, 2) if initial_risk_usd > 0 else 0.0

    now_utc = datetime.datetime.now(datetime.timezone.utc)
    trade_record = {
        "id": pos["id"],
        "symbol": sym,
        "setup": pos.get("setup", "orb"),
        "qty": qty,
        "entry_price": entry_price,
        "exit_price": exit_p,
        "initial_stop": pos.get("initial_stop"),
        "stop_at_exit": pos.get("stop_loss"),
        "take_profit": pos.get("take_profit"),
        "cost_usd": cost_usd,
        "net_proceeds_usd": net_proceeds,
        "fees_usd": total_fees,
        "pnl_usd": net_pnl_usd,
        "pnl_pct": net_pnl_pct,
        "r_multiple": r_multiple,
        "exit_reason": reason,
        "opened_at": pos["opened_at"],
        "closed_at": now_utc.strftime("%Y-%m-%dT%H:%M:%SZ"),
    }

    pf["positions"].remove(pos)
    pf["cash"] = round(pf["cash"] + net_proceeds, 2)
    pf["closed_trades"].append(trade_record)
    recalc_portfolio_stats(pf)
    _atomic_write_json(portfolio_path, pf)

    _append_broker_log(
        log_path,
        {
            "at": now_utc.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "event": "CLOSE_POSITION",
            "symbol": sym,
            "exit_price": exit_p,
            "exit_reason": reason,
            "pnl_usd": net_pnl_usd,
            "pnl_pct": net_pnl_pct,
            "r_multiple": r_multiple,
            "cash_after": pf["cash"],
            "total_equity": pf["total_equity"],
        },
    )
    return {"trade": trade_record, "portfolio": pf}


def _append_broker_log(log_path: str, entry: dict):
    doc = {"events": []}
    if os.path.isfile(log_path):
        try:
            with open(log_path, encoding="utf-8") as fh:
                doc = json.load(fh)
        except Exception:
            doc = {"events": []}
    doc.setdefault("events", []).append(entry)
    doc["events"] = doc["events"][-500:]
    _atomic_write_json(log_path, doc)

