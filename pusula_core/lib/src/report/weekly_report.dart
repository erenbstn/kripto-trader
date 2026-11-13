import '../journal/signal_journal.dart';
import '../model/market.dart';
import 'weighting.dart';

/// Sabit yasal uyarı metni (Kısıt 7).
const String kLegalDisclaimer =
    'Yatırım tavsiyesi değildir. Bu sistem borsa/aracı kurum emri açmaz; yalnızca ileriye dönük teknik analiz ve sinyal üretir.';

/// Geçen hafta önerilen tek bir varlığın gerçekleşen sonucu.
class LastWeekAssetOutcome {
  const LastWeekAssetOutcome({
    required this.instrument,
    required this.strategyCode,
    required this.weightPct,
    required this.entryPrice,
    required this.exitOrCurrentPrice,
    required this.realizedPct,
    required this.realizedR,
    required this.weightedContributionPct,
    required this.status,
    required this.note,
  });

  final Instrument instrument;
  final String strategyCode;
  final double weightPct;
  final double entryPrice;
  final double exitOrCurrentPrice;
  final double realizedPct;
  final double realizedR;

  /// Portföy toplam getirisine katkısı: `weightPct * realizedPct / 100` (%).
  final double weightedContributionPct;
  final SignalStatus status;
  final String note;

  bool get hitTarget => status == SignalStatus.target2 || status == SignalStatus.target1;
  bool get hitStop => status == SignalStatus.stop && !note.contains('başabaş');

  Map<String, Object?> toJson() => {
        'instrument': instrument.id,
        'strategyCode': strategyCode,
        'weightPct': weightPct,
        'entryPrice': entryPrice,
        'exitOrCurrentPrice': exitOrCurrentPrice,
        'realizedPct': realizedPct,
        'realizedR': realizedR,
        'weightedContributionPct': weightedContributionPct,
        'status': status.name,
        'note': note,
      };

  static LastWeekAssetOutcome fromJson(Map<String, Object?> j) => LastWeekAssetOutcome(
        instrument: Instrument.parseId(j['instrument'] as String),
        strategyCode: j['strategyCode'] as String,
        weightPct: (j['weightPct'] as num).toDouble(),
        entryPrice: (j['entryPrice'] as num).toDouble(),
        exitOrCurrentPrice: (j['exitOrCurrentPrice'] as num).toDouble(),
        realizedPct: (j['realizedPct'] as num).toDouble(),
        realizedR: (j['realizedR'] as num).toDouble(),
        weightedContributionPct: (j['weightedContributionPct'] as num).toDouble(),
        status: SignalStatus.values.byName(j['status'] as String),
        note: j['note'] as String,
      );
}

/// 1. Bölüm: Geçen Hafta Raporu.
/// Kayıt yoksa "Geçen hafta raporu: henüz veri yok" döner; asla veri uydurulmaz (Kısıt 2).
class LastWeekReview {
  const LastWeekReview({
    required this.hasData,
    required this.emptyMessage,
    required this.outcomes,
    required this.weightedPortfolioReturnPct,
    required this.targetsHit,
    required this.stopsHit,
    required this.winRatePct,
    required this.lessonsLearned,
    this.bestOutcome,
    this.worstOutcome,
  });

  const LastWeekReview.empty([this.emptyMessage = 'Geçen hafta raporu: henüz veri yok'])
      : hasData = false,
        outcomes = const [],
        weightedPortfolioReturnPct = 0.0,
        targetsHit = const [],
        stopsHit = const [],
        winRatePct = 0.0,
        lessonsLearned = const [],
        bestOutcome = null,
        worstOutcome = null;

  final bool hasData;
  final String emptyMessage;
  final List<LastWeekAssetOutcome> outcomes;
  final double weightedPortfolioReturnPct;
  final List<String> targetsHit;
  final List<String> stopsHit;
  final double winRatePct;
  final LastWeekAssetOutcome? bestOutcome;
  final LastWeekAssetOutcome? worstOutcome;
  final List<String> lessonsLearned;

