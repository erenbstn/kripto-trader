import 'dart:convert';

import '../bist/bist_calendar.dart';
import '../model/candle.dart';
import '../model/market.dart';
import 'errors.dart';
import 'http_fetcher.dart';
import 'provider.dart';

/// İş Yatırım herkese açık geçmiş fiyat ucu (belgesiz, anahtarsız). Yalnızca BIST günlük mum.
/// Açılış fiyatı vermez: açılış, önceki kapanıştan türetilir ve seri `approximateOpen` işaretlenir.
/// Hacim TL cinsindendir. Yedek kaynak olarak kullanılır.
class IsYatirimProvider implements MarketDataProvider {
  IsYatirimProvider(this._http, {this.calendar = const BistCalendar()});

  final HttpFetcher _http;
  final BistCalendar calendar;

  static const host = 'www.isyatirim.com.tr';
  static const path = '/_layouts/15/Isyatirim.Website/Common/Data.aspx/HisseTekil';

  @override
  String get id => 'isyatirim';
  @override
  String get label => 'İş Yatırım (gün sonu)';
  @override
  Duration delayFor(Market market) => const Duration(minutes: 15);
  @override
  bool supports(Instrument instrument, BarInterval interval) =>
      instrument.market == Market.bist && interval == BarInterval.d1;

  static String _fmt(DateTime trt) =>
      '${trt.day.toString().padLeft(2, '0')}-${trt.month.toString().padLeft(2, '0')}-${trt.year}';

  @override
  Future<CandleSeries> fetchCandles(
    Instrument instrument,
    BarInterval interval, {
    required int limit,
    required DateTime now,
  }) async {
    if (!supports(instrument, interval)) {
      throw ProviderException(id, 'yalnızca BIST günlük mum desteklenir');
    }
    final end = BistCalendar.toTrt(now);
    final start = end.subtract(Duration(days: (limit * 1.6).ceil() + 10));
    final uri = Uri.https(host, path, {
      'hisse': instrument.symbol,
      'startdate': _fmt(start),
      'enddate': _fmt(end),
    });
    final String body;
    try {
      body = await _http.getText(uri);
    } on HttpFetchException catch (e) {
      if (e.isRateLimited) throw ProviderException(id, 'hız sınırı (429)', rateLimited: true);
      throw ProviderException(id, 'veri alınamadı: $e');
    }
    final Object? doc;
    try {
      doc = jsonDecode(body);
    } on FormatException {
      throw ProviderException(id, 'biçim hatası (JSON değil)');
    }
    final rows = doc is Map ? doc['value'] : null;
    if (rows is! List || rows.isEmpty) throw ProviderException(id, 'boş sonuç');

    final nowMs = now.toUtc().millisecondsSinceEpoch;
    final delayMs = delayFor(Market.bist).inMilliseconds;
    final parsedRows = <({DateTime openTime, double close, double lo, double hi, double turnover, double avg})>[];
    for (final row in rows) {
      if (row is! Map) continue;
      final date = row['HGDG_TARIH'];
      final close = (row['HGDG_KAPANIS'] as num?)?.toDouble();
      if (date is! String || close == null || close <= 0) continue;
      final parts = date.split('-');
      if (parts.length != 3) continue;
      final d = int.tryParse(parts[0]), m = int.tryParse(parts[1]), y = int.tryParse(parts[2]);
      if (d == null || m == null || y == null) continue;
      // Sürekli işlem açılışı 10:00 TRT = 07:00 UTC.
      final openTime = DateTime.utc(y, m, d, 7);
      final lo = (row['HGDG_MIN'] as num?)?.toDouble() ?? close;
      final hi = (row['HGDG_MAX'] as num?)?.toDouble() ?? close;
      final turnover = (row['HGDG_HACIM'] as num?)?.toDouble() ?? 0.0;
      final avg = (row['HGDG_AOF'] as num?)?.toDouble() ?? close;
      parsedRows.add((openTime: openTime, close: close, lo: lo, hi: hi, turnover: turnover, avg: avg));
    }
    // İş Yatırım HisseTekil uç noktası satırları karışık tarih sırasıyla döndürebilir; kronolojik sırala.
    parsedRows.sort((a, b) => a.openTime.compareTo(b.openTime));

    final closed = <Candle>[];
    Candle? forming;
    double? prevClose;
    for (final r in parsedRows) {
      var open = prevClose ?? r.avg;
      if (open > r.hi) open = r.hi;
      if (open < r.lo) open = r.lo;
      final bar = Candle(
        openTimeMs: r.openTime.millisecondsSinceEpoch,
        open: open,
        high: r.hi,
        low: r.lo,
        close: r.close,
        volume: r.avg > 0 ? r.turnover / r.avg : 0.0,
        quoteVolume: r.turnover,
      );
      prevClose = r.close;
      final sessionClose = calendar.sessionOn(r.openTime)?.close ?? r.openTime.add(const Duration(hours: 8, minutes: 10));
      if (sessionClose.millisecondsSinceEpoch + delayMs <= nowMs) {
        closed.add(bar);
      } else {
        forming = bar;
      }
    }
    if (closed.isEmpty && forming == null) throw ProviderException(id, 'ayrıştırılabilir satır yok');
    final trimmed = closed.length > limit ? closed.sublist(closed.length - limit) : closed;
    return CandleSeries(
      instrument: instrument,
      interval: interval,
      closed: trimmed,
      forming: forming,
      lastPrice: forming?.close ?? trimmed.last.close,
      source: id,
      fetchedAt: now.toUtc(),
      dataDelay: delayFor(Market.bist),
      approximateOpen: true,
    );
  }
}
