import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pusula_core/pusula_core.dart';

import '../background/background_scheduler.dart';
import '../notifications/notification_engine.dart';
import '../storage/app_settings.dart';
import '../storage/sqlite_storage.dart';
import '../theme/gunduz_theme.dart';
import '../widgets/donut_3d_chart.dart';

/// Uygulamanın tüm ekranlarını besleyen birleşik durum nesnesi.
class PusulaAppState {
  const PusulaAppState({
    required this.settings,
    required this.currentReport,
    required this.archivedReports,
    required this.performanceCurve,
    required this.activeSignals,
    required this.allSignals,
    required this.recentNotifications,
    required this.providerHealthList,
    required this.scheduleSnapshot,
    required this.isLoading,
    this.statusMessage,
  });

  final AppSettings settings;
  final WeeklyReport currentReport;
  final List<WeeklyReport> archivedReports;
  final List<PerformanceCurvePoint> performanceCurve;
  final List<SignalRecord> activeSignals;
  final List<SignalRecord> allSignals;
  final List<LocalNotificationItem> recentNotifications;
  final List<ProviderHealth> providerHealthList;
  final BackgroundScheduleSnapshot scheduleSnapshot;
  final bool isLoading;
  final String? statusMessage;

  /// 3D / 2D halka grafik için bütçe dilimlerini üretir.
  List<DonutSliceData> get donutSlices {
    const bistPalette = [
      GunduzColors.accent,
      GunduzColors.accentDark,
      Color(0xFF4F6BED),
      Color(0xFF2E5AAC),
    ];
    const cryptoPalette = [
      GunduzColors.coral,
      Color(0xFFE07A5F),
      Color(0xFFC85A32),
      Color(0xFFB54824),
    ];

    final alloc = currentReport.newAllocation;
    final slices = <DonutSliceData>[];
    var bIdx = 0;
    for (final rec in alloc.bistRecommendations) {
      slices.add(
        DonutSliceData(
          id: 'bist_${rec.instrument.symbol}',
          label: rec.instrument.symbol,
          categoryLabel: 'BIST',
          weightPct: rec.weightPct,
          color: bistPalette[bIdx % bistPalette.length],
          subtitle: '${rec.signal.strategy.label} · Güven ${rec.confidence.total}/100',
          recommendation: rec,
        ),
      );
      bIdx++;
    }
    var cIdx = 0;
    for (final rec in alloc.cryptoRecommendations) {
      slices.add(
        DonutSliceData(
          id: 'crypto_${rec.instrument.symbol}',
          label: rec.instrument.short,
          categoryLabel: 'Kripto',
          weightPct: rec.weightPct,
          color: cryptoPalette[cIdx % cryptoPalette.length],
          subtitle: '${rec.signal.strategy.label} · Güven ${rec.confidence.total}/100',
          recommendation: rec,
        ),
      );
      cIdx++;
    }

    slices.add(
      DonutSliceData(
        id: 'cash',
        label: 'Nakit',
        categoryLabel: 'Koruma',
        weightPct: alloc.cashWeightPct,
        color: const Color(0xFF8C8A82),
        subtitle: 'Fırsat ve risk tamponu (%${alloc.cashWeightPct.toStringAsFixed(1).replaceAll('.', ',')})',
      ),
    );
    return slices;
  }

  PusulaAppState copyWith({
    AppSettings? settings,
    WeeklyReport? currentReport,
    List<WeeklyReport>? archivedReports,
    List<PerformanceCurvePoint>? performanceCurve,
    List<SignalRecord>? activeSignals,
    List<SignalRecord>? allSignals,
    List<LocalNotificationItem>? recentNotifications,
    List<ProviderHealth>? providerHealthList,
    BackgroundScheduleSnapshot? scheduleSnapshot,
    bool? isLoading,
    String? statusMessage,
  }) =>
      PusulaAppState(
        settings: settings ?? this.settings,
        currentReport: currentReport ?? this.currentReport,
        archivedReports: archivedReports ?? this.archivedReports,
        performanceCurve: performanceCurve ?? this.performanceCurve,
        activeSignals: activeSignals ?? this.activeSignals,
        allSignals: allSignals ?? this.allSignals,
        recentNotifications: recentNotifications ?? this.recentNotifications,
        providerHealthList: providerHealthList ?? this.providerHealthList,
        scheduleSnapshot: scheduleSnapshot ?? this.scheduleSnapshot,
        isLoading: isLoading ?? this.isLoading,
        statusMessage: statusMessage,
      );
}

