import 'exit_plan.dart';
import 'monte_carlo.dart';
import 'multi_timeframe.dart';
import 'regime.dart';
import 'setups.dart';

/// 0–100 güven skoru ve alt bileşenlerinin ayrıntılı dökümü.
///
/// Bileşenler ekranda ve haftalık raporda gerekçe olarak ayrı ayrı gösterilir.
class ConfidenceBreakdown {
  const ConfidenceBreakdown({
    required this.setupConfluence,
    required this.volumeConfirmation,
    required this.regimeAlignment,
    required this.higherTimeframeAlignment,
    required this.monteCarloScore,
    required this.rewardRiskScore,
    required this.reasons,
    this.qualityAdjustment = 0,
  });

  /// Kurulum kalitesi ve çoklu kurulum çakışması (0–25).
  final int setupConfluence;

  /// Hacim oranı ve alıcı baskısı teyidi (0–15).
  final int volumeConfirmation;

  /// Piyasa rejimi uyumu (0–15).
  final int regimeAlignment;

  /// Üst zaman dilimi trend uyumu (0–15).
  final int higherTimeframeAlignment;

  /// Monte Carlo olasılık ve ortalama R katkısı (0–15).
  final int monteCarloScore;

  /// Ödül/Risk (R:R) oranı katkısı (0–15).
  final int rewardRiskScore;

  /// Kalite düzeltmesi (≤ 0): bayatlamaya yakın veri, işlem maliyeti yükü, aşırı ısınmış RSI veya
  /// Monte Carlo güven aralığının sıfırı içermesi gibi durumlarda toplamdan düşülen ceza puanı.
  final int qualityAdjustment;

  /// Kullanıcıya gösterilen Türkçe gerekçe maddeleri.
  final List<String> reasons;

  /// Toplam güven skoru (0–100).
  int get total =>
      (setupConfluence +
              volumeConfirmation +
              regimeAlignment +
              higherTimeframeAlignment +
              monteCarloScore +
              rewardRiskScore +
              qualityAdjustment)
          .clamp(0, 100);

  Map<String, Object?> toJson() => {
        'total': total,
        'setupConfluence': setupConfluence,
        'volumeConfirmation': volumeConfirmation,
        'regimeAlignment': regimeAlignment,
        'higherTimeframeAlignment': higherTimeframeAlignment,
        'monteCarloScore': monteCarloScore,
        'rewardRiskScore': rewardRiskScore,
        'qualityAdjustment': qualityAdjustment,
        'reasons': reasons,
      };

  static ConfidenceBreakdown fromJson(Map<String, Object?> j) => ConfidenceBreakdown(
        setupConfluence: (j['setupConfluence'] as num).toInt(),
        volumeConfirmation: (j['volumeConfirmation'] as num).toInt(),
        regimeAlignment: (j['regimeAlignment'] as num).toInt(),
        higherTimeframeAlignment: (j['higherTimeframeAlignment'] as num).toInt(),
        monteCarloScore: (j['monteCarloScore'] as num).toInt(),
        rewardRiskScore: (j['rewardRiskScore'] as num).toInt(),
        qualityAdjustment: (j['qualityAdjustment'] as num?)?.toInt() ?? 0,
        reasons: [for (final r in (j['reasons'] as List? ?? const [])) '$r'],
      );
}

/// Altı bileşenden 0–100 güven skoru hesaplayıcı.
class ConfidenceScorer {
  const ConfidenceScorer();

