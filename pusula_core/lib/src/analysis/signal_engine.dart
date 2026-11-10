import '../journal/signal_journal.dart';
import '../model/candle.dart';
import '../util/clock.dart';
import 'confidence_score.dart';
import 'exit_plan.dart';
import 'monte_carlo.dart';
import 'multi_timeframe.dart';
import 'news_veto.dart';
import 'regime.dart';
import 'setups.dart';
import 'whale_info.dart';

/// Bir varlık için analiz hunisinin (Scanner → News → Whale → MTF → Exit → MonteCarlo → Confidence) çıktısı.
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
  final MonteCarloResult? monteCarlo;
  final ConfidenceBreakdown? confidence;
  final SignalRecord? signalRecord;
}

/// Faz 2 analiz çekirdeğini uçtan uca koşturan orkestratör.
class SignalEngine {
  SignalEngine({
    this.strategyVersion = '2.0.0',
    this.scanner = const SetupScanner(),
    this.mtfAnalyzer = const MultiTimeframeAnalyzer(),
    this.exitPlanner = const ExitPlanner(),
    this.monteCarlo = const MonteCarloSimulator(),
    this.newsAnalyzer = const NewsAnalyzer(),
    this.whaleAnalyzer = const WhaleAnalyzer(),
    this.confidenceScorer = const ConfidenceScorer(),
    this.minConfidenceScore = 50,
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
  final int minConfidenceScore;
  final Clock _clock;

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

    // 1. Kurulum taraması (yalnızca kapanmış mumlarla; Ayı rejiminde kırılım kurulumları elenir)
    final detection = scanner.analyze(signalSeries, regime: regime.regime);
    if (detection == null) {
      return SignalEvaluation(
        series: signalSeries,
        regime: regime,
        approved: false,
        stage: 'scanner',
        reason: 'Kapanmış mumlarda uygun kurulum bulunamadı',
      );
    }

    // 2. Haber vetosu
    final news = newsReport ?? newsAnalyzer.evaluateHeadlines(ins, const []);
    if (news.veto) {
      return SignalEvaluation(
        series: signalSeries,
        regime: regime,
        approved: false,
        stage: 'news',
        reason: news.vetoReason,
        detection: detection,
        news: news,
      );
    }

    // 3. Balina ve fonlama kontrolü (emir defteri veto etmez, fonlama > %0.20 veto eder)
    final whale = whaleAnalyzer.evaluate(
      ins,
      signalSeries.closed,
      fundingRatePct: fundingRatePct,
      orderbookBidAskRatio: orderbookBidAskRatio,
    );
    if (whale.veto) {
      return SignalEvaluation(
        series: signalSeries,
        regime: regime,
        approved: false,
        stage: 'whale',
        reason: whale.vetoReason,
        detection: detection,
        news: news,
        whale: whale,
      );
    }

    // 4. Çok zaman dilimli teyit
    final mtf = mtfAnalyzer.evaluate(
      market: ins.market,
      signalInterval: signalSeries.interval,
      higherClosedBars: higherClosedBars,
    );
    if (mtf.blocksBreakout && detection.primarySetup.isBreakout) {
      return SignalEvaluation(
        series: signalSeries,
        regime: regime,
        approved: false,
        stage: 'mtf',
        reason: 'Üst zaman dilimi (${mtf.higherInterval.code}) düşüş trendinde; kırılım sinyali reddedildi',
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
      return SignalEvaluation(
        series: signalSeries,
        regime: regime,
        approved: false,
        stage: 'exit',
        reason: e.message,
        detection: detection,
        news: news,
        whale: whale,
        mtf: mtf,
      );
    }

    // 6. Monte Carlo süzgeci (blok önyükleme)
    final MonteCarloResult mc;
    try {
      mc = monteCarlo.simulate(plan, signalSeries.closed, overrideSeed: monteCarloSeed);
    } on MonteCarloException catch (e) {
      return SignalEvaluation(
        series: signalSeries,
        regime: regime,
        approved: false,
        stage: 'monte_carlo',
        reason: e.message,
        detection: detection,
        news: news,
        whale: whale,
        mtf: mtf,
        plan: plan,
      );
    }

    if (!mc.approved) {
      return SignalEvaluation(
        series: signalSeries,
        regime: regime,
        approved: false,
        stage: 'monte_carlo',
        reason: 'Monte Carlo süzgeci onaylamadı: ${mc.verdict}',
        detection: detection,
        news: news,
        whale: whale,
        mtf: mtf,
        plan: plan,
        monteCarlo: mc,
      );
    }

    // 7. Güven skoru (0–100)
    final conf = confidenceScorer.score(
      detection: detection,
      regime: regime,
      mtf: mtf,
      plan: plan,
      monteCarlo: mc,
    );

    if (conf.total < minConfidenceScore) {
      return SignalEvaluation(
        series: signalSeries,
        regime: regime,
        approved: false,
        stage: 'confidence',
        reason: 'Güven skoru eşik altında (${conf.total} < $minConfidenceScore)',
        detection: detection,
        news: news,
        whale: whale,
        mtf: mtf,
        plan: plan,
        monteCarlo: mc,
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
      rationale: '${detection.rationale} ${mtf.summary}. ${mc.verdict}.',
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
      stage: 'approved',
      reason: 'Sinyal onaylandı (Güven: ${conf.total}/100)',
      detection: detection,
      news: news,
      whale: whale,
      mtf: mtf,
      plan: plan,
      monteCarlo: mc,
      confidence: conf,
      signalRecord: record,
    );
  }
}
