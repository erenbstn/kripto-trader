import '../model/candle.dart';
import '../model/market.dart';
import '../util/clock.dart';
import 'candle_cache.dart';
import 'errors.dart';
import 'provider.dart';
import 'rate_limiter.dart';

/// Bir sağlayıcının sağlık durumu (Ayarlar > Veri kaynağı durumu ekranı için).
class ProviderHealth {
  ProviderHealth(this.id, this.label);
  final String id;
  final String label;
  DateTime? lastSuccess;
  DateTime? lastFailure;
  String? lastError;
  int consecutiveFailures = 0;
  int successCount = 0;
  int failureCount = 0;
  DateTime? cooldownUntil;

  bool get healthy => consecutiveFailures == 0 && lastSuccess != null;
}

/// Sağlayıcıları öncelik sırasıyla dener, önbellek kullanır, hız sınırına uyar.
///
/// Sıra: taze önbellek → sağlayıcı 1 → sağlayıcı 2 → ... → eski önbellek (`stale`) → hata.
class MarketDataService {
  MarketDataService({
    required List<MarketDataProvider> providers,
    CandleCache? cache,
    RateLimiter? limiter,
    Clock? clock,
    this.failuresBeforeCooldown = 3,
  })  : _providers = List.unmodifiable(providers),
        _cache = cache ?? MemoryCandleCache(),
        _clock = clock ?? systemClock,
        _limiter = limiter ?? RateLimiter(clock: clock) {
    for (final p in _providers) {
      _health[p.id] = ProviderHealth(p.id, p.label);
    }
  }

  final List<MarketDataProvider> _providers;
  final CandleCache _cache;
  final Clock _clock;
  final RateLimiter _limiter;
  final int failuresBeforeCooldown;
  final Map<String, ProviderHealth> _health = {};

  List<ProviderHealth> get health => [
        for (final p in _providers) _health[p.id]!..cooldownUntil = _limiter.cooldownUntil(p.id),
      ];

  /// Önbelleğin taze sayıldığı süre: dilimin üçte biri, 30 sn ile 30 dk arasında.
  static Duration freshnessFor(BarInterval iv) {
    final ms = (iv.ms / 3).round().clamp(30 * 1000, 30 * 60 * 1000);
    return Duration(milliseconds: ms);
  }

  Future<CandleSeries> candles(
    Instrument instrument,
    BarInterval interval, {
    int limit = 300,
    Duration? maxAge,
    bool forceRefresh = false,
  }) async {
    final now = _clock();
    final key = cacheKey(instrument, interval);
    final cached = await _cache.read(key);
    final fresh = maxAge ?? freshnessFor(interval);
    if (!forceRefresh &&
        cached != null &&
        cached.closed.isNotEmpty &&
        now.difference(cached.fetchedAt) <= fresh &&
        _enough(cached, limit)) {
      return _trim(cached, limit);
    }

    final reasons = <String, String>{};
    for (final p in _providers) {
      if (!p.supports(instrument, interval)) continue;
      final h = _health[p.id]!;
      if (_limiter.isCoolingDown(p.id)) {
        reasons[p.id] = 'soğuma süresinde';
        continue;
      }
      await _limiter.acquire(p.id);
      try {
        final got = await p.fetchCandles(instrument, interval, limit: limit, now: _clock());
        if (got.closed.isEmpty) throw ProviderException(p.id, 'kapanmış mum yok');
        final merged = got.copyWith(closed: mergeClosed(cached, got));
        await _cache.write(key, merged);
        h
          ..lastSuccess = _clock()
          ..consecutiveFailures = 0
          ..successCount += 1
          ..lastError = null;
        _limiter.reportSuccess(p.id);
        return _trim(merged, limit);
      } on ProviderException catch (e) {
        reasons[p.id] = e.message;
        _fail(h, e.message, throttle: e.rateLimited);
      } on HttpFetchException catch (e) {
        reasons[p.id] = e.message;
        _fail(h, e.message, throttle: e.isRateLimited);
      } on FormatException catch (e) {
        reasons[p.id] = 'biçim hatası';
        _fail(h, 'biçim hatası: ${e.message}', throttle: false);
      }
    }

    if (cached != null && cached.closed.isNotEmpty) {
      return _trim(cached.copyWith(stale: true), limit);
    }
    if (reasons.isEmpty) reasons['-'] = 'bu varlık/dilim için sağlayıcı yok';
    throw MarketDataException(instrument.id, reasons);
  }

  /// Birden çok varlık için sırayla veri çeker; başarısız olanları ayrı döndürür.
  Future<({Map<Instrument, CandleSeries> ok, Map<Instrument, String> failed})> candlesFor(
    Iterable<Instrument> instruments,
    BarInterval interval, {
    int limit = 300,
  }) async {
    final ok = <Instrument, CandleSeries>{};
    final failed = <Instrument, String>{};
    for (final ins in instruments) {
      try {
        ok[ins] = await candles(ins, interval, limit: limit);
      } on MarketDataException catch (e) {
        failed[ins] = e.reasons.values.join(' | ');
      }
    }
    return (ok: ok, failed: failed);
  }

  bool _enough(CandleSeries s, int limit) => s.closed.length >= limit || s.closed.length >= 30;

  CandleSeries _trim(CandleSeries s, int limit) =>
      s.closed.length > limit ? s.copyWith(closed: s.closed.sublist(s.closed.length - limit)) : s;

  void _fail(ProviderHealth h, String msg, {required bool throttle}) {
    h
      ..lastFailure = _clock()
      ..lastError = msg
      ..consecutiveFailures += 1
      ..failureCount += 1;
    if (throttle || h.consecutiveFailures >= failuresBeforeCooldown) {
      _limiter.reportThrottled(h.id);
    }
  }
}
