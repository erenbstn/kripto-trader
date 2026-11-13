import 'package:pusula_core/pusula_core.dart';

import '../background/background_scheduler.dart';
import '../notifications/notification_engine.dart';
import '../storage/app_settings.dart';
import '../storage/sqlite_storage.dart';
import 'live_data.dart';

/// Tek bir tarama turunun uygulama katmanı çıktısı (ekran durumu bundan beslenir).
class ScanRunResult {
  const ScanRunResult({
    required this.outcome,
    required this.report,
    required this.archive,
    required this.curve,
    required this.allSignals,
    required this.activeSignals,
    required this.proposal,
    required this.cryptoQuotes,
    required this.bistQuotes,
    required this.health,
  });

  final ScanOutcome outcome;
  final WeeklyReport report;
  final List<WeeklyReport> archive;
  final List<PerformanceCurvePoint> curve;
  final List<SignalRecord> allSignals;
  final List<SignalRecord> activeSignals;
  final StrategyOptimizationProposal proposal;
  final List<LiveMarketQuote> cryptoQuotes;
  final List<LiveMarketQuote> bistQuotes;
  final List<ProviderHealth> health;
}

/// Canlı veriyi çekip analiz hunisini koşturan, sonucu günlüğe/rapora işleyen ve yerel bildirimleri
/// üreten ortak akış. Hem ön plandaki [PusulaController] hem de arka plan (WorkManager) girişi kullanır.
///
/// Emir açmaz, anahtar kullanmaz, dış mesajlaşma servisine bağlanmaz; bütçe tutarını loglamaz.
class ScanRunner {
  ScanRunner({
    required this.storage,
    required this.coordinator,
    required this.versionStore,
    required Clock clock,
    this.dataServiceFactory,
  // ignore: prefer_initializing_formals
  }) : _clock = clock;

  final StorageBundle storage;
  final NotificationCoordinator coordinator;
  final StrategyVersionStore versionStore;
  final Clock _clock;

  /// Testte sahte sağlayıcılı servis enjekte etmek için; verilmezse gerçek ağ sağlayıcıları kurulur.
  final MarketDataService Function()? dataServiceFactory;

  /// İçinde bulunulan rapor haftasının başlangıcı: en son Pazar 09:00 TRT (06:00 UTC).
  static DateTime weekStartUtc(DateTime now) =>
      BackgroundScheduler.nextSundayReportUtc(now.toUtc()).subtract(const Duration(days: 7));

  static String reportIdFor(DateTime weekStart) =>
      'weekly_${weekStart.year}${weekStart.month.toString().padLeft(2, '0')}${weekStart.day.toString().padLeft(2, '0')}';

  Future<ScanRunResult> run({
    required AppSettings settings,
    bool forceRefresh = false,
    bool headless = false,
    void Function(int done, int total)? onProgress,
  }) async {
    PusulaHttpFetcher? fetcher;
    final MarketDataService data;
    if (dataServiceFactory != null) {
      data = dataServiceFactory!();
    } else {
      fetcher = PusulaHttpFetcher();
      data = MarketDataService(
        providers: [BinanceProvider(fetcher), YahooProvider(fetcher), IsYatirimProvider(fetcher)],
        cache: storage.candleCache,
        clock: _clock,
      );
    }

    try {
      final scanner = MarketScanner(data: data, journal: storage.journalStore, clock: _clock);
      final outcome = await scanner.scan(
        [MarketScanPlan.crypto(), MarketScanPlan.bist(kWatchedBistStocks)],
        forceRefresh: forceRefresh,
        onProgress: onProgress,
      );

      final now = _clock().toUtc();
      final cryptoQuotes = _cryptoQuotes(outcome, now);
      final bistQuotes = _bistQuotes(outcome, now);

      // Haftalık rapor: bu haftanın kimliğiyle yerinde güncellenir; geçen haftanın karnesi yalnızca
      // o hafta önerilmiş ve ileriye dönük izlenmiş kayıtlardan hesaplanır.
      final weekStart = weekStartUtc(now);
      final reportId = reportIdFor(weekStart);
      final hadReport = (await storage.reportStore.allReports()).any((r) => r.id == reportId);
      final activeBefore = await storage.journalStore.activeSignals();
      final generator = WeeklyReportGenerator(
        journalStore: storage.journalStore,
        reportStore: storage.reportStore,
        clock: _clock,
      );
      final report = await generator.generate(
        newCandidates: [for (final s in activeBefore) if (s.isWeeklyProposal) s],
        appetite: settings.riskAppetite,
        totalBudget: settings.budgetAmount,
        currentPrices: {
          for (final q in [...cryptoQuotes, ...bistQuotes]) q.instrument: q.lastPrice,
        },
        reportId: reportId,
        reviewFrom: weekStart.subtract(const Duration(days: 7)),
        reviewUntil: weekStart,
      );

      final allSignals = await storage.journalStore.allSignals();
      final activeSignals = await storage.journalStore.activeSignals();
      final archive = await storage.reportStore.allReports();
      final proposal = await StrategyOptimizer(
        journalStore: storage.journalStore,
        versionStore: versionStore,
        clock: _clock,
      ).evaluate();

      await _notify(outcome, report, settings, headless: headless, isNewWeeklyReport: !hadReport, now: now);

      return ScanRunResult(
        outcome: outcome,
        report: report,
        archive: archive,
        curve: performanceCurveFrom(archive),
        allSignals: allSignals,
        activeSignals: activeSignals,
        proposal: proposal,
        cryptoQuotes: cryptoQuotes,
        bistQuotes: bistQuotes,
        health: data.health,
      );
    } finally {
      fetcher?.close();
    }
  }