final storageBundleProvider = Provider<StorageBundle>((ref) {
  return StorageBundle.inMemory();
});

final notificationGatewayProvider = Provider<LocalNotificationGateway>((ref) {
  return MemoryNotificationGateway();
});

final pusulaControllerProvider = StateNotifierProvider<PusulaController, PusulaAppState>((ref) {
  final storage = ref.watch(storageBundleProvider);
  final gateway = ref.watch(notificationGatewayProvider);
  return PusulaController(storage: storage, notificationGateway: gateway);
});

class PusulaController extends StateNotifier<PusulaAppState> {
  PusulaController({
    required this.storage,
    required LocalNotificationGateway notificationGateway,
    Clock? clock,
  })  : _notificationCoordinator = NotificationCoordinator(
          gateway: notificationGateway,
          clock: clock ?? (() => DateTime.utc(2026, 4, 19, 9, 0)),
        ),
        _scheduler = BackgroundScheduler(
          clock: clock ?? (() => DateTime.utc(2026, 4, 19, 9, 0)),
        ),
        super(_buildInitialSeedState(clock ?? (() => DateTime.utc(2026, 4, 19, 9, 0)))) {
    _hydrateFromStorage();
  }

  final StorageBundle storage;
  final NotificationCoordinator _notificationCoordinator;
  final BackgroundScheduler _scheduler;

  static SignalRecord _makeSeedSignal({
    required String id,
    required Instrument instrument,
    required BarInterval interval,
    required SetupType strategy,
    required String rationale,
    required double entryZoneLow,
    required double entryZoneHigh,
    required double entryPrice,
    required double stopPrice,
    required double target1,
    required double target2,
    required double rewardRisk,
    required int confidenceTotal,
    required String dataSource,
    required int dataAgeMinutes,
    required DateTime createdAt,
    SignalStatus status = SignalStatus.open,
    double? realizedR,
    double? realizedPct,
    DateTime? closedAt,
    bool isWeeklyProposal = false,
    double? allocatedWeightPct,
  }) {
    final rrScore = (confidenceTotal - 70).clamp(5, 15);
    return SignalRecord(
      id: id,
      instrument: instrument,
      interval: interval,
      strategy: strategy,
      allSetups: [strategy],
      strategyVersion: '2.0.0',
      entryZoneLow: entryZoneLow,
      entryZoneHigh: entryZoneHigh,
      entryPrice: entryPrice,
      initialStop: stopPrice,
      currentStop: status == SignalStatus.target1 ? entryPrice : stopPrice,
      target1: target1,
      target2: target2,
      rewardRisk: rewardRisk,
      confidence: ConfidenceBreakdown(
        setupConfluence: 20,
        volumeConfirmation: 12,
        regimeAlignment: 13,
        higherTimeframeAlignment: 13,
        monteCarloScore: 12,
        rewardRiskScore: rrScore,
        reasons: const [
          'Kapanmış mum teyitli kurulum',
          'Üst zaman dilimi EMA50 üzerinde',
          'Monte Carlo ort. +0,58R (%95 GA: [+0,44R, +0,72R])',
        ],
      ),
      rationale: rationale,
      invalidationRule: '${stopPrice.toStringAsFixed(2).replaceAll('.', ',')} altı kapanış kurulumu geçersiz kılar.',
      regime: MarketRegime.bull,
      dataSource: dataSource,
      dataAgeMs: dataAgeMinutes * 60 * 1000,
      dataStale: false,
      createdAt: createdAt,
      expiresAt: createdAt.add(instrument.market == Market.bist ? const Duration(days: 5) : const Duration(hours: 12)),
      status: status,
      realizedR: realizedR,
      realizedPct: realizedPct,
      closedAt: closedAt,
      isWeeklyProposal: isWeeklyProposal,
      allocatedWeightPct: allocatedWeightPct,
    );
  }

