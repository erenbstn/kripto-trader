import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pusula_core/pusula_core.dart';

import '../storage/app_settings.dart';

/// Yerel bildirim kanalları (K4, DEVIR.md Faz 4.4).
enum NotificationChannelType {
  signal('pusula_signal', 'Sinyal', 'Yeni teknik kurulum ve giriş bölgesi bildirimleri', true),
  outcome('pusula_outcome', 'Sonuç', 'Hedef, stop, başabaş ve stopa yakınlık bildirimleri', true),
  report('pusula_report', 'Rapor', 'Pazar günü haftalık rapor bildirimleri', false),
  system('pusula_system', 'Sistem', 'Veri kaynağı ve canlı izleme durum bildirimleri', false);

  const NotificationChannelType(this.id, this.label, this.description, this.highPriority);

  final String id;
  final String label;
  final String description;
  final bool highPriority;
}

/// Bildirim koordinatörünün bir olay için verdiği karar.
enum NotificationDecision {
  sentImmediately,
  coalescedWithRecent,
  queuedForQuietHours,
  droppedDuplicate,
  droppedChannelDisabled,
  droppedDailyCap,
}

/// Gönderilen veya kuyruğa alınan yerel bildirim kaydı.
class LocalNotificationItem {
  const LocalNotificationItem({
    required this.id,
    required this.channel,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.dedupKey,
    this.symbol,
    this.coalescedCount = 1,
  });

  final int id;
  final NotificationChannelType channel;
  final String title;
  final String body;
  final DateTime createdAt;
  final String dedupKey;
  final String? symbol;
  final int coalescedCount;

  LocalNotificationItem copyWith({String? title, String? body, DateTime? createdAt, int? coalescedCount}) =>
      LocalNotificationItem(
        id: id,
        channel: channel,
        title: title ?? this.title,
        body: body ?? this.body,
        createdAt: createdAt ?? this.createdAt,
        dedupKey: dedupKey,
        symbol: symbol,
        coalescedCount: coalescedCount ?? this.coalescedCount,
      );
}

/// Standart Türkçe bildirim metin biçimlendiricileri (DEVIR.md Faz 4.4).
class NotificationFormatter {
  const NotificationFormatter._();

  static String _trNum(double v, {int decimals = 1, bool trimTrailingZero = true}) {
    var s = v.toStringAsFixed(decimals);
    if (trimTrailingZero && s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    return s.replaceAll('.', ',');
  }

  /// Örnek: `"SOL hedefe ulaştı · +%3,2 · 2R"`
  static String formatTargetHit({
    required String shortSymbol,
    required double pct,
    required double rMultiple,
  }) {
    final sign = pct >= 0 ? '+' : '';
    final pctStr = _trNum(pct, decimals: 1, trimTrailingZero: false);
    final rStr = _trNum(rMultiple, decimals: 1, trimTrailingZero: true);
    return '$shortSymbol hedefe ulaştı · $sign%$pctStr · ${rStr}R';
  }

  /// Örnek: `"Pazar raporun hazır · Geçen hafta +%4,8 · 5 yeni öneri"`
  static String formatWeeklyReportReady({
    required bool hasLastWeek,
    double? lastWeekPct,
    required int newRecommendationsCount,
  }) {
    final recPart = newRecommendationsCount == 0
        ? 'Bu hafta net fırsat yok'
        : '$newRecommendationsCount yeni öneri';
    if (!hasLastWeek || lastWeekPct == null) {
      return 'Pazar raporun hazır · Geçen hafta: henüz veri yok · $recPart';
    }
    final sign = lastWeekPct >= 0 ? '+' : '';
    final pctStr = _trNum(lastWeekPct, decimals: 1, trimTrailingZero: false);
    return 'Pazar raporun hazır · Geçen hafta $sign%$pctStr · $recPart';
  }

  /// Örnek: `"THYAO stop seviyesine yakın · Stop 312,40 · fiyat 314,10"`
  static String formatNearStop({
    required String shortSymbol,
    required double stopPrice,
    required double currentPrice,
    int decimals = 2,
  }) {
    final stopStr = _trNum(stopPrice, decimals: decimals, trimTrailingZero: false);
    final curStr = _trNum(currentPrice, decimals: decimals, trimTrailingZero: false);
    return '$shortSymbol stop seviyesine yakın · Stop $stopStr · fiyat $curStr';
  }
}

/// İşletim sistemi bildirim katmanı soyutlaması.
abstract class LocalNotificationGateway {
  Future<void> initialize();
  Future<void> show(LocalNotificationItem item);
}

/// Testlerde ve Web önizlemesinde kullanılan bellek içi bildirim kapısı.
class MemoryNotificationGateway implements LocalNotificationGateway {
  final List<LocalNotificationItem> shown = [];

