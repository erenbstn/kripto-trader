import 'dart:convert';

import 'package:pusula_core/pusula_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  const btc = Instrument.crypto('BTCUSDT');
  const thy = Instrument.bist('THYAO');

  group('model', () {
    test('kısa ad, kimlik ve JSON gidiş-dönüş', () {
      expect(const Instrument.crypto('SOLUSDT').short, 'SOL');
      expect(thy.short, 'THYAO');
      expect(Instrument.parseId('bist:THYAO'), thy);
      expect(BarInterval.parse('4h'), BarInterval.h4);
      expect(() => BarInterval.parse('7m'), throwsArgumentError);

      final s = seriesOf(thy, BarInterval.d1,
          syntheticCandles(start: DateTime.utc(2026, 11, 2, 7), interval: BarInterval.d1, count: 3), DateTime.utc(2026, 11, 10));
      final back = CandleSeries.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, Object?>);
      expect(back.instrument, thy);
      expect(back.closed.length, 3);
      expect(back.closed.last.close, s.closed.last.close);
      expect(back.fetchedAt, s.fetchedAt);
    });

    test('veri yaşı gecikmeyi içerir', () {
      final s = CandleSeries(
        instrument: thy,
        interval: BarInterval.h1,
        closed: const [],
        forming: null,
        lastPrice: 1,
        source: 'yahoo',
        fetchedAt: DateTime.utc(2026, 11, 10, 10),
        dataDelay: const Duration(minutes: 15),
      );
      expect(s.ageAt(DateTime.utc(2026, 11, 10, 10, 2)), const Duration(minutes: 17));
    });
  });

  group('BinanceProvider', () {
    final now = DateTime.utc(2026, 11, 10, 12, 2);
    String rows() => jsonEncode([
          binanceRow(DateTime.utc(2026, 11, 10, 10), BarInterval.h1, 100, 102, 99, 101),
          binanceRow(DateTime.utc(2026, 11, 10, 11), BarInterval.h1, 101, 104, 100, 103),
          binanceRow(DateTime.utc(2026, 11, 10, 12), BarInterval.h1, 103, 105, 102, 104.5),
        ]);

    test('kapanmış ve oluşan mumu ayırır', () async {
      final f = FakeFetcher((_) => rows());
      final s = await BinanceProvider(f).fetchCandles(btc, BarInterval.h1, limit: 50, now: now);
      expect(s.closed.length, 2);
      expect(s.forming!.close, 104.5);
      expect(s.lastPrice, 104.5);
      expect(s.source, 'binance');
      expect(s.dataDelay, Duration.zero);
      expect(s.closed.first.takerBuyQuote, isNotNull);
      expect(f.calls.single.host, 'data-api.binance.vision');
      expect(f.calls.single.queryParameters['symbol'], 'BTCUSDT');
    });

    test('spot 400 dönerse diğer spot sunucularını denemeden futures ucuna geçer', () async {
      final f = FakeFetcher(
          (u) => u.path.startsWith('/api/') ? HttpFetchException('HTTP 400', status: 400) : rows());
      final s = await BinanceProvider(f).fetchCandles(const Instrument.crypto('ONDOUSDT'), BarInterval.h1, limit: 50, now: now);
      expect(s.source, 'binance_futures');
      expect(f.calls.length, 2);
    });

    test('futures öncelikli semboller önce futures ucunda aranır', () async {
      final f = FakeFetcher((_) => rows());
      await BinanceProvider(f).fetchCandles(const Instrument.crypto('XAGUSDT'), BarInterval.h1, limit: 50, now: now);
      expect(f.calls.first.host, 'fapi.binance.com');
    });

    test('ağ hatasında sıradaki sunucuya geçer', () async {
      var n = 0;
      final f = FakeFetcher((_) => n++ == 0 ? HttpFetchException('bağlantı hatası') : rows());
      final s = await BinanceProvider(f).fetchCandles(btc, BarInterval.h1, limit: 50, now: now);
      expect(s.closed.length, 2);
      expect(f.calls.map((u) => u.host).toList(), ['data-api.binance.vision', 'api.binance.com']);
    });

    test('429 hız sınırı olarak işaretlenir', () async {
      final f = FakeFetcher((_) => HttpFetchException('HTTP 429', status: 429));
      expect(
        () => BinanceProvider(f).fetchCandles(btc, BarInterval.h1, limit: 50, now: now),
        throwsA(isA<ProviderException>().having((e) => e.rateLimited, 'rateLimited', true)),
      );
    });

    test('BIST varlığını desteklemez', () {
      expect(BinanceProvider(FakeFetcher((_) => '')).supports(thy, BarInterval.d1), isFalse);
    });
  });

  group('YahooProvider', () {
    test('sembol eşlemesi', () {
      expect(YahooProvider.yahooSymbol(thy), 'THYAO.IS');
      expect(YahooProvider.yahooSymbol(const Instrument.crypto('SOLUSDT')), 'SOL-USD');
    });

    test('BIST saatlik: 15 dk gecikme dolmadan mum kapanmış sayılmaz, boş değer atlanır', () async {
      final opens = [for (var h = 6; h <= 11; h++) DateTime.utc(2026, 11, 10, h, 30)];
      final f = FakeFetcher((_) => yahooBody(opens, [310, 311, null, 312, 313, 314], marketPrice: 314.2));
      final p = YahooProvider(f);

      // 14:50 TRT: 10:30 UTC mumu 11:30'da biter, +15 dk = 11:45 <= 11:50 → kapanmış.
      var s = await p.fetchCandles(thy, BarInterval.h1, limit: 100, now: DateTime.utc(2026, 11, 10, 11, 50));
      expect(s.closed.length, 4); // 6 satır - 1 boş - 1 oluşan
      expect(s.forming!.close, 314);
      expect(s.lastPrice, 314.2);
      expect(s.dataDelay, const Duration(minutes: 15));
      expect(f.calls.single.path, contains('THYAO.IS'));

      // 11:40 UTC: 10:30 mumu bitti ama gecikme dolmadı → henüz kapanmış değil.
      s = await p.fetchCandles(thy, BarInterval.h1, limit: 100, now: DateTime.utc(2026, 11, 10, 11, 40));
      expect(s.closed.length, 3);
    });

    test('BIST günlük mum seans kapanışı + gecikmeden önce kapanmış sayılmaz', () async {
      final opens = [DateTime.utc(2026, 11, 9, 7), DateTime.utc(2026, 11, 10, 7)];
      final p = YahooProvider(FakeFetcher((_) => yahooBody(opens, [310, 313.75])));
      var s = await p.fetchCandles(thy, BarInterval.d1, limit: 100, now: DateTime.utc(2026, 11, 10, 15, 20));
      expect(s.closed.length, 1);
      expect(s.forming, isNotNull);
      s = await p.fetchCandles(thy, BarInterval.d1, limit: 100, now: DateTime.utc(2026, 11, 10, 15, 26));
      expect(s.closed.length, 2);
    });

    test('kripto 4 saatlik mum saatliklerden toplanır; BIST 4 saatlik desteklenmez', () async {
      final opens = [for (var h = 0; h < 8; h++) DateTime.utc(2026, 11, 9, h)];
      final p = YahooProvider(FakeFetcher((_) => yahooBody(opens, [10, 11, 12, 13, 14, 15, 16, 17])));
      final s = await p.fetchCandles(const Instrument.crypto('BTCUSDT'), BarInterval.h4,
          limit: 100, now: DateTime.utc(2026, 11, 10));
      expect(s.closed.length, 2);
      expect(s.closed.first.open, 9);
      expect(s.closed.first.close, 13);
      expect(s.closed.first.high, 15);
      expect(s.closed.first.volume, 4000);
      expect(p.supports(thy, BarInterval.h4), isFalse);
    });

    test('limit kadar son mum döner', () async {
      final opens = [for (var d = 1; d <= 9; d++) DateTime.utc(2026, 10, d)];
      final p = YahooProvider(FakeFetcher((_) => yahooBody(opens, [for (var d = 1; d <= 9; d++) d.toDouble()])));
      final s = await p.fetchCandles(const Instrument.crypto('BTCUSDT'), BarInterval.d1,
          limit: 3, now: DateTime.utc(2026, 11, 10));
      expect(s.closed.map((c) => c.close).toList(), [7, 8, 9]);
    });

    test('boş sonuç ve 404 sağlayıcı hatasıdır', () {
      final empty = YahooProvider(FakeFetcher((_) => '{"chart":{"result":null,"error":{"code":"Not Found"}}}'));
      expect(() => empty.fetchCandles(thy, BarInterval.d1, limit: 10, now: DateTime.utc(2026, 11, 10)),
          throwsA(isA<ProviderException>()));
      final nf = YahooProvider(FakeFetcher((_) => HttpFetchException('HTTP 404', status: 404)));
      expect(() => nf.fetchCandles(thy, BarInterval.d1, limit: 10, now: DateTime.utc(2026, 11, 10)),
          throwsA(isA<ProviderException>()));
    });
  });

  group('IsYatirimProvider', () {
    Map<String, Object> row(String date, double close, double min, double max, double hacim) => {
          'HGDG_HS_KODU': 'THYAO',
          'HGDG_TARIH': date,
          'HGDG_KAPANIS': close,
          'HGDG_AOF': (min + max) / 2,
          'HGDG_MIN': min,
          'HGDG_MAX': max,
          'HGDG_HACIM': hacim,
        };
    final body = jsonEncode({
      'ok': true,
      'value': [
        row('06-11-2026', 300, 296, 303, 9e9),
        row('09-11-2026', 310, 302, 310.25, 14.5e9),
        row('10-11-2026', 313.75, 309, 315, 8e9),
      ]
    });

    test('günlük mumu ayrıştırır, açılışı önceki kapanıştan türetir', () async {
      final f = FakeFetcher((_) => body);
      final s = await IsYatirimProvider(f)
          .fetchCandles(thy, BarInterval.d1, limit: 100, now: DateTime.utc(2026, 11, 10, 12));
      expect(s.closed.length, 2);
      expect(s.forming!.close, 313.75);
      expect(s.approximateOpen, isTrue);
      expect(s.closed[1].open, 302); // önceki kapanış 300, günün dibine sıkıştırıldı
      expect(s.closed[1].quoteVolume, 14.5e9);
      expect(s.closed[1].openTime, DateTime.utc(2026, 11, 9, 7));
      expect(f.calls.single.queryParameters['hisse'], 'THYAO');
      expect(f.calls.single.queryParameters['enddate'], '10-11-2026');
    });

    test('karışık tarih sırasıyla gelen satırları kronolojik sıralar ve son fiyatı doğru alır', () async {
      final unsortedBody = jsonEncode({
        'ok': true,
        'value': [
          row('10-11-2026', 313.75, 309, 315, 8e9),
          row('06-11-2026', 300, 296, 303, 9e9),
          row('09-11-2026', 310, 302, 310.25, 14.5e9),
        ],
      });
      final f = FakeFetcher((_) => unsortedBody);
      final s = await IsYatirimProvider(f)
          .fetchCandles(thy, BarInterval.d1, limit: 100, now: DateTime.utc(2026, 11, 10, 16));
      expect(s.closed.length, 3);
      expect(s.closed.first.close, 300);
      expect(s.closed.last.close, 313.75);
      expect(s.lastPrice, 313.75);
    });

    test('yalnızca BIST günlük desteklenir; bozuk yanıt sağlayıcı hatasıdır', () {
      final p = IsYatirimProvider(FakeFetcher((_) => '<html>bakım</html>'));
      expect(p.supports(thy, BarInterval.h1), isFalse);
      expect(p.supports(btc, BarInterval.d1), isFalse);
      expect(() => p.fetchCandles(thy, BarInterval.d1, limit: 10, now: DateTime.utc(2026, 11, 10)),
          throwsA(isA<ProviderException>()));
    });
  });
}
