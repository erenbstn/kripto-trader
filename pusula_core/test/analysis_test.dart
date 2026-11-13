import 'package:pusula_core/pusula_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  const btc = Instrument.crypto('BTCUSDT');
  const sol = Instrument.crypto('SOLUSDT');
  const thy = Instrument.bist('THYAO');

  group('Indicators (Python referansı eşleşmesi)', () {
    test('wilderRsi ve computeAtr Python referans motoruyla birebir aynı sonucu verir', () {
      final bars = <Candle>[];
      var p = 100.0;
      final t0 = DateTime.utc(2026, 11, 1);
      for (var i = 0; i < 40; i++) {
        final o = p;
        final step = (i % 3 != 0) ? 0.4 : -0.25;
        final c = p * (1.0 + step / 100.0);
        final hi = (o > c ? o : c) * 1.002;
        final lo = (o < c ? o : c) * 0.998;
        bars.add(Candle(
          openTimeMs: t0.millisecondsSinceEpoch + i * BarInterval.m5.ms,
          open: o,
          high: hi,
          low: lo,
          close: c,
          volume: 1000,
          quoteVolume: 1000 * c,
        ));
        p = c;
      }
      final closes = [for (final b in bars) b.close];

      // Python `scanner_agent.py` altın değerleri:
      expect(Indicators.wilderRsi(closes, period: 14), closeTo(74.3085666509501, 1e-9));
      expect(Indicators.wilderRsi(closes, period: 7), closeTo(71.71473966242837, 1e-9));
      expect(Indicators.computeAtr(bars, period: 14), closeTo(0.7907114476221325, 1e-9));
      expect(Indicators.computeAtr(bars, period: 7), closeTo(0.7844102621366014, 1e-9));
    });

    test('SMA, EMA, VWAP, ADX ve gerçekleşen oynaklık hesaplamaları', () {
      final bars = syntheticCandles(
        start: DateTime.utc(2026, 11, 1),
        interval: BarInterval.h1,
        count: 60,
        startPrice: 100,
        stepPct: 0.5,
      );
      final closes = [for (final b in bars) b.close];
      final sma20 = Indicators.sma(closes, 20);
      final ema20 = Indicators.ema(closes, 20);
      expect(sma20, isNotNull);
      expect(ema20, isNotNull);
      expect(sma20, greaterThan(100));
      expect(ema20, greaterThan(100));
      expect(Indicators.vwap(bars, lookback: 24), greaterThan(100));

      final adx = Indicators.adx(bars, period: 14);
      expect(adx, isNotNull);
      expect(adx!.plusDi, greaterThan(adx.minusDi));

      final vol = Indicators.realizedVolatility(bars, period: 20);
      expect(vol, isNotNull);
      expect(vol!.barStdPct, greaterThan(0));
      expect(vol.annualizedPct, greaterThan(vol.barStdPct));
    });
  });

  group('RegimeDetector', () {
    const detector = RegimeDetector();

    test('güçlü yükseliş serisinde Boğa rejimi, düşüşte Ayı rejimi, kısa veride Yatay döner', () {
      final upBars = <Candle>[];
      final downBars = <Candle>[];
      var pu = 100.0;
      var pd = 200.0;
      final t0 = DateTime.utc(2026, 1, 1);
      for (var i = 0; i < 220; i++) {
        final cu = pu * 1.004;
        upBars.add(Candle(
          openTimeMs: t0.millisecondsSinceEpoch + i * 3600000,
          open: pu,
          high: cu * 1.002,
          low: pu * 0.999,
          close: cu,
          volume: 1000,
          quoteVolume: 1000 * cu,
        ));
        pu = cu;

        final cd = pd * 0.996;
        downBars.add(Candle(
          openTimeMs: t0.millisecondsSinceEpoch + i * 3600000,
          open: pd,
          high: pd * 1.001,
          low: cd * 0.998,
          close: cd,
          volume: 1000,
          quoteVolume: 1000 * cd,
        ));
        pd = cd;
      }

      final bull = detector.detect(btc, upBars);
      expect(bull.regime, MarketRegime.bull);
      expect(bull.riskMultiplier, 1.0);

      final bear = detector.detect(BistUniverse.benchmark, downBars);
      expect(bear.regime, MarketRegime.bear);
      expect(bear.riskMultiplier, 0.5);

      final short = detector.detect(btc, upBars.sublist(0, 15));
      expect(short.regime, MarketRegime.sideways);
    });
  });

  group('SetupScanner (6 kurulum, BIST kuralları, rejim süzgeci)', () {
    const scanner = SetupScanner();
    final t0 = DateTime.utc(2026, 11, 10, 8, 0); // 4 saatlik seans başlangıcı

    Candle barAt(int i, double o, double h, double l, double c, {double qv = 1e6, BarInterval iv = BarInterval.m5}) =>
        Candle(
          openTimeMs: t0.millisecondsSinceEpoch + i * iv.ms,
          open: o,
          high: h,
          low: l,
          close: c,
          volume: qv / c,
          quoteVolume: qv,
          takerBuyQuote: qv * 0.6,
        );

    /// RSI'ı ~52 civarında tutan gerçekçi salınımlı baz mumlar.
    List<Candle> oscillatingBase(int count, {double base = 100.0, BarInterval iv = BarInterval.m5}) {
      final out = <Candle>[];
      var p = base;
      for (var i = 0; i < count; i++) {
        final delta = i.isEven ? base * 0.002 : -base * 0.002;
        final c = p + delta;
        final hi = (p > c ? p : c) + base * 0.002;
        final lo = (p < c ? p : c) - base * 0.002;
        out.add(barAt(i, p, hi, lo, c, iv: iv));
        p = c;
      }
      return out;
    }

    test('1) ORB ve 2) 20-bar kırılımı tespit eder; forming mumu yok sayar', () {
      final bars = oscillatingBase(35);
      // Son kapanmış mum: ORB ve 20-bar zirvesini (~100.4) hacimli kırar
      bars.add(barAt(35, 100.1, 101.3, 100.0, 101.1, qv: 2.5e6));

      final series = CandleSeries(
        instrument: sol,
        interval: BarInterval.m5,
        closed: bars,
        // Forming mum çok düşük olsa bile kapanmış mumu etkilememeli
        forming: barAt(36, 101.1, 101.1, 80.0, 85.0),
        lastPrice: 85.0,
        source: 'binance',
        fetchedAt: t0.add(const Duration(hours: 3)),
        dataDelay: Duration.zero,
      );

      final det = scanner.analyze(series, regime: MarketRegime.bull);
      expect(det, isNotNull);
      expect(det!.setups, containsAll([SetupType.orb, SetupType.breakout20]));
      expect(det.lastClose, 101.1);

      // Ayı rejiminde kırılım kurulumları elenir
      final bearDet = scanner.analyze(series, regime: MarketRegime.bear);
      expect(bearDet, isNull);
    });

    test('3) Boğa Bayrağı (bull_flag) kurulumunu tespit eder', () {
      final bars = oscillatingBase(20);
      // 10 mumluk direk (indeks 20..29): 100 -> 102.6 (arada küçük kırmızı mumlarla RSI < 80 tutulur)
      var p = 100.0;
      for (var i = 20; i < 30; i++) {
        final step = (i == 23 || i == 27) ? -0.15 : 0.38;
        final c = p + step;
        bars.add(barAt(i, p, (p > c ? p : c) + 0.1, (p < c ? p : c) - 0.1, c));
        p = c;
      }
      // 5 mumluk dar bayrak (indeks 30..34): direk tepesi altında hafif geri çekilerek sıkışma
      final flagTop = p + 0.1;
      for (var i = 30; i < 35; i++) {
        final c = p - (i.isEven ? 0.25 : 0.05);
        bars.add(barAt(i, p, flagTop, p - 0.4, c));
      }
      // Son mum (indeks 35) bayrağı yukarı kırar
      bars.add(barAt(35, p, flagTop + 0.5, p - 0.1, flagTop + 0.35, qv: 2e6));

      final det = scanner.analyze(seriesOf(sol, BarInterval.m5, bars, t0));
      expect(det, isNotNull);
      expect(det!.setups, contains(SetupType.bullFlag));
    });

    test('4) MA20 geri kazanım (reclaim_ma20) ve 6) VWAP kırılımını tespit eder', () {
      final bars = oscillatingBase(34);
      // Sondan bir önceki mum MA20 ve VWAP altına sarkar
      bars.add(barAt(34, 100.0, 100.1, 98.8, 99.1));
      // Son mum güçlü hacimle hem MA20 hem VWAP üstüne çıkar
      bars.add(barAt(35, 99.2, 100.9, 99.1, 100.6, qv: 2.2e6));

      final det = scanner.analyze(seriesOf(sol, BarInterval.m5, bars, t0), regime: MarketRegime.sideways);
      expect(det, isNotNull);
      expect(det!.setups, containsAll([SetupType.reclaimMa20, SetupType.vwapBreakout]));
    });

    test('5) RSI aşırı satım tepkisini (oversold_bounce) Ayı rejiminde bile tespit eder', () {
      final bars = <Candle>[];
      var p = 100.0;
      for (var i = 0; i < 34; i++) {
        final next = p * 0.992; // sürekli düşüş -> RSI < 30
        bars.add(barAt(i, p, p * 1.001, next * 0.999, next));
        p = next;
      }
      // Son mum yeşil dönüş mumu
      final bounce = p * 1.008;
      bars.add(barAt(34, p * 0.999, bounce * 1.001, p * 0.998, bounce, qv: 1.8e6));

      final det = scanner.analyze(seriesOf(sol, BarInterval.m5, bars, t0), regime: MarketRegime.bear);
      expect(det, isNotNull);
      expect(det!.setups, contains(SetupType.oversoldBounce));
    });

    test('BIST 5 dk scalp dilimini reddeder; 1 saatlikte giriş bölgesini fiyat adımına yuvarlar', () {
      final bars5m = oscillatingBase(35, base: 310);
      bars5m.add(barAt(35, 310.5, 316, 310.2, 314.8, qv: 5e6));

      expect(scanner.analyze(seriesOf(thy, BarInterval.m5, bars5m, t0)), isNull);

      final bars1h = oscillatingBase(35, base: 310, iv: BarInterval.h1);
      bars1h.add(barAt(35, 310.5, 316, 310.2, 314.83, qv: 3e6, iv: BarInterval.h1));
      final det = scanner.analyze(seriesOf(thy, BarInterval.h1, bars1h, t0));
      expect(det, isNotNull);
      // 300-500 TL kademesinde fiyat adımı 0.25 TL'dir
      expect(det!.entryZoneLow, BistRules.roundToTick(det.entryZoneLow));
      expect(det.entryZoneHigh, BistRules.roundToTick(det.entryZoneHigh));
      expect(det.entryZoneHigh, greaterThan(det.entryZoneLow));
    });
  });

  group('ExitPlanner, MonteCarlo, News, Whale ve SignalEngine', () {
    final t0 = DateTime.utc(2026, 11, 10, 12);

    /// RSI'ı sağlıklı aralıkta (55-72) tutarken yukarı yönlü eğilim ve son mum kırılımı üreten seri.
    List<Candle> buildBullSeries(Instrument ins, BarInterval iv, {int count = 80}) {
      final bars = <Candle>[];
      var p = 100.0;
      for (var i = 0; i < count - 1; i++) {
        // 2 ileri 1 geri: sağlıklı yükseliş ve gerçekçi geri çekilmeler
        final double step;
        if (i >= count - 8) {
          // Kırılım öncesi son 7 mumda hafif geri çekilme / sıkışma (RSI ~58'e soğur)
          step = i.isEven ? -0.22 : 0.15;
        } else {
          step = (i % 3 == 0) ? -0.35 : 0.32;
        }
        final c = p * (1.0 + step / 100.0);
        bars.add(Candle(
          openTimeMs: t0.millisecondsSinceEpoch + i * iv.ms,
          open: p,
          high: (p > c ? p : c) * 1.003,
          low: (p < c ? p : c) * 0.998,
          close: c,
          volume: 1000,
          quoteVolume: 1000 * c,
          takerBuyQuote: 620 * c,
        ));
        p = c;
      }
      // Son mumda 20-bar zirvesi üzerine hacimli kırılım
      var hi20 = 0.0;
      for (var i = count - 21; i < count - 1; i++) {
        if (bars[i].high > hi20) hi20 = bars[i].high;
      }
      final cLast = hi20 * 1.006;
      bars.add(Candle(
        openTimeMs: t0.millisecondsSinceEpoch + (count - 1) * iv.ms,
        open: p,
        high: cLast * 1.002,
        low: p * 0.999,
        close: cLast,
        volume: 2500,
        quoteVolume: 2500 * cLast,
        takerBuyQuote: 1600 * cLast,
      ));
      return bars;
    }

    test('BIST çıkış planı adımlara oturur ve tavana yakınlık uyarısı üretir', () {
      final bars = buildBullSeries(thy, BarInterval.h1);
      final det = const SetupScanner().analyze(seriesOf(thy, BarInterval.h1, bars, t0))!;
      final plan = const ExitPlanner().build(det, previousDayClose: det.lastClose / 1.095);
      expect(plan.stop, BistRules.roundToTick(plan.stop));
      expect(plan.target1, BistRules.roundToTick(plan.target1));
      expect(plan.target2, BistRules.roundToTick(plan.target2));
      expect(plan.limitWarning, isNotNull);
    });

    test('Monte Carlo blok önyükleme aynı tohumla aynı sonucu ve güven aralığını üretir', () {
      final bars = buildBullSeries(sol, BarInterval.m5, count: 90);
      final det = const SetupScanner().analyze(seriesOf(sol, BarInterval.m5, bars, t0))!;
      final plan = const ExitPlanner().build(det);
      const sim = MonteCarloSimulator(replays: 1000, blockSize: 4, seed: 42);

      final r1 = sim.simulate(plan, bars);
      final r2 = sim.simulate(plan, bars);
      expect(r1.avgR, r2.avgR);
      expect(r1.pTarget, r2.pTarget);
      expect(r1.avgRConfidenceLow, lessThanOrEqualTo(r1.avgR));
      expect(r1.avgRConfidenceHigh, greaterThanOrEqualTo(r1.avgR));
      expect(r1.approved, isTrue);
    });

    test('Haber vetosu: genel kelimeler (link, sol, gold, default) yanlış pozitif üretmez', () {
      const news = NewsAnalyzer();
      final falsePositives = [
        (source: 'RSS', title: 'Click this link to read the default settings for gold medalists', summary: 'Sol de verano'),
        (source: 'RSS', title: 'Browser exploit patched by default in new link handler', summary: ''),
      ];
      expect(news.evaluateHeadlines(const Instrument.crypto('LINKUSDT'), falsePositives).veto, isFalse);
      expect(news.evaluateHeadlines(sol, falsePositives).veto, isFalse);
      expect(news.evaluateHeadlines(const Instrument.crypto('PAXGUSDT'), falsePositives).veto, isFalse);

      final realDanger = [
        (source: 'CoinDesk', title: 'Solana bridge exploited for 50M in major hack', summary: ''),
      ];
      final rep = news.evaluateHeadlines(sol, realDanger);
      expect(rep.veto, isTrue);
      expect(rep.vetoReason, contains('hack_exploit'));
    });

    test('WhaleAnalyzer: emir defteri dengesi veto etmez, aşırı fonlama oranı veto eder', () {
      const whale = WhaleAnalyzer();
      final bars = buildBullSeries(sol, BarInterval.m5, count: 30);
      final r1 = whale.evaluate(sol, bars, fundingRatePct: 0.02, orderbookBidAskRatio: 0.25);
      expect(r1.veto, isFalse);
      expect(r1.orderbookInfoNote, contains('bilgi amaçlı'));

      final r2 = whale.evaluate(sol, bars, fundingRatePct: 0.28, orderbookBidAskRatio: 1.5);
      expect(r2.veto, isTrue);
      expect(r2.vetoReason, contains('fonlama'));
    });

    test('SignalEngine uçtan uca onaylı SignalRecord ve güven skoru dökümü üretir', () {
      final clock = FakeClock(t0.add(const Duration(hours: 8)));
      final engine = SignalEngine(
        clock: clock.call,
        monteCarlo: const MonteCarloSimulator(replays: 800, seed: 7),
      );
      final sigBars = buildBullSeries(sol, BarInterval.m5, count: 90);
      final higherBars = buildBullSeries(sol, BarInterval.h1, count: 60);
      final regime = const RegimeDetector().detect(btc, buildBullSeries(btc, BarInterval.h1, count: 120));

      final eval = engine.evaluate(
        signalSeries: seriesOf(sol, BarInterval.m5, sigBars, clock.now, source: 'binance'),
        higherClosedBars: higherBars,
        regime: regime,
      );

      expect(eval.approved, isTrue, reason: eval.reason);
      expect(eval.confidence, isNotNull);
      expect(eval.confidence!.total, inInclusiveRange(50, 100));
      // 6 bileşen + (varsa) kalite düzeltmesi satırı: bu senaryoda sinyal mumu 30 dk (6 mum) önce kapandı.
      expect(eval.confidence!.reasons.length, inInclusiveRange(6, 7));
      expect(eval.cost, isNotNull);
      expect(eval.signalRecord, isNotNull);
      expect(eval.signalRecord!.status, SignalStatus.open);
      expect(eval.signalRecord!.strategyVersion, '2.1.0');
    });
  });
}
