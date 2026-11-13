import '../journal/signal_journal.dart';
import '../model/candle.dart';
import '../model/market.dart';
import '../util/clock.dart';
import 'confidence_score.dart';
import 'exit_plan.dart';
import 'monte_carlo.dart';
import 'multi_timeframe.dart';
import 'news_veto.dart';
import 'regime.dart';
import 'setups.dart';
import 'trading_costs.dart';
import 'whale_info.dart';

/// Huni aşaması kodları ve kullanıcıya gösterilen Türkçe etiketleri.
///
/// Reddedilen her aday hangi aşamada elendiğini taşır; ekranda "neden öneri yok?" sorusunun
/// dürüst cevabı bu etiketlerle verilir.
class FunnelStage {
  const FunnelStage._();

  static const String data = 'data';
  static const String scanner = 'scanner';
  static const String quality = 'quality';
  static const String news = 'news';
  static const String whale = 'whale';
  static const String mtf = 'mtf';
  static const String exit = 'exit';
  static const String cost = 'cost';
  static const String monteCarlo = 'monte_carlo';
  static const String confidence = 'confidence';
  static const String approved = 'approved';

  /// Tarama orkestratörünün (MarketScanner) eklediği aşamalar.
  static const String duplicate = 'duplicate';
  static const String cooldown = 'cooldown';
  static const String portfolio = 'portfolio';
  static const String fetch = 'fetch';

  static String label(String stage) {
    switch (stage) {
      case data:
        return 'Veri bayat / yetersiz';
      case scanner:
        return 'Kurulum yok';
      case quality:
        return 'Kurulum kalitesi zayıf';
      case news:
        return 'Haber vetosu';
      case whale:
        return 'Fonlama vetosu';
      case mtf:
        return 'Üst dilim ters';
      case exit:
        return 'Çıkış planı kurulamadı';
      case cost:
        return 'İşlem maliyeti riski yiyor';
      case monteCarlo:
        return 'Monte Carlo onaylamadı';
      case confidence:
        return 'Güven eşiği altında';
      case approved:
        return 'Onaylandı';
      case duplicate:
        return 'Zaten açık sinyal var';
      case cooldown:
        return 'Stop sonrası bekleme';
      case portfolio:
        return 'Eşzamanlı sinyal sınırı';
      case fetch:
        return 'Veri alınamadı';
      default:
        return stage;
    }
  }
}

/// Bir varlık için analiz hunisinin
/// (Veri → Scanner → Kalite → News → Whale → MTF → Exit → Maliyet → MonteCarlo → Confidence) çıktısı.
class SignalEvaluation {
  const SignalEvaluation({
    required this.series,
    required this.regime,
    required this.approved,
    required this.stage,
    required this.reason,
    this.detection,
    this.news,
    this.whale,
    this.mtf,
    this.plan,
    this.cost,
    this.monteCarlo,
    this.confidence,
    this.signalRecord,
  });

  final CandleSeries series;
  final RegimeReport regime;
  final bool approved;
  final String stage;
  final String reason;
  final SetupDetection? detection;
  final NewsReport? news;
  final WhaleReport? whale;
  final MultiTimeframeConfirmation? mtf;
  final ExitPlan? plan;
  final CostImpact? cost;
  final MonteCarloResult? monteCarlo;
  final ConfidenceBreakdown? confidence;
  final SignalRecord? signalRecord;

  /// Bir kurulum bulundu ama sonraki süzgeçlerden biri reddetti mi?
  bool get hadSetup => detection != null;
}

/// Analiz çekirdeğini uçtan uca koşturan orkestratör (strateji [kStrategyVersion]).
///
/// K9 iyileştirmeleri — "fırsat yoksa dürüstçe nakitte kal" ilkesi:
/// - **Veri tazeliği:** bayat seri veya çok eski son mumla sinyal üretilmez.
/// - **Kurulum kalitesi:** fiyat tetik seviyesinden çok uzaklaşmışsa (kovalama), kırılım mumu üst
///   fitille reddedilmişse veya kırılım ortalama altı hacimle geldiyse aday elenir.
/// - **İşlem maliyeti:** komisyon + kayma stop mesafesinin büyük kısmını yiyorsa aday elenir;
///   güven skoru net (maliyet sonrası) Ödül/Risk üzerinden hesaplanır.
/// - **Rejime duyarlı eşik:** Yatay ve Ayı rejiminde güven eşiği yükselir.
class SignalEngine {
  SignalEngine({
    this.strategyVersion = kStrategyVersion,
    this.scanner = const SetupScanner(),
    this.mtfAnalyzer = const MultiTimeframeAnalyzer(),
    this.exitPlanner = const ExitPlanner(),
    this.monteCarlo = const MonteCarloSimulator(),
    this.newsAnalyzer = const NewsAnalyzer(),
    this.whaleAnalyzer = const WhaleAnalyzer(),
    this.confidenceScorer = const ConfidenceScorer(),
    this.costs = const TradingCosts(),
    this.minConfidenceScore = 50,
    this.sidewaysConfidenceBump = 4,
    this.bearConfidenceBump = 8,
    this.maxExtensionAtr = 1.5,
    this.minBreakoutCloseLocation = 0.5,
    this.minBreakoutVolumeRatio = 1.0,
    this.maxCostShareOfRisk = 0.25,
    this.minNetRewardRisk = 1.3,
    Clock? clock,
  }) : _clock = clock ?? systemClock;

