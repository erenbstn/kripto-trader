import 'package:pusula_core/pusula_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// K9 huni iyileştirmeleri — tamamı sentetik veriyle, ağsız ve geçmiş veri sınaması olmadan doğrulanır.
void main() {
  const btc = Instrument.crypto('BTCUSDT');
  const sol = Instrument.crypto('SOLUSDT');
  const thy = Instrument.bist('THYAO');
  final now = DateTime.utc(2026, 11, 12, 14, 1);
  final lastClose = DateTime.utc(2026, 11, 12, 14, 0);

  RegimeReport bullRegime() => const RegimeDetector().detect(
        btc,
        bullBreakoutBars(lastBarClose: lastClose, interval: BarInterval.h4, count: 220),
      );

  SignalEngine engineAt(DateTime at, {TradingCosts costs = const TradingCosts(), double maxExtensionAtr = 1.5}) =>
      SignalEngine(
        clock: () => at,
        monteCarlo: const MonteCarloSimulator(replays: 600, seed: 11),
        costs: costs,
        maxExtensionAtr: maxExtensionAtr,
      );

  SignalEvaluation run(
    SignalEngine engine,
    List<Candle> bars, {
    Instrument ins = sol,
    BarInterval iv = BarInterval.h1,
    bool stale = false,
    DateTime? fetchedAt,
  }) =>
      engine.evaluate(
        signalSeries: seriesOf(ins, iv, bars, fetchedAt ?? now, source: 'binance').copyWith(stale: stale),
        higherClosedBars: bullBreakoutBars(lastBarClose: lastClose, interval: BarInterval.h4, count: 80),
        regime: bullRegime(),
      );

  group('Veri tazeliği süzgeci', () {
    test('temiz kırılım serisi varsayılan ayarlarla onaylanır (taban senaryo)', () {
      final eval = run(engineAt(now), bullBreakoutBars(lastBarClose: lastClose, interval: BarInterval.h1));
      expect(eval.approved, isTrue, reason: eval.reason);
      expect(eval.stage, FunnelStage.approved);
      expect(eval.signalRecord!.strategyVersion, kStrategyVersion);
    });

    test('bayat (stale) seriyle aynı kurulum sinyal üretmez', () {
      final eval = run(
        engineAt(now),
        bullBreakoutBars(lastBarClose: lastClose, interval: BarInterval.h1),
        stale: true,
      );
      expect(eval.approved, isFalse);
      expect(eval.stage, FunnelStage.data);
      expect(eval.reason, contains('bayat'));
      expect(eval.signalRecord, isNull);
    });

    test('kriptoda son mum 3 mumdan eskiyse sinyal üretilmez', () {
      final later = lastClose.add(const Duration(hours: 5));
      final eval = run(
        engineAt(later),
        bullBreakoutBars(lastBarClose: lastClose, interval: BarInterval.h1),
        fetchedAt: later,
      );
      expect(eval.stage, FunnelStage.data);
      expect(eval.reason, contains('güncel değil'));
    });

    test('BIST günlük mumunda hafta sonu boşluğu (3 gün) bayat sayılmaz, 6 gün sayılır', () {
      expect(SignalEngine.maxSignalBarAge(Market.bist, BarInterval.d1), const Duration(days: 4));
      expect(SignalEngine.maxSignalBarAge(Market.bist, BarInterval.h1), const Duration(hours: 20));
      expect(SignalEngine.maxSignalBarAge(Market.crypto, BarInterval.h1), const Duration(hours: 3));
      expect(SignalEngine.maxSignalBarAge(Market.crypto, BarInterval.m5), const Duration(minutes: 45));

      final friClose = DateTime.utc(2026, 11, 6, 15, 10);
      final bars = bullBreakoutBars(lastBarClose: friClose, interval: BarInterval.d1, startPrice: 300);
      final monday = friClose.add(const Duration(days: 3));
      final ok = run(engineAt(monday), bars, ins: thy, iv: BarInterval.d1, fetchedAt: monday);
      expect(ok.stage, isNot(FunnelStage.data), reason: ok.reason);

      final nextWeek = friClose.add(const Duration(days: 6));
      final old = run(engineAt(nextWeek), bars, ins: thy, iv: BarInterval.d1, fetchedAt: nextWeek);
      expect(old.stage, FunnelStage.data);
    });
  });

  group('Kurulum kalitesi süzgeci', () {
    test('fiyat tetik seviyesinden çok uzaklaşmışsa (kovalama) aday elenir', () {
      final eval = run(
        engineAt(now, maxExtensionAtr: 0.05),
        bullBreakoutBars(lastBarClose: lastClose, interval: BarInterval.h1),
      );
      expect(eval.approved, isFalse);
      expect(eval.stage, FunnelStage.quality);
      expect(eval.reason, contains('ATR'));
      expect(eval.detection, isNotNull, reason: 'kurulum bulundu ama kalite süzgecinde elendi');
    });

    test('kırılım mumu uzun üst fitille kapandıysa reddedilir', () {
      final eval = run(
        engineAt(now),
        bullBreakoutBars(lastBarClose: lastClose, interval: BarInterval.h1, wickPct: 3.0),
      );
      expect(eval.approved, isFalse);
      expect(eval.stage, FunnelStage.quality);
      expect(eval.reason, contains('fitil'));
    });

    test('ortalama altı hacimli kırılım onaylanmaz', () {
      final eval = run(
        engineAt(now),
        bullBreakoutBars(lastBarClose: lastClose, interval: BarInterval.h1, lastVolumeFactor: 0.6),
      );
      expect(eval.approved, isFalse);
      expect([FunnelStage.quality, FunnelStage.scanner], contains(eval.stage));
    });
  });

  group('İşlem maliyeti süzgeci', () {
    test('maliyet etkisi: net Ö/R = (brüt − maliyetR) / (1 + maliyetR)', () {
      final det = const SetupScanner().analyze(
        seriesOf(sol, BarInterval.h1, bullBreakoutBars(lastBarClose: lastClose, interval: BarInterval.h1), now),
      )!;
      final plan = const ExitPlanner().build(det);
      final impact = const TradingCosts(cryptoRoundTripPct: 0.20).impact(plan);
      final costR = 0.20 / plan.stopDistancePct;
      expect(impact.costShareOfRisk, closeTo(costR, 0.001));
      expect(impact.netRewardRisk, closeTo((plan.rewardRisk - costR) / (1 + costR), 0.01));
      expect(impact.netRewardRisk, lessThan(plan.rewardRisk));
      expect(const TradingCosts().roundTripPct(Market.bist), greaterThan(const TradingCosts().roundTripPct(Market.crypto)));
    });

    test('maliyet stop mesafesinin büyük kısmını yiyorsa aday "cost" aşamasında elenir', () {
      final eval = run(
        engineAt(now, costs: const TradingCosts(cryptoRoundTripPct: 1.5)),
        bullBreakoutBars(lastBarClose: lastClose, interval: BarInterval.h1),
      );
      expect(eval.approved, isFalse);
      expect(eval.stage, FunnelStage.cost);
      expect(eval.cost, isNotNull);
      expect(eval.reason, contains('maliyet'));
    });

    test('onaylanan sinyalde güven skoru net Ö/R üzerinden hesaplanır ve gerekçede görünür', () {
      final eval = run(engineAt(now), bullBreakoutBars(lastBarClose: lastClose, interval: BarInterval.h1));
      expect(eval.approved, isTrue, reason: eval.reason);
      expect(eval.cost!.netRewardRisk, lessThan(eval.plan!.rewardRisk));
      expect(eval.confidence!.reasons.any((r) => r.contains('maliyet sonrası')), isTrue);
      expect(eval.signalRecord!.rationale, contains('net Ö/R'));
    });
  });

  group('Rejime duyarlı güven eşiği ve kalite düzeltmesi', () {
    test('eşik Boğa < Yatay < Ayı sırasıyla yükselir', () {
      final e = SignalEngine(clock: () => now);
      expect(e.confidenceThresholdFor(MarketRegime.bull), 50);
      expect(e.confidenceThresholdFor(MarketRegime.sideways), 54);
      expect(e.confidenceThresholdFor(MarketRegime.bear), 58);
    });

    test('Ayı rejiminde kırılım kurulumları elenir; kalan kurulum yükseltilmiş eşiği geçmek zorundadır', () {
      final bear = const RegimeDetector().detect(
        btc,
        downtrendBars(lastBarClose: lastClose, interval: BarInterval.h4),
      );
      expect(bear.regime, MarketRegime.bear);
      final eval = engineAt(now).evaluate(
        signalSeries: seriesOf(
          sol,
          BarInterval.h1,
          bullBreakoutBars(lastBarClose: lastClose, interval: BarInterval.h1),
          now,
        ),
        higherClosedBars: bullBreakoutBars(lastBarClose: lastClose, interval: BarInterval.h4, count: 80),
        regime: bear,
      );
      // Kırılım kurulumları (ORB, 20-bar, bayrak, VWAP) Ayı rejiminde elenir; geriye yalnızca kırılım
      // olmayan kurulum (ör. MA20 geri kazanım) kalabilir ve o da yükseltilmiş eşiği (58) geçmek zorundadır.
      expect(eval.detection?.setups.any((s) => s.isBreakout) ?? false, isFalse);
      if (eval.approved) {
        expect(eval.signalRecord!.strategy.isBreakout, isFalse);
        expect(eval.confidence!.total, greaterThanOrEqualTo(58));
        expect(eval.signalRecord!.regime, MarketRegime.bear);
      }
    });

    test('kalite düzeltmesi toplamdan düşer, JSON döngüsünde korunur, eski kayıtlarda 0 okunur', () {
      const withPenalty = ConfidenceBreakdown(
        setupConfluence: 20,
        volumeConfirmation: 10,
        regimeAlignment: 15,
        higherTimeframeAlignment: 15,
        monteCarloScore: 10,
        rewardRiskScore: 10,
        qualityAdjustment: -7,
        reasons: ['x'],
      );
      expect(withPenalty.total, 73);
      final back = ConfidenceBreakdown.fromJson(withPenalty.toJson());
      expect(back.qualityAdjustment, -7);
      expect(back.total, 73);

      final legacy = Map<String, Object?>.from(withPenalty.toJson())..remove('qualityAdjustment');
      expect(ConfidenceBreakdown.fromJson(legacy).qualityAdjustment, 0);
      expect(ConfidenceBreakdown.fromJson(legacy).total, 80);
    });

    test('Monte Carlo güven aralığı sıfırı içeriyorsa ceza uygulanır ve gerekçeye yazılır', () {
      final bars = bullBreakoutBars(lastBarClose: lastClose, interval: BarInterval.h1);
      final det = const SetupScanner().analyze(seriesOf(sol, BarInterval.h1, bars, now))!;
      final plan = const ExitPlanner().build(det);
      final mtf = const MultiTimeframeAnalyzer().evaluate(
        market: Market.crypto,
        signalInterval: BarInterval.h1,
        higherClosedBars: bullBreakoutBars(lastBarClose: lastClose, interval: BarInterval.h4, count: 80),
      );
      MonteCarloResult mc({required double ciLow}) => MonteCarloResult(
            replays: 100,
            seed: 1,
            blockSize: 4,
            barsSimulated: 24,
            pTarget: 0.4,
            pTarget1: 0.6,
            pStop: 0.4,
            pNeither: 0.2,
            pGreen: 0.55,
            avgR: 0.12,
            avgRConfidenceLow: ciLow,
            avgRConfidenceHigh: 0.3,
            winShareOfDecided: 0.5,
            breakevenShareNeeded: 0.33,
            p5Close: 95,
            medianClose: 101,
            p95Close: 108,
            approved: true,
            verdict: 'test',
          );
      const scorer = ConfidenceScorer();
      final clean = scorer.score(detection: det, regime: bullRegime(), mtf: mtf, plan: plan, monteCarlo: mc(ciLow: 0.02));
      final shaky = scorer.score(detection: det, regime: bullRegime(), mtf: mtf, plan: plan, monteCarlo: mc(ciLow: -0.05));
      expect(clean.qualityAdjustment, 0);
      expect(clean.reasons.length, 6);
      expect(shaky.qualityAdjustment, -4);
      expect(shaky.total, clean.total - 4);
      expect(shaky.reasons.last, contains('Kalite düzeltmesi'));
    });
  });

  group('Boşluklu (gap) stop muhasebesi', () {
    final t0 = DateTime.utc(2026, 11, 10, 12);
    SignalRecord sig({SignalStatus status = SignalStatus.open, double? currentStop}) => SignalRecord(
          id: 'bist:THYAO|1d|1',
          instrument: thy,
          interval: BarInterval.d1,
          strategy: SetupType.breakout20,
          allSetups: const [SetupType.breakout20],
          strategyVersion: kStrategyVersion,
          entryZoneLow: 99.5,
          entryZoneHigh: 100.5,
          entryPrice: 100.0,
          initialStop: 98.0,
          currentStop: currentStop ?? 98.0,
          target1: 102.0,
          target2: 104.0,
          rewardRisk: 2.0,
          confidence: const ConfidenceBreakdown(
            setupConfluence: 20,
            volumeConfirmation: 10,
            regimeAlignment: 15,
            higherTimeframeAlignment: 15,
            monteCarloScore: 10,
            rewardRiskScore: 10,
            reasons: [],
          ),
          rationale: 'test',
          invalidationRule: 'test',
          regime: MarketRegime.bull,
          dataSource: 'yahoo',
          dataAgeMs: 0,
          dataStale: false,
          createdAt: t0,
          expiresAt: t0.add(const Duration(days: 7)),
          status: status,
          lastProcessedBarTimeMs: t0.millisecondsSinceEpoch,
        );
    Candle day(int i, double o, double h, double l, double c) => Candle(
          openTimeMs: t0.millisecondsSinceEpoch + i * BarInterval.d1.ms,
          open: o,
          high: h,
          low: l,
          close: c,
          volume: 1,
          quoteVolume: c,
        );

    test('mum stop altında açılırsa çıkış açılış fiyatından olur (kayıp -1R\'den büyük)', () async {
      final store = MemorySignalJournalStore();
      final tracker = SignalOutcomeTracker(store: store, clock: () => t0.add(const Duration(days: 2)));
      final r = await tracker.evaluateSignal(sig(), [day(1, 96.0, 97.0, 95.5, 96.5)]);
      expect(r.updated.status, SignalStatus.stop);
      expect(r.updated.exitPrice, 96.0);
      expect(r.updated.realizedR, -2.0);
      expect(r.updated.realizedPct, -4.0);
      expect(r.updated.exitReason, contains('Boşluk'));
    });

    test('mum stop üstünde açılıp stopa değerse çıkış stop fiyatından olur (-1R)', () async {
      final store = MemorySignalJournalStore();
      final tracker = SignalOutcomeTracker(store: store, clock: () => t0.add(const Duration(days: 2)));
      final r = await tracker.evaluateSignal(sig(), [day(1, 99.5, 99.8, 97.5, 98.2)]);
      expect(r.updated.exitPrice, 98.0);
      expect(r.updated.realizedR, -1.0);
    });

    test('hedef 1 sonrası boşlukla girişin altında açılış: +1R yarısı ile zarar yarısı netleşir', () async {
      final store = MemorySignalJournalStore();
      final tracker = SignalOutcomeTracker(store: store, clock: () => t0.add(const Duration(days: 2)));
      final r = await tracker.evaluateSignal(
        sig(status: SignalStatus.target1, currentStop: 100.0),
        [day(1, 98.0, 98.5, 97.0, 97.5)],
      );
      expect(r.updated.status, SignalStatus.stop);
      expect(r.updated.breakevenStop, isTrue);
      // 0,5 × (+1R) + 0,5 × (−1R) = 0R
      expect(r.updated.realizedR, 0.0);
    });
  });

  group('Haftalık rapor: takvim haftası penceresi ve performans eğrisi', () {
    test('reviewFrom/reviewUntil verilince yalnızca geçen haftanın önerileri karneye girer; reportId sabitlenir',
        () async {
      final journal = MemorySignalJournalStore();
      final reports = MemoryWeeklyReportStore();
      final weekStart = DateTime.utc(2026, 11, 9);
      final clockNow = DateTime.utc(2026, 11, 11, 9);

      SignalRecord proposal(String id, DateTime createdAt, {double? realizedPct}) => SignalRecord(
            id: id,
            instrument: thy,
            interval: BarInterval.d1,
            strategy: SetupType.breakout20,
            allSetups: const [SetupType.breakout20],
            strategyVersion: kStrategyVersion,
            entryZoneLow: 99,
            entryZoneHigh: 101,
            entryPrice: 100,
            initialStop: 96,
            currentStop: 96,
            target1: 104,
            target2: 108,
            rewardRisk: 2,
            confidence: const ConfidenceBreakdown(
              setupConfluence: 20,
              volumeConfirmation: 10,
              regimeAlignment: 15,
              higherTimeframeAlignment: 15,
              monteCarloScore: 10,
              rewardRiskScore: 10,
              reasons: [],
            ),
            rationale: 'test',
            invalidationRule: 'test',
            regime: MarketRegime.bull,
            dataSource: 'yahoo',
            dataAgeMs: 0,
            dataStale: false,
            createdAt: createdAt,
            expiresAt: createdAt.add(const Duration(days: 7)),
            status: realizedPct == null ? SignalStatus.open : SignalStatus.target2,
            isWeeklyProposal: true,
            allocatedWeightPct: 10,
            realizedPct: realizedPct,
            realizedR: realizedPct == null ? null : 2.0,
            closedAt: realizedPct == null ? null : createdAt.add(const Duration(days: 3)),
            exitPrice: realizedPct == null ? null : 108,
          );

      await journal.save(proposal('gecen_hafta', DateTime.utc(2026, 11, 3), realizedPct: 8.0));
      await journal.save(proposal('bu_hafta', DateTime.utc(2026, 11, 10)));

      final gen = WeeklyReportGenerator(journalStore: journal, reportStore: reports, clock: () => clockNow);
      final report = await gen.generate(
        newCandidates: const [],
        reportId: 'weekly_20261109',
        reviewFrom: weekStart.subtract(const Duration(days: 7)),
        reviewUntil: weekStart,
        saveProposalsToJournal: false,
      );

      expect(report.id, 'weekly_20261109');
      expect(report.lastWeekReview.hasData, isTrue);
      expect(report.lastWeekReview.outcomes.length, 1, reason: 'bu haftanın önerisi karneye girmemeli');
      expect(report.lastWeekReview.weightedPortfolioReturnPct, closeTo(0.8, 1e-9));
      expect(report.newAllocation.cashWeightPct, 100.0);
      expect(report.newAllocation.summaryMessage, contains('nakitte kal'));

      final curve = performanceCurveFrom(await reports.allReports());
      expect(curve.length, 1);
      expect(curve.single.cumulativeIndex, closeTo(100.8, 1e-9));
    });
  });
}
