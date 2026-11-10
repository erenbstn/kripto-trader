import 'dart:convert';

import 'package:pusula_core/pusula_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  final t0 = DateTime.utc(2026, 11, 15, 9, 0); // Pazar günü

  SignalRecord makeCandidate(
    Instrument ins, {
    int conf = 75,
    double entry = 100.0,
    double stop = 98.0, // %2 stop mesafesi
    double target1 = 102.0,
    double target2 = 104.0,
    MarketRegime regime = MarketRegime.bull,
    SetupType setup = SetupType.orb,
    bool isWeekly = false,
    SignalStatus status = SignalStatus.open,
    double? realizedPct,
    double? realizedR,
    double? allocatedWeightPct,
    DateTime? createdAt,
  }) =>
      SignalRecord(
        id: '${ins.id}|${setup.code}|${(createdAt ?? t0).millisecondsSinceEpoch}',
        instrument: ins,
        interval: ins.market == Market.bist ? BarInterval.h1 : BarInterval.m5,
        strategy: setup,
        allSetups: [setup],
        strategyVersion: '2.0.0',
        entryZoneLow: entry * 0.998,
        entryZoneHigh: entry * 1.002,
        entryPrice: entry,
        initialStop: stop,
        currentStop: stop,
        target1: target1,
        target2: target2,
        rewardRisk: (target2 - entry) / (entry - stop),
        confidence: ConfidenceBreakdown(
          setupConfluence: (conf * 0.25).round(),
          volumeConfirmation: (conf * 0.15).round(),
          regimeAlignment: (conf * 0.15).round(),
          higherTimeframeAlignment: (conf * 0.15).round(),
          monteCarloScore: (conf * 0.15).round(),
          rewardRiskScore: conf -
              ((conf * 0.25).round() +
                  (conf * 0.15).round() * 4),
          reasons: const ['Sentetik test gerekçesi'],
        ),
        rationale: '${ins.short} teknik + hacim teyitli kurulum',
        invalidationRule: '$stop altı kapanış',
        regime: regime,
        dataSource: ins.market == Market.bist ? 'yahoo' : 'binance',
        dataAgeMs: 1000,
        dataStale: false,
        createdAt: createdAt ?? t0,
        expiresAt: (createdAt ?? t0).add(const Duration(days: 5)),
        status: status,
        isWeeklyProposal: isWeekly,
        allocatedWeightPct: allocatedWeightPct,
        realizedPct: realizedPct,
        realizedR: realizedR,
        exitPrice: realizedPct == null ? null : entry * (1.0 + realizedPct / 100.0),
        closedAt: status.isTerminal ? t0 : null,
      );

  group('PortfolioWeightAllocator (K3 ağırlık ve sınır testleri)', () {
    const allocator = PortfolioWeightAllocator();

    test('eşik üstü aday yoksa "net fırsat yok, nakitte kal" ve %100 nakit döner', () {
      final res = allocator.allocate([
        makeCandidate(const Instrument.crypto('BTCUSDT'), conf: 42),
      ]);
      expect(res.hasRecommendations, isFalse);
      expect(res.cashWeightPct, 100.0);
      expect(res.investedWeightPct, 0.0);
      expect(res.summaryMessage, contains('net fırsat yok, nakitte kal'));
    });

    test('tek varlık %20, kripto toplam %40, en az nakit %20 ve toplam <= %100 sınırlarını korur', () {
      // Çok dar stoplu (%0.5) 4 kripto ve 3 BIST adayı -> ham ağırlıklar çok yüksek çıkacak
      final candidates = [
        makeCandidate(const Instrument.crypto('BTCUSDT'), conf: 95, stop: 99.5),
        makeCandidate(const Instrument.crypto('SOLUSDT'), conf: 92, stop: 99.5),
        makeCandidate(const Instrument.crypto('ETHUSDT'), conf: 90, stop: 99.5),
        makeCandidate(const Instrument.crypto('LINKUSDT'), conf: 88, stop: 99.5),
        makeCandidate(const Instrument.bist('THYAO'), conf: 94, entry: 300, stop: 298.5),
        makeCandidate(const Instrument.bist('ASELS'), conf: 91, entry: 100, stop: 99.5),
        makeCandidate(const Instrument.bist('AKBNK'), conf: 85, entry: 60, stop: 59.7),
      ];

      final res = allocator.allocate(candidates, appetite: RiskAppetite.balanced, totalBudget: 100000);
      // En fazla 6 öneri seçilir
      expect(res.recommendations.length, 6);
      for (final r in res.recommendations) {
        expect(r.weightPct, lessThanOrEqualTo(20.0));
      }
      expect(res.cryptoTotalWeightPct, lessThanOrEqualTo(40.0 + 0.05));
      expect(res.totalOpenRiskPct, lessThanOrEqualTo(6.0 + 0.05));
      expect(res.cashWeightPct, greaterThanOrEqualTo(20.0 - 0.05));
      expect(res.investedWeightPct + res.cashWeightPct, closeTo(100.0, 0.05));
    });

    test('Temkinli (0.6x), Atak (1.4x, en çok %25) ve Ayı rejimi (0.5x) ölçeklemesi çalışır', () {
      final cBull = [makeCandidate(const Instrument.bist('THYAO'), conf: 80, entry: 100, stop: 90)]; // %10 stop
      final cBear = [
        makeCandidate(const Instrument.bist('THYAO'), conf: 80, entry: 100, stop: 90, regime: MarketRegime.bear),
      ];

      final wBull = allocator.allocate(cBull, appetite: RiskAppetite.balanced).recommendations.single.weightPct;
      final wBear = allocator.allocate(cBear, appetite: RiskAppetite.balanced).recommendations.single.weightPct;
      expect(wBear, closeTo(wBull * 0.5, 0.05));

      final wCons = allocator.allocate(cBull, appetite: RiskAppetite.conservative).recommendations.single.weightPct;
      final wAggr = allocator.allocate(cBull, appetite: RiskAppetite.aggressive).recommendations.single.weightPct;
      expect(wCons, closeTo(wBull * 0.6, 0.05));
      expect(wAggr, closeTo(wBull * 1.4, 0.05));
      expect(wAggr, lessThanOrEqualTo(25.0));
    });
  });

  group('WeeklyReportGenerator (Pazar günü raporu, boş günlük ve arşiv)', () {
    late MemorySignalJournalStore journal;
    late MemoryWeeklyReportStore archive;
    late FakeClock clock;
    late WeeklyReportGenerator generator;

    setUp(() {
      journal = MemorySignalJournalStore();
      archive = MemoryWeeklyReportStore();
      clock = FakeClock(t0);
      generator = WeeklyReportGenerator(
        journalStore: journal,
        reportStore: archive,
        clock: clock.call,
      );
    });

    test('ilk haftada (boş günlük) "Geçen hafta raporu: henüz veri yok" döner; veri uydurmaz', () async {
      final report = await generator.generate(
        newCandidates: [
          makeCandidate(const Instrument.bist('THYAO'), conf: 82, entry: 300, stop: 291, target1: 309, target2: 318),
          makeCandidate(const Instrument.crypto('SOLUSDT'), conf: 78, entry: 150, stop: 145.5, target1: 154.5, target2: 159),
        ],
      );

      expect(report.lastWeekReview.hasData, isFalse);
      expect(report.lastWeekReview.emptyMessage, 'Geçen hafta raporu: henüz veri yok');
      expect(report.shortTermReport.hasAnyData, isFalse);
      expect(report.newAllocation.recommendations.length, 2);
      expect(report.newAllocation.bistRecommendations.length, 1);
      expect(report.newAllocation.cryptoRecommendations.length, 1);
      expect(report.disclaimer, contains('Yatırım tavsiyesi değildir'));
      expect(report.notificationSummary, contains('henüz veri yok'));
    });

    test('sentetik günlükten geçen hafta raporu, kısa vade raporu ve performans eğrisi üretir', () async {
      final prevTime = t0.subtract(const Duration(days: 5));
      // Geçen haftanın 2 haftalık önerisi (1 hedef2, 1 stop)
      await journal.save(makeCandidate(
        const Instrument.bist('ASELS'),
        isWeekly: true,
        allocatedWeightPct: 20.0,
        status: SignalStatus.target2,
        realizedPct: 8.0,
        realizedR: 2.0,
        createdAt: prevTime,
      ));
      await journal.save(makeCandidate(
        const Instrument.crypto('BTCUSDT'),
        isWeekly: true,
        allocatedWeightPct: 15.0,
        status: SignalStatus.stop,
        realizedPct: -2.0,
        realizedR: -1.0,
        createdAt: prevTime,
      ));

      // Geçen haftanın kısa vadeli sinyalleri (Kripto ve BIST ayrı)
      await journal.save(makeCandidate(
        const Instrument.crypto('SOLUSDT'),
        setup: SetupType.bullFlag,
        status: SignalStatus.target2,
        realizedPct: 4.5,
        realizedR: 2.2,
        createdAt: prevTime,
      ));
      await journal.save(makeCandidate(
        const Instrument.bist('THYAO'),
        setup: SetupType.reclaimMa20,
        status: SignalStatus.target1,
        realizedPct: 3.0,
        realizedR: 1.0,
        createdAt: prevTime,
      ));

      final report = await generator.generate(
        newCandidates: [
          makeCandidate(const Instrument.bist('GARAN'), conf: 84, entry: 120, stop: 116.4, target1: 123.6, target2: 127.2),
        ],
      );

      // Geçen hafta ağırlıklı getiri: (%20 * +8%) + (%15 * -2%) = +1.6% - 0.3% = +1.3%
      expect(report.lastWeekReview.hasData, isTrue);
      expect(report.lastWeekReview.weightedPortfolioReturnPct, closeTo(1.3, 0.01));
      expect(report.lastWeekReview.targetsHit, ['ASELS']);
      expect(report.lastWeekReview.stopsHit, ['BTC']);
      expect(report.lastWeekReview.winRatePct, 50.0);
      expect(report.lastWeekReview.bestOutcome!.instrument.symbol, 'ASELS');
      expect(report.lastWeekReview.worstOutcome!.instrument.symbol, 'BTCUSDT');
      expect(report.lastWeekReview.lessonsLearned, isNotEmpty);

      // Kısa vade raporu
      expect(report.shortTermReport.crypto.hasData, isTrue);
      expect(report.shortTermReport.crypto.closedSignals, 1);
      expect(report.shortTermReport.crypto.avgR, 2.2);
      expect(report.shortTermReport.bist.hasData, isTrue);
      expect(report.shortTermReport.bist.openSignals, 1);

      // Performans eğrisi ve JSON serileştirme
      final curve = await archive.buildPerformanceCurve();
      expect(curve.length, 1);
      expect(curve.single.cumulativeIndex, closeTo(101.3, 0.01));

      final restored = WeeklyReport.fromJson(jsonDecode(jsonEncode(report.toJson())) as Map<String, Object?>);
      expect(restored.id, report.id);
      expect(restored.lastWeekReview.weightedPortfolioReturnPct, report.lastWeekReview.weightedPortfolioReturnPct);
    });
  });
}