  static PusulaAppState _buildInitialSeedState(Clock clock) {
    final now = clock().toUtc();
    const settings = AppSettings();

    const thyao = Instrument.bist('THYAO', name: 'Türk Hava Yolları');
    const asels = Instrument.bist('ASELS', name: 'Aselsan');
    const akbnk = Instrument.bist('AKBNK', name: 'Akbank');
    const sol = Instrument.crypto('SOLUSDT', name: 'Solana');
    const btc = Instrument.crypto('BTCUSDT', name: 'Bitcoin');
    const link = Instrument.crypto('LINKUSDT', name: 'Chainlink');

    final sThyao = _makeSeedSignal(
      id: 'sig_thyao_w1',
      instrument: thyao,
      interval: BarInterval.d1,
      strategy: SetupType.breakout20,
      rationale: '20 günlük direnç hacim artışıyla (+%42) kırıldı; XU100 boğa rejiminde.',
      entryZoneLow: 318.00,
      entryZoneHigh: 320.50,
      entryPrice: 319.25,
      stopPrice: 306.50,
      target1: 332.00,
      target2: 344.75,
      rewardRisk: 2.0,
      confidenceTotal: 84,
      dataSource: 'Yahoo Finance',
      dataAgeMinutes: 15,
      createdAt: now.subtract(const Duration(hours: 2)),
    );

    final sAsels = _makeSeedSignal(
      id: 'sig_asels_w1',
      instrument: asels,
      interval: BarInterval.h1,
      strategy: SetupType.bullFlag,
      rationale: 'Güçlü yükseliş direği sonrası daralan bayrak üst bandı kapanmış mumla geçildi.',
      entryZoneLow: 92.40,
      entryZoneHigh: 93.10,
      entryPrice: 92.75,
      stopPrice: 89.05,
      target1: 96.45,
      target2: 100.15,
      rewardRisk: 2.0,
      confidenceTotal: 80,
      dataSource: 'Yahoo Finance',
      dataAgeMinutes: 15,
      createdAt: now.subtract(const Duration(hours: 3)),
    );

    final sSol = _makeSeedSignal(
      id: 'sig_sol_w1',
      instrument: sol,
      interval: BarInterval.h1,
      strategy: SetupType.reclaimMa20,
      rationale: '4 saatlik yükseliş trendinde saatlik MA20 alıcı baskısıyla (%59) geri kazanıldı.',
      entryZoneLow: 148.20,
      entryZoneHigh: 149.40,
      entryPrice: 148.80,
      stopPrice: 142.85,
      target1: 154.75,
      target2: 160.70,
      rewardRisk: 2.0,
      confidenceTotal: 82,
      dataSource: 'Binance Spot',
      dataAgeMinutes: 1,
      createdAt: now.subtract(const Duration(minutes: 45)),
    );

    final sBtc = _makeSeedSignal(
      id: 'sig_btc_w1',
      instrument: btc,
      interval: BarInterval.h1,
      strategy: SetupType.vwapBreakout,
      rationale: 'Seans VWAP seviyesi kurumsal hacimle kırıldı; fonlama oranı nötr (%0,01).',
      entryZoneLow: 86200.0,
      entryZoneHigh: 86600.0,
      entryPrice: 86400.0,
      stopPrice: 83800.0,
      target1: 89000.0,
      target2: 91600.0,
      rewardRisk: 2.0,
      confidenceTotal: 78,
      dataSource: 'Binance Spot',
      dataAgeMinutes: 1,
      createdAt: now.subtract(const Duration(hours: 1)),
    );

    final sLinkClosed = _makeSeedSignal(
      id: 'sig_link_closed',
      instrument: link,
      interval: BarInterval.m15,
      strategy: SetupType.orb,
      rationale: 'Açılış aralığı üst bandı hacimli geçildi.',
      entryZoneLow: 16.10,
      entryZoneHigh: 16.25,
      entryPrice: 16.18,
      stopPrice: 15.70,
      target1: 16.66,
      target2: 17.14,
      rewardRisk: 2.0,
      confidenceTotal: 77,
      dataSource: 'Binance Spot',
      dataAgeMinutes: 1,
      createdAt: now.subtract(const Duration(days: 2)),
      status: SignalStatus.target2,
      realizedR: 2.0,
      realizedPct: 5.93,
      closedAt: now.subtract(const Duration(days: 1, hours: 18)),
    );

    final sAkbnkClosed = _makeSeedSignal(
      id: 'sig_akbnk_closed',
      instrument: akbnk,
      interval: BarInterval.h1,
      strategy: SetupType.reclaimMa20,
      rationale: 'Saatlik MA20 üzerinde kapanış teyidi.',
      entryZoneLow: 64.10,
      entryZoneHigh: 64.40,
      entryPrice: 64.25,
      stopPrice: 62.50,
      target1: 66.00,
      target2: 67.75,
      rewardRisk: 2.0,
      confidenceTotal: 74,
      dataSource: 'Yahoo Finance',
      dataAgeMinutes: 15,
      createdAt: now.subtract(const Duration(days: 3)),
      status: SignalStatus.target1,
      realizedR: 0.5,
      realizedPct: 1.36,
      closedAt: now.subtract(const Duration(days: 2, hours: 4)),
    );

    const allocator = PortfolioWeightAllocator();
    final allocation = allocator.allocate(
      [sThyao, sAsels, sSol, sBtc],
      appetite: settings.riskAppetite,
      totalBudget: settings.budgetAmount,
    );

    final allSigs = [sSol, sBtc, sThyao, sAsels, sLinkClosed, sAkbnkClosed];
    final activeSigs = allSigs.where((s) => s.isActive).toList();

    final shortTerm = ShortTermWeeklyReport(
      crypto: ShortTermMarketSummary(
        market: Market.crypto,
        hasData: true,
        totalSignals: 3,
        closedSignals: 1,
        openSignals: 2,
        totalReturnPct: 5.93,
        winRatePct: 100.0,
        avgR: 2.0,
        bestSignalSummary: 'LINK (Açılış Aralığı Kırılımı (ORB)): +%5,93 (+2,00R)',
        worstSignalSummary: 'LINK (Açılış Aralığı Kırılımı (ORB)): +%5,93 (+2,00R)',
        byStrategy: const [
          StrategyBreakdownItem(
            strategyCode: 'orb',
            strategyLabel: 'Açılış Aralığı Kırılımı (ORB)',
            signalCount: 1,
            closedCount: 1,
            winRatePct: 100.0,
            avgR: 2.0,
            totalReturnPct: 5.93,
          ),
        ],
      ),
      bist: ShortTermMarketSummary(
        market: Market.bist,
        hasData: true,
        totalSignals: 3,
        closedSignals: 1,
        openSignals: 2,
        totalReturnPct: 1.36,
        winRatePct: 100.0,
        avgR: 0.5,
        bestSignalSummary: 'AKBNK (MA20 Ortalamasını Geri Kazanım): +%1,36 (+0,50R)',
        worstSignalSummary: 'AKBNK (MA20 Ortalamasını Geri Kazanım): +%1,36 (+0,50R)',
        byStrategy: const [
          StrategyBreakdownItem(
            strategyCode: 'reclaim_ma20',
            strategyLabel: 'MA20 Ortalamasını Geri Kazanım',
            signalCount: 1,
            closedCount: 1,
            winRatePct: 100.0,
            avgR: 0.5,
            totalReturnPct: 1.36,
          ),
        ],
      ),
    );

    // Kısıt 2: İlk haftada geçmişten sahte haftalık rapor üretilmez;
    // "Geçen hafta raporu: henüz veri yok" açıkça gösterilir.
    final initialReport = WeeklyReport(
      id: 'report_2026_04_19',
      weekStart: now.subtract(const Duration(days: 7)),
      weekEnd: now,
      generatedAt: now,
      lastWeekReview: const LastWeekReview.empty(),
      shortTermReport: shortTerm,
      newAllocation: allocation,
    );

    final seedNotifications = [
      LocalNotificationItem(
        id: 1001,
        channel: NotificationChannelType.report,
        title: 'Haftalık Pusula Raporu',
        body: NotificationFormatter.formatWeeklyReportReady(
          hasLastWeek: false,
          newRecommendationsCount: allocation.recommendations.length,
        ),
        createdAt: now.subtract(const Duration(minutes: 15)),
        dedupKey: 'seed_report_1',
      ),
      LocalNotificationItem(
        id: 1002,
        channel: NotificationChannelType.outcome,
        title: 'LINKUSDT Hedef 2 (2R)',
        body: NotificationFormatter.formatTargetHit(shortSymbol: 'LINK', pct: 5.9, rMultiple: 2.0),
        createdAt: now.subtract(const Duration(hours: 6)),
        dedupKey: 'seed_link_t2',
        symbol: 'LINKUSDT',
      ),
      LocalNotificationItem(
        id: 1003,
        channel: NotificationChannelType.signal,
        title: 'THYAO Yeni Kurulum · 20-Bar Zirve Kırılımı',
        body: 'Giriş bölgesi 318,00 – 320,50 TL · Stop 306,50 · 2R Hedef 344,75 (Veri 15 dk gecikmeli · Yahoo)',
        createdAt: now.subtract(const Duration(hours: 2)),
        dedupKey: 'seed_thyao_sig',
        symbol: 'THYAO',
      ),
    ];

    final providers = [
      ProviderHealth('binance_spot', 'Binance Spot (Kripto Birincil)')
        ..lastSuccess = now.subtract(const Duration(seconds: 40))
        ..successCount = 42,
      ProviderHealth('binance_futures', 'Binance Futures (XAG/SIREN ve Fonlama)')
        ..lastSuccess = now.subtract(const Duration(minutes: 2))
        ..successCount = 12,
      ProviderHealth('yahoo_finance', 'Yahoo Finance .IS / -USD (~15 dk gecikmeli)')
        ..lastSuccess = now.subtract(const Duration(minutes: 4))
        ..successCount = 75,
      ProviderHealth('is_yatirim', 'İş Yatırım HisseTekil (BIST Günlük Yedek)')
        ..lastSuccess = now.subtract(const Duration(hours: 3))
        ..successCount = 15,
    ];

    final schedule = BackgroundScheduleSnapshot(
      periodicIntervalMinutes: 15,
      nextSundayReportUtc: BackgroundScheduler.nextSundayReportUtc(now),
      nextBistOpenUtc: const BistCalendar().nextOpen(now),
      nextBistCloseUtc: BackgroundScheduler().nextBistCloseUtc(now),
      liveMonitorActive: settings.liveMonitorEnabled,
      batteryOptimizationIgnored: false,
    );

    return PusulaAppState(
      settings: settings,
      currentReport: initialReport,
      archivedReports: [initialReport],
      performanceCurve: const [],
      activeSignals: activeSigs,
      allSignals: allSigs,
      recentNotifications: seedNotifications,
      providerHealthList: providers,
      scheduleSnapshot: schedule,
      isLoading: false,
    );
  }

