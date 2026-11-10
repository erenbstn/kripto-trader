import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pusula_core/pusula_core.dart';

import '../background/background_scheduler.dart';
import '../notifications/notification_engine.dart';
import '../storage/app_settings.dart';
import '../storage/sqlite_storage.dart';
import '../theme/gunduz_theme.dart';
import '../widgets/donut_3d_chart.dart';

/// Tek bir varlığın canlı piyasa fiyat özeti (Özet ve Sinyal ekranlarında gösterilir).
class LiveMarketQuote {
  const LiveMarketQuote({
    required this.instrument,
    required this.lastPrice,
    required this.changePct,
    required this.sourceLabel,
    required this.ageMinutes,
    required this.isStale,
  });

  final Instrument instrument;
  final double lastPrice;
  final double changePct;
  final String sourceLabel;
  final int ageMinutes;
  final bool isStale;
}

/// Web (Chrome) ve Android uyumlu HTTP istemcisi.
/// Android'de doğrudan hedefe bağlanır; Web (Chrome) üzerinde Yahoo Finance ve İş Yatırım
/// CORS kısıtlamasına takılmamak için önce yerel PC köprüsünü (127.0.0.1:8787) dener.
class PusulaHttpFetcher implements HttpFetcher {
  PusulaHttpFetcher({NetworkHttpFetcher? delegate})
      : _delegate = delegate ?? NetworkHttpFetcher(sendUserAgent: !kIsWeb);

  final NetworkHttpFetcher _delegate;

  static const Set<String> _corsRestrictedWebHosts = {
    'query1.finance.yahoo.com',
    'query2.finance.yahoo.com',
    'www.isyatirim.com.tr',
  };

  @override
  Future<String> getText(
    Uri uri, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    if (kIsWeb && _corsRestrictedWebHosts.contains(uri.host)) {
      final proxyUri = Uri.parse(
        'http://127.0.0.1:8787/proxy?url=${Uri.encodeComponent(uri.toString())}',
      );
      try {
        return await _delegate.getText(proxyUri, headers: headers, timeout: timeout);
      } catch (_) {
        // Yerel köprü çalışmıyorsa doğrudan isteği dene.
      }
    }
    return _delegate.getText(uri, headers: headers, timeout: timeout);
  }

  void close() => _delegate.close();
}

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
    List<LiveMarketQuote>? cryptoQuotes,
    List<LiveMarketQuote>? bistQuotes,
    List<LocalNotificationItem>? recentNotifications,
    List<ProviderHealth>? providerHealthList,
    BackgroundScheduleSnapshot? scheduleSnapshot,
    StrategyOptimizationProposal? optimizationProposal,
    bool? isLoading,
    DateTime? lastRefreshedAt,
    String? statusMessage,
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

final pusulaControllerProvider = StateNotifierProvider<PusulaController, PusulaAppState>((ref) {
  final storage = ref.watch(storageBundleProvider);
  final gateway = ref.watch(notificationGatewayProvider);
  final enableLive = ref.watch(liveNetworkEnabledProvider);
  return PusulaController(
    storage: storage,
    notificationGateway: gateway,
    enableLiveNetwork: enableLive,
  );
});

class PusulaController extends StateNotifier<PusulaAppState> {
  PusulaController({
    required this.storage,
    required LocalNotificationGateway notificationGateway,
    this.enableLiveNetwork = false,
    Clock? clock,
  })  : _clock = clock ?? (() => DateTime.now().toUtc()),
        _notificationCoordinator = NotificationCoordinator(
          gateway: notificationGateway,
          clock: clock ?? (() => DateTime.now().toUtc()),
        ),
        _scheduler = BackgroundScheduler(
          clock: clock ?? (() => DateTime.now().toUtc()),
        ),
        super(_buildInitialSeedState(clock ?? (() => DateTime.now().toUtc()))) {
    _init();
  }

  final StorageBundle storage;
  final bool enableLiveNetwork;
  final Clock _clock;
  final NotificationCoordinator _notificationCoordinator;
  final BackgroundScheduler _scheduler;
  final StrategyVersionStore _versionStore = MemoryStrategyVersionStore();

  /// Eski hatalı tohum (seed) kimlikleri; SQLite'ta bunlardan biri varsa temizlenir.
  static const Set<String> _legacyStaleSeedIds = {
    'sig_thyao_w1',
    'sig_asels_w1',
    'sig_sol_w1',
    'sig_btc_w1',
    'sig_link_closed',
    'sig_akbnk_closed',
  };

