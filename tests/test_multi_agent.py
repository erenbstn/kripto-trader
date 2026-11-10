"""
Kripto Multi-Agent Day Trader — Kapsamlı Birim ve Entegrasyon Testleri
11 Ajanın tamamını (Scanner, News, Whale, Entry, Exit, TimeMachine,
Budget, Risk, Broker, Alerts, Notifier) ve uçtan uca işlem döngüsünü test eder.
"""

import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_DIR))

from agents.scanner_agent import analyze_symbol_setups
from agents.news_agent import check_symbol_news
from agents.entry_agent import check_entry
from agents.exit_agent import build_exit_plan
from agents.timemachine_agent import run_timemachine
from agents.budget_agent import size_position
from agents.risk_agent import check_order_risk
from agents.broker_agent import load_portfolio, reset_portfolio, execute_paper_buy
from agents.alerts_agent import monitor_open_positions


def make_synthetic_bars(n: int = 120, start_price: float = 100.0) -> list:
    """Testler için gerçekçi 5 dakikalık OHLCV mum dizisi üretir (son mum hacimli kırılım yapar)."""
    bars = []
    price = start_price
    # 00:00 UTC'den başlayan 5 dakikalık mumlar
    base_ts = 1710028800

    for i in range(n):
        if i < n - 1:
            # Sıkışma / konsolidasyon bölgesi (99.60 - 100.40 arası)
            wave = ((i % 6) - 2.5) * 0.08
            o = round(price, 4)
            c = round(100.0 + wave, 4)
            h = round(max(o, c) + 0.15, 4)
            l = round(min(o, c) - 0.15, 4)
            v = 1000.0 + (i % 5) * 80.0
            price = c
        else:
            # Son kapanmış mumda hacimli yukarı kırılım (20-bar zirvesi ve ORB üstü)
            o = round(price, 4)
            c = 101.10
            h = 101.25
            l = round(min(o, 99.95), 4)
            v = 4200.0
            price = c

        ts = base_ts + i * 300
        bars.append({
            "t": ts,
            "dt": f"2026-03-10 {(i // 12) % 24:02d}:{(i % 12) * 5:02d}",
            "o": o,
            "h": h,
            "l": l,
            "c": c,
            "v": v,
            "qv": round(v * c, 2),
            "tbv": round(v * 0.68, 2),
            "closed": True,
        })
    return bars


