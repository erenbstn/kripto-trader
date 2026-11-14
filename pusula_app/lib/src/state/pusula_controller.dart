import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pusula_core/pusula_core.dart';

import '../background/background_scheduler.dart';
import '../notifications/notification_engine.dart';
import '../storage/app_settings.dart';
import '../storage/sqlite_storage.dart';
import '../update/app_updater.dart';
import '../widgets/donut_3d_chart.dart';
import 'live_data.dart';
import 'scan_runner.dart';

export 'live_data.dart';

/// Uygulamanın tüm ekranlarını besleyen birleşik durum nesnesi.
class PusulaAppState {
  const PusulaAppState({
    required this.settings,
    required this.currentReport,
    required this.archivedReports,
    required this.performanceCurve,
    required this.activeSignals,
    required this.allSignals,
    required this.cryptoQuotes,
    required this.bistQuotes,
    required this.recentNotifications,
    required this.providerHealthList,
    required this.scheduleSnapshot,
    required this.optimizationProposal,
    required this.isLoading,
    this.lastRefreshedAt,
    this.statusMessage,
    this.isDemo = false,
    this.lastScan,
    this.scanProgress,
    this.updateState = const AppUpdateState.idle(),
    this.toastMessage,
    this.toastVisible = false,
    this.toastPositive = true,
  });

  final AppSettings settings;
  final WeeklyReport currentReport;
  final List<WeeklyReport> archivedReports;
  final List<PerformanceCurvePoint> performanceCurve;
  final List<SignalRecord> activeSignals;
  final List<SignalRecord> allSignals;
  final List<LiveMarketQuote> cryptoQuotes;
  final List<LiveMarketQuote> bistQuotes;
  final List<LocalNotificationItem> recentNotifications;
  final List<ProviderHealth> providerHealthList;
  final BackgroundScheduleSnapshot scheduleSnapshot;
  final StrategyOptimizationProposal optimizationProposal;
  final bool isLoading;
  final DateTime? lastRefreshedAt;
  final String? statusMessage;

  /// Ağsız önizleme/test kipi: ekrandaki sinyaller ÖRNEK veridir ve öyle etiketlenir.
  /// Gerçek uygulamada her zaman false olur; hiçbir örnek sinyal gösterilmez.
  final bool isDemo;

  /// Son tarama turunun özeti (kaç varlık tarandı, kaç aday neden elendi).
  final ScanOutcome? lastScan;

  /// Devam eden taramanın ilerlemesi (0–1); tarama yokken null.
  final double? scanProgress;

  /// GitHub Releases üzerinden uygulama içi APK güncelleme durumu.
  final AppUpdateState updateState;

  /// Phantom tarzı üst yüzen durum kapsülü (ör. `✓ Tarama tamamlandı`).
  final String? toastMessage;
  final bool toastVisible;
  final bool toastPositive;

  /// Piyasa rejimleri (son taramadan).
  Map<Market, RegimeReport> get regimes => lastScan?.regimes ?? const {};

  /// Haftalık öneri niteliğindeki açık sinyaller (bütçe ağırlığı alanlar).
  List<SignalRecord> get activeWeeklySignals =>
      [for (final s in activeSignals) if (isDemo || s.isWeeklyProposal) s];

  /// Varlığın bilinen son fiyatı (piyasa şeridinden); yoksa null.
  double? priceOf(Instrument ins) {
    for (final q in ins.market == Market.bist ? bistQuotes : cryptoQuotes) {
      if (q.instrument == ins) return q.lastPrice;
    }
    return null;
  }

  /// Kısa vade niteliğindeki açık sinyaller.
  List<SignalRecord> get activeShortTermSignals =>
      [for (final s in activeSignals) if (!s.isWeeklyProposal) s];

  /// 3D / 2D halka grafik için bütçe dilimlerini üretir.
  List<DonutSliceData> get donutSlices {
    const bistPalette = [
      Color(0xFFAB9FF2),
      Color(0xFF818CF8),
      Color(0xFF6366F1),
      Color(0xFF38BDF8),
    ];
    const cryptoPalette = [
      Color(0xFF26D07C),
      Color(0xFFF7931A),
      Color(0xFF14F195),
      Color(0xFFFB7185),
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
    List<LiveMarketQuote>? cryptoQuotes,
    List<LiveMarketQuote>? bistQuotes,
    List<LocalNotificationItem>? recentNotifications,
    List<ProviderHealth>? providerHealthList,
    BackgroundScheduleSnapshot? scheduleSnapshot,
    StrategyOptimizationProposal? optimizationProposal,
    bool? isLoading,
    DateTime? lastRefreshedAt,
    String? statusMessage,
    ScanOutcome? lastScan,
    double? scanProgress,
    AppUpdateState? updateState,
    String? toastMessage,
    bool? toastVisible,
    bool? toastPositive,
  }) =>
      PusulaAppState(
        settings: settings ?? this.settings,
        currentReport: currentReport ?? this.currentReport,
        archivedReports: archivedReports ?? this.archivedReports,
        performanceCurve: performanceCurve ?? this.performanceCurve,
        activeSignals: activeSignals ?? this.activeSignals,
        allSignals: allSignals ?? this.allSignals,
        cryptoQuotes: cryptoQuotes ?? this.cryptoQuotes,
        bistQuotes: bistQuotes ?? this.bistQuotes,
        recentNotifications: recentNotifications ?? this.recentNotifications,
        providerHealthList: providerHealthList ?? this.providerHealthList,
        scheduleSnapshot: scheduleSnapshot ?? this.scheduleSnapshot,
        optimizationProposal: optimizationProposal ?? this.optimizationProposal,
        isLoading: isLoading ?? this.isLoading,
        lastRefreshedAt: lastRefreshedAt ?? this.lastRefreshedAt,
        statusMessage: statusMessage,
        isDemo: isDemo,
        lastScan: lastScan ?? this.lastScan,
        scanProgress: scanProgress,
        updateState: updateState ?? this.updateState,
        toastMessage: toastMessage ?? this.toastMessage,
        toastVisible: toastVisible ?? this.toastVisible,
        toastPositive: toastPositive ?? this.toastPositive,
      );
}

final storageBundleProvider = Provider<StorageBundle>((ref) {
  return StorageBundle.inMemory();
});

final notificationGatewayProvider = Provider<LocalNotificationGateway>((ref) {
  return MemoryNotificationGateway();
});

/// Gerçek ağ yenilemesinin otomatik çalışıp çalışmayacağını belirler.
/// Birim ve widget testlerinde false (varsayılan), gerçek uygulamada (`main.dart`) true olarak verilir.
final liveNetworkEnabledProvider = Provider<bool>((ref) {
  return false;
});