  ConfidenceBreakdown score({
    required SetupDetection detection,
    required RegimeReport regime,
    required MultiTimeframeConfirmation mtf,
    required ExitPlan plan,
    required MonteCarloResult monteCarlo,
    double? netRewardRisk,
    double costShareOfRisk = 0.0,
    double dataAgeBars = 0.0,
  }) {
    final reasons = <String>[];

    // 1. Kurulum çakışması (0–25)
    var setupPts = 12 + (detection.setups.length - 1) * 6;
    if (detection.setups.contains(SetupType.orb) || detection.setups.contains(SetupType.bullFlag)) {
      setupPts += 3;
    }
    setupPts = setupPts.clamp(0, 25);
    reasons.add(
      'Kurulum (${detection.setups.map((s) => s.label).join(' + ')}): +$setupPts/25',
    );

    // 2. Hacim teyidi (0–15)
    var volPts = ((detection.volumeRatio - 0.8) * 10.0).round().clamp(0, 12);
    if (detection.takerBuyRatio >= 0.56) volPts += 3;
    volPts = volPts.clamp(0, 15);
    reasons.add(
      'Hacim (${detection.volumeRatio.toStringAsFixed(2)}x ortalama): +$volPts/15',
    );

    // 3. Rejim uyumu (0–15)
    final int regimePts;
    switch (regime.regime) {
      case MarketRegime.bull:
        regimePts = 15;
      case MarketRegime.sideways:
        regimePts = detection.primarySetup.isBreakout ? 9 : 12;
      case MarketRegime.bear:
        regimePts = detection.primarySetup.isBreakout ? 0 : 6;
    }
    reasons.add('Piyasa rejimi (${regime.regime.label}): +$regimePts/15');

    // 4. Üst dilim uyumu (0–15)
    final int mtfPts;
    switch (mtf.trend) {
      case HigherTimeframeTrend.bullish:
        mtfPts = 15;
      case HigherTimeframeTrend.neutral:
        mtfPts = 8;
      case HigherTimeframeTrend.bearish:
        mtfPts = 0;
    }
    reasons.add('Üst dilim (${mtf.higherInterval.code} ${mtf.trend.label}): +$mtfPts/15');

    // 5. Monte Carlo sonucu (0–15)
    var mcPts = 0;
    if (monteCarlo.approved) {
      mcPts = (8 + (monteCarlo.avgR * 20).round()).clamp(8, 15);
    } else if (monteCarlo.avgR > 0) {
      mcPts = (monteCarlo.avgR * 15).round().clamp(2, 7);
    }
    reasons.add(
      'Monte Carlo (Ort. ${monteCarlo.avgR >= 0 ? '+' : ''}${monteCarlo.avgR.toStringAsFixed(2)}R): +$mcPts/15',
    );

    // 6. R:R oranı (0–15) — işlem maliyeti biliniyorsa NET oran üzerinden puanlanır
    final effRr = netRewardRisk ?? plan.rewardRisk;
    final rrPts = ((effRr - 1.0) * 12.0).round().clamp(0, 15);
    reasons.add(netRewardRisk == null
        ? 'Ödül/Risk (${plan.rewardRisk.toStringAsFixed(2)}R): +$rrPts/15'
        : 'Ödül/Risk (brüt ${plan.rewardRisk.toStringAsFixed(2)}R, maliyet sonrası ${effRr.toStringAsFixed(2)}R): +$rrPts/15');

    // 7. Kalite düzeltmesi (yalnızca ceza; 0 ise gerekçe satırı eklenmez)
    var penalty = 0;
    final penaltyNotes = <String>[];
    if (monteCarlo.avgRConfidenceLow <= 0) {
      penalty -= 4;
      penaltyNotes.add('Monte Carlo güven aralığı sıfırı içeriyor');
    }
    if (detection.rsi14 >= 76.0) {
      penalty -= 3;
      penaltyNotes.add('RSI ${detection.rsi14.toStringAsFixed(0)} aşırı ısınmış');
    }
    if (costShareOfRisk >= 0.15) {
      penalty -= 3;
      penaltyNotes.add('işlem maliyeti riskin %${(costShareOfRisk * 100).toStringAsFixed(0)} kadarı');
    }
    if (dataAgeBars >= 1.5) {
      penalty -= 3;
      penaltyNotes.add('sinyal mumu ${dataAgeBars.toStringAsFixed(1)} mum önce kapandı');
    }
    if (penalty != 0) {
      reasons.add('Kalite düzeltmesi (${penaltyNotes.join(', ')}): $penalty');
    }

    return ConfidenceBreakdown(
      setupConfluence: setupPts,
      volumeConfirmation: volPts,
      regimeAlignment: regimePts,
      higherTimeframeAlignment: mtfPts,
      monteCarloScore: mcPts,
      rewardRiskScore: rrPts,
      qualityAdjustment: penalty,
      reasons: reasons,
    );
  }
}