class TestMultiAgentSystem(unittest.TestCase):

    def setUp(self):
        with open(PROJECT_DIR / "config.json", "r", encoding="utf-8") as f:
            self.config = json.load(f)
        self.bars = make_synthetic_bars(120, start_price=100.0)

    def test_01_scanner_agent_detects_breakout(self):
        """Ajan 1 (Scanner): Kırılım mumlarında sinyal, kurulum ve OR seviyeleri üretmeli."""
        res = analyze_symbol_setups("SOLUSDT", self.bars, or_minutes=15)
        self.assertIsNotNone(res)
        self.assertEqual(res["symbol"], "SOLUSDT")
        self.assertGreater(res["score"], 0)
        self.assertTrue(len(res["setups"]) >= 1)
        self.assertGreater(res["or_high"], res["or_low"])

    def test_02_news_agent_veto_on_hack_headline(self):
        """Ajan 2 (News): Hack/Exploit haberlerinde işlemi otomatik VETO etmeli."""
        fake_news = [
            {
                "title": "Major exploit and hack reported on Solana bridge, funds drained",
                "summary": "Hackers drained funds in an exploit.",
                "source": "CoinDesk",
                "link": "https://example.com",
            }
        ]
        res = check_symbol_news("SOLUSDT", offline_headlines=fake_news, fetch_live=False)
        self.assertTrue(res["veto"])
        self.assertIn("hack_exploit", res["veto_reason"])

    def test_03_entry_agent_requires_closed_candle_breakout(self):
        """Ajan 4 (Entry): Tamamlanmış mum kırılım seviyesinin üzerindeyse triggered dönmeli."""
        hit = analyze_symbol_setups("SOLUSDT", self.bars, or_minutes=15)
        res = check_entry(
            symbol="SOLUSDT",
            setup=hit["primary_setup"],
            level=hit["level"],
            interval="5m",
            or_minutes=15,
            bars=self.bars,
        )
        self.assertEqual(res["status"], "triggered")
        self.assertGreater(res["price"], res["level"])

    def test_04_exit_agent_computes_2r_plan_and_breakeven(self):
        """Ajan 5 (Exit): Stop-Loss, 2R Take-Profit ve +1R Breakeven tetikleyicisini doğru hesaplamalı."""
        hit = analyze_symbol_setups("SOLUSDT", self.bars, or_minutes=15)
        entry_doc = check_entry(
            symbol="SOLUSDT",
            setup=hit["primary_setup"],
            level=hit["level"],
            interval="5m",
            or_minutes=15,
            bars=self.bars,
        )
        plan = build_exit_plan(entry_doc=entry_doc, config=self.config, stop_rule="auto")
        self.assertLess(plan["stop"], plan["entry"])
        self.assertGreater(plan["target"], plan["entry"])
        self.assertAlmostEqual(plan["reward_risk"], 2.0, places=1)
        self.assertAlmostEqual(
            plan["breakeven_trigger"] - plan["entry"],
            plan["entry"] - plan["stop"],
            places=4,
        )

    def test_05_timemachine_monte_carlo_simulation(self):
        """Ajan 6 (TimeMachine): Monte Carlo simülasyonu çalışmalı ve olasılık raporu üretmeli."""
        hit = analyze_symbol_setups("SOLUSDT", self.bars, or_minutes=15)
        entry_doc = check_entry(
            symbol="SOLUSDT",
            setup=hit["primary_setup"],
            level=hit["level"],
            interval="5m",
            or_minutes=15,
            bars=self.bars,
        )
        plan = build_exit_plan(entry_doc=entry_doc, config=self.config, stop_rule="auto")
        cfg = dict(self.config)
        cfg["timemachine"] = dict(self.config.get("timemachine", {}), sims=2000)
        tm = run_timemachine(plan=plan, config=cfg, bars=self.bars)
        self.assertIn("p_target", tm["mc"])
        self.assertIn("p_stop", tm["mc"])
        self.assertIn("avg_R", tm["mc"])

    def test_06_budget_agent_respects_500_budget_and_50_max_loss(self):
        """Ajan 7 (Budget): $500 kasa ve $50 maksimum zarar sınırını kesinlikle aşmamalı."""
        plan = {
            "symbol": "ETHUSDT",
            "setup": "orb",
            "entry": 2500.0,
            "stop": 2400.0,  # %4 stop mesafesi
            "target": 2700.0,
            "breakeven_trigger": 2600.0,
            "reward_to_risk": 2.0,
            "flat_by": "2099-01-01T00:00:00Z",
        }
        pf = {"cash": 500.0, "total_equity": 500.0, "positions": []}
        budget_doc = size_position(plan=plan, config=self.config, portfolio=pf, live_price=2500.0)
        self.assertIsNone(budget_doc["refusal"])
        self.assertLessEqual(budget_doc["max_loss_usd"], 50.01)
        self.assertLessEqual(budget_doc["notional_usd"], 500.0 * 0.75 + 0.01)
        self.assertLessEqual(budget_doc["notional_usd"], 500.0 * 0.90 + 0.01)
        self.assertGreater(budget_doc["qty"], 0)

    def test_07_risk_agent_16_rules_and_sha256_fingerprint(self):
        """Ajan 8 (Risk): 16 kuralı doğrulamalı ve 16 karakterlik SHA-256 parmak izi üretmeli."""
        plan = {
            "symbol": "BTCUSDT",
            "setup": "orb",
            "entry": 90000.0,
            "stop": 88500.0,
            "target": 93000.0,
            "breakeven_trigger": 91500.0,
            "reward_to_risk": 2.0,
            "flat_by": "2099-01-01T00:00:00Z",
        }
        pf = {"cash": 500.0, "total_equity": 500.0, "positions": [], "closed_trades": []}
        budget_doc = size_position(plan=plan, config=self.config, portfolio=pf, live_price=90000.0)
        order = budget_doc["orders"][0]

        risk_doc = check_order_risk(
            order=order,
            config=self.config,
            portfolio=pf,
            news_report={"veto": False},
            whale_report={"veto": False},
            timemachine_report={"approved": True},
        )
        self.assertEqual(risk_doc["verdict"], "PASS")
        self.assertEqual(len(risk_doc["fingerprint"]), 16)

    def test_08_broker_and_alerts_lifecycle_with_breakeven_and_tp(self):
        """Ajan 9 & 10 (Broker + Alerts): Pozisyon açma -> +1R Breakeven -> 2R Take-Profit tam döngüsü."""
        with tempfile.TemporaryDirectory() as tmpdir:
            pf_path = os.path.join(tmpdir, "portfolio.json")
            log_path = os.path.join(tmpdir, "broker_log.json")

            # 1. $500 Bakiye ile başlat
            pf = reset_portfolio(500.0, path=pf_path)
            self.assertEqual(pf["cash"], 500.0)

            plan = {
                "symbol": "SOLUSDT",
                "setup": "orb",
                "entry": 100.0,
                "stop": 95.0,
                "target": 110.0,
                "breakeven_trigger": 105.0,
                "reward_to_risk": 2.0,
                "flat_by": "2099-01-01T00:00:00Z",
            }
            budget_doc = size_position(plan=plan, config=self.config, portfolio=pf, live_price=100.0)
            order = budget_doc["orders"][0]
            risk_doc = check_order_risk(
                order=order,
                config=self.config,
                portfolio=pf,
                news_report={"veto": False},
                whale_report={"veto": False},
                timemachine_report={"approved": True},
            )

            # 2. Sanal Pozisyonu Aç
            exec_res = execute_paper_buy(
                order=order,
                risk_doc=risk_doc,
                config=self.config,
                timemachine_doc={"verdict": "ONAYLANDI"},
                portfolio_path=pf_path,
                log_path=log_path,
            )
            self.assertEqual(len(exec_res["portfolio"]["positions"]), 1)

            # 3. Fiyat $106'ya çıktı (+1R = $105 aşıldı) -> Breakeven tetiklenmeli!
            mon_1r = monitor_open_positions(
                config=self.config,
                portfolio_path=pf_path,
                log_path=log_path,
                live_prices_override={"SOLUSDT": 106.0},
            )
            self.assertEqual(len(mon_1r["breakeven_events"]), 1)
            pf_after_be = load_portfolio(self.config, path=pf_path)
            self.assertTrue(pf_after_be["positions"][0]["breakeven_moved"])
            self.assertGreater(pf_after_be["positions"][0]["stop_loss"], 100.0)

            # 4. Fiyat $111'e çıktı (TP = $110 aşıldı) -> Kar Al ile otomatik kapanmalı!
            mon_tp = monitor_open_positions(
                config=self.config,
                portfolio_path=pf_path,
                log_path=log_path,
                live_prices_override={"SOLUSDT": 111.0},
            )
            self.assertEqual(len(mon_tp["closed_events"]), 1)
            self.assertIn("TAKE_PROFIT", mon_tp["closed_events"][0]["exit_reason"])
            self.assertGreater(mon_tp["closed_events"][0]["pnl_usd"], 0)

            # 5. Kasa $500'ün üzerine çıkmış olmalı
            final_pf = load_portfolio(self.config, path=pf_path)
            self.assertEqual(len(final_pf["positions"]), 0)
            self.assertGreater(final_pf["total_equity"], 500.0)
            self.assertEqual(final_pf["stats"]["wins"], 1)



