import 'dart:convert';

import 'package:pusula_core/pusula_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  const sol = Instrument.crypto('SOLUSDT');
  final t0 = DateTime.utc(2026, 11, 10, 12, 0);

  SignalRecord sampleSignal({DateTime? expiresAt}) => SignalRecord(
        id: 'crypto:SOLUSDT|5m|1',
        instrument: sol,
        interval: BarInterval.m5,
        strategy: SetupType.orb,
        allSetups: const [SetupType.orb, SetupType.breakout20],
        strategyVersion: '2.0.0',
        entryZoneLow: 99.8,
        entryZoneHigh: 100.2,
        entryPrice: 100.0,
        initialStop: 98.0,
        currentStop: 98.0,
        target1: 102.0, // 1R
        target2: 104.0, // 2R
        rewardRisk: 2.0,
        confidence: const ConfidenceBreakdown(
          setupConfluence: 20,
          volumeConfirmation: 12,
          regimeAlignment: 15,
          higherTimeframeAlignment: 15,
          monteCarloScore: 12,
          rewardRiskScore: 12,
          reasons: ['Test gerekçesi'],
        ),
        rationale: 'Test sinyali',
        invalidationRule: '98.0 USDT altı kapanış',
        regime: MarketRegime.bull,
        dataSource: 'binance',
        dataAgeMs: 5000,
        dataStale: false,
        createdAt: t0,
        expiresAt: expiresAt ?? t0.add(const Duration(hours: 4)),
        status: SignalStatus.open,
        lastProcessedBarTimeMs: t0.millisecondsSinceEpoch,
      );

  Candle bar(int step, double o, double h, double l, double c) => Candle(
        openTimeMs: t0.millisecondsSinceEpoch + step * BarInterval.m5.ms,
        open: o,
        high: h,
        low: l,
        close: c,
        volume: 100,
        quoteVolume: 100 * c,
      );

  group('SignalOutcomeTracker yaşam döngüsü', () {
    late MemorySignalJournalStore store;
    late FakeClock clock;
    late SignalOutcomeTracker tracker;

    setUp(() {
      store = MemorySignalJournalStore();
      clock = FakeClock(t0);
      tracker = SignalOutcomeTracker(store: store, clock: clock.call);
    });

    test('açık → hedef1 (stop başabaşa çekilir) → hedef2', () async {
      final sig = sampleSignal();
      await store.save(sig);

      // 1. mum: 102.5 görür -> hedef1'e ulaşır, stop 100.0'a çekilir
      final r1 = await tracker.evaluateSignal(sig, [bar(1, 100.0, 102.5, 99.5, 102.1)]);
      expect(r1.updated.status, SignalStatus.target1);
      expect(r1.updated.currentStop, 100.0);
      expect(r1.updated.isActive, isTrue);
      expect(r1.events.single.newStatus, SignalStatus.target1);

      // 2. mum: 104.2 görür -> hedef2 ile kapanır (+2R)
      final r2 = await tracker.evaluateSignal(r1.updated, [
        bar(1, 100.0, 102.5, 99.5, 102.1),
        bar(2, 102.1, 104.2, 101.5, 104.0),
      ]);
      expect(r2.updated.status, SignalStatus.target2);
      expect(r2.updated.isClosed, isTrue);
      expect(r2.updated.realizedR, 2.0);
      expect(r2.updated.realizedPct, 4.0);
      expect(await store.activeSignals(), isEmpty);
    });

    test('açık → hedef1 → başabaş stop (+0.5R kısmi gerçekleşme)', () async {
      final sig = sampleSignal();
      await store.save(sig);

      final r1 = await tracker.evaluateSignal(sig, [
        bar(1, 100.0, 102.3, 99.6, 101.8),
        bar(2, 101.8, 102.0, 99.9, 100.0), // başabaş stop (100.0) tetiklenir
      ]);
      expect(r1.updated.status, SignalStatus.stop);
      expect(r1.updated.breakevenStop, isTrue);
      expect(r1.updated.realizedR, 0.5);
      expect(r1.events.length, 2);
    });

    test('aynı mumda hem stop hem hedef görülürse muhafazakâr olarak STOP sayılır', () async {
      final sig = sampleSignal();
      await store.save(sig);

      // Mumda hem 97.5 (stop altı) hem 105.0 (hedef2 üstü) var -> STOP olmalı!
      final r = await tracker.evaluateSignal(sig, [bar(1, 100.0, 105.0, 97.5, 103.0)]);
      expect(r.updated.status, SignalStatus.stop);
      expect(r.updated.realizedR, -1.0);
      expect(r.updated.exitPrice, 98.0);
    });

    test('tutma süresi dolduğunda (expired) son kapanış fiyatından kapanır', () async {
      final sig = sampleSignal(expiresAt: t0.add(const Duration(minutes: 15)));
      await store.save(sig);

      final r = await tracker.evaluateSignal(sig, [
        bar(1, 100.0, 101.0, 99.2, 100.5), // kapanışı t0 + 10m
        bar(2, 100.5, 101.2, 99.8, 101.0), // kapanışı t0 + 15m -> süre doldu
      ]);
      expect(r.updated.status, SignalStatus.expired);
      expect(r.updated.exitPrice, 101.0);
      expect(r.updated.realizedR, 0.5);
    });

    test('geçersiz kılma (invalidated) ve JSON serileştirme', () async {
      final sig = sampleSignal();
      await store.save(sig);

      final ev = await tracker.invalidateSignal(
        sig.id,
        currentPrice: 98.5,
        reason: 'Kritik haber vetosu',
      );
      expect(ev, isNotNull);
      expect(ev!.signal.status, SignalStatus.invalidated);

      final jsonMap = jsonDecode(jsonEncode(ev.signal.toJson())) as Map<String, Object?>;
      final restored = SignalRecord.fromJson(jsonMap);
      expect(restored.id, sig.id);
      expect(restored.status, SignalStatus.invalidated);
      expect(restored.confidence.total, sig.confidence.total);
    });
  });
}
