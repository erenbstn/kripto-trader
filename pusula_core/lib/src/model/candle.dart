import 'market.dart';

/// Tek mum. Zaman UTC milisaniyedir.
class Candle {
  const Candle({
    required this.openTimeMs,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    required this.quoteVolume,
    this.takerBuyQuote,
  });

  final int openTimeMs;
  final double open;
  final double high;
  final double low;
  final double close;

  /// Adet/coin cinsinden hacim.
  final double volume;

  /// Para birimi cinsinden işlem hacmi (TL veya USDT). Kaynak vermiyorsa yaklaşık değerdir.
  final double quoteVolume;

  /// Agresif alıcı hacmi (yalnızca Binance verir).
  final double? takerBuyQuote;

  DateTime get openTime => DateTime.fromMillisecondsSinceEpoch(openTimeMs, isUtc: true);
  double get typical => (high + low + close) / 3.0;

  Map<String, Object?> toJson() => {
        't': openTimeMs,
        'o': open,
        'h': high,
        'l': low,
        'c': close,
        'v': volume,
        'q': quoteVolume,
        if (takerBuyQuote != null) 'b': takerBuyQuote,
      };

  static Candle fromJson(Map<String, Object?> j) => Candle(
        openTimeMs: (j['t'] as num).toInt(),
        open: (j['o'] as num).toDouble(),
        high: (j['h'] as num).toDouble(),
        low: (j['l'] as num).toDouble(),
        close: (j['c'] as num).toDouble(),
        volume: (j['v'] as num).toDouble(),
        quoteVolume: (j['q'] as num).toDouble(),
        takerBuyQuote: (j['b'] as num?)?.toDouble(),
      );
}

/// Bir sağlayıcıdan gelen mum dizisi. `closed` yalnızca kapanmış mumları içerir;
/// kapanmamış mum asla sinyal teyidi sayılmaz.
class CandleSeries {
  const CandleSeries({
    required this.instrument,
    required this.interval,
    required this.closed,
    required this.forming,
    required this.lastPrice,
    required this.source,
    required this.fetchedAt,
    required this.dataDelay,
    this.stale = false,
    this.approximateOpen = false,
  });

  final Instrument instrument;
  final BarInterval interval;
  final List<Candle> closed;
  final Candle? forming;
  final double lastPrice;

  /// Sağlayıcı kimliği (`binance`, `yahoo`, `isyatirim`).
  final String source;
  final DateTime fetchedAt;

  /// Kaynağın beyan edilen veri gecikmesi (BIST için ~15 dk).
  final Duration dataDelay;

  /// Tüm sağlayıcılar başarısız olduğu için önbellekten dönen eski veri.
  final bool stale;

  /// Açılış fiyatı kaynakta yok, önceki kapanıştan türetildi.
  final bool approximateOpen;

  bool get isEmpty => closed.isEmpty;

  /// Verinin yaşı: indirme anından bu yana geçen süre + kaynak gecikmesi.
  Duration ageAt(DateTime now) => now.toUtc().difference(fetchedAt) + dataDelay;

  CandleSeries copyWith({List<Candle>? closed, bool? stale, Candle? forming, double? lastPrice}) => CandleSeries(
        instrument: instrument,
        interval: interval,
        closed: closed ?? this.closed,
        forming: forming ?? this.forming,
        lastPrice: lastPrice ?? this.lastPrice,
        source: source,
        fetchedAt: fetchedAt,
        dataDelay: dataDelay,
        stale: stale ?? this.stale,
        approximateOpen: approximateOpen,
      );

  Map<String, Object?> toJson() => {
        'instrument': instrument.id,
        'interval': interval.code,
        'closed': [for (final c in closed) c.toJson()],
        'forming': forming?.toJson(),
        'lastPrice': lastPrice,
        'source': source,
        'fetchedAt': fetchedAt.toUtc().millisecondsSinceEpoch,
        'delayMs': dataDelay.inMilliseconds,
        'approximateOpen': approximateOpen,
      };

  static CandleSeries fromJson(Map<String, Object?> j) => CandleSeries(
        instrument: Instrument.parseId(j['instrument'] as String),
        interval: BarInterval.parse(j['interval'] as String),
        closed: [for (final c in j['closed'] as List<Object?>) Candle.fromJson((c as Map).cast<String, Object?>())],
        forming: j['forming'] == null ? null : Candle.fromJson((j['forming'] as Map).cast<String, Object?>()),
        lastPrice: (j['lastPrice'] as num).toDouble(),
        source: j['source'] as String,
        fetchedAt: DateTime.fromMillisecondsSinceEpoch((j['fetchedAt'] as num).toInt(), isUtc: true),
        dataDelay: Duration(milliseconds: (j['delayMs'] as num).toInt()),
        approximateOpen: (j['approximateOpen'] as bool?) ?? false,
      );
}

