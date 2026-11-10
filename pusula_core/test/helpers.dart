import 'dart:convert';

import 'package:pusula_core/pusula_core.dart';

/// Sahte ağ katmanı: gerçek istek yapılmaz.
class FakeFetcher implements HttpFetcher {
  FakeFetcher(this.handler);
  final Object Function(Uri uri) handler;
  final List<Uri> calls = [];

  @override
  Future<String> getText(Uri uri, {Map<String, String>? headers, Duration timeout = const Duration(seconds: 15)}) async {
    calls.add(uri);
    final r = handler(uri);
    if (r is Exception) throw r;
    return r as String;
  }
}

/// Elle ilerletilen saat.
class FakeClock {
  FakeClock(this.now);
  DateTime now;
  DateTime call() => now;
  void advance(Duration d) => now = now.add(d);
}

RateLimiter testLimiter(FakeClock clock, {Duration minGap = const Duration(milliseconds: 100)}) => RateLimiter(
      minGap: minGap,
      clock: clock.call,
      sleeper: (d) async => clock.advance(d),
    );

/// Sentetik mum dizisi (rastgele değil, belirlenimci).
List<Candle> syntheticCandles({
  required DateTime start,
  required BarInterval interval,
  required int count,
  double startPrice = 100,
  double stepPct = 0.1,
  double turnover = 1e6,
}) {
  final out = <Candle>[];
  var p = startPrice;
  for (var i = 0; i < count; i++) {
    final o = p;
    final c = p * (1 + (i.isEven ? stepPct : -stepPct / 2) / 100);
    final hi = (o > c ? o : c) * 1.001, lo = (o < c ? o : c) * 0.999;
    out.add(Candle(
      openTimeMs: start.millisecondsSinceEpoch + i * interval.ms,
      open: o,
      high: hi,
      low: lo,
      close: c,
      volume: turnover / c,
      quoteVolume: turnover,
    ));
    p = c;
  }
  return out;
}

CandleSeries seriesOf(Instrument ins, BarInterval iv, List<Candle> closed, DateTime fetchedAt, {String source = 'stub'}) =>
    CandleSeries(
      instrument: ins,
      interval: iv,
      closed: closed,
      forming: null,
      lastPrice: closed.isEmpty ? 0 : closed.last.close,
      source: source,
      fetchedAt: fetchedAt,
      dataDelay: Duration.zero,
    );

/// Binance kline satırı.
List<Object> binanceRow(DateTime open, BarInterval iv, double o, double h, double l, double c, {double v = 10}) => [
      open.millisecondsSinceEpoch,
      '$o',
      '$h',
      '$l',
      '$c',
      '$v',
      open.millisecondsSinceEpoch + iv.ms - 1,
      '${v * c}',
      100,
      '${v / 2}',
      '${v * c / 2}',
      '0',
    ];

String yahooBody(List<DateTime> opens, List<double?> closes, {double? marketPrice}) => jsonEncode({
      'chart': {
        'result': [
          {
            'meta': {if (marketPrice != null) 'regularMarketPrice': marketPrice},
            'timestamp': [for (final t in opens) t.millisecondsSinceEpoch ~/ 1000],
            'indicators': {
              'quote': [
                {
                  'open': [for (final c in closes) c == null ? null : c - 1],
                  'high': [for (final c in closes) c == null ? null : c + 2],
                  'low': [for (final c in closes) c == null ? null : c - 2],
                  'close': closes,
                  'volume': [for (final c in closes) c == null ? null : 1000],
                }
              ]
            }
          }
        ],
        'error': null,
      }
    });

/// Sıradaki davranışı uygulayan sahte sağlayıcı.
class StubProvider implements MarketDataProvider {
  StubProvider(this.id, {this.supportsAll = true});
  @override
  final String id;
  final bool supportsAll;
  int calls = 0;

  /// Her çağrıda çalıştırılır; seri döndürür veya istisna fırlatır.
  CandleSeries Function(Instrument ins, BarInterval iv, int limit, DateTime now)? behavior;

  @override
  String get label => 'Stub $id';
  @override
  Duration delayFor(Market market) => Duration.zero;
  @override
  bool supports(Instrument instrument, BarInterval interval) => supportsAll;

  @override
  Future<CandleSeries> fetchCandles(Instrument instrument, BarInterval interval,
      {required int limit, required DateTime now}) async {
    calls++;
    return behavior!(instrument, interval, limit, now);
  }
}
