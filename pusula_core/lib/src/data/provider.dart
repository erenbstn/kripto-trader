import '../model/candle.dart';
import '../model/market.dart';

/// Piyasa verisi sağlayıcısı. Her sağlayıcı anahtarsız, herkese açık uçları kullanır.
abstract class MarketDataProvider {
  /// Kısa kimlik: `binance`, `yahoo`, `isyatirim`.
  String get id;

  /// Ekranda gösterilen ad.
  String get label;

  /// Bu piyasa için beyan edilen veri gecikmesi.
  Duration delayFor(Market market);

  bool supports(Instrument instrument, BarInterval interval);

  /// En fazla [limit] kapanmış mum döndürür. Başarısızlıkta `ProviderException`
  /// veya `HttpFetchException` fırlatır.
  Future<CandleSeries> fetchCandles(
    Instrument instrument,
    BarInterval interval, {
    required int limit,
    required DateTime now,
  });
}