  Future<void> _hydrateFromStorage() async {
    final loadedSettings = await storage.settingsStore.load();
    final existingSignals = await storage.journalStore.allSignals();
    if (existingSignals.isEmpty) {
      for (final s in state.allSignals) {
        await storage.journalStore.save(s);
      }
      await storage.reportStore.save(state.currentReport);
    } else {
      final reports = await storage.reportStore.allReports();
      final active = await storage.journalStore.activeSignals();
      state = state.copyWith(
        settings: loadedSettings,
        allSignals: existingSignals,
        activeSignals: active,
        archivedReports: reports.isEmpty ? state.archivedReports : reports,
        currentReport: reports.isEmpty ? state.currentReport : reports.first,
      );
      return;
    }
    if (loadedSettings != state.settings) {
      await _applySettings(loadedSettings);
    }
  }

  Future<void> _applySettings(AppSettings next) async {
    const allocator = PortfolioWeightAllocator();
    final allocation = allocator.allocate(
      state.activeSignals,
      appetite: next.riskAppetite,
      totalBudget: next.budgetAmount,
    );
    final updatedReport = WeeklyReport(
      id: state.currentReport.id,
      weekStart: state.currentReport.weekStart,
      weekEnd: state.currentReport.weekEnd,
      generatedAt: state.currentReport.generatedAt,
      lastWeekReview: state.currentReport.lastWeekReview,
      shortTermReport: state.currentReport.shortTermReport,
      newAllocation: allocation,
    );
    state = state.copyWith(
      settings: next,
      currentReport: updatedReport,
    );
    await storage.settingsStore.save(next);
    final schedule = await _scheduler.syncSchedule(liveMonitorEnabled: next.liveMonitorEnabled);
    if (mounted) {
      state = state.copyWith(scheduleSnapshot: schedule);
    }
  }

