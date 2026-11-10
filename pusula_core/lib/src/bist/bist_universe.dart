import '../model/candle.dart';
import '../model/market.dart';

/// BIST evreni: aday listesi + likidite süzgeci.
///
/// Aday listesi BIST 100 ağırlıklı, elle derlenmiş bir listedir ve endeks dönemlerinde
/// güncellenmelidir ([candidatesAsOf]). Listedeki bir sembol veri kaynağında bulunamazsa
/// (kod değişikliği, kottan çıkma) süzgeç onu "veri yok" gerekçesiyle eler; sistem çalışmaya devam eder.
class BistUniverse {
  const BistUniverse._();

  static const String candidatesAsOf = '2026-11';

  /// Piyasa rejimi için referans endeks.
  static const Instrument benchmark = Instrument.bist('XU100', name: 'BIST 100');

  static const List<String> candidateSymbols = [
    'AEFES', 'AGHOL', 'AKBNK', 'AKSA', 'AKSEN', 'ALARK', 'ALFAS', 'ANSGR', 'ARCLK', 'ASELS',
    'ASTOR', 'BERA', 'BIMAS', 'BRSAN', 'BRYAT', 'BTCIM', 'CANTE', 'CCOLA', 'CIMSA', 'CWENE',
    'DOAS', 'DOHOL', 'ECILC', 'EGEEN', 'EKGYO', 'ENERY', 'ENJSA', 'ENKAI', 'EREGL', 'EUPWR',
    'FROTO', 'GARAN', 'GESAN', 'GUBRF', 'HALKB', 'HEKTS', 'ISCTR', 'ISMEN', 'KARSN', 'KCAER',
    'KCHOL', 'KONTR', 'KRDMD', 'MAVI', 'MGROS', 'MIATK', 'MPARK', 'ODAS', 'OTKAR', 'OYAKC',
    'PETKM', 'PGSUS', 'REEDR', 'SAHOL', 'SASA', 'SISE', 'SKBNK', 'SMRTG', 'SOKM', 'TABGD',
    'TAVHL', 'TCELL', 'THYAO', 'TKFEN', 'TOASO', 'TSKB', 'TTKOM', 'TTRAK', 'TUPRS', 'TURSG',
    'ULKER', 'VAKBN', 'VESTL', 'YKBNK', 'ZOREN',
  ];

  static List<Instrument> get candidates => [for (final s in candidateSymbols) Instrument.bist(s)];
}

class UniverseRejection {
  const UniverseRejection(this.symbol, this.reason);
  final String symbol;
  final String reason;
}

class UniverseSelection {
  const UniverseSelection({required this.selected, required this.rejected, required this.turnover});
  final List<Instrument> selected;
  final List<UniverseRejection> rejected;

  /// Seçilenlerin 20 günlük ortalama işlem hacmi (TL).
  final Map<String, double> turnover;
}

/// Likidite süzgeci. Gecikmeli veriyle makul giriş yalnızca derin tahtalarda mümkün olduğu için
/// en yüksek işlem hacimli hisseler tutulur.
class BistUniverseFilter {
  const BistUniverseFilter({
    this.topN = 40,
    this.minAvgTurnoverTry = 300e6,
    this.minBars = 60,
    this.lookback = 20,
    this.maxLimitDays = 5,
    this.limitMovePct = 9.5,
    this.maxStaleDays = 6,
  });

  final int topN;
  final double minAvgTurnoverTry;
  final int minBars;
  final int lookback;

  /// Son [lookback] günde bu sayıdan fazla tavan/taban günü olan hisse elenir.
  final int maxLimitDays;
  final double limitMovePct;

  /// Son mum bu kadar takvim gününden eskiyse veri bayat sayılır.
  final int maxStaleDays;

  UniverseSelection select(Map<String, List<Candle>> dailyBySymbol, {required DateTime now}) {
    final rejected = <UniverseRejection>[];
    final turnover = <String, double>{};
    for (final sym in dailyBySymbol.keys) {
      final bars = dailyBySymbol[sym]!;
      if (bars.isEmpty) {
        rejected.add(UniverseRejection(sym, 'veri yok'));
        continue;
      }
      if (bars.length < minBars) {
        rejected.add(UniverseRejection(sym, 'yetersiz geçmiş (${bars.length} < $minBars gün)'));
        continue;
      }
      final ageDays = now.toUtc().difference(bars.last.openTime).inDays;
      if (ageDays > maxStaleDays) {
        rejected.add(UniverseRejection(sym, 'veri bayat ($ageDays gün)'));
        continue;
      }
      final recent = bars.sublist(bars.length - lookback);
      final avg = recent.fold<double>(0, (s, b) => s + b.quoteVolume) / recent.length;
      var limitDays = 0;
      for (var i = bars.length - lookback; i < bars.length; i++) {
        final prev = bars[i - 1].close;
        if (prev > 0 && ((bars[i].close / prev - 1).abs() * 100) >= limitMovePct) limitDays++;
      }
      if (limitDays > maxLimitDays) {
        rejected.add(UniverseRejection(sym, 'son $lookback günde $limitDays tavan/taban günü'));
        continue;
      }
      if (avg < minAvgTurnoverTry) {
        rejected.add(UniverseRejection(sym, 'düşük likidite (${(avg / 1e6).toStringAsFixed(0)} mn TL/gün)'));
        continue;
      }
      turnover[sym] = avg;
    }
    final ranked = turnover.keys.toList()..sort((a, b) => turnover[b]!.compareTo(turnover[a]!));
    for (final sym in ranked.skip(topN)) {
      rejected.add(UniverseRejection(sym, 'ilk $topN dışında'));
    }
    final keep = ranked.take(topN).toList();
    return UniverseSelection(
      selected: [for (final s in keep) Instrument.bist(s)],
      rejected: rejected,
      turnover: {for (final s in keep) s: turnover[s]!},
    );
  }
}