  /// Canlı izlenen başlıca BIST hisseleri ve endeks.
  static const List<Instrument> watchedBistInstruments = [
    BistUniverse.benchmark,
    Instrument.bist('THYAO', name: 'Türk Hava Yolları'),
    Instrument.bist('ASELS', name: 'Aselsan'),
    Instrument.bist('AKBNK', name: 'Akbank'),
    Instrument.bist('GARAN', name: 'Garanti BBVA'),
    Instrument.bist('TUPRS', name: 'Tüpraş'),
    Instrument.bist('BIMAS', name: 'BİM Mağazaları'),
    Instrument.bist('KCHOL', name: 'Koç Holding'),
    Instrument.bist('ISCTR', name: 'İş Bankası (C)'),
    Instrument.bist('SAHOL', name: 'Sabancı Holding'),
    Instrument.bist('EREGL', name: 'Erdemir'),
    Instrument.bist('SISE', name: 'Şişecam'),
    Instrument.bist('TCELL', name: 'Turkcell'),
    Instrument.bist('PGSUS', name: 'Pegasus'),
    Instrument.bist('ASTOR', name: 'Astor Enerji'),
    Instrument.bist('FROTO', name: 'Ford Otosan'),
    Instrument.bist('EKGYO', name: 'Emlak Konut GYO'),
  ];

