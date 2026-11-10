import 'package:pusula_core/pusula_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  const cal = BistCalendar();

  group('BistCalendar', () {
    test('normal gün seans aşamaları (10 Kasım 2026 Salı)', () {
      expect(cal.phaseAt(DateTime.utc(2026, 11, 10, 6, 39)), BistPhase.closed);
      expect(cal.phaseAt(DateTime.utc(2026, 11, 10, 6, 45)), BistPhase.openingAuction);
      expect(cal.phaseAt(DateTime.utc(2026, 11, 10, 7, 0)), BistPhase.continuous);
      expect(cal.phaseAt(DateTime.utc(2026, 11, 10, 14, 59)), BistPhase.continuous);
      expect(cal.phaseAt(DateTime.utc(2026, 11, 10, 15, 5)), BistPhase.closingAuction);
      expect(cal.phaseAt(DateTime.utc(2026, 11, 10, 15, 10)), BistPhase.closed);
      expect(cal.isOpenAt(DateTime.utc(2026, 11, 10, 10)), isTrue);
    });

    test('hafta sonu ve resmî tatil kapalıdır', () {
      expect(cal.isTradingDay(DateTime.utc(2026, 11, 7, 9)), isFalse);
      expect(cal.isTradingDay(DateTime.utc(2026, 11, 8, 9)), isFalse);
      expect(cal.holidayName(DateTime.utc(2026, 10, 29, 9)), 'Cumhuriyet Bayramı');
      expect(cal.phaseAt(DateTime.utc(2026, 10, 29, 9)), BistPhase.closed);
      expect(cal.isTradingDay(DateTime.utc(2026, 1, 1, 9)), isFalse);
      expect(cal.isTradingDay(DateTime.utc(2026, 5, 19, 9)), isFalse);
    });

    test('yarım gün 12:30 sürekli işlem, 12:40 kapanış', () {
      final s = cal.sessionOn(DateTime.utc(2026, 10, 28, 9))!;
      expect(s.halfDay, isTrue);
      expect(s.continuousEnd, DateTime.utc(2026, 10, 28, 9, 30));
      expect(s.close, DateTime.utc(2026, 10, 28, 9, 40));
      expect(cal.phaseAt(DateTime.utc(2026, 10, 28, 9, 35)), BistPhase.closingAuction);
      expect(cal.phaseAt(DateTime.utc(2026, 10, 28, 9, 45)), BistPhase.closed);
      expect(cal.halfDayName(DateTime.utc(2026, 3, 19, 9)), isNotNull);
    });

    test('gün sınırı Türkiye saatine göredir', () {
      // 10 Kasım 21:30 UTC = 11 Kasım 00:30 TRT (Çarşamba)
      expect(cal.isTradingDay(DateTime.utc(2026, 11, 10, 21, 30)), isTrue);
      // 6 Kasım Cuma 22:00 UTC = 7 Kasım Cumartesi 01:00 TRT
      expect(cal.isTradingDay(DateTime.utc(2026, 11, 6, 22)), isFalse);
    });

    test('sonraki açılış: aynı gün, ertesi gün, bayram sonrası', () {
      expect(cal.nextOpen(DateTime.utc(2026, 11, 10, 5)), DateTime.utc(2026, 11, 10, 7));
      expect(cal.nextOpen(DateTime.utc(2026, 11, 10, 8)), DateTime.utc(2026, 11, 11, 7));
      expect(cal.nextOpen(DateTime.utc(2026, 11, 6, 16)), DateTime.utc(2026, 11, 9, 7));
      // Kurban Bayramı arifesi (26 Mayıs Salı, yarım gün) sonrası: 27-30 tatil, 31 Pazar → 1 Haziran
      expect(cal.nextOpen(DateTime.utc(2026, 5, 26, 10)), DateTime.utc(2026, 6, 1, 7));
    });

    test('son kapanış ve işlem günü sayımı', () {
      expect(cal.lastCloseAtOrBefore(DateTime.utc(2026, 11, 9, 5)), DateTime.utc(2026, 11, 6, 15, 10));
      expect(cal.lastCloseAtOrBefore(DateTime.utc(2026, 11, 10, 15, 10)), DateTime.utc(2026, 11, 10, 15, 10));
      expect(cal.tradingDaysBetween(DateTime.utc(2026, 11, 6, 9), DateTime.utc(2026, 11, 13, 9)), 5);
      // 26 Ekim Pzt → 30 Ekim Cum: 27, 28 (yarım), 30 → 3 gün (29 tatil)
      expect(cal.tradingDaysBetween(DateTime.utc(2026, 10, 26, 9), DateTime.utc(2026, 10, 30, 9)), 3);
    });

    test('kapsanmayan yılda sabit tatiller bilinir ve kapsam dışı olduğu bildirilir', () {
      expect(cal.isCoveredYear(2030), isFalse);
      expect(cal.isCoveredYear(2026), isTrue);
      expect(cal.isProvisionalYear(2027), isTrue);
      expect(cal.holidayName(DateTime.utc(2030, 4, 23, 9)), isNotNull);
      expect(cal.isTradingDay(DateTime.utc(2030, 4, 24, 9)), isTrue);
    });
  });

  group('BistRules', () {
    test('fiyat adımı kademeleri', () {
      expect(BistRules.tickSize(15), 0.01);
      expect(BistRules.tickSize(19.99), 0.01);
      expect(BistRules.tickSize(20), 0.02);
      expect(BistRules.tickSize(75), 0.05);
      expect(BistRules.tickSize(313.75), 0.25);
      expect(BistRules.tickSize(3000), 2.5);
      expect(BistRules.roundToTick(313.8), 313.75);
      expect(BistRules.roundToTick(20.03), 20.04);
    });

    test('tavan/taban adıma oturur', () {
      final a = BistRules.dailyLimits(100);
      expect(a.ceiling, 110.0);
      expect(a.floor, 90.0);
      final b = BistRules.dailyLimits(313.75);
      expect(b.ceiling, 345.0);
      expect(b.floor, 282.5);
      expect(BistRules.isAtLimit(345, 313.75), isTrue);
      expect(BistRules.isAtLimit(282.5, 313.75), isTrue);
      expect(BistRules.isAtLimit(320, 313.75), isFalse);
    });

    test('lot hesabı', () {
      expect(BistRules.lotsFor(10000, 313.75), 31);
      expect(BistRules.lotsFor(100, 313.75), 0);
      expect(BistRules.lotsFor(100, 0), 0);
    });
  });

  group('BistUniverseFilter', () {
    final now = DateTime.utc(2026, 11, 10, 16);
    List<Candle> daily(double turnover, {int count = 80, DateTime? last, double step = 0.1}) {
      final end = last ?? DateTime.utc(2026, 11, 10, 7);
      return syntheticCandles(
        start: end.subtract(Duration(days: count - 1)),
        interval: BarInterval.d1,
        count: count,
        turnover: turnover,
        stepPct: step,
      );
    }

    test('likidite, geçmiş, bayatlık ve tavan/taban süzgeçleri', () {
      final sel = const BistUniverseFilter(topN: 2).select({
        'BUYUK': daily(5e9),
        'ORTA': daily(1e9),
        'UCUNCU': daily(5e8),
        'SIG': daily(5e7),
        'YENI': daily(5e9, count: 30),
        'BAYAT': daily(5e9, last: DateTime.utc(2026, 10, 20, 7)),
        'TAVAN': daily(5e9, step: 10),
        'BOS': const [],
      }, now: now);
      expect(sel.selected.map((i) => i.symbol).toList(), ['BUYUK', 'ORTA']);
      expect(sel.turnover['BUYUK'], closeTo(5e9, 1));
      final why = {for (final r in sel.rejected) r.symbol: r.reason};
      expect(why['UCUNCU'], contains('ilk 2 dışında'));
      expect(why['SIG'], contains('düşük likidite'));
      expect(why['YENI'], contains('yetersiz geçmiş'));
      expect(why['BAYAT'], contains('bayat'));
      expect(why['TAVAN'], contains('tavan/taban'));
      expect(why['BOS'], 'veri yok');
    });

    test('aday listesi tekrarsız ve kripto evreni 10 varlık', () {
      expect(BistUniverse.candidateSymbols.toSet().length, BistUniverse.candidateSymbols.length);
      expect(CryptoUniverse.instruments.length, 10);
      expect(CryptoUniverse.contains('SOLUSDT'), isTrue);
      expect(CryptoUniverse.contains('DOGEUSDT'), isFalse);
    });
  });
}