  final String strategyVersion;
  final SetupScanner scanner;
  final MultiTimeframeAnalyzer mtfAnalyzer;
  final ExitPlanner exitPlanner;
  final MonteCarloSimulator monteCarlo;
  final NewsAnalyzer newsAnalyzer;
  final WhaleAnalyzer whaleAnalyzer;
  final ConfidenceScorer confidenceScorer;
  final TradingCosts costs;

  /// Boğa rejiminde geçerli taban güven eşiği.
  final int minConfidenceScore;

  /// Yatay rejimde eşiğe eklenen puan (sahte kırılım riski).
  final int sidewaysConfidenceBump;

  /// Ayı rejiminde eşiğe eklenen puan (long-only strateji zayıf).
  final int bearConfidenceBump;

  /// Kapanışın tetik seviyesinden en fazla kaç ATR uzaklaşmış olabileceği (kovalama süzgeci).
  final double maxExtensionAtr;

  /// Kırılım mumunda kapanışın mum aralığındaki en düşük konumu (0 = dip, 1 = tepe).
  final double minBreakoutCloseLocation;

  /// Kırılım kurulumlarında en düşük hacim oranı (20 mum ortalamasına göre).
  final double minBreakoutVolumeRatio;

  /// İşlem maliyetinin 1R'ye en yüksek kabul edilebilir oranı.
  final double maxCostShareOfRisk;

  /// Maliyet sonrası en düşük kabul edilebilir Ödül/Risk.
  final double minNetRewardRisk;
  final Clock _clock;

  /// Bir dilim için "son kapanmış mum en fazla ne kadar eski olabilir" sınırı.
  ///
  /// Kripto 7/24 işlem görür: 3 mum veya 45 dk (hangisi büyükse). BIST seans dışı saatleri ve hafta
  /// sonunu kapsayacak şekilde: saatlikte 20 saat (gece + açılış öncesi), günlükte 4 gün (hafta sonu).
  static Duration maxSignalBarAge(Market market, BarInterval interval) {
    if (market == Market.bist) {
      return interval == BarInterval.d1 ? const Duration(days: 4) : const Duration(hours: 20);
    }
    final three = Duration(milliseconds: interval.ms * 3);
    return three > const Duration(minutes: 45) ? three : const Duration(minutes: 45);
  }

  /// Rejime göre geçerli güven eşiği.
  int confidenceThresholdFor(MarketRegime regime) {
    switch (regime) {
      case MarketRegime.bull:
        return minConfidenceScore;
      case MarketRegime.sideways:
        return minConfidenceScore + sidewaysConfidenceBump;
      case MarketRegime.bear:
        return minConfidenceScore + bearConfidenceBump;
    }
  }

