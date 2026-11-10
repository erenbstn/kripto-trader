import 'dart:math' as math;

import '../analysis/confidence_score.dart';
import '../analysis/regime.dart';
import '../bist/bist_rules.dart';
import '../journal/signal_journal.dart';
import '../model/market.dart';

/// Kullanıcının seçtiği risk iştahı (K3).
enum RiskAppetite {
  conservative('Temkinli', 0.6, maxSingleAssetPct: 12.0, maxTotalRiskPct: 3.6, maxCryptoTotalPct: 24.0, minCashPct: 35.0),
  balanced('Dengeli', 1.0, maxSingleAssetPct: 20.0, maxTotalRiskPct: 6.0, maxCryptoTotalPct: 40.0, minCashPct: 20.0),
  aggressive('Atak', 1.4, maxSingleAssetPct: 25.0, maxTotalRiskPct: 8.4, maxCryptoTotalPct: 56.0, minCashPct: 15.0);

  const RiskAppetite(
    this.label,
    this.scale, {
    required this.maxSingleAssetPct,
    required this.maxTotalRiskPct,
    required this.maxCryptoTotalPct,
    required this.minCashPct,
  });

  final String label;
  final double scale;

  /// Tek varlık üst sınırı (%). K3: Atak modda bile en çok %25.
  final double maxSingleAssetPct;

  /// Toplam açık risk üst sınırı: Σ (ağırlık × stop mesafesi) (%).
  final double maxTotalRiskPct;

  /// Kripto varlıkların toplam ağırlık üst sınırı (%).
  final double maxCryptoTotalPct;

  /// En az nakit oranı (%).
  final double minCashPct;

  double get maxInvestedPct => 100.0 - minCashPct;
}

/// Haftalık öneri kartı ve hesaplanan bütçe ağırlığı.
class WeeklyRecommendation {
  const WeeklyRecommendation({
    required this.signal,
    required this.weightPct,
    required this.riskContributionPct,
    required this.stopDistancePct,
    required this.allocatedAmount,
    required this.estimatedLots,
    required this.keyRisks,
  });

  final SignalRecord signal;

  /// Portföy bütçesi içindeki ağırlığı (%, 0–25).
  final double weightPct;

  /// Portföy toplam riskine katkısı: `weightPct * stopDistancePct / 100` (%).
  final double riskContributionPct;

  /// Giriş fiyatına göre stop uzaklığı (%).
  final double stopDistancePct;

  /// Kullanıcının bütçe tutarına göre ayrılan para tutarı.
  final double allocatedAmount;

  /// BIST için yaklaşık tam lot sayısı (kripto için null).
  final int? estimatedLots;

  /// Ana risk maddeleri (veri gecikmesi, açılış boşluğu, oynaklık vb.).
  final List<String> keyRisks;

  Instrument get instrument => signal.instrument;
  ConfidenceBreakdown get confidence => signal.confidence;

  Map<String, Object?> toJson() => {
        'signal': signal.toJson(),
        'weightPct': weightPct,
        'riskContributionPct': riskContributionPct,
        'stopDistancePct': stopDistancePct,
        'allocatedAmount': allocatedAmount,
        'estimatedLots': estimatedLots,
        'keyRisks': keyRisks,
      };

  static WeeklyRecommendation fromJson(Map<String, Object?> j) => WeeklyRecommendation(
        signal: SignalRecord.fromJson((j['signal'] as Map).cast<String, Object?>()),
        weightPct: (j['weightPct'] as num).toDouble(),
        riskContributionPct: (j['riskContributionPct'] as num).toDouble(),
        stopDistancePct: (j['stopDistancePct'] as num).toDouble(),
        allocatedAmount: (j['allocatedAmount'] as num).toDouble(),
        estimatedLots: (j['estimatedLots'] as num?)?.toInt(),
        keyRisks: [for (final r in (j['keyRisks'] as List? ?? const [])) '$r'],
      );
}

