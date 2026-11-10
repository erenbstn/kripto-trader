/// Borsa İstanbul Pay Piyasası takvimi: seans saatleri, resmî tatiller, yarım günler.
///
/// Türkiye 2016'dan beri kalıcı UTC+3 kullanır; yaz saati yoktur. Bu yüzden saat dilimi
/// veritabanına gerek yoktur.
///
/// Tatil tablosu yıl bazında gömülüdür ve her yıl güncellenmelidir. Kapsanmayan bir yıl için
/// yalnızca hafta sonu ve sabit tarihli tatiller bilinir; [isCoveredYear] false döner ve
/// uygulama bunu kullanıcıya gösterir.
library;

enum BistPhase { closed, openingAuction, continuous, closingAuction }

/// Tek işlem gününün seans zamanları (hepsi UTC).
class BistSession {
  const BistSession({
    required this.auctionOpen,
    required this.open,
    required this.continuousEnd,
    required this.close,
    required this.halfDay,
  });

  /// Açılış seansı emir toplama başlangıcı (09:40).
  final DateTime auctionOpen;

  /// Sürekli işlem başlangıcı (10:00).
  final DateTime open;

  /// Sürekli işlem bitişi (18:00; yarım gün 12:30).
  final DateTime continuousEnd;

  /// Kapanış seansı bitişi (18:10; yarım gün 12:40).
  final DateTime close;
  final bool halfDay;
}

class BistCalendar {
  const BistCalendar();

  static const Duration trtOffset = Duration(hours: 3);

  /// Dini bayram tarihleri dahil tam tablosu girilmiş yıllar.
  /// 2026: Borsa İstanbul 2026 tatil tablosuna göre. 2027: takvim hesabına göre ÖNGÖRÜ;
  /// resmî tablo yayımlanınca doğrulanmalıdır.
  static const Set<int> coveredYears = {2026, 2027};
  static const Set<int> provisionalYears = {2027};

  static const Map<int, String> _fullDay = {
    // 2026
    20260101: 'Yılbaşı',
    20260320: 'Ramazan Bayramı',
    20260321: 'Ramazan Bayramı',
    20260322: 'Ramazan Bayramı',
    20260423: 'Ulusal Egemenlik ve Çocuk Bayramı',
    20260501: 'Emek ve Dayanışma Günü',
    20260519: 'Atatürk\'ü Anma, Gençlik ve Spor Bayramı',
    20260527: 'Kurban Bayramı',
    20260528: 'Kurban Bayramı',
    20260529: 'Kurban Bayramı',
    20260530: 'Kurban Bayramı',
    20260715: 'Demokrasi ve Millî Birlik Günü',
    20260830: 'Zafer Bayramı',
    20261029: 'Cumhuriyet Bayramı',
    // 2027 (öngörü)
    20270101: 'Yılbaşı',
    20270309: 'Ramazan Bayramı',
    20270310: 'Ramazan Bayramı',
    20270311: 'Ramazan Bayramı',
    20270423: 'Ulusal Egemenlik ve Çocuk Bayramı',
    20270501: 'Emek ve Dayanışma Günü',
    20270516: 'Kurban Bayramı',
    20270517: 'Kurban Bayramı',
    20270518: 'Kurban Bayramı',
    20270519: 'Kurban Bayramı',
    20270715: 'Demokrasi ve Millî Birlik Günü',
    20270830: 'Zafer Bayramı',
    20271029: 'Cumhuriyet Bayramı',
  };

  static const Map<int, String> _halfDay = {
    20260319: 'Ramazan Bayramı arifesi',
    20260526: 'Kurban Bayramı arifesi',
    20261028: 'Cumhuriyet Bayramı arifesi',
    20270308: 'Ramazan Bayramı arifesi',
    20270515: 'Kurban Bayramı arifesi',
    20271028: 'Cumhuriyet Bayramı arifesi',
  };

  /// Kapsanmayan yıllarda da geçerli sabit tarihli tatiller (ay*100+gün).
  static const Map<int, String> _fixedEveryYear = {
    101: 'Yılbaşı',
    423: 'Ulusal Egemenlik ve Çocuk Bayramı',
    501: 'Emek ve Dayanışma Günü',
    519: 'Atatürk\'ü Anma, Gençlik ve Spor Bayramı',
    715: 'Demokrasi ve Millî Birlik Günü',
    830: 'Zafer Bayramı',
    1029: 'Cumhuriyet Bayramı',
  };