class TestLocalNotifierAndNoSecrets(unittest.TestCase):

    def test_09_notifier_writes_local_jsonl_and_strips_markup(self):
        from agents.notifier import LocalNotifier
        with tempfile.TemporaryDirectory() as td:
            n = LocalNotifier(td, echo=False, max_lines=3)
            for i in range(5):
                n.push(f"<b>SOL</b> hedefe ulaştı {i}", kind="sonuc", symbol="SOLUSDT")
            rec = n.recent(10)
            self.assertEqual(len(rec), 3)
            self.assertEqual(rec[-1]["text"], "SOL hedefe ulaştı 4")
            self.assertEqual(rec[-1]["kind"], "sonuc")

    def test_10_no_messaging_service_or_secret_in_code_and_config(self):
        import re
        banned = re.compile(r"telegram|bot_token|api\.telegram\.org", re.I)
        token_like = re.compile(r"[0-9]{8,10}:[A-Za-z0-9_-]{35}")
        files = [PROJECT_DIR / "main.py", PROJECT_DIR / "config.json"] + sorted((PROJECT_DIR / "agents").glob("*.py"))
        for fp in files:
            text = fp.read_text(encoding="utf-8")
            self.assertIsNone(banned.search(text), f"{fp.name} içinde mesajlaşma servisi izi var")
            self.assertIsNone(token_like.search(text), f"{fp.name} içinde token benzeri değer var")
        self.assertFalse((PROJECT_DIR / "agents" / "telegram_agent.py").exists())
        with open(PROJECT_DIR / "config.json", encoding="utf-8") as f:
            cfg = json.load(f)
        self.assertNotIn("telegram", cfg)
        self.assertEqual(len(cfg["watchlist_symbols"]), 10)


if __name__ == "__main__":
    unittest.main()