  List<LiveMarketQuote> _cryptoQuotes(ScanOutcome outcome, DateTime now) {
    final out = <LiveMarketQuote>[];
    for (final ins in CryptoUniverse.instruments) {
      final s = outcome.seriesFor(ins, BarInterval.h1);
      if (s == null || s.closed.isEmpty) continue;
      // 24 saat önceki kapanışa göre değişim (yeterli mum yoksa eldeki en eski mum).
      final c = s.closed;
      final ref = c.length > 24 ? c[c.length - 25].close : c.first.close;
      out.add(LiveMarketQuote(
        instrument: ins,
        lastPrice: s.lastPrice,
        changePct: ref > 0 ? (s.lastPrice / ref - 1.0) * 100.0 : 0.0,
        sourceLabel: s.source == 'binance_futures'
            ? 'Binance Futures'
            : (s.source == 'yahoo' ? 'Yahoo Finance' : 'Binance Spot'),
        ageMinutes: s.ageAt(now).inMinutes.clamp(0, 99999),
        isStale: s.stale,
      ));
    }
    return out;
  }

  List<LiveMarketQuote> _bistQuotes(ScanOutcome outcome, DateTime now) {
    final out = <LiveMarketQuote>[];
    for (final ins in [BistUniverse.benchmark, ...kWatchedBistStocks]) {
      final s = outcome.seriesFor(ins, BarInterval.d1);
      if (s == null || s.closed.isEmpty) continue;
      final c = s.closed;
      // Gün içi fiyat varsa son kapanmış güne, yoksa bir önceki güne göre değişim.
      final hasIntraday = s.forming != null;
      final ref = hasIntraday ? c.last.close : (c.length >= 2 ? c[c.length - 2].close : c.last.close);
      out.add(LiveMarketQuote(
        instrument: ins,
        lastPrice: s.lastPrice,
        changePct: ref > 0 ? (s.lastPrice / ref - 1.0) * 100.0 : 0.0,
        sourceLabel: s.source == 'isyatirim' ? 'İş Yatırım (gün sonu)' : 'Yahoo Finance',
        ageMinutes: s.ageAt(now).inMinutes.clamp(0, 99999),
        isStale: s.stale,
      ));
    }
    return out;
  }

  static String _fmt(double v, Market m) {
    final d = m == Market.bist ? 2 : (v >= 100 ? 2 : (v >= 1 ? 3 : 5));
    return v.toStringAsFixed(d).replaceAll('.', ',');
  }

  Future<void> _notify(
    ScanOutcome outcome,
    WeeklyReport report,
    AppSettings settings, {
    required bool headless,
    required bool isNewWeeklyReport,
    required DateTime now,
  }) async {
    // Arka plan izolatı her çalışmada sıfırdan başlar; sessiz saat kuyruğu bellekte kaybolurdu.
    // Bu yüzden arka planda sessiz saatte bildirim düşürülmez: sessiz "Sistem" kanalına yönlendirilir.
    final quietHeadless = headless && NotificationCoordinator.isQuietTime(now, settings);
    final effSettings = quietHeadless ? settings.copyWith(quietHoursEnabled: false) : settings;
    NotificationChannelType ch(NotificationChannelType wanted) =>
        quietHeadless ? NotificationChannelType.system : wanted;

    for (final e in outcome.transitions) {
      final wanted = settings.notifyOutcome;
      if (!wanted) continue;
      await coordinator.dispatch(
        channel: ch(NotificationChannelType.outcome),
        title: '${e.signal.instrument.short} · ${_statusTitle(e.newStatus)}',
        body: e.message.replaceAll('.', ','),
        dedupKey: '${e.signal.id}_${e.newStatus.name}',
        settings: effSettings,
        symbol: e.signal.instrument.symbol,
      );
    }

    for (final s in outcome.newSignals) {
      if (!settings.notifySignal) continue;
      final m = s.instrument.market;
      final delay = m == Market.bist ? ' · veri ~15 dk gecikmeli' : '';
      await coordinator.dispatch(
        channel: ch(NotificationChannelType.signal),
        title: '${s.instrument.short} yeni kurulum · ${s.strategy.label}',
        body: 'Giriş bölgesi ${_fmt(s.entryZoneLow, m)} – ${_fmt(s.entryZoneHigh, m)} · '
            'Stop ${_fmt(s.initialStop, m)} · Hedef ${_fmt(s.target2, m)} · Güven ${s.confidence.total}/100$delay',
        dedupKey: 'sig_new_${s.id}',
        settings: effSettings,
        symbol: s.instrument.symbol,
      );
    }

    if (isNewWeeklyReport && settings.notifyReport) {
      await coordinator.dispatch(
        channel: ch(NotificationChannelType.report),
        title: 'Haftalık Pusula raporu',
        body: report.notificationSummary,
        dedupKey: 'report_${report.id}',
        settings: effSettings,
      );
    }
  }

  static String _statusTitle(SignalStatus s) {
    switch (s) {
      case SignalStatus.target1:
        return '1. hedef görüldü';
      case SignalStatus.target2:
        return 'Ana hedefe ulaştı';
      case SignalStatus.stop:
        return 'Stop oldu';
      case SignalStatus.expired:
        return 'Süre doldu';
      case SignalStatus.invalidated:
        return 'Geçersiz';
      case SignalStatus.open:
        return 'Açık';
    }
  }
}
