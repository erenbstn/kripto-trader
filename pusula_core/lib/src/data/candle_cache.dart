import '../model/candle.dart';
import '../model/market.dart';

/// Mum önbelleği arayüzü. Uygulama kalıcı (disk) sürümünü sağlar; çekirdek ve testler
/// bellek içi sürümü kullanır.
abstract class CandleCache {
  Future<CandleSeries?> read(String key);
  Future<void> write(String key, CandleSeries series);
  Future<void> clear();
}

String cacheKey(Instrument instrument, BarInterval interval) => '${instrument.id}|${interval.code}';

class MemoryCandleCache implements CandleCache {
  final Map<String, CandleSeries> _store = {};

  @override
  Future<CandleSeries?> read(String key) async => _store[key];

  @override
  Future<void> write(String key, CandleSeries series) async => _store[key] = series;

  @override
  Future<void> clear() async => _store.clear();

  int get length => _store.length;
}

/// Aynı kaynaktan gelen eski ve yeni mumları açılış zamanına göre birleştirir.
/// Çakışmada yeni veri kazanır. Kaynak farklıysa (mum hizası farklı olabilir) yalnızca yeni döner.
List<Candle> mergeClosed(CandleSeries? old, CandleSeries fresh, {int maxBars = 1500}) {
  if (old == null || old.source != fresh.source || old.interval != fresh.interval) return fresh.closed;
  final firstFresh = fresh.closed.isEmpty ? null : fresh.closed.first.openTimeMs;
  final merged = <Candle>[
    for (final c in old.closed)
      if (firstFresh == null || c.openTimeMs < firstFresh) c,
    ...fresh.closed,
  ];
  return merged.length > maxBars ? merged.sublist(merged.length - maxBars) : merged;
}