  /// Verilen anın Türkiye duvar saati (alanları TRT'dir; `isUtc` bayrağı dikkate alınmamalı).
  static DateTime toTrt(DateTime t) => t.toUtc().add(trtOffset);

  static int _key(DateTime trt) => trt.year * 10000 + trt.month * 100 + trt.day;

  static DateTime _utcFromTrt(int y, int m, int d, int h, int min) =>
      DateTime.utc(y, m, d, h, min).subtract(trtOffset);

  bool isCoveredYear(int year) => coveredYears.contains(year);
  bool isProvisionalYear(int year) => provisionalYears.contains(year);

  /// Tam gün tatilse adını döndürür.
  String? holidayName(DateTime t) {
    final trt = toTrt(t);
    return _fullDay[_key(trt)] ?? (isCoveredYear(trt.year) ? null : _fixedEveryYear[trt.month * 100 + trt.day]);
  }

  String? halfDayName(DateTime t) => _halfDay[_key(toTrt(t))];

  bool isTradingDay(DateTime t) {
    final trt = toTrt(t);
    if (trt.weekday == DateTime.saturday || trt.weekday == DateTime.sunday) return false;
    return holidayName(t) == null;
  }

  /// [t] anının düştüğü TRT gününün seansı; işlem günü değilse null.
  BistSession? sessionOn(DateTime t) {
    if (!isTradingDay(t)) return null;
    final trt = toTrt(t);
    final half = _halfDay.containsKey(_key(trt));
    return BistSession(
      auctionOpen: _utcFromTrt(trt.year, trt.month, trt.day, 9, 40),
      open: _utcFromTrt(trt.year, trt.month, trt.day, 10, 0),
      continuousEnd: half
          ? _utcFromTrt(trt.year, trt.month, trt.day, 12, 30)
          : _utcFromTrt(trt.year, trt.month, trt.day, 18, 0),
      close: half
          ? _utcFromTrt(trt.year, trt.month, trt.day, 12, 40)
          : _utcFromTrt(trt.year, trt.month, trt.day, 18, 10),
      halfDay: half,
    );
  }

  BistPhase phaseAt(DateTime t) {
    final s = sessionOn(t);
    if (s == null) return BistPhase.closed;
    final u = t.toUtc();
    if (u.isBefore(s.auctionOpen) || !u.isBefore(s.close)) return BistPhase.closed;
    if (u.isBefore(s.open)) return BistPhase.openingAuction;
    if (u.isBefore(s.continuousEnd)) return BistPhase.continuous;
    return BistPhase.closingAuction;
  }

  bool isOpenAt(DateTime t) => phaseAt(t) != BistPhase.closed;

  /// [from] anından sonraki ilk sürekli işlem açılışı (o an açılıştan önceyse aynı gün).
  DateTime nextOpen(DateTime from) {
    var probe = from.toUtc();
    for (var i = 0; i < 40; i++) {
      final s = sessionOn(probe);
      if (s != null && s.open.isAfter(from.toUtc())) return s.open;
      final trt = toTrt(probe);
      probe = _utcFromTrt(trt.year, trt.month, trt.day, 12, 0).add(const Duration(days: 1));
    }
    throw StateError('40 gün içinde işlem günü bulunamadı');
  }

  /// [t] anında veya öncesinde biten son seansın kapanışı.
  DateTime lastCloseAtOrBefore(DateTime t) {
    var probe = t.toUtc();
    for (var i = 0; i < 40; i++) {
      final s = sessionOn(probe);
      if (s != null && !s.close.isAfter(t.toUtc())) return s.close;
      final trt = toTrt(probe);
      probe = _utcFromTrt(trt.year, trt.month, trt.day, 12, 0).subtract(const Duration(days: 1));
    }
    throw StateError('40 gün içinde işlem günü bulunamadı');
  }

  /// `(a günü, b günü]` aralığındaki işlem günü sayısı (TRT gün sınırlarıyla).
  int tradingDaysBetween(DateTime a, DateTime b) {
    final ta = toTrt(a), tb = toTrt(b);
    var day = DateTime.utc(ta.year, ta.month, ta.day);
    final end = DateTime.utc(tb.year, tb.month, tb.day);
    var n = 0;
    while (day.isBefore(end)) {
      day = day.add(const Duration(days: 1));
      // Öğlen 12:00 TRT = 09:00 UTC; gün sınırı belirsizliğini önler.
      if (isTradingDay(DateTime.utc(day.year, day.month, day.day, 9))) n++;
    }
    return n;
  }
}