  Future<void> updateBudget(double budgetAmount) async {
    if (budgetAmount <= 0) return;
    await _applySettings(state.settings.copyWith(budgetAmount: budgetAmount));
  }

  Future<void> updateRiskAppetite(RiskAppetite appetite) async {
    await _applySettings(state.settings.copyWith(riskAppetite: appetite));
  }

  Future<void> toggleDarkMode(bool value) async {
    await _applySettings(state.settings.copyWith(darkMode: value));
  }

  Future<void> toggleReduceAnimations(bool value) async {
    await _applySettings(state.settings.copyWith(reduceAnimations: value));
  }

  Future<void> toggleBatterySaver(bool value) async {
    await _applySettings(state.settings.copyWith(batterySaverMode: value));
  }

  Future<void> toggleLiveMonitor(bool value) async {
    await _applySettings(state.settings.copyWith(liveMonitorEnabled: value));
  }

  Future<void> updateNotificationChannels({
    bool? signal,
    bool? outcome,
    bool? report,
    bool? system,
    bool? quietHoursEnabled,
  }) async {
    await _applySettings(
      state.settings.copyWith(
        notifySignal: signal,
        notifyOutcome: outcome,
        notifyReport: report,
        notifySystem: system,
        quietHoursEnabled: quietHoursEnabled,
      ),
    );
  }

  /// Yerel bildirim motorunu test etmek için örnek bildirim tetikler.
  Future<void> triggerSampleNotification() async {
    final idx = state.recentNotifications.length + 1;
    final body = NotificationFormatter.formatTargetHit(shortSymbol: 'SOL', pct: 3.2, rMultiple: 2.0);
    await _notificationCoordinator.dispatch(
      channel: NotificationChannelType.outcome,
      title: 'SOLUSDT Hedef Bildirimi',
      body: body,
      dedupKey: 'manual_sample_$idx',
      settings: state.settings,
      symbol: 'SOLUSDT',
    );
    final combined = [
      ..._notificationCoordinator.recentNotifications,
      ...state.recentNotifications.where(
        (old) => !_notificationCoordinator.recentNotifications.any((n) => n.id == old.id),
      ),
    ];
    state = state.copyWith(
      recentNotifications: combined,
      statusMessage: 'Yerel bildirim gönderildi: $body',
    );
  }
}