  @override
  Future<void> initialize() async {}

  @override
  Future<void> show(LocalNotificationItem item) async {
    final existingIdx = shown.indexWhere((e) => e.id == item.id);
    if (existingIdx >= 0) {
      shown[existingIdx] = item;
    } else {
      shown.insert(0, item);
    }
  }
}

/// Android yerel `NotificationManager` tabanlı gerçek cihaz bildirim kapısı.
/// Hiçbir dış mesajlaşma servisine bağlanmaz; yalnızca yerel işletim sistemi bildirimi üretir.
class FlutterLocalNotificationGateway implements LocalNotificationGateway {
  FlutterLocalNotificationGateway();

  static const MethodChannel _channel = MethodChannel('app.pusula/background');
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized || kIsWeb) {
      _initialized = true;
      return;
    }
    try {
      await _channel.invokeMethod<void>('initNotificationChannels');
      _initialized = true;
    } catch (_) {
      // Cihazsız ortamda veya izin reddedildiğinde çökmez
    }
  }

  @override
  Future<void> show(LocalNotificationItem item) async {
    if (kIsWeb) return;
    if (!_initialized) await initialize();
    try {
      await _channel.invokeMethod<void>('showLocalNotification', {
        'id': item.id,
        'channelId': item.channel.id,
        'title': item.title,
        'body': item.body,
        'highPriority': item.channel.highPriority,
      });
    } catch (_) {}
  }
}

/// Bildirim birleştirme (10 dk), sessiz saat kuyruğu, günlük üst sınır ve tekrar anahtarı motoru.
class NotificationCoordinator {
  NotificationCoordinator({
    required this.gateway,
    this.coalesceWindow = const Duration(minutes: 10),
    Clock? clock,
  }) : _clock = clock ?? systemClock;

  final LocalNotificationGateway gateway;
  final Duration coalesceWindow;
  final Clock _clock;

  int _nextId = 1000;
  final Set<String> _seenDedupKeys = {};
  final Map<String, LocalNotificationItem> _recentBySymbol = {};
  final List<LocalNotificationItem> _quietQueue = [];
  final List<LocalNotificationItem> _history = [];
  final Map<int, int> _dailyCountsByTrtDay = {};

  /// Uygulama içi Özet ekranında gösterilen son bildirimler.
  List<LocalNotificationItem> get recentNotifications => List.unmodifiable(_history);

  /// Sessiz saat kuyruğunda bekleyen bildirim sayısı.
  int get queuedCount => _quietQueue.length;

  /// Verilen an Türkiye saatine göre sessiz saat aralığında mı?
  static bool isQuietTime(DateTime utcNow, AppSettings settings) {
    if (!settings.quietHoursEnabled) return false;
    final trt = BistCalendar.toTrt(utcNow);
    final h = trt.hour;
    final start = settings.quietStartHourTrt;
    final end = settings.quietEndHourTrt;
    if (start == end) return false;
    if (start > end) {
      // Örn: 23:00 -> 08:00 (gece yarısını aşan aralık)
      return h >= start || h < end;
    }
    return h >= start && h < end;
  }

  static bool _isChannelEnabled(NotificationChannelType ch, AppSettings s) {
    switch (ch) {
      case NotificationChannelType.signal:
        return s.notifySignal;
      case NotificationChannelType.outcome:
        return s.notifyOutcome;
      case NotificationChannelType.report:
        return s.notifyReport;
      case NotificationChannelType.system:
        return s.notifySystem;
    }
  }

  static int _trtDayKey(DateTime utcNow) {
    final trt = BistCalendar.toTrt(utcNow);
    return trt.year * 10000 + trt.month * 100 + trt.day;
  }

