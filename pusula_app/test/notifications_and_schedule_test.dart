import 'package:flutter_test/flutter_test.dart';
import 'package:pusula_app/src/background/background_scheduler.dart';
import 'package:pusula_app/src/notifications/notification_engine.dart';
import 'package:pusula_app/src/storage/app_settings.dart';
import 'package:pusula_app/src/storage/sqlite_storage.dart';
import 'package:pusula_core/pusula_core.dart';

void main() {
  group('Faz 4 — Yerel Bildirim Biçimlendirici (DEVIR.md 4.4)', () {
    test('Standart Türkçe bildirim biçimleri virgül ondalık ile tam eşleşir', () {
      expect(
        NotificationFormatter.formatTargetHit(shortSymbol: 'SOL', pct: 3.2, rMultiple: 2.0),
        'SOL hedefe ulaştı · +%3,2 · 2R',
      );
      expect(
        NotificationFormatter.formatWeeklyReportReady(
          hasLastWeek: true,
          lastWeekPct: 4.8,
          newRecommendationsCount: 5,
        ),
        'Pazar raporun hazır · Geçen hafta +%4,8 · 5 yeni öneri',
      );
      expect(
        NotificationFormatter.formatWeeklyReportReady(
          hasLastWeek: false,
          newRecommendationsCount: 3,
        ),
        'Pazar raporun hazır · Geçen hafta: henüz veri yok · 3 yeni öneri',
      );
      expect(
        NotificationFormatter.formatNearStop(
          shortSymbol: 'THYAO',
          stopPrice: 312.40,
          currentPrice: 314.10,
        ),
        'THYAO stop seviyesine yakın · Stop 312,40 · fiyat 314,10',
      );
    });
  });

  group('Faz 4 — Bildirim Koordinatörü: 10 dk birleştirme, sessiz saat, günlük sınır', () {
    test('Aynı varlık için 10 dk içinde gelen bildirimler tek bildirimde birleşir', () async {
      var now = DateTime.utc(2026, 4, 15, 11, 0); // 14:00 TRT (sessiz saat dışı)
      final gateway = MemoryNotificationGateway();
      final coordinator = NotificationCoordinator(gateway: gateway, clock: () => now);
      const settings = AppSettings(quietHoursEnabled: true, quietStartHourTrt: 23, quietEndHourTrt: 8);

      final d1 = await coordinator.dispatch(
        channel: NotificationChannelType.signal,
        title: 'SOLUSDT Yeni Kurulum',
        body: 'Giriş bölgesine ulaştı',
        dedupKey: 'sol_setup_1',
        settings: settings,
        symbol: 'SOLUSDT',
      );
      expect(d1, NotificationDecision.sentImmediately);
      expect(gateway.shown.length, 1);

      // 4 dakika sonra aynı sembol için ikinci bildirim
      now = now.add(const Duration(minutes: 4));
      final d2 = await coordinator.dispatch(
        channel: NotificationChannelType.outcome,
        title: 'SOLUSDT Hedef 1',
        body: 'SOL hedefe ulaştı · +%3,2 · 1R',
        dedupKey: 'sol_t1_1',
        settings: settings,
        symbol: 'SOLUSDT',
      );
      expect(d2, NotificationDecision.coalescedWithRecent);
      expect(gateway.shown.length, 1);
      expect(gateway.shown.first.coalescedCount, 2);
      expect(gateway.shown.first.title, contains('2 güncelleme'));
    });

    test('Aynı dedupKey ile ikinci bildirim düşürülür', () async {
      final now = DateTime.utc(2026, 4, 15, 11, 0);
      final gateway = MemoryNotificationGateway();
      final coordinator = NotificationCoordinator(gateway: gateway, clock: () => now);
      const settings = AppSettings(quietHoursEnabled: false);

      final first = await coordinator.dispatch(
        channel: NotificationChannelType.signal,
        title: 'BTC',
        body: 'Sinyal',
        dedupKey: 'dup_key_1',
        settings: settings,
      );
      final second = await coordinator.dispatch(
        channel: NotificationChannelType.signal,
        title: 'BTC',
        body: 'Sinyal',
        dedupKey: 'dup_key_1',
        settings: settings,
      );
      expect(first, NotificationDecision.sentImmediately);
      expect(second, NotificationDecision.droppedDuplicate);
      expect(gateway.shown.length, 1);
    });

    test('Sessiz saatte bildirimler kuyruğa alınır, sabah tek özet olarak gönderilir', () async {
      // 2026-04-15 21:30 UTC = 00:30 TRT (sessiz saat: 23:00 - 08:00 TRT)
      var now = DateTime.utc(2026, 4, 15, 21, 30);
      final gateway = MemoryNotificationGateway();
      final coordinator = NotificationCoordinator(gateway: gateway, clock: () => now);
      const settings = AppSettings(quietHoursEnabled: true, quietStartHourTrt: 23, quietEndHourTrt: 8);

      final q1 = await coordinator.dispatch(
        channel: NotificationChannelType.signal,
        title: 'SOL Sinyal',
        body: 'SOL kırılım',
        dedupKey: 'night_1',
        settings: settings,
      );
      final q2 = await coordinator.dispatch(
        channel: NotificationChannelType.outcome,
        title: 'BTC Hedef',
        body: 'BTC 1R ulaştı',
        dedupKey: 'night_2',
        settings: settings,
      );
      expect(q1, NotificationDecision.queuedForQuietHours);
      expect(q2, NotificationDecision.queuedForQuietHours);
      expect(gateway.shown, isEmpty);
      expect(coordinator.queuedCount, 2);

      // Sabah 08:15 TRT = 05:15 UTC (sessiz saat bitti)
      now = DateTime.utc(2026, 4, 16, 5, 15);
      final summary = await coordinator.flushQuietHoursSummary(settings);
      expect(summary, isNotNull);
      expect(summary!.title, 'Sessiz saat özeti · 2 bildirim');
      expect(coordinator.queuedCount, 0);
      expect(gateway.shown.length, 1);
    });

    test('Günlük bildirim üst sınırı aşıldığında bildirim düşürülür', () async {
      final now = DateTime.utc(2026, 4, 15, 11, 0);
      final gateway = MemoryNotificationGateway();
      final coordinator = NotificationCoordinator(gateway: gateway, clock: () => now);
      const settings = AppSettings(quietHoursEnabled: false, maxDailyNotifications: 2);

      final r1 = await coordinator.dispatch(
        channel: NotificationChannelType.signal,
        title: '1',
        body: 'B1',
        dedupKey: 'k1',
        settings: settings,
      );
      final r2 = await coordinator.dispatch(
        channel: NotificationChannelType.signal,
        title: '2',
        body: 'B2',
        dedupKey: 'k2',
        settings: settings,
      );
      final r3 = await coordinator.dispatch(
        channel: NotificationChannelType.signal,
        title: '3',
        body: 'B3',
        dedupKey: 'k3',
        settings: settings,
      );
      expect(r1, NotificationDecision.sentImmediately);
      expect(r2, NotificationDecision.sentImmediately);
      expect(r3, NotificationDecision.droppedDailyCap);
    });
  });

  group('Faz 4 — Arka Plan Zamanlayıcısı ve Depolama', () {
    test('Pazar raporu alarmı sonraki Pazar 09:00 TRT (06:00 UTC) olarak hesaplanır', () {
      // 2026-04-15 Çarşamba 12:00 UTC -> sonraki Pazar 2026-04-19 06:00 UTC (09:00 TRT)
      final wed = DateTime.utc(2026, 4, 15, 12, 0);
      final nextSun = BackgroundScheduler.nextSundayReportUtc(wed);
      expect(nextSun, DateTime.utc(2026, 4, 19, 6, 0));

      // Pazar günü 07:00 UTC (10:00 TRT, yani 09:00 TRT geçtikten sonra) -> bir sonraki Pazar
      final sunAfter9 = DateTime.utc(2026, 4, 19, 7, 0);
      final followingSun = BackgroundScheduler.nextSundayReportUtc(sunAfter9);
      expect(followingSun, DateTime.utc(2026, 4, 26, 6, 0));
    });

    test('Depolama paketi JSON dışa/içe aktarım döngüsünü kayıpsız tamamlar', () async {
      final bundle = StorageBundle.inMemory();
      await bundle.settingsStore.save(const AppSettings(budgetAmount: 250000, darkMode: true));
      final exported = await bundle.exportToJson();
      expect(exported, contains('250000'));

      final bundle2 = StorageBundle.inMemory();
      await bundle2.importFromJson(exported);
      final loaded = await bundle2.settingsStore.load();
      expect(loaded.budgetAmount, 250000);
      expect(loaded.darkMode, isTrue);
      expect(loaded.riskAppetite, RiskAppetite.balanced);
    });
  });
}
