enum Market { crypto, bist }

/// Mum zaman dilimi.
enum BarInterval {
  m5(5, '5m'),
  m15(15, '15m'),
  h1(60, '1h'),
  h4(240, '4h'),
  d1(1440, '1d');

  const BarInterval(this.minutes, this.code);
  final int minutes;
  final String code;

  Duration get duration => Duration(minutes: minutes);
  int get ms => minutes * 60 * 1000;

  static BarInterval parse(String code) =>
      values.firstWhere((v) => v.code == code, orElse: () => throw ArgumentError('Bilinmeyen dilim: $code'));
}

/// İzlenen varlık. Kripto için sembol `BTCUSDT`, BIST için `THYAO` biçimindedir.
class Instrument {
  const Instrument(this.market, this.symbol, {this.name = ''});
  const Instrument.crypto(String symbol, {String name = ''}) : this(Market.crypto, symbol, name: name);
  const Instrument.bist(String symbol, {String name = ''}) : this(Market.bist, symbol, name: name);

  final Market market;
  final String symbol;
  final String name;

  String get id => '${market.name}:$symbol';
  String get currency => market == Market.bist ? 'TRY' : 'USDT';

  /// Ekranda ve bildirimde kullanılan kısa ad (`SOL`, `THYAO`).
  String get short =>
      market == Market.crypto && symbol.endsWith('USDT') ? symbol.substring(0, symbol.length - 4) : symbol;

  static Instrument parseId(String id) {
    final i = id.indexOf(':');
    if (i <= 0) throw ArgumentError('Geçersiz varlık kimliği: $id');
    return Instrument(Market.values.byName(id.substring(0, i)), id.substring(i + 1));
  }

  @override
  bool operator ==(Object other) => other is Instrument && other.market == market && other.symbol == symbol;
  @override
  int get hashCode => Object.hash(market, symbol);
  @override
  String toString() => id;
}
