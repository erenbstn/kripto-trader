import 'dart:convert';

import '../bist/bist_calendar.dart';
import '../model/candle.dart';
import '../model/market.dart';
import 'errors.dart';
import 'http_fetcher.dart';
import 'provider.dart';

/// Yahoo Finance grafik ucu (resmî olmayan, anahtarsız).
/// BIST (`.IS`) verisi yaklaşık 15 dakika gecikmelidir; kripto için yedek kaynaktır.
/// Kullanım koşulları kişisel, ticari olmayan kullanıma izin verir.
class YahooProvider implements MarketDataProvider {
  YahooProvider(this._http, {this.calendar = const BistCalendar(), this.bistDelay = const Duration(minutes: 15)});

  final HttpFetcher _http;
  final BistCalendar calendar;
  final Duration bistDelay;

  static const hosts = ['query2.finance.yahoo.com', 'query1.finance.yahoo.com'];

  @override
  String get id => 'yahoo';
  @override
  String get label => 'Yahoo Finance';
  @override
  Duration delayFor(Market market) => market == Market.bist ? bistDelay : const Duration(minutes: 1);

  @override
  bool supports(Instrument instrument, BarInterval interval) =>
      !(instrument.market == Market.bist && interval == BarInterval.h4);

  static String yahooSymbol(Instrument i) {
    if (i.market == Market.bist) return '${i.symbol}.IS';
    if (i.symbol == 'XAGUSDT') return 'XAGUSD=X';
    return '${i.short}-USD';
  }

  static ({String interval, String range}) _query(BarInterval iv, int limit) {
    switch (iv) {
      case BarInterval.m5:
        return (interval: '5m', range: limit <= 400 ? '5d' : '1mo');
      case BarInterval.m15:
        return (interval: '15m', range: limit <= 130 ? '5d' : '1mo');
      case BarInterval.h1:
        return (interval: '1h', range: limit <= 150 ? '1mo' : '3mo');
      case BarInterval.h4:
        return (interval: '1h', range: '3mo');
      case BarInterval.d1:
        return (interval: '1d', range: limit <= 120 ? '6mo' : (limit <= 250 ? '1y' : '2y'));
    }
  }

  @override
  Future<CandleSeries> fetchCandles(
    Instrument instrument,
    BarInterval interval, {
    required int limit,
    required DateTime now,
  }) async {
    if (!supports(instrument, interval)) {
      throw ProviderException(id, 'desteklenmeyen dilim: ${interval.code}');
    }
    final q = _query(interval, limit);
    Object? lastErr;
    for (final host in hosts) {
      final uri = Uri.https(host, '/v8/finance/chart/${yahooSymbol(instrument)}', {
        'range': q.range,
        'interval': q.interval,
      });
      try {
        final body = await _http.getText(uri);
        return _parse(body, instrument, interval, limit, now);
      } on HttpFetchException catch (e) {
        lastErr = e;
        if (e.isRateLimited) throw ProviderException(id, 'hız sınırı (429)', rateLimited: true);
        if (e.status == 404) throw ProviderException(id, 'sembol bulunamadı');
      } on FormatException catch (e) {
        lastErr = 'biçim hatası: ${e.message}';
      }
    }
    throw ProviderException(id, 'veri alınamadı: $lastErr');
  }

  CandleSeries _parse(String body, Instrument ins, BarInterval iv, int limit, DateTime now) {
    final doc = jsonDecode(body);
    if (doc is! Map) throw const FormatException('nesne bekleniyordu');
    final chart = doc['chart'];
    if (chart is! Map) throw const FormatException('chart alanı yok');
    final results = chart['result'];
    if (results is! List || results.isEmpty) {
      throw ProviderException(id, 'boş sonuç${chart['error'] != null ? ' (kaynak hatası)' : ''}');
    }
    final r0 = results.first as Map;
    final meta = (r0['meta'] as Map?) ?? const {};
    final ts = (r0['timestamp'] as List?) ?? const [];
    final quoteList = ((r0['indicators'] as Map?)?['quote'] as List?) ?? const [];
    final q = quoteList.isEmpty ? const <String, Object?>{} : (quoteList.first as Map);
    List<Object?> col(String k) => (q[k] as List?)?.cast<Object?>() ?? const [];
    final o = col('open'), h = col('high'), l = col('low'), c = col('close'), v = col('volume');

    var raw = <Candle>[];
    for (var i = 0; i < ts.length; i++) {
      final close = i < c.length ? c[i] as num? : null;
      final t = ts[i] as num?;
      if (t == null || close == null) continue;
      double pick(List<Object?> xs) => (i < xs.length && xs[i] != null) ? (xs[i] as num).toDouble() : close.toDouble();
      final vol = (i < v.length && v[i] != null) ? (v[i] as num).toDouble() : 0.0;
      final hi = pick(h), lo = pick(l), cl = close.toDouble();
      raw.add(Candle(
        openTimeMs: t.toInt() * 1000,
        open: pick(o),
        high: hi,
        low: lo,
        close: cl,
        volume: vol,
        quoteVolume: vol * (hi + lo + cl) / 3.0,
      ));
    }
    if (iv == BarInterval.h4) raw = _aggregate(raw, BarInterval.h4.ms);

    final delay = delayFor(ins.market);
    final nowMs = now.toUtc().millisecondsSinceEpoch;
    final closed = <Candle>[];
    Candle? forming;
    for (final bar in raw) {
      if (_barEndMs(bar, ins, iv) + delay.inMilliseconds <= nowMs) {
        closed.add(bar);
      } else {
        forming = bar;
      }
    }
    final trimmed = closed.length > limit ? closed.sublist(closed.length - limit) : closed;
    final metaPrice = (meta['regularMarketPrice'] as num?)?.toDouble();
    final last = metaPrice ?? forming?.close ?? (trimmed.isEmpty ? 0.0 : trimmed.last.close);
    return CandleSeries(
      instrument: ins,
      interval: iv,
      closed: trimmed,
      forming: forming,
      lastPrice: last,
      source: id,
      fetchedAt: now.toUtc(),
      dataDelay: delay,
    );
  }

  /// Mumun bittiği an. BIST'te seans kapanışı mumun doğal süresinden önce gelebilir.
  int _barEndMs(Candle bar, Instrument ins, BarInterval iv) {
    final natural = bar.openTimeMs + iv.ms;
    if (ins.market != Market.bist) return natural;
    final session = calendar.sessionOn(bar.openTime);
    if (session == null) return natural;
    final closeMs = session.close.millisecondsSinceEpoch;
    if (iv == BarInterval.d1) return closeMs;
    return natural < closeMs ? natural : closeMs;
  }

  static List<Candle> _aggregate(List<Candle> bars, int bucketMs) {
    final out = <Candle>[];
    int? bucket;
    for (final b in bars) {
      final k = b.openTimeMs ~/ bucketMs;
      if (bucket != k || out.isEmpty) {
        bucket = k;
        out.add(Candle(
          openTimeMs: k * bucketMs,
          open: b.open,
          high: b.high,
          low: b.low,
          close: b.close,
          volume: b.volume,
          quoteVolume: b.quoteVolume,
        ));
      } else {
        final p = out.removeLast();
        out.add(Candle(
          openTimeMs: p.openTimeMs,
          open: p.open,
          high: b.high > p.high ? b.high : p.high,
          low: b.low < p.low ? b.low : p.low,
          close: b.close,
          volume: p.volume + b.volume,
          quoteVolume: p.quoteVolume + b.quoteVolume,
        ));
      }
    }
    return out;
  }
}