  Map<String, Object?> toJson() => {
        'hasData': hasData,
        'emptyMessage': emptyMessage,
        'outcomes': [for (final o in outcomes) o.toJson()],
        'weightedPortfolioReturnPct': weightedPortfolioReturnPct,
        'targetsHit': targetsHit,
        'stopsHit': stopsHit,
        'winRatePct': winRatePct,
        'bestOutcome': bestOutcome?.toJson(),
        'worstOutcome': worstOutcome?.toJson(),
        'lessonsLearned': lessonsLearned,
      };

  static LastWeekReview fromJson(Map<String, Object?> j) {
    if (!(j['hasData'] as bool? ?? false)) {
      return LastWeekReview.empty((j['emptyMessage'] as String?) ?? 'Geçen hafta raporu: henüz veri yok');
    }
    return LastWeekReview(
      hasData: true,
      emptyMessage: (j['emptyMessage'] as String?) ?? '',
      outcomes: [
        for (final o in (j['outcomes'] as List? ?? const []))
          LastWeekAssetOutcome.fromJson((o as Map).cast<String, Object?>()),
      ],
      weightedPortfolioReturnPct: (j['weightedPortfolioReturnPct'] as num).toDouble(),
      targetsHit: [for (final s in (j['targetsHit'] as List? ?? const [])) '$s'],
      stopsHit: [for (final s in (j['stopsHit'] as List? ?? const [])) '$s'],
      winRatePct: (j['winRatePct'] as num).toDouble(),
      bestOutcome: j['bestOutcome'] == null
          ? null
          : LastWeekAssetOutcome.fromJson((j['bestOutcome'] as Map).cast<String, Object?>()),
      worstOutcome: j['worstOutcome'] == null
          ? null
          : LastWeekAssetOutcome.fromJson((j['worstOutcome'] as Map).cast<String, Object?>()),
      lessonsLearned: [for (final l in (j['lessonsLearned'] as List? ?? const [])) '$l'],
    );
  }
}

/// Kısa vadeli sinyallerde strateji bazında performans kırılımı.
class StrategyBreakdownItem {
  const StrategyBreakdownItem({
    required this.strategyCode,
    required this.strategyLabel,
    required this.signalCount,
    required this.closedCount,
    required this.winRatePct,
    required this.avgR,
    required this.totalReturnPct,
  });

  final String strategyCode;
  final String strategyLabel;
  final int signalCount;
  final int closedCount;
  final double winRatePct;
  final double avgR;
  final double totalReturnPct;

  Map<String, Object?> toJson() => {
        'strategyCode': strategyCode,
        'strategyLabel': strategyLabel,
        'signalCount': signalCount,
        'closedCount': closedCount,
        'winRatePct': winRatePct,
        'avgR': avgR,
        'totalReturnPct': totalReturnPct,
      };

  static StrategyBreakdownItem fromJson(Map<String, Object?> j) => StrategyBreakdownItem(
        strategyCode: j['strategyCode'] as String,
        strategyLabel: j['strategyLabel'] as String,
        signalCount: (j['signalCount'] as num).toInt(),
        closedCount: (j['closedCount'] as num).toInt(),
        winRatePct: (j['winRatePct'] as num).toDouble(),
        avgR: (j['avgR'] as num).toDouble(),
        totalReturnPct: (j['totalReturnPct'] as num).toDouble(),
      );
}

/// Tek bir piyasa (Kripto veya BIST) için kısa vade haftalık özeti.
class ShortTermMarketSummary {
  const ShortTermMarketSummary({
    required this.market,
    required this.hasData,
    required this.totalSignals,
    required this.closedSignals,
    required this.openSignals,
    required this.totalReturnPct,
    required this.winRatePct,
    required this.avgR,
    required this.byStrategy,
    this.bestSignalSummary,
    this.worstSignalSummary,
  });

  const ShortTermMarketSummary.empty(this.market)
      : hasData = false,
        totalSignals = 0,
        closedSignals = 0,
        openSignals = 0,
        totalReturnPct = 0.0,
        winRatePct = 0.0,
        avgR = 0.0,
        byStrategy = const [],
        bestSignalSummary = null,
        worstSignalSummary = null;

  final Market market;
  final bool hasData;
  final int totalSignals;
  final int closedSignals;
  final int openSignals;
  final double totalReturnPct;
  final double winRatePct;
  final double avgR;
  final String? bestSignalSummary;
  final String? worstSignalSummary;
  final List<StrategyBreakdownItem> byStrategy;

