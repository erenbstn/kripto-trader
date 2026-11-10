import 'package:pusula_core/pusula_core.dart';
import 'package:test/test.dart';

SignalRecord _makeClosedSignal({
  required String id,
  required SetupType strategy,
  required MarketRegime regime,
  required double realizedR,
}) {
  final now = DateTime.utc(2026, 4, 15, 12, 0);
  return SignalRecord(
    id: id,
    instrument: const Instrument.crypto('SOLUSDT'),
    interval: BarInterval.h1,
    strategy: strategy,
    allSetups: [strategy],
    strategyVersion: '2.0.0',
    entryZoneLow: 100.0,
    entryZoneHigh: 101.0,
    entryPrice: 100.5,
    initialStop: 98.5,
    currentStop: 98.5,
    target1: 102.5,
    target2: 104.5,
    rewardRisk: 2.0,
    confidence: const ConfidenceBreakdown(
      setupConfluence: 18,
      volumeConfirmation: 10,
      regimeAlignment: 12,
      higherTimeframeAlignment: 12,
      monteCarloScore: 10,
      rewardRiskScore: 10,
      reasons: ['Test'],
    ),
    rationale: 'Sentetik test sinyali',
    invalidationRule: '98,50 altı',
    regime: regime,
    dataSource: 'sentetik',
    dataAgeMs: 1000,
    dataStale: false,
    createdAt: now.subtract(const Duration(hours: 6)),
    expiresAt: now.add(const Duration(hours: 6)),
    status: realizedR > 0 ? SignalStatus.target2 : SignalStatus.stop,
    closedAt: now,
    exitPrice: realizedR > 0 ? 104.5 : 98.5,
    realizedR: realizedR,
    realizedPct: realizedR * 2.0,
  );
}

void main() {
  group('Faz 6 — Kendini Geliştirme, 30 Sinyal Aşırı Uyum Yasağı ve Sürüm Geri Alma', () {
    test('Wilson %95 güven aralığı uç ve orta değerlerde geçerli sınırlar üretir', () {
      final zero = WilsonInterval.compute95(wins: 0, total: 10);
      expect(zero.low, closeTo(0.0, 1e-6));
      expect(zero.high, greaterThan(0.20));

      final half = WilsonInterval.compute95(wins: 15, total: 30);
      expect(half.low, closeTo(0.3315, 0.01));
      expect(half.high, closeTo(0.6685, 0.01));
    });

    test('Kısıt 9: 30 kapanmış sinyalin altında (29 sinyal) hiçbir parametre değiştirilmez, yalnızca gözlem üretilir',
        () async {
      final journal = MemorySignalJournalStore();
      final versionStore = MemoryStrategyVersionStore();
      final optimizer = StrategyOptimizer(
        journalStore: journal,
        versionStore: versionStore,
        clock: () => DateTime.utc(2026, 4, 19, 10, 0),
      );

      // 29 adet zararlı (-1R) kapanmış sinyal ekle (eşik = 30)
      for (var i = 0; i < 29; i++) {
        await journal.save(
          _makeClosedSignal(
            id: 'orb_loss_$i',
            strategy: SetupType.orb,
            regime: MarketRegime.sideways,
            realizedR: -1.0,
          ),
        );
      }

      final proposal = await optimizer.evaluate(autoApplyIfEligible: true);
      expect(proposal.canModifyParameters, isFalse);
      expect(proposal.proposedVersion, isNull);

      final orbStats = proposal.statsByStrategy[SetupType.orb]!;
      expect(orbStats.closedCount, 29);
      expect(orbStats.isEligibleForTuning, isFalse);
      expect(orbStats.observationNoteTr, contains('Yetersiz örneklem (29/30 kapanmış sinyal)'));
      expect(orbStats.observationNoteTr, contains('Wilson %95 GA'));

      final activeVer = await versionStore.active();
      expect(activeVer.version, '2.0.0');
    });

    test('30+ kapanmış sinyalde yeni sürüm (v2.1.0) önerilir/uygulanır ve tek adımla v2.0.0 sürümüne geri alınır',
        () async {
      final journal = MemorySignalJournalStore();
      final versionStore = MemoryStrategyVersionStore();
      final optimizer = StrategyOptimizer(
        journalStore: journal,
        versionStore: versionStore,
        clock: () => DateTime.utc(2026, 4, 19, 10, 0),
      );

      // 32 adet kapanmış sinyal (8 kazanç +2R, 24 kayıp -1R -> ort. -0.25R)
      for (var i = 0; i < 32; i++) {
        await journal.save(
          _makeClosedSignal(
            id: 'orb_32_$i',
            strategy: SetupType.orb,
            regime: i.isEven ? MarketRegime.bull : MarketRegime.sideways,
            realizedR: i < 8 ? 2.0 : -1.0,
          ),
        );
      }

      final proposal = await optimizer.evaluate(autoApplyIfEligible: true);
      expect(proposal.canModifyParameters, isTrue);
      expect(proposal.proposedVersion, isNotNull);
      expect(proposal.proposedVersion!.version, '2.1.0');
      expect(proposal.proposedVersion!.parentVersion, '2.0.0');

      // ORB güven eşiği 55 -> 60 ve hacim eşiği 1.15 -> 1.25 sıkılaştırılmış olmalı
      final newOrbParams = proposal.proposedVersion!.paramsFor(SetupType.orb);
      expect(newOrbParams.minConfidenceScore, 60);
      expect(newOrbParams.minVolumeRatio, closeTo(1.25, 1e-6));

      // Diğer stratejiler (<30 sinyal) değişmemiş olmalı
      final bullFlagParams = proposal.proposedVersion!.paramsFor(SetupType.bullFlag);
      expect(bullFlagParams.minConfidenceScore, 55);

      // Aktif sürüm 2.1.0 oldu
      expect((await versionStore.active()).version, '2.1.0');

      // Tek dokunuşla önceki sürüme (2.0.0) geri alma
      final rolledBack = await versionStore.rollbackToPrevious();
      expect(rolledBack, isNotNull);
      expect(rolledBack!.version, '2.0.0');
      expect((await versionStore.active()).version, '2.0.0');
      expect((await versionStore.active()).paramsFor(SetupType.orb).minConfidenceScore, 55);
    });
  });
}
