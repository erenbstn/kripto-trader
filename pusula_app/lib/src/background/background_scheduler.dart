import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pusula_core/pusula_core.dart';

/// Arka plan zamanlama özeti: sonraki kesin alarmların zamanları ve canlı izleme durumu.
class BackgroundScheduleSnapshot {
  const BackgroundScheduleSnapshot({
    required this.periodicIntervalMinutes,
    required this.nextSundayReportUtc,
    required this.nextBistOpenUtc,
    required this.nextBistCloseUtc,
    required this.liveMonitorActive,
    required this.batteryOptimizationIgnored,
  });

  final int periodicIntervalMinutes;
  final DateTime nextSundayReportUtc;
  final DateTime nextBistOpenUtc;
  final DateTime nextBistCloseUtc;
  final bool liveMonitorActive;
  final bool batteryOptimizationIgnored;
}

/// Üretici bazlı pil optimizasyonu muafiyeti yönergesi (K1).
class OemBatteryGuideItem {
  const OemBatteryGuideItem({
    required this.brand,
    required this.steps,
  });

  final String brand;
  final String steps;
}

/// Android arka plan zamanlayıcısı (K1):
/// 1. WorkManager 15 dk periyodik tarama/izleme
/// 2. Pazar raporu (Pazar 09:00 TRT) ve BIST açılış (10:00 TRT) / kapanış (18:10 TRT) için kesin alarm
/// 3. Kullanıcı açarsa kalıcı bildirimli "Canlı İzleme" ön plan servisi (`dataSync`).
class BackgroundScheduler {
  BackgroundScheduler({
    this.calendar = const BistCalendar(),
    Clock? clock,
  }) : _clock = clock ?? systemClock;

  static const MethodChannel _channel = MethodChannel('app.pusula/background');

  final BistCalendar calendar;
  final Clock _clock;

  static const List<OemBatteryGuideItem> oemGuides = [
    OemBatteryGuideItem(
      brand: 'Genel Android (AOSP / Pixel)',
      steps: 'Ayarlar → Uygulamalar → Pusula → Pil → "Kısıtlanmamış" (Unrestricted) seçeneğini işaretleyin.',
    ),
    OemBatteryGuideItem(
      brand: 'Samsung (One UI)',
      steps: 'Ayarlar → Pil ve Cihaz Bakımı → Pil → Arka Plan Kullanım Sınırları → "Hiç uyku moduna geçmeyen uygulamalar" listesine Pusula\'yı ekleyin.',
    ),
    OemBatteryGuideItem(
      brand: 'Xiaomi / Redmi / POCO (MIUI & HyperOS)',
      steps: 'Ayarlar → Uygulamalar → Uygulamaları Yönet → Pusula → "Otomatik Başlatma"yı açın ve Pil Tasarrufu kısmında "Kısıtlama yok" seçin.',
    ),
    OemBatteryGuideItem(
      brand: 'Oppo / Realme / OnePlus (ColorOS)',
      steps: 'Ayarlar → Pil → Daha Fazla Ayar → Uygulama Pil Yönetimi → Pusula → "Arka plan etkinliğine izin ver" ve "Otomatik başlatma"yı açın.',
    ),
  ];

  /// [from] anından sonraki ilk Pazar günü saat 09:00 TRT (06:00 UTC) zamanını hesaplar.
  static DateTime nextSundayReportUtc(DateTime from) {
    final trt = BistCalendar.toTrt(from);
    // Pazar = DateTime.sunday (7)
    var daysUntilSunday = (DateTime.sunday - trt.weekday) % 7;
    var candidateTrt = DateTime.utc(trt.year, trt.month, trt.day, 9, 0).add(Duration(days: daysUntilSunday));
    final candidateUtc = candidateTrt.subtract(BistCalendar.trtOffset);
    if (!candidateUtc.isAfter(from.toUtc())) {
      candidateTrt = candidateTrt.add(const Duration(days: 7));
      return candidateTrt.subtract(BistCalendar.trtOffset);
    }
    return candidateUtc;
  }

  /// [from] anından sonraki ilk BIST sürekli işlem açılışını (10:00 TRT) döndürür.
  DateTime nextBistOpenUtc(DateTime from) => calendar.nextOpen(from);

  /// [from] anından sonraki ilk BIST seans kapanışını (normal 18:10 TRT, yarım gün 12:40 TRT) döndürür.
  DateTime nextBistCloseUtc(DateTime from) {
    final u = from.toUtc();
    final todaySession = calendar.sessionOn(u);
    if (todaySession != null && todaySession.close.isAfter(u)) {
      return todaySession.close;
    }
    final nextOpen = calendar.nextOpen(u);
    final nextSession = calendar.sessionOn(nextOpen);
    return nextSession?.close ?? nextOpen.add(const Duration(hours: 8, minutes: 10));
  }

  /// Tüm zamanlamaları hesaplar ve Android platform kanalına bildirir.
  Future<BackgroundScheduleSnapshot> syncSchedule({required bool liveMonitorEnabled}) async {
    final now = _clock().toUtc();
    final sundayUtc = nextSundayReportUtc(now);
    final bistOpenUtc = nextBistOpenUtc(now);
    final bistCloseUtc = nextBistCloseUtc(now);

    var batteryIgnored = false;
    if (!kIsWeb) {
      try {
        await _channel.invokeMethod<void>('schedulePeriodicScan', {'intervalMinutes': 15});
        await _channel.invokeMethod<void>('scheduleExactAlarms', {
          'sundayReportMs': sundayUtc.millisecondsSinceEpoch,
          'bistOpenMs': bistOpenUtc.millisecondsSinceEpoch,
          'bistCloseMs': bistCloseUtc.millisecondsSinceEpoch,
        });
        await _channel.invokeMethod<void>('setLiveMonitor', {'enabled': liveMonitorEnabled});
        batteryIgnored = (await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations')) ?? false;
      } on MissingPluginException {
        // Test ortamında veya masaüstünde kanal bulunmayabilir
      } on PlatformException {
        // İzin verilmemişse güvenli devam et
      }
    }

    return BackgroundScheduleSnapshot(
      periodicIntervalMinutes: 15,
      nextSundayReportUtc: sundayUtc,
      nextBistOpenUtc: bistOpenUtc,
      nextBistCloseUtc: bistCloseUtc,
      liveMonitorActive: liveMonitorEnabled,
      batteryOptimizationIgnored: batteryIgnored,
    );
  }

  /// Android sistem pil optimizasyonu muafiyet penceresini açar.
  Future<bool> requestIgnoreBatteryOptimizations() async {
    if (kIsWeb) return false;
    try {
      return (await _channel.invokeMethod<bool>('requestIgnoreBatteryOptimizations')) ?? false;
    } catch (_) {
      return false;
    }
  }
}