  Map<String, Object?> toJson() => {
        'market': market.name,
        'hasData': hasData,
        'totalSignals': totalSignals,
        'closedSignals': closedSignals,
        'openSignals': openSignals,
        'totalReturnPct': totalReturnPct,
        'winRatePct': winRatePct,
        'avgR': avgR,
        'bestSignalSummary': bestSignalSummary,
        'worstSignalSummary': worstSignalSummary,
        'byStrategy': [for (final s in byStrategy) s.toJson()],
      };

  static ShortTermMarketSummary fromJson(Map<String, Object?> j) => ShortTermMarketSummary(
        market: Market.values.byName(j['market'] as String),
        hasData: (j['hasData'] as bool?) ?? false,
        totalSignals: (j['totalSignals'] as num).toInt(),
        closedSignals: (j['closedSignals'] as num).toInt(),
        openSignals: (j['openSignals'] as num).toInt(),
        totalReturnPct: (j['totalReturnPct'] as num).toDouble(),
        winRatePct: (j['winRatePct'] as num).toDouble(),
        avgR: (j['avgR'] as num).toDouble(),
        bestSignalSummary: j['bestSignalSummary'] as String?,
        worstSignalSummary: j['worstSignalSummary'] as String?,
        byStrategy: [
          for (final s in (j['byStrategy'] as List? ?? const []))
            StrategyBreakdownItem.fromJson((s as Map).cast<String, Object?>()),
        ],
      );
}

/// 2. Bölüm: Kısa Vade Haftalık Raporu (Kripto ve BIST ayrı).
class ShortTermWeeklyReport {
  const ShortTermWeeklyReport({
    required this.crypto,
    required this.bist,
  });

  final ShortTermMarketSummary crypto;
  final ShortTermMarketSummary bist;

  bool get hasAnyData => crypto.hasData || bist.hasData;

  Map<String, Object?> toJson() => {
        'crypto': crypto.toJson(),
        'bist': bist.toJson(),
      };

  static ShortTermWeeklyReport fromJson(Map<String, Object?> j) => ShortTermWeeklyReport(
        crypto: ShortTermMarketSummary.fromJson((j['crypto'] as Map).cast<String, Object?>()),
        bist: ShortTermMarketSummary.fromJson((j['bist'] as Map).cast<String, Object?>()),
      );
}

/// Pazar günü üretilen tam Haftalık Rapor.
///
/// Sıra (DEVIR.md Faz 3.5):
/// 1. [lastWeekReview] (önce geçen hafta raporu)
/// 2. [shortTermReport] (sonra kısa vade raporu — Kripto ve BIST ayrı)
/// 3. [newAllocation] (sonra yeni haftanın önerileri ve bütçe ağırlıkları)
class WeeklyReport {
  const WeeklyReport({
    required this.id,
    required this.weekStart,
    required this.weekEnd,
    required this.generatedAt,
    required this.lastWeekReview,
    required this.shortTermReport,
    required this.newAllocation,
    this.disclaimer = kLegalDisclaimer,
  });

  final String id;
  final DateTime weekStart;
  final DateTime weekEnd;
  final DateTime generatedAt;
  final LastWeekReview lastWeekReview;
  final ShortTermWeeklyReport shortTermReport;
  final PortfolioAllocationResult newAllocation;
  final String disclaimer;

  /// Yerel bildirim özeti (ör. "Pazar raporun hazır · Geçen hafta +%4,8 · 5 yeni öneri").
  String get notificationSummary {
    final recCount = newAllocation.recommendations.length;
    final recText = recCount == 0 ? 'Net fırsat yok (nakitte kal)' : '$recCount yeni öneri';
    if (!lastWeekReview.hasData) {
      return 'Pazar raporun hazır · Geçen hafta: henüz veri yok · $recText';
    }
    final ret = lastWeekReview.weightedPortfolioReturnPct;
    final sign = ret >= 0 ? '+' : '';
    final fmt = ret.toStringAsFixed(1).replaceAll('.', ',');
    return 'Pazar raporun hazır · Geçen hafta $sign%$fmt · $recText';
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'weekStart': weekStart.toUtc().millisecondsSinceEpoch,
        'weekEnd': weekEnd.toUtc().millisecondsSinceEpoch,
        'generatedAt': generatedAt.toUtc().millisecondsSinceEpoch,
        'lastWeekReview': lastWeekReview.toJson(),
        'shortTermReport': shortTermReport.toJson(),
        'newAllocation': newAllocation.toJson(),
        'disclaimer': disclaimer,
      };