  Future<void> _init() async {
    await _hydrateFromStorage();
    if (enableLiveNetwork && mounted) {
      await refreshLiveMarketData();
    }
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
          'Hiçbir strateji henüz 30 kapanmış sinyal eşiğine ulaşmadı. Aşırı uyum (overfitting) yasağı gereği tüm parametreler v2.0.0 sürümünde korundu.',
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
    );
  }

  Future<void> _hydrateFromStorage() async {
    final loadedSettings = await storage.settingsStore.load();
    final existingSignals = await storage.journalStore.allSignals();
    final hasLegacyStaleSeed = existingSignals.any((s) => _legacyStaleSeedIds.contains(s.id));

    if (existingSignals.isEmpty || hasLegacyStaleSeed) {
      if (hasLegacyStaleSeed) {
        await storage.journalStore.clear();
        await storage.reportStore.clear();
      }
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

  /// Binance, Yahoo Finance ve İş Yatırım üzerinden canlı BIST ve Kripto verilerini çeker,
  /// fiyatları ve aktif sinyal seviyelerini güncel piyasa verileriyle yeniler.
  Future<void> refreshLiveMarketData() async {
    if (!mounted) return;
    state = state.copyWith(
      isLoading: true,
      statusMessage: 'Canlı BIST ve Kripto fiyatları güncelleniyor...',
    );

    final httpFetcher = PusulaHttpFetcher();
    final marketSvc = MarketDataService(
      providers: [
        BinanceProvider(httpFetcher),
        YahooProvider(httpFetcher),
        IsYatirimProvider(httpFetcher),
      ],
      cache: storage.candleCache,
      clock: _clock,
    );

    final now = _clock().toUtc();
    final liveSeriesBySymbol = <String, CandleSeries>{};
    final updatedCryptoQuotes = <LiveMarketQuote>[];
    final updatedBistQuotes = <LiveMarketQuote>[];

    // 1. Kripto Evreni (10 sabit sembol) — Binance canlı veri
    for (final ins in CryptoUniverse.instruments) {
      try {
        final s = await marketSvc.candles(ins, BarInterval.h1, limit: 60, forceRefresh: true);
        liveSeriesBySymbol[ins.symbol] = s;
        final prevClose = s.closed.length >= 2 ? s.closed[s.closed.length - 2].close : s.lastPrice;
        final chg = prevClose > 0 ? ((s.lastPrice / prevClose) - 1.0) * 100.0 : 0.0;
        updatedCryptoQuotes.add(
          LiveMarketQuote(
            instrument: ins,
            lastPrice: s.lastPrice,
            changePct: chg,
            sourceLabel: s.source == 'binance_futures' ? 'Binance Futures' : 'Binance Spot',
            ageMinutes: s.ageAt(now).inMinutes.clamp(0, 999),
            isStale: s.stale,
          ),
        );
      } catch (_) {
        final fallback = state.cryptoQuotes.where((q) => q.instrument.symbol == ins.symbol).firstOrNull;
        if (fallback != null) updatedCryptoQuotes.add(fallback);
      }
    }

    // 2. BIST İzleme Listesi — Yahoo Finance (.IS) ve İş Yatırım canlı/gecikmeli veri
    for (final ins in watchedBistInstruments) {
      try {
        final s = await marketSvc.candles(ins, BarInterval.d1, limit: 60, forceRefresh: true);
        liveSeriesBySymbol[ins.symbol] = s;
        final prevClose = s.closed.length >= 2 ? s.closed[s.closed.length - 2].close : s.lastPrice;
        final chg = prevClose > 0 ? ((s.lastPrice / prevClose) - 1.0) * 100.0 : 0.0;
        updatedBistQuotes.add(
          LiveMarketQuote(
            instrument: ins,
            lastPrice: s.lastPrice,
            changePct: chg,
            sourceLabel: s.source == 'isyatirim' ? 'İş Yatırım (Gün Sonu)' : 'Yahoo Finance (~15 dk)',
            ageMinutes: s.ageAt(now).inMinutes.clamp(15, 9999),
            isStale: s.stale,
          ),
        );
      } catch (_) {
        final fallback = state.bistQuotes.where((q) => q.instrument.symbol == ins.symbol).firstOrNull;
        if (fallback != null) updatedBistQuotes.add(fallback);
      }
    }

    httpFetcher.close();
    if (!mounted) return;

    // 3. Aktif sinyallerin giriş/stop/hedef seviyelerini çekilen gerçek canlı fiyat ve ATR ile güncelle
    final updatedAllSignals = <SignalRecord>[];
    for (final sig in state.allSignals) {
      final liveSeries = liveSeriesBySymbol[sig.instrument.symbol];
      if (liveSeries == null || liveSeries.lastPrice <= 0) {
        updatedAllSignals.add(sig);
        continue;
      }
      final livePrice = liveSeries.lastPrice;
      final isBist = sig.instrument.market == Market.bist;
      final atr = liveSeries.closed.length >= 15
          ? Indicators.computeAtr(liveSeries.closed, period: 14)
          : livePrice * (isBist ? 0.025 : 0.018);

      double roundPrice(double v) {
        if (isBist) return BistRules.roundToTick(v);
        if (v >= 1000) return double.parse(v.toStringAsFixed(2));
        if (v >= 10) return double.parse(v.toStringAsFixed(2));
        if (v >= 1) return double.parse(v.toStringAsFixed(4));
        return double.parse(v.toStringAsFixed(6));
      }

      if (sig.isActive) {
        final entry = roundPrice(livePrice);
        final band = (atr * 0.25).clamp(entry * 0.003, entry * 0.012);
        final zoneLow = roundPrice(entry - band);
        final zoneHigh = roundPrice(entry + band);
        final riskDist = (atr * 1.6).clamp(entry * 0.022, entry * 0.045);
        final stop = roundPrice(entry - riskDist);
        final actualRisk = (entry - stop) > 0 ? (entry - stop) : entry * 0.03;
        final t1 = roundPrice(entry + actualRisk * 1.0);
        final t2 = roundPrice(entry + actualRisk * 2.0);
        final ageMs = liveSeries.ageAt(now).inMilliseconds.clamp(0, 86400000);
        final srcLabel = liveSeries.source == 'yahoo'
            ? 'Yahoo Finance'
            : (liveSeries.source == 'isyatirim' ? 'İş Yatırım' : 'Binance Spot');

        updatedAllSignals.add(
          SignalRecord(
            id: sig.id,
            instrument: sig.instrument,
            interval: sig.interval,
            strategy: sig.strategy,
            allSetups: sig.allSetups,
            strategyVersion: sig.strategyVersion,
            entryZoneLow: zoneLow,
            entryZoneHigh: zoneHigh,
            entryPrice: entry,
            initialStop: stop,
            currentStop: stop,
            target1: t1,
            target2: t2,
            rewardRisk: 2.0,
            confidence: sig.confidence,
            rationale:
                '${sig.strategy.label} · Canlı fiyat ${entry.toStringAsFixed(2).replaceAll('.', ',')} ${sig.instrument.currency} ($srcLabel).',
            invalidationRule: '${stop.toStringAsFixed(2).replaceAll('.', ',')} ${sig.instrument.currency} altı kapanış kurulumu geçersiz kılar.',
            regime: sig.regime,
            dataSource: srcLabel,
            dataAgeMs: ageMs,
            dataStale: liveSeries.stale,
            createdAt: sig.createdAt,
            expiresAt: sig.expiresAt,
            status: sig.status,
            isWeeklyProposal: sig.isWeeklyProposal,
            allocatedWeightPct: sig.allocatedWeightPct,
          ),
        );
      } else {
        updatedAllSignals.add(sig);
      }
    }

    final updatedActive = updatedAllSignals.where((s) => s.isActive).toList();
    const allocator = PortfolioWeightAllocator();
    final updatedAllocation = allocator.allocate(
      updatedActive,
      appetite: state.settings.riskAppetite,
      totalBudget: state.settings.budgetAmount,
    );

    final updatedReport = WeeklyReport(
      id: state.currentReport.id,
      weekStart: state.currentReport.weekStart,
      weekEnd: now,
      generatedAt: now,
      lastWeekReview: state.currentReport.lastWeekReview,
      shortTermReport: state.currentReport.shortTermReport,
      newAllocation: updatedAllocation,
    );

    for (final s in updatedAllSignals) {
      await storage.journalStore.save(s);
    }
    await storage.reportStore.save(updatedReport);

    if (!mounted) return;
    state = state.copyWith(
      allSignals: updatedAllSignals,
      activeSignals: updatedActive,
      currentReport: updatedReport,
      cryptoQuotes: updatedCryptoQuotes.isNotEmpty ? updatedCryptoQuotes : state.cryptoQuotes,
      bistQuotes: updatedBistQuotes.isNotEmpty ? updatedBistQuotes : state.bistQuotes,
      providerHealthList: marketSvc.health.any((h) => h.successCount > 0 || h.failureCount > 0)
          ? marketSvc.health
          : state.providerHealthList,
      isLoading: false,
      lastRefreshedAt: now,
      statusMessage: 'Canlı veriler güncellendi (${liveSeriesBySymbol.length} varlık).',
    );
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
}