/// Örnek (demo) veriyle başlatma. Ağsız widget testleri ve tasarım önizlemesi için varsayılan true;
/// gerçek uygulama (`main.dart`) bunu false yapar: örnek sinyal asla gerçek öneri gibi gösterilmez.
final demoSeedProvider = Provider<bool>((ref) {
  return true;
});

/// Testte sahte veri servisi enjekte etmek için (varsayılan: gerçek ağ sağlayıcıları).
final dataServiceFactoryProvider = Provider<MarketDataService Function()?>((ref) {
  return null;
});

/// Testte veya yerelde uygulama güncelleyici servisi enjekte etmek için.
final appUpdateServiceProvider = Provider<AppUpdateService?>((ref) {
  return null;
});

/// Alt Phantom arama çubuğundan beslenen küresel sembol/varlık filtresi.
final searchQueryProvider = StateProvider<String>((ref) => '');

final pusulaControllerProvider = StateNotifierProvider<PusulaController, PusulaAppState>((ref) {
  final storage = ref.watch(storageBundleProvider);
  final gateway = ref.watch(notificationGatewayProvider);
  final enableLive = ref.watch(liveNetworkEnabledProvider);
  final demo = ref.watch(demoSeedProvider);
  return PusulaController(
    storage: storage,
    notificationGateway: gateway,
    enableLiveNetwork: enableLive,
    demoSeed: demo,
    dataServiceFactory: ref.watch(dataServiceFactoryProvider),
    updateService: ref.watch(appUpdateServiceProvider),
  );
});

class PusulaController extends StateNotifier<PusulaAppState> {
  PusulaController({
    required this.storage,
    required LocalNotificationGateway notificationGateway,
    this.enableLiveNetwork = false,
    this.demoSeed = true,
    this.dataServiceFactory,
    AppUpdateService? updateService,
    Clock? clock,
  })  : _clock = clock ?? (() => DateTime.now().toUtc()),
        _updater = updateService ?? AppUpdateService(),
        _ownsUpdater = updateService == null,
        _notificationCoordinator = NotificationCoordinator(
          gateway: notificationGateway,
          clock: clock ?? (() => DateTime.now().toUtc()),
        ),
        _scheduler = BackgroundScheduler(
          clock: clock ?? (() => DateTime.now().toUtc()),
        ),
        super(demoSeed
            ? _buildInitialSeedState(clock ?? (() => DateTime.now().toUtc()))
            : _buildInitialLiveState(clock ?? (() => DateTime.now().toUtc()))) {
    ready = _init();
  }

  final StorageBundle storage;
  final bool enableLiveNetwork;

  /// true ise ağsız örnek veriyle başlar (test/önizleme); false ise yalnızca gerçek tarama sonuçları gösterilir.
  final bool demoSeed;
  final MarketDataService Function()? dataServiceFactory;
  final AppUpdateService _updater;
  final bool _ownsUpdater;
  final Clock _clock;
  final NotificationCoordinator _notificationCoordinator;
  final BackgroundScheduler _scheduler;
  final StrategyVersionStore _versionStore = MemoryStrategyVersionStore();
  Timer? _toastTimer;

  /// Başlangıç yüklemesi (ve varsa ilk canlı tarama) tamamlandığında biten gelecek; testler bunu bekler.
  late final Future<void> ready;

  /// Canlı izlenen başlıca BIST hisseleri ve endeks.
  static const List<Instrument> watchedBistInstruments = [BistUniverse.benchmark, ...kWatchedBistStocks];

  /// Kullanıcının ayarlarına göre tam Borsa İstanbul (BIST) hisse kataloğu.
  List<Instrument> get bistCatalog => buildBistCatalog(state.settings);

  Future<void> _init() async {
    await _hydrateFromStorage();
    try {
      final installed = await _updater.installedVersion();
      if (mounted) {
        state = state.copyWith(
          updateState: state.updateState.copyWith(currentVersion: installed),
          statusMessage: state.statusMessage,
          scanProgress: state.scanProgress,
        );
      }
    } catch (e) {
      debugPrint('Pusula sürüm okuma hatası: $e');
    }
    if (enableLiveNetwork && !demoSeed && mounted) {
      if (!kIsWeb && state.settings.autoCheckUpdates && state.settings.updateRepo.isNotEmpty) {
        unawaited(checkForAppUpdate(silent: true));
      }
      await refreshLiveMarketData();
    }
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    if (_ownsUpdater) _updater.dispose();
    super.dispose();
  }

  void dismissToast() {
    _toastTimer?.cancel();
    if (!mounted) return;
    state = state.copyWith(
      toastVisible: false,
      statusMessage: state.statusMessage,
      scanProgress: state.scanProgress,
    );
  }