  /// Yeni bir yerel bildirimi kurallardan geçirerek gönderir, birleştirir veya kuyruğa alır.
  Future<NotificationDecision> dispatch({
    required NotificationChannelType channel,
    required String title,
    required String body,
    required String dedupKey,
    required AppSettings settings,
    String? symbol,
  }) async {
    if (!_isChannelEnabled(channel, settings)) {
      return NotificationDecision.droppedChannelDisabled;
    }
    if (_seenDedupKeys.contains(dedupKey)) {
      return NotificationDecision.droppedDuplicate;
    }
    _seenDedupKeys.add(dedupKey);

    final now = _clock().toUtc();

    // Sessiz saat kontrolü: kuyruğa al ve sessiz saat sonunda tek özet olarak gönder
    if (isQuietTime(now, settings)) {
      _quietQueue.add(LocalNotificationItem(
        id: _nextId++,
        channel: channel,
        title: title,
        body: body,
        createdAt: now,
        dedupKey: dedupKey,
        symbol: symbol,
      ));
      return NotificationDecision.queuedForQuietHours;
    }

    // 10 dk içinde aynı varlık için birleştirme (coalescing)
    if (symbol != null && symbol.isNotEmpty) {
      final prev = _recentBySymbol[symbol];
      if (prev != null && now.difference(prev.createdAt) <= coalesceWindow) {
        final mergedCount = prev.coalescedCount + 1;
        final mergedBody = '${prev.body} · $body';
        final updated = prev.copyWith(
          title: '$symbol ($mergedCount güncelleme)',
          body: mergedBody,
          createdAt: now,
          coalescedCount: mergedCount,
        );
        _recentBySymbol[symbol] = updated;
        _upsertHistory(updated);
        await gateway.show(updated);
        return NotificationDecision.coalescedWithRecent;
      }
    }

    // Günlük üst sınır kontrolü
    final dayKey = _trtDayKey(now);
    final sentToday = _dailyCountsByTrtDay[dayKey] ?? 0;
    if (sentToday >= settings.maxDailyNotifications) {
      return NotificationDecision.droppedDailyCap;
    }
    _dailyCountsByTrtDay[dayKey] = sentToday + 1;

    final item = LocalNotificationItem(
      id: _nextId++,
      channel: channel,
      title: title,
      body: body,
      createdAt: now,
      dedupKey: dedupKey,
      symbol: symbol,
    );
    if (symbol != null && symbol.isNotEmpty) {
      _recentBySymbol[symbol] = item;
    }
    _upsertHistory(item);
    await gateway.show(item);
    return NotificationDecision.sentImmediately;
  }

  /// Sessiz saat bittiğinde kuyruktaki bildirimleri tek bir özet bildirimde birleştirip gönderir.
  Future<LocalNotificationItem?> flushQuietHoursSummary(AppSettings settings) async {
    if (_quietQueue.isEmpty) return null;
    final now = _clock().toUtc();
    if (isQuietTime(now, settings)) return null;

    final items = List<LocalNotificationItem>.from(_quietQueue);
    _quietQueue.clear();

    final bodies = [for (final it in items.take(4)) it.body];
    final more = items.length > 4 ? ' (+${items.length - 4} olay daha)' : '';
    final summaryItem = LocalNotificationItem(
      id: _nextId++,
      channel: NotificationChannelType.system,
      title: 'Sessiz saat özeti · ${items.length} bildirim',
      body: '${bodies.join(' | ')}$more',
      createdAt: now,
      dedupKey: 'quiet_summary_${now.millisecondsSinceEpoch}',
      coalescedCount: items.length,
    );

    final dayKey = _trtDayKey(now);
    _dailyCountsByTrtDay[dayKey] = (_dailyCountsByTrtDay[dayKey] ?? 0) + 1;

    _upsertHistory(summaryItem);
    await gateway.show(summaryItem);
    return summaryItem;
  }

  void _upsertHistory(LocalNotificationItem item) {
    final idx = _history.indexWhere((e) => e.id == item.id);
    if (idx >= 0) {
      _history[idx] = item;
    } else {
      _history.insert(0, item);
      if (_history.length > 50) {
        _history.removeLast();
      }
    }
  }
}

