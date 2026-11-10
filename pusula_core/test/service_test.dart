import 'package:pusula_core/pusula_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  const btc = Instrument.crypto('BTCUSDT');
  final t0 = DateTime.utc(2026, 11, 10, 12);

  CandleSeries bars(String source, DateTime now, {int count = 50, int offset = 0}) => seriesOf(
        btc,
        BarInterval.h1,
        syntheticCandles(
            start: DateTime.utc(2026, 11, 1).add(Duration(hours: offset)), interval: BarInterval.h1, count: count),
        now,
        source: source,
      );

  late FakeClock clock;
  late StubProvider p1, p2;
  late MarketDataService svc;

  setUp(() {
    clock = FakeClock(t0);
    p1 = StubProvider('p1');
    p2 = StubProvider('p2');
    svc = MarketDataService(providers: [p1, p2], clock: clock.call, limiter: testLimiter(clock));
  });

  test('birincil başarısızsa yedeğe geçer ve sağlık durumunu günceller', () async {
    p1.behavior = (_, __, ___, ____) => throw ProviderException('p1', 'kapalı');
    p2.behavior = (_, __, ___, now) => bars('p2', now);
    final s = await svc.candles(btc, BarInterval.h1, limit: 40);
    expect(s.source, 'p2');
    expect(s.closed.length, 40);
    expect(s.stale, isFalse);
    final h = {for (final x in svc.health) x.id: x};
    expect(h['p1']!.consecutiveFailures, 1);
    expect(h['p1']!.lastError, 'kapalı');
    expect(h['p2']!.healthy, isTrue);
  });

  test('taze önbellek varken ağa gidilmez; süre dolunca yeniden çekilir', () async {
    p1.behavior = (_, __, ___, now) => bars('p1', now);
    await svc.candles(btc, BarInterval.h1, limit: 40);
    await svc.candles(btc, BarInterval.h1, limit: 40);
    expect(p1.calls, 1);
    clock.advance(MarketDataService.freshnessFor(BarInterval.h1) + const Duration(seconds: 1));
    await svc.candles(btc, BarInterval.h1, limit: 40);
    expect(p1.calls, 2);
    await svc.candles(btc, BarInterval.h1, limit: 40, forceRefresh: true);
    expect(p1.calls, 3);
  });

  test('tazelik süresi dilime göre 30 sn - 30 dk arasında', () {
    expect(MarketDataService.freshnessFor(BarInterval.m5), const Duration(seconds: 100));
    expect(MarketDataService.freshnessFor(BarInterval.h1), const Duration(minutes: 20));
    expect(MarketDataService.freshnessFor(BarInterval.d1), const Duration(minutes: 30));
  });

  test('tüm sağlayıcılar düşerse eski önbellek "stale" olarak döner', () async {
    p1.behavior = (_, __, ___, now) => bars('p1', now);
    p2.behavior = (_, __, ___, ____) => throw ProviderException('p2', 'kapalı');
    await svc.candles(btc, BarInterval.h1, limit: 40);
    clock.advance(const Duration(hours: 2));
    p1.behavior = (_, __, ___, ____) => throw HttpFetchException('zaman aşımı');
    final s = await svc.candles(btc, BarInterval.h1, limit: 40);
    expect(s.stale, isTrue);
    expect(s.closed.length, 40);
    expect(s.ageAt(clock.now), const Duration(hours: 2));
  });

  test('önbellek de yoksa nedenleriyle hata verir', () async {
    p1.behavior = (_, __, ___, ____) => throw ProviderException('p1', 'kapalı');
    p2.behavior = (_, __, ___, ____) => throw const FormatException('bozuk');
    await expectLater(
      svc.candles(btc, BarInterval.h1),
      throwsA(isA<MarketDataException>()
          .having((e) => e.reasons.keys.toSet(), 'sağlayıcılar', {'p1', 'p2'})
          .having((e) => e.reasons['p1'], 'p1 nedeni', 'kapalı')),
    );
  });

  test('429 sonrası sağlayıcı soğuma süresince atlanır, sonra yeniden denenir', () async {
    p1.behavior = (_, __, ___, ____) => throw ProviderException('p1', 'hız sınırı (429)', rateLimited: true);
    p2.behavior = (_, __, ___, now) => bars('p2', now);
    await svc.candles(btc, BarInterval.h1, limit: 40, forceRefresh: true);
    expect(p1.calls, 1);
    expect(svc.health.first.cooldownUntil, isNotNull);

    clock.advance(const Duration(seconds: 5));
    await svc.candles(btc, BarInterval.h1, limit: 40, forceRefresh: true);
    expect(p1.calls, 1, reason: 'soğuma süresinde çağrılmamalı');

    clock.advance(const Duration(seconds: 31));
    p1.behavior = (_, __, ___, now) => bars('p1', now);
    final s = await svc.candles(btc, BarInterval.h1, limit: 40, forceRefresh: true);
    expect(p1.calls, 2);
    expect(s.source, 'p1');
    expect(svc.health.first.cooldownUntil, isNull);
  });

  test('art arda üç hata soğumayı başlatır', () async {
    p1.behavior = (_, __, ___, ____) => throw ProviderException('p1', 'kapalı');
    p2.behavior = (_, __, ___, now) => bars('p2', now);
    for (var i = 0; i < 4; i++) {
      await svc.candles(btc, BarInterval.h1, limit: 40, forceRefresh: true);
      clock.advance(const Duration(seconds: 1));
    }
    expect(p1.calls, 3);
  });

  test('aynı kaynaktan gelen yeni mumlar önbellekle birleştirilir', () async {
    p1.behavior = (_, __, ___, now) => bars('p1', now, count: 50);
    await svc.candles(btc, BarInterval.h1, limit: 100);
    clock.advance(const Duration(hours: 1));
    p1.behavior = (_, __, ___, now) => bars('p1', now, count: 20, offset: 40);
    final s = await svc.candles(btc, BarInterval.h1, limit: 100);
    expect(s.closed.length, 60);
    final times = s.closed.map((c) => c.openTimeMs).toList();
    expect(times, [...times]..sort());
    expect(times.toSet().length, 60);
  });

  test('farklı kaynaktan gelen veri önbellekle karıştırılmaz', () {
    final old = bars('p1', t0, count: 50);
    final fresh = bars('p2', t0, count: 20, offset: 40);
    expect(mergeClosed(old, fresh).length, 20);
  });

  test('desteklenmeyen istek ve toplu çekim', () async {
    final none = MarketDataService(
        providers: [StubProvider('x', supportsAll: false)], clock: clock.call, limiter: testLimiter(clock));
    await expectLater(none.candles(btc, BarInterval.h1), throwsA(isA<MarketDataException>()));

    p1.behavior = (ins, _, __, now) =>
        ins.symbol == 'ETHUSDT' ? throw ProviderException('p1', 'yok') : bars('p1', now);
    p2.behavior = (_, __, ___, ____) => throw ProviderException('p2', 'yok');
    final r = await svc.candlesFor(const [btc, Instrument.crypto('ETHUSDT')], BarInterval.h1, limit: 40);
    expect(r.ok.keys, [btc]);
    expect(r.failed.keys.single.symbol, 'ETHUSDT');
  });

  group('RateLimiter', () {
    test('istekler arasına en az aralık koyar', () async {
      final waits = <Duration>[];
      final c = FakeClock(t0);
      final rl = RateLimiter(
        minGap: const Duration(milliseconds: 300),
        clock: c.call,
        sleeper: (d) async {
          waits.add(d);
          c.advance(d);
        },
      );
      await rl.acquire('h');
      await rl.acquire('h');
      await rl.acquire('h');
      await rl.acquire('diger');
      expect(waits, [const Duration(milliseconds: 300), const Duration(milliseconds: 300)]);
    });

    test('soğuma süresi iki katına çıkar, üst sınırda durur, başarıda sıfırlanır', () {
      final c = FakeClock(t0);
      final rl = RateLimiter(clock: c.call, sleeper: (_) async {});
      expect(rl.reportThrottled('h'), const Duration(seconds: 30));
      expect(rl.reportThrottled('h'), const Duration(seconds: 60));
      expect(rl.reportThrottled('h'), const Duration(seconds: 120));
      for (var i = 0; i < 10; i++) {
        rl.reportThrottled('h');
      }
      expect(rl.reportThrottled('h'), const Duration(minutes: 15));
      expect(rl.isCoolingDown('h'), isTrue);
      rl.reportSuccess('h');
      expect(rl.isCoolingDown('h'), isFalse);
      expect(rl.reportThrottled('h'), const Duration(seconds: 30));
    });
  });
}