  void _showToast(String message, {bool positive = true, bool autoHide = true}) {
    _toastTimer?.cancel();
    if (!mounted) return;
    state = state.copyWith(
      toastMessage: message,
      toastVisible: true,
      toastPositive: positive,
      statusMessage: state.statusMessage,
      scanProgress: state.scanProgress,
    );
    if (autoHide && !demoSeed) {
      _toastTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) dismissToast();
      });
    }
  }

  static StrategyOptimizationProposal _emptyProposal(DateTime now) => StrategyOptimizationProposal(
        currentVersion: StrategyVersionRecord.baseline(createdAt: now),
        statsByStrategy: const {},
        statsByRegime: const {},
        canModifyParameters: false,
        proposedVersion: null,
        summaryReportTr:
            'Henüz kapanmış sinyal yok. Aşırı uyum (overfitting) yasağı gereği strateji başına '
            '$kMinClosedSignalsForTuning kapanmış sinyal birikmeden hiçbir parametre değiştirilmez.',
      );

  /// Gerçek uygulamanın başlangıç durumu: hiçbir örnek sinyal, fiyat veya bildirim içermez.
  /// İlk tarama bitene kadar dürüstçe "%100 nakit · tarama bekleniyor" gösterilir.
  static PusulaAppState _buildInitialLiveState(Clock clock) {
    final now = clock().toUtc();
    const settings = AppSettings();
    final allocation = const PortfolioWeightAllocator().allocate(
      const [],
      appetite: settings.riskAppetite,
      totalBudget: settings.budgetAmount,
    );
    final weekStart = ScanRunner.weekStartUtc(now);
    final report = WeeklyReport(
      id: ScanRunner.reportIdFor(weekStart),
      weekStart: weekStart,
      weekEnd: now,
      generatedAt: now,
      lastWeekReview: const LastWeekReview.empty(),
      shortTermReport: const ShortTermWeeklyReport(
        crypto: ShortTermMarketSummary.empty(Market.crypto),
        bist: ShortTermMarketSummary.empty(Market.bist),
      ),
      newAllocation: allocation,
    );
    return PusulaAppState(
      settings: settings,
      currentReport: report,
      archivedReports: const [],
      performanceCurve: const [],
      activeSignals: const [],
      allSignals: const [],
      cryptoQuotes: const [],
      bistQuotes: const [],
      recentNotifications: const [],
      providerHealthList: const [],
      scheduleSnapshot: BackgroundScheduleSnapshot(
        periodicIntervalMinutes: 15,
        nextSundayReportUtc: BackgroundScheduler.nextSundayReportUtc(now),
        nextBistOpenUtc: const BistCalendar().nextOpen(now),
        nextBistCloseUtc: BackgroundScheduler().nextBistCloseUtc(now),
        liveMonitorActive: settings.liveMonitorEnabled,
        batteryOptimizationIgnored: false,
      ),
      optimizationProposal: _emptyProposal(now),
      isLoading: false,
      statusMessage: 'Henüz tarama yapılmadı.',
    );
  }

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
      strategyVersion: kStrategyVersion,
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

    // Güncel piyasa seviyeleriyle kalibre edilmiş başlangıç sinyalleri:
    // THYAO ~ 313,75 TL, ASELS ~ 337,00 TL, SOL ~ 82,90 USDT, BTC ~ 73.506 USDT, LINK ~ 10,30 USDT, AKBNK ~ 70,70 TL.
    final sThyao = _makeSeedSignal(
      id: 'sig_thyao_v2',
      instrument: thyao,
      interval: BarInterval.d1,
      strategy: SetupType.breakout20,
      rationale: 'Kapanmış günlük mumda 310,00 TL direnci hacim artışıyla geçildi; son fiyat 313,75 TL.',
      entryZoneLow: 312.50,
      entryZoneHigh: 315.00,
      entryPrice: 313.75,
      stopPrice: 301.25,
      target1: 326.25,
      target2: 338.75,
      rewardRisk: 2.0,
      confidenceTotal: 84,
      dataSource: 'Yahoo Finance',
      dataAgeMinutes: 15,
      createdAt: now.subtract(const Duration(hours: 2)),
    );

    final sAsels = _makeSeedSignal(
      id: 'sig_asels_v2',
      instrument: asels,
      interval: BarInterval.h1,
      strategy: SetupType.bullFlag,
      rationale: 'Güçlü yükseliş direği sonrası bayrak üst bandı kapanmış mumla geçildi; son fiyat 337,00 TL.',
      entryZoneLow: 335.50,
      entryZoneHigh: 338.50,
      entryPrice: 337.00,
      stopPrice: 323.50,
      target1: 350.50,
      target2: 364.00,
      rewardRisk: 2.0,
      confidenceTotal: 80,
      dataSource: 'Yahoo Finance',
      dataAgeMinutes: 15,
      createdAt: now.subtract(const Duration(hours: 3)),
    );

    final sSol = _makeSeedSignal(
      id: 'sig_sol_v2',
      instrument: sol,
      interval: BarInterval.h1,
      strategy: SetupType.oversoldBounce,
      rationale: 'Saatlik RSI aşırı satım bölgesinden hacimli dönüş teyidi; güncel fiyat 82,90 USDT.',
      entryZoneLow: 82.40,
      entryZoneHigh: 83.30,
      entryPrice: 82.90,
      stopPrice: 79.60,
      target1: 86.20,
      target2: 89.50,
      rewardRisk: 2.0,
      confidenceTotal: 82,
      dataSource: 'Binance Spot',
      dataAgeMinutes: 1,
      createdAt: now.subtract(const Duration(minutes: 45)),
    );

    final sBtc = _makeSeedSignal(
      id: 'sig_btc_v2',
      instrument: btc,
      interval: BarInterval.h1,
      strategy: SetupType.vwapBreakout,
      rationale: 'Seans VWAP seviyesi hacimle geri kazanıldı; güncel fiyat 73.506 USDT.',
      entryZoneLow: 73200.0,
      entryZoneHigh: 73750.0,
      entryPrice: 73506.0,
      stopPrice: 71300.0,
      target1: 75712.0,
      target2: 77918.0,
      rewardRisk: 2.0,
      confidenceTotal: 78,
      dataSource: 'Binance Spot',
      dataAgeMinutes: 1,
      createdAt: now.subtract(const Duration(hours: 1)),
    );

    final sLinkClosed = _makeSeedSignal(
      id: 'sig_link_closed_v2',
      instrument: link,
      interval: BarInterval.m15,
      strategy: SetupType.orb,
      rationale: 'Açılış aralığı üst bandı hacimli geçildi (güncel seviye ~10,30 USDT).',
      entryZoneLow: 9.68,
      entryZoneHigh: 9.76,
      entryPrice: 9.72,
      stopPrice: 9.43,
      target1: 10.01,
      target2: 10.30,
      rewardRisk: 2.0,
      confidenceTotal: 77,
      dataSource: 'Binance Spot',
      dataAgeMinutes: 1,
      createdAt: now.subtract(const Duration(days: 2)),
      status: SignalStatus.target2,
      realizedR: 2.0,
      realizedPct: 5.97,
      closedAt: now.subtract(const Duration(days: 1, hours: 18)),
    );

    final sAkbnkClosed = _makeSeedSignal(
      id: 'sig_akbnk_closed_v2',
      instrument: akbnk,
      interval: BarInterval.h1,
      strategy: SetupType.reclaimMa20,
      rationale: 'Saatlik MA20 üzerinde kapanış teyidi (güncel seviye 70,70 TL).',
      entryZoneLow: 69.50,
      entryZoneHigh: 69.90,
      entryPrice: 69.75,
      stopPrice: 68.80,
      target1: 70.70,
      target2: 71.65,
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

    final initialCryptoQuotes = <LiveMarketQuote>[
      const LiveMarketQuote(
        instrument: Instrument.crypto('BTCUSDT', name: 'Bitcoin'),
        lastPrice: 73506.01,
        changePct: 0.30,
        sourceLabel: 'Binance Spot',
        ageMinutes: 1,
        isStale: false,
      ),
      const LiveMarketQuote(
        instrument: Instrument.crypto('ETHUSDT', name: 'Ethereum'),
        lastPrice: 2045.62,
        changePct: 0.18,
        sourceLabel: 'Binance Spot',
        ageMinutes: 1,
        isStale: false,
      ),
      const LiveMarketQuote(
        instrument: Instrument.crypto('SOLUSDT', name: 'Solana'),
        lastPrice: 82.90,
        changePct: -0.10,
        sourceLabel: 'Binance Spot',
        ageMinutes: 1,
        isStale: false,
      ),
      const LiveMarketQuote(
        instrument: Instrument.crypto('XRPUSDT', name: 'XRP'),
        lastPrice: 1.0678,
        changePct: -0.38,
        sourceLabel: 'Binance Spot',
        ageMinutes: 1,
        isStale: false,
      ),
      const LiveMarketQuote(
        instrument: Instrument.crypto('LINKUSDT', name: 'Chainlink'),
        lastPrice: 10.30,
        changePct: 0.11,
        sourceLabel: 'Binance Spot',
        ageMinutes: 1,
        isStale: false,
      ),
      const LiveMarketQuote(
        instrument: Instrument.crypto('PAXGUSDT', name: 'PAX Gold (altın)'),
        lastPrice: 4026.26,
        changePct: 0.09,
        sourceLabel: 'Binance Spot',
        ageMinutes: 1,
        isStale: false,
      ),
      const LiveMarketQuote(
        instrument: Instrument.crypto('XAGUSDT', name: 'Gümüş'),
        lastPrice: 51.53,
        changePct: 0.25,
        sourceLabel: 'Binance Futures',
        ageMinutes: 1,
        isStale: false,
      ),
      const LiveMarketQuote(
        instrument: Instrument.crypto('ONDOUSDT', name: 'Ondo'),
        lastPrice: 0.3628,
        changePct: 0.14,
        sourceLabel: 'Binance Spot',
        ageMinutes: 1,
        isStale: false,
      ),
      const LiveMarketQuote(
        instrument: Instrument.crypto('HBARUSDT', name: 'Hedera'),
        lastPrice: 0.0660,
        changePct: 0.08,
        sourceLabel: 'Binance Spot',
        ageMinutes: 1,
        isStale: false,
      ),
      const LiveMarketQuote(
        instrument: Instrument.crypto('SIRENUSDT', name: 'Siren'),
        lastPrice: 0.0253,
        changePct: 0.20,
        sourceLabel: 'Binance Futures',
        ageMinutes: 1,
        isStale: false,
      ),
    ];

    final initialBistQuotes = <LiveMarketQuote>[
      const LiveMarketQuote(
        instrument: BistUniverse.benchmark,
        lastPrice: 11661.86,
        changePct: 0.42,
        sourceLabel: 'Yahoo Finance (~15 dk)',
        ageMinutes: 15,
        isStale: false,
      ),
      const LiveMarketQuote(
        instrument: Instrument.bist('THYAO', name: 'Türk Hava Yolları'),
        lastPrice: 313.75,
        changePct: 1.21,
        sourceLabel: 'Yahoo Finance (~15 dk)',
        ageMinutes: 15,
        isStale: false,
      ),
      const LiveMarketQuote(
        instrument: Instrument.bist('ASELS', name: 'Aselsan'),
        lastPrice: 337.00,
        changePct: 1.81,
        sourceLabel: 'Yahoo Finance (~15 dk)',
        ageMinutes: 15,
        isStale: false,
      ),
      const LiveMarketQuote(
        instrument: Instrument.bist('AKBNK', name: 'Akbank'),
        lastPrice: 70.70,
        changePct: 0.86,
        sourceLabel: 'Yahoo Finance (~15 dk)',
        ageMinutes: 15,
        isStale: false,
      ),
      const LiveMarketQuote(
        instrument: Instrument.bist('GARAN', name: 'Garanti BBVA'),
        lastPrice: 155.40,
        changePct: 0.65,
        sourceLabel: 'Yahoo Finance (~15 dk)',
        ageMinutes: 15,
        isStale: false,
      ),
      const LiveMarketQuote(
        instrument: Instrument.bist('TUPRS', name: 'Tüpraş'),
        lastPrice: 331.25,
        changePct: 0.53,
        sourceLabel: 'Yahoo Finance (~15 dk)',
        ageMinutes: 15,
        isStale: false,
      ),
      const LiveMarketQuote(
        instrument: Instrument.bist('BIMAS', name: 'BİM Mağazaları'),
        lastPrice: 381.25,
        changePct: 0.40,
        sourceLabel: 'Yahoo Finance (~15 dk)',
        ageMinutes: 15,
        isStale: false,
      ),
      const LiveMarketQuote(
        instrument: Instrument.bist('KCHOL', name: 'Koç Holding'),
        lastPrice: 206.00,
        changePct: 0.49,
        sourceLabel: 'Yahoo Finance (~15 dk)',
        ageMinutes: 15,
        isStale: false,
      ),
      const LiveMarketQuote(
        instrument: Instrument.bist('ISCTR', name: 'İş Bankası (C)'),
        lastPrice: 13.66,
        changePct: 0.74,
        sourceLabel: 'Yahoo Finance (~15 dk)',
        ageMinutes: 15,
        isStale: false,
      ),
      const LiveMarketQuote(
        instrument: Instrument.bist('SAHOL', name: 'Sabancı Holding'),
        lastPrice: 87.30,
        changePct: 0.34,
        sourceLabel: 'Yahoo Finance (~15 dk)',
        ageMinutes: 15,
        isStale: false,
      ),
      const LiveMarketQuote(
        instrument: Instrument.bist('EREGL', name: 'Erdemir'),
        lastPrice: 32.52,
        changePct: 0.25,
        sourceLabel: 'Yahoo Finance (~15 dk)',
        ageMinutes: 15,
        isStale: false,
      ),
      const LiveMarketQuote(
        instrument: Instrument.bist('SISE', name: 'Şişecam'),
        lastPrice: 35.72,
        changePct: 0.17,
        sourceLabel: 'Yahoo Finance (~15 dk)',
        ageMinutes: 15,
        isStale: false,
      ),
      const LiveMarketQuote(
        instrument: Instrument.bist('TCELL', name: 'Turkcell'),
        lastPrice: 97.75,
        changePct: 0.62,
        sourceLabel: 'Yahoo Finance (~15 dk)',
        ageMinutes: 15,
        isStale: false,
      ),
      const LiveMarketQuote(
        instrument: Instrument.bist('PGSUS', name: 'Pegasus'),
        lastPrice: 154.40,
        changePct: 0.92,
        sourceLabel: 'Yahoo Finance (~15 dk)',
        ageMinutes: 15,
        isStale: false,
      ),
      const LiveMarketQuote(
        instrument: Instrument.bist('ASTOR', name: 'Astor Enerji'),
        lastPrice: 157.10,
        changePct: 1.16,
        sourceLabel: 'Yahoo Finance (~15 dk)',
        ageMinutes: 15,
        isStale: false,
      ),
    ];

    final shortTerm = ShortTermWeeklyReport(
      crypto: ShortTermMarketSummary(
        market: Market.crypto,
        hasData: true,
        totalSignals: 3,
        closedSignals: 1,
        openSignals: 2,
        totalReturnPct: 5.97,
        winRatePct: 100.0,
        avgR: 2.0,
        bestSignalSummary: 'LINK (Açılış Aralığı Kırılımı (ORB)): +%5,97 (+2,00R)',
        worstSignalSummary: 'LINK (Açılış Aralığı Kırılımı (ORB)): +%5,97 (+2,00R)',
        byStrategy: const [
          StrategyBreakdownItem(
            strategyCode: 'orb',
            strategyLabel: 'Açılış Aralığı Kırılımı (ORB)',
            signalCount: 1,
            closedCount: 1,
            winRatePct: 100.0,
            avgR: 2.0,
            totalReturnPct: 5.97,
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
      id: 'report_live_v2',
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
        body: NotificationFormatter.formatTargetHit(shortSymbol: 'LINK', pct: 6.0, rMultiple: 2.0),
        createdAt: now.subtract(const Duration(hours: 6)),
        dedupKey: 'seed_link_t2',
        symbol: 'LINKUSDT',
      ),
      LocalNotificationItem(
        id: 1003,
        channel: NotificationChannelType.signal,
        title: 'THYAO Yeni Kurulum · 20-Bar Zirve Kırılımı',
        body: 'Giriş bölgesi 312,50 – 315,00 TL · Stop 301,25 · 2R Hedef 338,75 (Veri 15 dk gecikmeli · Yahoo)',
        createdAt: now.subtract(const Duration(hours: 2)),
        dedupKey: 'seed_thyao_sig',
        symbol: 'THYAO',
      ),
    ];

    final providers = [
      ProviderHealth('binance_spot', 'Binance Spot (Kripto Birincil)')
        ..lastSuccess = now.subtract(const Duration(seconds: 40))
        ..successCount = 10,
      ProviderHealth('binance_futures', 'Binance Futures (XAG/SIREN ve Fonlama)')
        ..lastSuccess = now.subtract(const Duration(minutes: 1))
        ..successCount = 2,
      ProviderHealth('yahoo_finance', 'Yahoo Finance .IS / -USD (~15 dk gecikmeli)')
        ..lastSuccess = now.subtract(const Duration(minutes: 2))
        ..successCount = 17,
      ProviderHealth('is_yatirim', 'İş Yatırım HisseTekil (BIST Günlük Yedek)')
        ..lastSuccess = now.subtract(const Duration(minutes: 15))
        ..successCount = 3,
    ];

    final schedule = BackgroundScheduleSnapshot(
      periodicIntervalMinutes: 15,
      nextSundayReportUtc: BackgroundScheduler.nextSundayReportUtc(now),
      nextBistOpenUtc: const BistCalendar().nextOpen(now),
      nextBistCloseUtc: BackgroundScheduler().nextBistCloseUtc(now),
      liveMonitorActive: settings.liveMonitorEnabled,
      batteryOptimizationIgnored: false,
    );

    final baseVer = StrategyVersionRecord.baseline(createdAt: now);
    final seedProposal = StrategyOptimizationProposal(
      currentVersion: baseVer,
      statsByStrategy: {
        for (final s in SetupType.values)
          s: StrategyPerformanceStats(
            strategy: s,
            closedCount: s == SetupType.orb || s == SetupType.reclaimMa20 ? 1 : 0,
            winCount: s == SetupType.orb || s == SetupType.reclaimMa20 ? 1 : 0,
            winRate: s == SetupType.orb || s == SetupType.reclaimMa20 ? 1.0 : 0.0,
            avgR: s == SetupType.orb ? 2.0 : (s == SetupType.reclaimMa20 ? 0.5 : 0.0),
            wilson95Low: s == SetupType.orb || s == SetupType.reclaimMa20 ? 0.207 : 0.0,
            wilson95High: 1.0,
            observationNoteTr:
                '${s.label}: Yetersiz örneklem (${s == SetupType.orb || s == SetupType.reclaimMa20 ? 1 : 0}/30 kapanmış sinyal). '
                'Aşırı uyum yasağı gereği parametre değiştirilmez; yalnızca gözlem (Wilson %95 GA).',
          ),
      },
      statsByRegime: const {},
      canModifyParameters: false,
      proposedVersion: null,
      summaryReportTr:
          'Hiçbir strateji henüz 30 kapanmış sinyal eşiğine ulaşmadı. Aşırı uyum (overfitting) yasağı gereği tüm parametreler v$kStrategyVersion sürümünde korundu.',
    );

    return PusulaAppState(
      settings: settings,
      currentReport: initialReport,
      archivedReports: [initialReport],
      performanceCurve: const [],
      activeSignals: activeSigs,
      allSignals: allSigs,
      cryptoQuotes: initialCryptoQuotes,
      bistQuotes: initialBistQuotes,
      recentNotifications: seedNotifications,
      providerHealthList: providers,
      scheduleSnapshot: schedule,
      optimizationProposal: seedProposal,
      isLoading: false,
      lastRefreshedAt: now,
      isDemo: true,
      statusMessage: 'Örnek veri gösteriliyor.',
      toastMessage: 'Portföy güncel',
      toastVisible: true,
      toastPositive: true,
    );
  }

  /// Ayarlarda kayıtlı eski strateji sürümünü etkin taban sürüme taşır.
  static AppSettings _migrateSettings(AppSettings loaded) =>
      loaded.activeStrategyVersion == '2.0.0' ? loaded.copyWith(activeStrategyVersion: kStrategyVersion) : loaded;

  Future<void> _hydrateFromStorage() async {
    AppSettings loadedSettings = state.settings;
    try {
      loadedSettings = _migrateSettings(await storage.settingsStore.load());
    } catch (e) {
      debugPrint('Pusula ayar yükleme hatası (varsayılan kullanılıyor): $e');
    }

    if (demoSeed) {
      try {
        // Örnek kip: örnek kayıtlar yalnızca bellek içi depoya yazılır.
        for (final s in state.allSignals) {
          await storage.journalStore.save(s);
        }
        await storage.reportStore.save(state.currentReport);
        if (loadedSettings != state.settings) {
          await _applySettings(loadedSettings);
        }
      } catch (e) {
        debugPrint('Pusula demo depo yazma hatası: $e');
      }
      return;
    }

    try {
      // Gerçek kip: önceki sürümlerin diske yazdığı ÖRNEK sinyaller (kimliği `sig_` ile başlar) ve onlardan
      // üretilmiş raporlar temizlenir. O sürümlerde gerçek huni çalışmadığı için kaybolan gerçek kayıt yoktur.
      var signals = await storage.journalStore.allSignals();
      if (signals.any((s) => s.id.startsWith('sig_'))) {
        await storage.journalStore.clear();
        await storage.reportStore.clear();
        signals = const [];
      }
      final reports = await storage.reportStore.allReports();
      final active = await storage.journalStore.activeSignals();
      if (!mounted) return;
      state = state.copyWith(
        settings: loadedSettings,
        allSignals: signals,
        activeSignals: active,
        archivedReports: reports,
        currentReport: reports.isEmpty ? state.currentReport : reports.first,
        performanceCurve: performanceCurveFrom(reports),
        statusMessage: signals.isEmpty ? 'Henüz tarama yapılmadı.' : 'Kayıtlı sinyaller yüklendi; tarama bekleniyor.',
      );
      await _applySettings(loadedSettings);
    } catch (e) {
      debugPrint('Pusula yerel veritabanı kurtarma modu: $e');
      if (!mounted) return;
      state = state.copyWith(
        settings: loadedSettings,
        statusMessage: 'Yerel veritabanı sıfırlandı; canlı tarama bekleniyor.',
      );
    }
  }

  /// Canlı veriyi çeker, analiz hunisini tüm evrende koşturur ve ekran durumunu GERÇEK sonuçla günceller.
  ///
  /// Hiçbir seviye "canlı fiyata yapıştırılmaz": giriş/stop/hedef yalnızca hunide onaylanan kapanmış
  /// mum kurulumundan gelir. Onaylanan fırsat yoksa portföy dürüstçe %100 nakit gösterilir.
  Future<void> refreshLiveMarketData({bool forceRefresh = false}) async {
    if (!mounted || state.isLoading) return;
    if (demoSeed) {
      state = state.copyWith(
        statusMessage: 'Örnek veri kipinde canlı tarama kapalıdır.',
        toastMessage: 'Örnek mod · Tarama kapalı',
        toastVisible: true,
        toastPositive: true,
      );
      return;
    }
    _toastTimer?.cancel();
    state = state.copyWith(
      isLoading: true,
      scanProgress: 0.0,
      statusMessage: 'Piyasa taranıyor…',
      toastMessage: 'Piyasa taranıyor…',
      toastVisible: true,
      toastPositive: true,
    );

    final runner = ScanRunner(
      storage: storage,
      coordinator: _notificationCoordinator,
      versionStore: _versionStore,
      clock: _clock,
      dataServiceFactory: dataServiceFactory,
    );

    try {
      final r = await runner.run(
        settings: state.settings,
        forceRefresh: forceRefresh,
        onProgress: (done, total) {
          if (!mounted || total <= 0) return;
          // Her adımda yeniden çizim yapmamak için ilerleme %5'lik dilimlerle yayınlanır.
          final p = ((done / total) * 20).floor() / 20.0;
          if (p != state.scanProgress) {
            state = state.copyWith(
              isLoading: true,
              scanProgress: p,
              statusMessage: 'Piyasa taranıyor… $done/$total',
            );
          }
        },
      );
      if (!mounted) return;
      state = state.copyWith(
        allSignals: r.allSignals,
        activeSignals: r.activeSignals,
        currentReport: r.report,
        archivedReports: r.archive,
        performanceCurve: r.curve,
        cryptoQuotes: r.cryptoQuotes.isNotEmpty ? r.cryptoQuotes : state.cryptoQuotes,
        bistQuotes: r.bistQuotes.isNotEmpty ? r.bistQuotes : state.bistQuotes,
        providerHealthList: r.health,
        optimizationProposal: r.proposal,
        recentNotifications: _mergedNotifications(),
        lastScan: r.outcome,
        isLoading: false,
        lastRefreshedAt: _clock().toUtc(),
        statusMessage: r.outcome.summaryTr,
      );
      _showToast('Tarama tamamlandı · ${r.activeSignals.length} aktif sinyal');
    } catch (e) {
      if (!mounted) return;
      // Ayrıntı (URL, sorgu) kullanıcıya/loga taşınmaz; yalnızca hata türü gösterilir.
      state = state.copyWith(
        isLoading: false,
        statusMessage: 'Tarama tamamlanamadı (${e.runtimeType}). Önceki sonuçlar korunuyor.',
      );
      _showToast('Bağlantı hatası (${e.runtimeType})', positive: false);
    }
  }

  List<LocalNotificationItem> _mergedNotifications() => [
        ..._notificationCoordinator.recentNotifications,
        ...state.recentNotifications.where(
          (old) => !_notificationCoordinator.recentNotifications.any((n) => n.id == old.id),
        ),
      ];

  Future<void> _applySettings(AppSettings next) async {
    const allocator = PortfolioWeightAllocator();
    final allocation = allocator.allocate(
      state.activeWeeklySignals,
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
      statusMessage: state.statusMessage,
      scanProgress: state.scanProgress,
    );
    try {
      await storage.settingsStore.save(next);
    } catch (e) {
      debugPrint('Pusula ayar kaydetme hatası: $e');
    }
    try {
      final schedule = await _scheduler.syncSchedule(liveMonitorEnabled: next.liveMonitorEnabled);
      if (mounted) {
        state = state.copyWith(
          scheduleSnapshot: schedule,
          statusMessage: state.statusMessage,
          scanProgress: state.scanProgress,
        );
      }
    } catch (e) {
      debugPrint('Pusula zamanlama eşitleme hatası: $e');
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

  /// Seçili hisseyi veya kripto varlığı favorilere ekler / çıkarır.
  ///
  /// Kripto tarafında yalnızca kullanıcının belirlediği 10 coin desteklenir.
  Future<void> toggleFavorite(Instrument instrument) async {
    final isBist = instrument.market == Market.bist;
    final clean = isBist
        ? BistUniverse.normalizeSymbol(instrument.symbol)
        : instrument.symbol.trim().toUpperCase();
    if (clean.isEmpty || clean == BistUniverse.benchmark.symbol) return;
    if (!isBist && !CryptoUniverse.contains(clean)) {
      _showToast('Yalnızca listedeki 10 kripto favoriye eklenebilir', positive: false);
      return;
    }

    final current = List<String>.from(state.settings.favoriteSymbols);
    final existed = current.any((s) => s.trim().toUpperCase() == clean);
    if (existed) {
      current.removeWhere((s) => s.trim().toUpperCase() == clean);
    } else {
      current.add(clean);
    }

    var customBist = List<String>.from(state.settings.customBistSymbols);
    if (isBist &&
        !existed &&
        BistUniverse.nameOf(clean) == null &&
        !customBist.any((s) => s.trim().toUpperCase() == clean)) {
      customBist.add(clean);
    }

    await _applySettings(
      state.settings.copyWith(
        favoriteSymbols: List.unmodifiable(current),
        customBistSymbols: List.unmodifiable(customBist),
      ),
    );
    _showToast(existed ? '${instrument.short} favorilerden çıkarıldı' : '${instrument.short} favorilere eklendi');

    if (!existed && enableLiveNetwork && !demoSeed && mounted) {
      final hasQuote = (isBist ? state.bistQuotes : state.cryptoQuotes)
          .any((q) => q.instrument.symbol.toUpperCase() == clean);
      if (!hasQuote) {
        unawaited(fetchSingleQuote(isBist ? BistUniverse.instrumentFor(clean) : instrument));
      }
    }
  }

  /// Kullanıcının elle girdiği bir BIST hisse kodunu listeye ve favorilere ekler.
  Future<bool> addCustomBistSymbol(String rawSymbol) async {
    final clean = BistUniverse.normalizeSymbol(rawSymbol);
    if (clean.length < 3 ||
        clean.length > 6 ||
        !RegExp(r'^[A-Z0-9]+$').hasMatch(clean) ||
        CryptoUniverse.contains(clean)) {
      _showToast('Geçerli bir BIST hisse kodu girin (ör. THYAO)', positive: false);
      return false;
    }

    final favs = List<String>.from(state.settings.favoriteSymbols);
    if (!favs.any((s) => s.trim().toUpperCase() == clean)) {
      favs.add(clean);
    }
    final custom = List<String>.from(state.settings.customBistSymbols);
    if (!custom.any((s) => s.trim().toUpperCase() == clean)) {
      custom.add(clean);
    }

    await _applySettings(
      state.settings.copyWith(
        favoriteSymbols: List.unmodifiable(favs),
        customBistSymbols: List.unmodifiable(custom),
      ),
    );
    final ins = BistUniverse.instrumentFor(clean);
    _showToast('${ins.short} eklendi');

    if (enableLiveNetwork && !demoSeed && mounted) {
      unawaited(fetchSingleQuote(ins));
    }
    return true;
  }

  Future<void> toggleScanOnlyFavorites(bool value) async {
    await _applySettings(state.settings.copyWith(scanOnlyFavorites: value));
    _showToast(value ? 'Tarama: Yalnızca favori varlıklar' : 'Tarama: Tüm seçili varlıklar');
  }

  Future<void> toggleScanAllBistUniverse(bool value) async {
    await _applySettings(state.settings.copyWith(scanAllBistUniverse: value));
    _showToast(value ? 'BIST: Tüm hisse kataloğu taranacak' : 'BIST: Hızlı izleme listesi');
  }

  static String _formatQuickPrice(double v, Market m) {
    final prefix = m == Market.bist ? '₺' : '\$';
    final d = m == Market.bist ? 2 : (v >= 1000 ? 0 : (v >= 100 ? 2 : (v >= 1 ? 3 : 4)));
    return '$prefix${v.toStringAsFixed(d).replaceAll('.', ',')}';
  }

  /// Grafik okumaya gerek kalmadan tek bir BIST hissesi veya izinli kriptonun son fiyatını getirir.
  Future<LiveMarketQuote?> fetchSingleQuote(Instrument instrument) async {
    final isBist = instrument.market == Market.bist;
    final clean = isBist
        ? BistUniverse.normalizeSymbol(instrument.symbol)
        : instrument.symbol.trim().toUpperCase();
    if (clean.isEmpty) return null;
    if (!isBist && !CryptoUniverse.contains(clean)) {
      _showToast('Yalnızca listedeki 10 kripto sorgulanabilir', positive: false);
      return null;
    }

    final resolved = isBist ? BistUniverse.instrumentFor(clean) : instrument;
    if (demoSeed) {
      for (final q in isBist ? state.bistQuotes : state.cryptoQuotes) {
        if (q.instrument.symbol.toUpperCase() == clean) {
          _showToast('${resolved.short}: ${_formatQuickPrice(q.lastPrice, resolved.market)}');
          return q;
        }
      }
      _showToast('Örnek modda ${resolved.short} için ek veri indirilemez', positive: false);
      return null;
    }

    PusulaHttpFetcher? fetcher;
    try {
      final MarketDataService data;
      if (dataServiceFactory != null) {
        data = dataServiceFactory!();
      } else {
        fetcher = PusulaHttpFetcher();
        data = MarketDataService(
          providers: [BinanceProvider(fetcher), YahooProvider(fetcher), IsYatirimProvider(fetcher)],
          cache: storage.candleCache,
          limiter: RateLimiter(minGap: const Duration(milliseconds: 50), clock: _clock),
          clock: _clock,
        );
      }

      final interval = isBist ? BarInterval.d1 : BarInterval.h1;
      final s = await data.candles(resolved, interval, limit: 30, forceRefresh: true);
      if (s.closed.isEmpty) {
        _showToast('${resolved.short} için fiyat bulunamadı', positive: false);
        return null;
      }

      final now = _clock().toUtc();
      final c = s.closed;
      final double ref;
      if (isBist) {
        final hasIntraday = s.forming != null;
        ref = hasIntraday ? c.last.close : (c.length >= 2 ? c[c.length - 2].close : c.last.close);
      } else {
        ref = c.length > 24 ? c[c.length - 25].close : c.first.close;
      }

      final quote = LiveMarketQuote(
        instrument: resolved,
        lastPrice: s.lastPrice,
        changePct: ref > 0 ? (s.lastPrice / ref - 1.0) * 100.0 : 0.0,
        sourceLabel: isBist
            ? (s.source == 'isyatirim' ? 'İş Yatırım (gün sonu)' : 'Yahoo Finance')
            : (s.source == 'binance_futures'
                ? 'Binance Futures'
                : (s.source == 'yahoo' ? 'Yahoo Finance' : 'Binance Spot')),
        ageMinutes: s.ageAt(now).inMinutes.clamp(0, 99999),
        isStale: s.stale,
      );

      if (!mounted) return quote;
      if (isBist) {
        final updated = [
          for (final q in state.bistQuotes)
            if (q.instrument.symbol.toUpperCase() != clean) q,
        ];
        final insertIdx = (updated.isNotEmpty && updated.first.instrument.symbol == BistUniverse.benchmark.symbol) ? 1 : 0;
        updated.insert(insertIdx, quote);
        state = state.copyWith(
          bistQuotes: updated,
          statusMessage: state.statusMessage,
          scanProgress: state.scanProgress,
        );
      } else {
        final updated = [
          for (final q in state.cryptoQuotes)
            if (q.instrument.symbol.toUpperCase() != clean) q,
          quote,
        ];
        state = state.copyWith(
          cryptoQuotes: updated,
          statusMessage: state.statusMessage,
          scanProgress: state.scanProgress,
        );
      }
      _showToast('${resolved.short}: ${_formatQuickPrice(quote.lastPrice, resolved.market)}');
      return quote;
    } catch (e) {
      if (mounted) {
        _showToast('${resolved.short} fiyatı alınamadı (${e.runtimeType})', positive: false);
      }
      return null;
    } finally {
      fetcher?.close();
    }
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
    state = state.copyWith(
      recentNotifications: _mergedNotifications(),
      statusMessage: 'Yerel bildirim gönderildi: $body',
    );
  }

  /// Android pil optimizasyonu muafiyet penceresini açar ve zamanlama özetini yeniler.
  Future<void> requestBatteryExemption() async {
    await _scheduler.requestIgnoreBatteryOptimizations();
    final schedule = await _scheduler.syncSchedule(liveMonitorEnabled: state.settings.liveMonitorEnabled);
    if (mounted) {
      state = state.copyWith(scheduleSnapshot: schedule, statusMessage: state.statusMessage);
    }
  }

  /// Önceki strateji sürümüne tek dokunuşla geri alır (Faz 6.2).
  Future<void> rollbackStrategyVersion() async {
    final prev = await _versionStore.rollbackToPrevious();
    if (prev == null) return;
    await _applySettings(state.settings.copyWith(activeStrategyVersion: prev.version));
  }

  /// Kullanıcı ayarlarını varsayılan başlangıç değerlerine sıfırlar (Faz 7.3 çok kullanıcı denetimi).
  Future<void> resetSettingsToDefault() async {
    await _applySettings(const AppSettings());
  }

  /// GitHub Releases otomatik güncelleme deposunu kaydeder (`kullanici/depo`).
  Future<void> updateGitHubRepo(String repo) async {
    final clean = repo.trim();
    if (clean.isNotEmpty && !AppUpdateService.isValidGitHubRepo(clean)) {
      state = state.copyWith(
        updateState: state.updateState.copyWith(
          status: UpdateStatus.error,
          message: 'Depo adı "kullanici/depo" biçiminde olmalıdır.',
        ),
        statusMessage: state.statusMessage,
        scanProgress: state.scanProgress,
      );
      return;
    }
    await _applySettings(state.settings.copyWith(updateRepo: clean));
    if (clean.isEmpty) {
      if (!mounted) return;
      state = state.copyWith(
        updateState: state.updateState.copyWith(
          status: UpdateStatus.idle,
          clearRelease: true,
          clearProgress: true,
          clearMessage: true,
        ),
        statusMessage: state.statusMessage,
        scanProgress: state.scanProgress,
      );
    }
  }

  Future<void> toggleAutoCheckUpdates(bool value) async {
    await _applySettings(state.settings.copyWith(autoCheckUpdates: value));
  }

  /// GitHub Releases üzerinden yeni APK sürümü olup olmadığını denetler.
  Future<void> checkForAppUpdate({bool silent = false}) async {
    if (!mounted) return;
    final repo = state.settings.updateRepo.trim();
    if (repo.isEmpty) {
      if (!silent) {
        state = state.copyWith(
          updateState: state.updateState.copyWith(
            status: UpdateStatus.error,
            message: 'Önce Ayarlar → Uygulama Güncelleme bölümünden GitHub deposunu ("kullanici/depo") girin.',
          ),
          statusMessage: state.statusMessage,
          scanProgress: state.scanProgress,
        );
      }
      return;
    }

    if (!silent) {
      state = state.copyWith(
        updateState: state.updateState.copyWith(
          status: UpdateStatus.checking,
          clearProgress: true,
          message: 'GitHub Releases kontrol ediliyor…',
        ),
        statusMessage: state.statusMessage,
        scanProgress: state.scanProgress,
      );
    }

    try {
      final res = await _updater.checkLatest(repo: repo);
      if (!mounted) return;
      if (res.updateAvailable && res.latestRelease != null) {
        final rel = res.latestRelease!;
        state = state.copyWith(
          updateState: state.updateState.copyWith(
            status: UpdateStatus.available,
            currentVersion: res.currentVersion,
            availableRelease: rel,
            clearProgress: true,
            message: '${rel.version.label} sürümü hazır (${rel.sizeLabel}).',
          ),
          statusMessage: state.statusMessage,
          scanProgress: state.scanProgress,
        );
        _showToast('Güncelleme hazır · ${rel.version.label}');
      } else {
        state = state.copyWith(
          updateState: state.updateState.copyWith(
            status: silent ? UpdateStatus.idle : UpdateStatus.upToDate,
            currentVersion: res.currentVersion,
            clearRelease: true,
            clearProgress: true,
            message: silent ? null : 'Uygulama güncel (${res.currentVersion.label}).',
            clearMessage: silent,
          ),
          statusMessage: state.statusMessage,
          scanProgress: state.scanProgress,
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (silent) return;
      state = state.copyWith(
        updateState: state.updateState.copyWith(
          status: UpdateStatus.error,
          clearProgress: true,
          message: 'Güncelleme denetlenemedi (${e.runtimeType}). İnterneti ve repo adını kontrol edin.',
        ),
        statusMessage: state.statusMessage,
        scanProgress: state.scanProgress,
      );
    }
  }

  /// Bulunan yeni APK sürümünü indirir ve Android sistem yükleme ekranını açar.
  Future<void> downloadAndInstallUpdate() async {
    final release = state.updateState.availableRelease;
    if (!mounted || release == null) return;
    if (state.updateState.status == UpdateStatus.downloading) return;

    state = state.copyWith(
      updateState: state.updateState.copyWith(
        status: UpdateStatus.downloading,
        downloadProgress: 0.0,
        message: '${release.version.label} indiriliyor…',
      ),
      statusMessage: state.statusMessage,
      scanProgress: state.scanProgress,
    );

    try {
      final outcome = await _updater.downloadAndInstall(
        release,
        onProgress: (p) {
          if (!mounted) return;
          final snapped = (p * 20).floor() / 20.0;
          if (snapped != state.updateState.downloadProgress) {
            state = state.copyWith(
              updateState: state.updateState.copyWith(
                status: UpdateStatus.downloading,
                downloadProgress: snapped,
                message: '${release.version.label} indiriliyor… %${(p * 100).round()}',
              ),
              statusMessage: state.statusMessage,
              scanProgress: state.scanProgress,
            );
          }
        },
      );
      if (!mounted) return;
      if (outcome == UpdateStatus.permissionRequired) {
        state = state.copyWith(
          updateState: state.updateState.copyWith(
            status: UpdateStatus.permissionRequired,
            clearProgress: true,
            message: 'Açılan Android ayarlarından "Bu kaynaktan izin ver" seçeneğini açıp tekrar "İndir ve Güncelle"ye dokunun.',
          ),
          statusMessage: state.statusMessage,
          scanProgress: state.scanProgress,
        );
      } else {
        state = state.copyWith(
          updateState: state.updateState.copyWith(
            status: UpdateStatus.readyToInstall,
            downloadProgress: 1.0,
            message: 'Android kurulum ekranı açıldı. "Güncelle"ye dokunarak tamamlayın.',
          ),
          statusMessage: state.statusMessage,
          scanProgress: state.scanProgress,
        );
      }
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        updateState: state.updateState.copyWith(
          status: UpdateStatus.error,
          clearProgress: true,
          message: 'APK indirilemedi (${e.runtimeType}).',
        ),
        statusMessage: state.statusMessage,
        scanProgress: state.scanProgress,
      );
    }
  }
}
