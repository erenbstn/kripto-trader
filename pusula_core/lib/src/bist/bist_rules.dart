/// Borsa İstanbul Pay Piyasası işlem kuralları: fiyat adımı, günlük fiyat marjı, lot, takas.
///
/// Değerler genel kurallardır. Tedbirli paylarda (brüt takas, tek fiyat, daraltılmış marj)
/// farklı sınırlar uygulanabilir; bu durumlar veri kaynağından otomatik algılanamaz.
library;

class BistRules {
  const BistRules._();

  /// Bir lot = 1 pay.
  static const int lotSize = 1;

  /// Takas süresi (iş günü).
  static const int settlementDays = 2;

  /// Günlük fiyat marjı (baz fiyatın ±%10'u).
  static const double dailyLimitPct = 10.0;

  /// Fiyat kademesine göre fiyat adımı (TL).
  static double tickSize(double price) {
    if (price < 20) return 0.01;
    if (price < 50) return 0.02;
    if (price < 100) return 0.05;
    if (price < 250) return 0.10;
    if (price < 500) return 0.25;
    if (price < 1000) return 0.50;
    if (price < 2500) return 1.00;
    return 2.50;
  }

  static double _snap(double v, double tick, {required bool down}) {
    final q = v / tick;
    final n = down ? (q + 1e-9).floorToDouble() : (q - 1e-9).ceilToDouble();
    return double.parse((n * tick).toStringAsFixed(2));
  }

  /// En yakın fiyat adımına yuvarlar.
  static double roundToTick(double price) {
    final tick = tickSize(price);
    return double.parse(((price / tick).roundToDouble() * tick).toStringAsFixed(2));
  }

  /// Önceki kapanışa göre taban ve tavan fiyat. Taban yukarı, tavan aşağı adıma oturtulur.
  static ({double floor, double ceiling}) dailyLimits(double previousClose) {
    final rawUp = previousClose * (1 + dailyLimitPct / 100);
    final rawDown = previousClose * (1 - dailyLimitPct / 100);
    return (
      floor: _snap(rawDown, tickSize(rawDown), down: false),
      ceiling: _snap(rawUp, tickSize(rawUp), down: true),
    );
  }

  /// Fiyat tavana/tabana yapışık mı? (stopun çalışmayabileceği durum)
  static bool isAtLimit(double price, double previousClose, {double tolerancePct = 0.3}) {
    final l = dailyLimits(previousClose);
    final tol = previousClose * tolerancePct / 100;
    return price >= l.ceiling - tol || price <= l.floor + tol;
  }

  /// Verilen tutarla alınabilecek tam lot sayısı.
  static int lotsFor(double amountTry, double price) => price <= 0 ? 0 : (amountTry / price).floor();
}