/// Bütçe ağırlıklandırma çıktısı.
class PortfolioAllocationResult {
  const PortfolioAllocationResult({
    required this.appetite,
    required this.totalBudget,
    required this.recommendations,
    required this.bistRecommendations,
    required this.cryptoRecommendations,
    required this.investedWeightPct,
    required this.bistTotalWeightPct,
    required this.cryptoTotalWeightPct,
    required this.cashWeightPct,
    required this.cashAmount,
    required this.totalOpenRiskPct,
    required this.scalingNotes,
    required this.summaryMessage,
  });

  final RiskAppetite appetite;
  final double totalBudget;
  final List<WeeklyRecommendation> recommendations;
  final List<WeeklyRecommendation> bistRecommendations;
  final List<WeeklyRecommendation> cryptoRecommendations;
  final double investedWeightPct;
  final double bistTotalWeightPct;
  final double cryptoTotalWeightPct;
  final double cashWeightPct;
  final double cashAmount;
  final double totalOpenRiskPct;
  final List<String> scalingNotes;
  final String summaryMessage;

  bool get hasRecommendations => recommendations.isNotEmpty;

  Map<String, Object?> toJson() => {
        'appetite': appetite.name,
        'totalBudget': totalBudget,
        'recommendations': [for (final r in recommendations) r.toJson()],
        'investedWeightPct': investedWeightPct,
        'bistTotalWeightPct': bistTotalWeightPct,
        'cryptoTotalWeightPct': cryptoTotalWeightPct,
        'cashWeightPct': cashWeightPct,
        'cashAmount': cashAmount,
        'totalOpenRiskPct': totalOpenRiskPct,
        'scalingNotes': scalingNotes,
        'summaryMessage': summaryMessage,
      };

  static PortfolioAllocationResult fromJson(Map<String, Object?> j) {
    final recs = [
      for (final r in (j['recommendations'] as List? ?? const []))
        WeeklyRecommendation.fromJson((r as Map).cast<String, Object?>()),
    ];
    return PortfolioAllocationResult(
      appetite: RiskAppetite.values.byName(j['appetite'] as String),
      totalBudget: (j['totalBudget'] as num).toDouble(),
      recommendations: recs,
      bistRecommendations: [for (final r in recs) if (r.instrument.market == Market.bist) r],
      cryptoRecommendations: [for (final r in recs) if (r.instrument.market == Market.crypto) r],
      investedWeightPct: (j['investedWeightPct'] as num).toDouble(),
      bistTotalWeightPct: (j['bistTotalWeightPct'] as num).toDouble(),
      cryptoTotalWeightPct: (j['cryptoTotalWeightPct'] as num).toDouble(),
      cashWeightPct: (j['cashWeightPct'] as num).toDouble(),
      cashAmount: (j['cashAmount'] as num).toDouble(),
      totalOpenRiskPct: (j['totalOpenRiskPct'] as num).toDouble(),
      scalingNotes: [for (final s in (j['scalingNotes'] as List? ?? const [])) '$s'],
      summaryMessage: j['summaryMessage'] as String,
    );
  }
}

/// Eşit risk bütçesi ve K3 kısıtlarıyla haftalık öneri ağırlıklandırıcısı.
///
/// Kurallar (K3):
/// - Öneri sayısı 0–6 (en yüksek güvenli en fazla 6 aday seçilir; eşik üstü yoksa %100 nakit).
/// - Baz risk payı = bütçenin %0,5–%1,5'i (güven skoruna göre doğrusal).
/// - Ayı rejiminde risk payı yarıya iner (`regime.riskMultiplier == 0.5`).
/// - Ham ağırlık = `riskPayı / stopMesafesi`.
/// - Sınırlar: tek varlık üst sınırı, kripto toplam üst sınırı, toplam açık risk sınırı ve en az nakit sınırı.
///   Sınır aşımında ağırlıklar orantılı küçültülür.
class PortfolioWeightAllocator {
  const PortfolioWeightAllocator({
    this.maxRecommendations = 6,
    this.minConfidenceThreshold = 55,
  });

  final int maxRecommendations;
  final int minConfidenceThreshold;