  /// Verilen mum serisi ve bağlam bilgisiyle sinyali değerlendirir.
  SignalEvaluation evaluate({
    required CandleSeries signalSeries,
    required List<Candle> higherClosedBars,
    required RegimeReport regime,
    NewsReport? newsReport,
    double fundingRatePct = 0.01,
    double? orderbookBidAskRatio,
    double? previousDayClose,
    bool isWeeklyProposal = false,
    int? monteCarloSeed,
  }) {
    final ins = signalSeries.instrument;
    final now = _clock().toUtc();

    SignalEvaluation reject(
      String stage,
      String reason, {
      SetupDetection? detection,
      NewsReport? news,
      WhaleReport? whale,
      MultiTimeframeConfirmation? mtf,
      ExitPlan? plan,
      CostImpact? cost,
      MonteCarloResult? mc,
      ConfidenceBreakdown? confidence,
    }) =>
        SignalEvaluation(
          series: signalSeries,
          regime: regime,
          approved: false,
          stage: stage,
          reason: reason,
          detection: detection,
          news: news,
          whale: whale,
          mtf: mtf,
          plan: plan,
          cost: cost,
          monteCarlo: mc,
          confidence: confidence,
        );

    // 0. Veri tazeliği: bayat veya çok eski veriyle sinyal üretmek, olmayan bir fırsatı göstermektir.
    if (signalSeries.stale) {
      return reject(FunnelStage.data, 'Veri bayat (tüm kaynaklar başarısız, önbellekten okundu); sinyal üretilmedi');
    }
    var dataAgeBars = 0.0;
    if (signalSeries.closed.isNotEmpty) {
      final lastBarEnd = DateTime.fromMillisecondsSinceEpoch(
        signalSeries.closed.last.openTimeMs + signalSeries.interval.ms,
        isUtc: true,
      );
      final barAge = now.difference(lastBarEnd);
      final limit = maxSignalBarAge(ins.market, signalSeries.interval);
      if (barAge > limit) {
        return reject(
          FunnelStage.data,
          'Son kapanmış ${signalSeries.interval.code} mumu ${_fmtAge(barAge)} önce kapandı '
          '(sınır ${_fmtAge(limit)}); veri güncel değil',
        );
      }
      // Kalite cezası yalnızca 7/24 işleyen kriptoda anlamlıdır; BIST'te seans dışı saatler doğaldır.
      if (ins.market == Market.crypto && !barAge.isNegative) {
        dataAgeBars = barAge.inMilliseconds / signalSeries.interval.ms;
      }
    }

    // 1. Kurulum taraması (yalnızca kapanmış mumlarla; Ayı rejiminde kırılım kurulumları elenir)
    final detection = scanner.analyze(signalSeries, regime: regime.regime);
    if (detection == null) {
      return reject(FunnelStage.scanner, 'Kapanmış mumlarda uygun kurulum bulunamadı');
    }

    // 1b. Kurulum kalitesi: kovalama, fitil reddi ve hacimsiz kırılım süzgeci
    final qualityIssue = _qualityIssue(detection, signalSeries.closed.last);
    if (qualityIssue != null) {
      return reject(FunnelStage.quality, qualityIssue, detection: detection);
    }

    // 2. Haber vetosu
    final news = newsReport ?? newsAnalyzer.evaluateHeadlines(ins, const []);
    if (news.veto) {
      return reject(FunnelStage.news, news.vetoReason, detection: detection, news: news);
    }

    // 3. Balina ve fonlama kontrolü (emir defteri veto etmez, fonlama > %0.20 veto eder)
    final whale = whaleAnalyzer.evaluate(
      ins,
      signalSeries.closed,
      fundingRatePct: fundingRatePct,
      orderbookBidAskRatio: orderbookBidAskRatio,
    );
    if (whale.veto) {
      return reject(FunnelStage.whale, whale.vetoReason, detection: detection, news: news, whale: whale);
    }

    // 4. Çok zaman dilimli teyit
    final mtf = mtfAnalyzer.evaluate(
      market: ins.market,
      signalInterval: signalSeries.interval,
      higherClosedBars: higherClosedBars,
    );
    if (mtf.blocksBreakout && detection.primarySetup.isBreakout) {
      return reject(
        FunnelStage.mtf,
        'Üst zaman dilimi (${mtf.higherInterval.code}) düşüş trendinde; kırılım sinyali reddedildi',
        detection: detection,
        news: news,
        whale: whale,
        mtf: mtf,
      );
    }

    // 5. Çıkış planı
    final ExitPlan plan;
    try {
      plan = exitPlanner.build(detection, previousDayClose: previousDayClose);
    } on ExitPlanException catch (e) {
      return reject(FunnelStage.exit, e.message, detection: detection, news: news, whale: whale, mtf: mtf);
    }

    // 5b. İşlem maliyeti: dar stopta komisyon + kayma beklenen getiriyi siler
    final cost = costs.impact(plan);
    if (cost.costShareOfRisk > maxCostShareOfRisk || cost.netRewardRisk < minNetRewardRisk) {
      return reject(
        FunnelStage.cost,
        'İşlem maliyeti (~%${cost.roundTripCostPct.toStringAsFixed(2)}) stop mesafesinin '
        '(%${plan.stopDistancePct.toStringAsFixed(2)}) %${(cost.costShareOfRisk * 100).toStringAsFixed(0)} kadarını yiyor; '
        'net Ödül/Risk ${cost.netRewardRisk.toStringAsFixed(2)}',
        detection: detection,
        news: news,
        whale: whale,
        mtf: mtf,
        plan: plan,
        cost: cost,
      );
    }

    // 6. Monte Carlo süzgeci (blok önyükleme)
    final MonteCarloResult mc;
    try {
      mc = monteCarlo.simulate(plan, signalSeries.closed, overrideSeed: monteCarloSeed);
    } on MonteCarloException catch (e) {
      return reject(
        FunnelStage.monteCarlo,
        e.message,
        detection: detection,
        news: news,
        whale: whale,
        mtf: mtf,
        plan: plan,
        cost: cost,
      );
    }

    if (!mc.approved) {
      return reject(
        FunnelStage.monteCarlo,
        'Monte Carlo süzgeci onaylamadı: ${mc.verdict}',
        detection: detection,
        news: news,
        whale: whale,
        mtf: mtf,
        plan: plan,
        cost: cost,
        mc: mc,
      );
    }

    // 7. Güven skoru (0–100) — net Ödül/Risk ve kalite düzeltmesiyle
    final conf = confidenceScorer.score(
      detection: detection,
      regime: regime,
      mtf: mtf,
      plan: plan,
      monteCarlo: mc,
      netRewardRisk: cost.netRewardRisk,
      costShareOfRisk: cost.costShareOfRisk,
      dataAgeBars: dataAgeBars,
    );

    final threshold = confidenceThresholdFor(regime.regime);
    if (conf.total < threshold) {
      return reject(
        FunnelStage.confidence,
        'Güven skoru eşik altında (${conf.total} < $threshold, ${regime.regime.label} rejimi)',
        detection: detection,
        news: news,
        whale: whale,
        mtf: mtf,
        plan: plan,
        cost: cost,
        mc: mc,
        confidence: conf,
      );
    }

    final ageMs = signalSeries.ageAt(now).inMilliseconds;
    final id = '${ins.id}|${signalSeries.interval.code}|${detection.lastClosedBarTime.millisecondsSinceEpoch}';

    final record = SignalRecord(
      id: id,
      instrument: ins,
      interval: signalSeries.interval,
      strategy: detection.primarySetup,
      allSetups: detection.setups,
      strategyVersion: strategyVersion,
      entryZoneLow: plan.entryZoneLow,
      entryZoneHigh: plan.entryZoneHigh,
      entryPrice: plan.entryPrice,
      initialStop: plan.stop,
      currentStop: plan.stop,
      target1: plan.target1,
      target2: plan.target2,
      rewardRisk: plan.rewardRisk,
      confidence: conf,
      rationale: '${detection.rationale} ${mtf.summary}. ${mc.verdict}. '
          'Maliyet sonrası net Ö/R ${cost.netRewardRisk.toStringAsFixed(2)}.',
      invalidationRule: plan.invalidationRule,
      regime: regime.regime,
      dataSource: signalSeries.source,
      dataAgeMs: ageMs < 0 ? 0 : ageMs,
      dataStale: signalSeries.stale,
      createdAt: now,
      expiresAt: now.add(plan.maxHoldDuration),
      status: SignalStatus.open,
      isWeeklyProposal: isWeeklyProposal,
      lastProcessedBarTimeMs: detection.lastClosedBarTime.millisecondsSinceEpoch,
    );

    return SignalEvaluation(
      series: signalSeries,
      regime: regime,
      approved: true,
      stage: FunnelStage.approved,
      reason: 'Sinyal onaylandı (Güven: ${conf.total}/100)',
      detection: detection,
      news: news,
      whale: whale,
      mtf: mtf,
      plan: plan,
      cost: cost,
      monteCarlo: mc,
      confidence: conf,
      signalRecord: record,
    );
  }

