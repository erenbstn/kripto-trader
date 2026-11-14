import 'dart:convert';

import '../model/candle.dart';
import '../model/market.dart';
import 'errors.dart';
import 'http_fetcher.dart';
import 'provider.dart';

/// Binance herkese açık spot piyasa verisi (anahtarsız, gecikmesiz). Yalnızca kripto spot.
class BinanceProvider implements MarketDataProvider {
  BinanceProvider(this._http);

  final HttpFetcher _http;

  static const spotHosts = ['data-api.binance.vision', 'api.binance.com', 'api1.binance.com'];

  @override
  String get id => 'binance';
  @override
  String get label => 'Binance Spot';
  @override
  Duration delayFor(Market market) => Duration.zero;
  @override
  bool supports(Instrument instrument, BarInterval interval) => instrument.market == Market.crypto;

  @override
  Future<CandleSeries> fetchCandles(
    Instrument instrument,
    BarInterval interval, {
    required int limit,
    required DateTime now,
  }) async {
    if (!supports(instrument, interval)) {
      throw ProviderException(id, 'desteklenmeyen varlık: ${instrument.id}');
    }
    final lim = limit.clamp(1, 999) + 1; // +1: kapanmamış mum
    Object? lastErr;
    for (final host in spotHosts) {
      final uri = Uri.https(host, '/api/v3/klines', {
        'symbol': instrument.symbol,
        'interval': interval.code,
        'limit': '$lim',
      });
      try {
        final body = await _http.getText(uri);
        final series = _parse(body, instrument, interval, now, 'binance');
        if (!series.isEmpty || series.forming != null) return series;
        lastErr = 'boş yanıt';
      } on HttpFetchException catch (e) {
        lastErr = e;
        if (e.isRateLimited) throw ProviderException(id, 'hız sınırı (429)', rateLimited: true);
        if (e.isNotFound) break; // sembol Binance Spot'ta yok; yedek sağlayıcıya geç
      } on FormatException catch (e) {
        lastErr = 'biçim hatası: ${e.message}';
      }
    }
    throw ProviderException(id, 'veri alınamadı: $lastErr');
  }

  CandleSeries _parse(String body, Instrument ins, BarInterval iv, DateTime now, String source) {
    final decoded = jsonDecode(body);
    if (decoded is! List) throw const FormatException('liste bekleniyordu');
    final nowMs = now.toUtc().millisecondsSinceEpoch;
    final closed = <Candle>[];
    Candle? forming;
    for (final row in decoded) {
      if (row is! List || row.length < 11) continue;
      final c = Candle(
        openTimeMs: (row[0] as num).toInt(),
        open: double.parse('${row[1]}'),
        high: double.parse('${row[2]}'),
        low: double.parse('${row[3]}'),
        close: double.parse('${row[4]}'),
        volume: double.parse('${row[5]}'),
        quoteVolume: double.parse('${row[7]}'),
        takerBuyQuote: double.parse('${row[10]}'),
      );
      final closeMs = (row[6] as num).toInt();
      if (closeMs <= nowMs) {
        closed.add(c);
      } else {
        forming = c;
      }
    }
    final last = forming?.close ?? (closed.isEmpty ? 0.0 : closed.last.close);
    return CandleSeries(
      instrument: ins,
      interval: iv,
      closed: closed,
      forming: forming,
      lastPrice: last,
      source: source,
      fetchedAt: now.toUtc(),
      dataDelay: Duration.zero,
    );
  }
}