  PortfolioAllocationResult allocate(
    List<SignalRecord> candidates, {
    RiskAppetite appetite = RiskAppetite.balanced,
    double totalBudget = 100000.0,
  }) {
    final qualified = [
      for (final c in candidates)
        if (c.confidence.total >= minConfidenceThreshold && c.entryPrice > c.initialStop) c,
    ];

    // Güven skoruna, ardından R:R oranına göre sırala; aynı varlıktan yalnızca en güçlü olanı tut
    qualified.sort((a, b) {
      final cmp = b.confidence.total.compareTo(a.confidence.total);
      if (cmp != 0) return cmp;
      return b.rewardRisk.compareTo(a.rewardRisk);
    });

    final unique = <SignalRecord>[];
    final seenIds = <String>{};
    for (final c in qualified) {
      if (seenIds.add(c.instrument.id)) {
        unique.add(c);
        if (unique.length >= maxRecommendations) break;
      }
    }

    if (unique.isEmpty) {
      return PortfolioAllocationResult(
        appetite: appetite,
        totalBudget: totalBudget,
        recommendations: const [],
        bistRecommendations: const [],
        cryptoRecommendations: const [],
        investedWeightPct: 0.0,
        bistTotalWeightPct: 0.0,
        cryptoTotalWeightPct: 0.0,
        cashWeightPct: 100.0,
        cashAmount: totalBudget,
        totalOpenRiskPct: 0.0,
        scalingNotes: const [],
        summaryMessage: 'Bu hafta net fırsat yok, nakitte kal (%100 nakit).',
      );
    }

    final notes = <String>[];
    final weights = <double>[];
    final stopPcts = <double>[];

    // 1. Ham ağırlık ve tek varlık üst sınırı
    for (final sig in unique) {
      final stopDistPct = ((sig.entryPrice - sig.initialStop) / sig.entryPrice) * 100.0;
      final safeStopPct = math.max(stopDistPct, 0.25);
      stopPcts.add(safeStopPct);

      final confNorm = ((sig.confidence.total - 50) / 50.0).clamp(0.0, 1.0);
      final baseRiskPct = 0.5 + confNorm * 1.0; // %0,5 – %1,5
      final effRiskPct = baseRiskPct * appetite.scale * sig.regime.riskMultiplier;

      var w = (effRiskPct / safeStopPct) * 100.0;
      if (w > appetite.maxSingleAssetPct) {
        w = appetite.maxSingleAssetPct;
      }
      weights.add(w);
    }

    if (unique.any((s) => s.regime == MarketRegime.bear)) {
      notes.add('Ayı rejimi nedeniyle ilgili varlıklarda risk payı %50 azaltıldı.');
    }

    // 2. Kripto toplam üst sınırı kontrolü
    var cryptoSum = 0.0;
    for (var i = 0; i < unique.length; i++) {
      if (unique[i].instrument.market == Market.crypto) {
        cryptoSum += weights[i];
      }
    }
    if (cryptoSum > appetite.maxCryptoTotalPct && cryptoSum > 0) {
      final factor = appetite.maxCryptoTotalPct / cryptoSum;
      for (var i = 0; i < unique.length; i++) {
        if (unique[i].instrument.market == Market.crypto) {
          weights[i] *= factor;
        }
      }
      notes.add('Kripto toplam ağırlığı %${appetite.maxCryptoTotalPct.toStringAsFixed(0)} üst sınırına göre orantılı küçültüldü.');
    }

    // 3. Toplam açık risk (Σ ağırlık × stopMesafesi / 100) üst sınırı kontrolü
    var totalRisk = 0.0;
    for (var i = 0; i < unique.length; i++) {
      totalRisk += weights[i] * stopPcts[i] / 100.0;
    }
    if (totalRisk > appetite.maxTotalRiskPct && totalRisk > 0) {
      final factor = appetite.maxTotalRiskPct / totalRisk;
      for (var i = 0; i < weights.length; i++) {
        weights[i] *= factor;
      }
      notes.add('Toplam açık risk %${appetite.maxTotalRiskPct.toStringAsFixed(1)} sınırına göre orantılı küçültüldü.');
    }

    // 4. En az nakit (maksimum yatırım = 100 - minCashPct) kontrolü
    var totalInvested = weights.fold<double>(0.0, (a, b) => a + b);
    if (totalInvested > appetite.maxInvestedPct && totalInvested > 0) {
      final factor = appetite.maxInvestedPct / totalInvested;
      for (var i = 0; i < weights.length; i++) {
        weights[i] *= factor;
      }
      notes.add('En az %${appetite.minCashPct.toStringAsFixed(0)} nakit tamponu için ağırlıklar orantılı küçültüldü.');
    }

    // Yuvarlama ve son toplam kontrolü
    final recs = <WeeklyRecommendation>[];
    var finalInvested = 0.0;
    var finalBist = 0.0;
    var finalCrypto = 0.0;
    var finalRisk = 0.0;

    for (var i = 0; i < unique.length; i++) {
      final w = double.parse(weights[i].toStringAsFixed(2));
      final stopPct = double.parse(stopPcts[i].toStringAsFixed(2));
      final riskContrib = double.parse((w * stopPct / 100.0).toStringAsFixed(2));
      final amount = double.parse((totalBudget * w / 100.0).toStringAsFixed(2));
      final sig = unique[i].copyWith(allocatedWeightPct: w, isWeeklyProposal: true);
      final lots = sig.instrument.market == Market.bist ? BistRules.lotsFor(amount, sig.entryPrice) : null;

      final risks = _buildKeyRisks(sig, stopPct);

      recs.add(WeeklyRecommendation(
        signal: sig,
        weightPct: w,
        riskContributionPct: riskContrib,
        stopDistancePct: stopPct,
        allocatedAmount: amount,
        estimatedLots: lots,
        keyRisks: risks,
      ));

      finalInvested += w;
      finalRisk += riskContrib;
      if (sig.instrument.market == Market.bist) {
        finalBist += w;
      } else {
        finalCrypto += w;
      }
    }

    finalInvested = double.parse(finalInvested.toStringAsFixed(2));
    finalBist = double.parse(finalBist.toStringAsFixed(2));
    finalCrypto = double.parse(finalCrypto.toStringAsFixed(2));
    finalRisk = double.parse(finalRisk.toStringAsFixed(2));
    final cashPct = double.parse(math.max(0.0, 100.0 - finalInvested).toStringAsFixed(2));
    final cashAmt = double.parse((totalBudget * cashPct / 100.0).toStringAsFixed(2));

    final bistRecs = [for (final r in recs) if (r.instrument.market == Market.bist) r];
    final cryptoRecs = [for (final r in recs) if (r.instrument.market == Market.crypto) r];

    final summary = '${recs.length} yeni öneri (${bistRecs.length} BIST, ${cryptoRecs.length} Kripto) · '
        'Yatırım %${finalInvested.toStringAsFixed(1)} · Nakit %${cashPct.toStringAsFixed(1)} · '
        'Toplam Açık Risk %${finalRisk.toStringAsFixed(2)}';

    return PortfolioAllocationResult(
      appetite: appetite,
      totalBudget: totalBudget,
      recommendations: recs,
      bistRecommendations: bistRecs,
      cryptoRecommendations: cryptoRecs,
      investedWeightPct: finalInvested,
      bistTotalWeightPct: finalBist,
      cryptoTotalWeightPct: finalCrypto,
      cashWeightPct: cashPct,
      cashAmount: cashAmt,
      totalOpenRiskPct: finalRisk,
      scalingNotes: notes,
      summaryMessage: summary,
    );
  }

  static List<String> _buildKeyRisks(SignalRecord sig, double stopPct) {
    final risks = <String>[];
    if (sig.instrument.market == Market.bist) {
      risks.add('Veri ~15 dk gecikmelidir (${sig.dataSource}); giriş nokta değil bölge olarak uygulanmalıdır.');
      risks.add('Seans açılış boşlukları ve ±%10 günlük marj stopun kayarak gerçekleşmesine yol açabilir.');
    } else {
      risks.add('7/24 kripto oynaklığı ve hafta sonu likidite düşüşü ani iğnelere yol açabilir.');
    }
    if (sig.regime != MarketRegime.bull) {
      risks.add('Piyasa rejimi ${sig.regime.label}; sahte kırılım riskine karşı kademeli giriş önemlidir.');
    }
    if (stopPct > 3.0) {
      risks.add('Geniş stop mesafesi (%${stopPct.toStringAsFixed(2)}); ağırlık bu nedenle otomatik düşürüldü.');
    }
    return risks;
  }
}