  /// Kurulum kalitesini denetler; sorun varsa Türkçe gerekçe döner, yoksa `null`.
  String? _qualityIssue(SetupDetection det, Candle lastBar) {
    final atr = det.atr14 > 0 ? det.atr14 : det.lastClose * 0.008;

    // a) Kovalama: kapanış tetik seviyesinin çok üstündeyse giriş bölgesi kaçmıştır.
    final extension = det.lastClose - det.triggerLevel;
    if (det.triggerLevel > 0 && extension > atr * maxExtensionAtr) {
      return 'Fiyat tetik seviyesinden ${(extension / atr).toStringAsFixed(1)} ATR uzaklaşmış '
          '(sınır ${maxExtensionAtr.toStringAsFixed(1)}); kovalamak yerine beklenir';
    }

    if (det.primarySetup.isBreakout) {
      // b) Fitil reddi: kırılım mumu aralığının alt yarısında kapandıysa alıcı kontrolü yok.
      final range = lastBar.high - lastBar.low;
      if (range > 0) {
        final location = (lastBar.close - lastBar.low) / range;
        if (location < minBreakoutCloseLocation) {
          return 'Kırılım mumu üst fitille reddedildi (kapanış mum aralığının '
              '%${(location * 100).toStringAsFixed(0)} seviyesinde)';
        }
      }
      // c) Hacimsiz kırılım.
      if (det.volumeRatio < minBreakoutVolumeRatio) {
        return 'Kırılım ortalama altı hacimle geldi (${det.volumeRatio.toStringAsFixed(2)}x); teyit yok';
      }
    }
    return null;
  }

  static String _fmtAge(Duration d) {
    if (d.inHours >= 48) return '${d.inDays} gün';
    if (d.inMinutes >= 120) return '${d.inHours} saat';
    return '${d.inMinutes} dk';
  }
}