  static WeeklyReport fromJson(Map<String, Object?> j) => WeeklyReport(
        id: j['id'] as String,
        weekStart: DateTime.fromMillisecondsSinceEpoch((j['weekStart'] as num).toInt(), isUtc: true),
        weekEnd: DateTime.fromMillisecondsSinceEpoch((j['weekEnd'] as num).toInt(), isUtc: true),
        generatedAt: DateTime.fromMillisecondsSinceEpoch((j['generatedAt'] as num).toInt(), isUtc: true),
        lastWeekReview: LastWeekReview.fromJson((j['lastWeekReview'] as Map).cast<String, Object?>()),
        shortTermReport: ShortTermWeeklyReport.fromJson((j['shortTermReport'] as Map).cast<String, Object?>()),
        newAllocation: PortfolioAllocationResult.fromJson((j['newAllocation'] as Map).cast<String, Object?>()),
        disclaimer: (j['disclaimer'] as String?) ?? kLegalDisclaimer,
      );
}

/// Performans eğrisi noktası (yalnızca ileriye dönük gerçekleşen haftalık raporlardan üretilir).
class PerformanceCurvePoint {
  const PerformanceCurvePoint({
    required this.reportId,
    required this.date,
    required this.weeklyReturnPct,
    required this.cumulativeIndex,
    required this.cumulativeReturnPct,
  });

  final String reportId;
  final DateTime date;
  final double weeklyReturnPct;

  /// 100,0 bazlı bileşik endeks değeri.
  final double cumulativeIndex;
  final double cumulativeReturnPct;
}

/// Haftalık rapor arşivi depo arayüzü.
abstract class WeeklyReportStore {
  Future<void> save(WeeklyReport report);
  Future<WeeklyReport?> latest();
  Future<List<WeeklyReport>> allReports();
  Future<void> clear();
}

/// Bellek içi haftalık rapor arşivi.
class MemoryWeeklyReportStore implements WeeklyReportStore {
  final Map<String, WeeklyReport> _store = {};

  @override
  Future<void> save(WeeklyReport report) async {
    _store[report.id] = report;
  }

  @override
  Future<WeeklyReport?> latest() async {
    if (_store.isEmpty) return null;
    final list = _store.values.toList()..sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
    return list.first;
  }

  @override
  Future<List<WeeklyReport>> allReports() async {
    final list = _store.values.toList()..sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
    return list;
  }

  @override
  Future<void> clear() async => _store.clear();

  /// Arşivlenmiş raporlardan ileriye dönük bileşik performans eğrisini hesaplar.
  Future<List<PerformanceCurvePoint>> buildPerformanceCurve() async =>
      performanceCurveFrom(_store.values);
}

/// Haftalık raporlardan 100 bazlı bileşik performans eğrisi üretir.
///
/// Yalnızca `lastWeekReview.hasData` olan (yani ileriye dönük gerçekleşmiş sonucu bulunan) raporlar
/// eğriye girer; geçmiş mumlardan veri türetilmez (Kısıt 2).
List<PerformanceCurvePoint> performanceCurveFrom(Iterable<WeeklyReport> reports) {
  final sorted = reports.toList()..sort((a, b) => a.generatedAt.compareTo(b.generatedAt));
  final points = <PerformanceCurvePoint>[];
  var index = 100.0;
  for (final r in sorted) {
    if (!r.lastWeekReview.hasData) continue;
    final wRet = r.lastWeekReview.weightedPortfolioReturnPct;
    index = index * (1.0 + wRet / 100.0);
    points.add(PerformanceCurvePoint(
      reportId: r.id,
      date: r.generatedAt,
      weeklyReturnPct: wRet,
      cumulativeIndex: double.parse(index.toStringAsFixed(2)),
      cumulativeReturnPct: double.parse((index - 100.0).toStringAsFixed(2)),
    ));
  }
  return points;
}
