import 'dart:math' as math;

import '../model/candle.dart';
import 'exit_plan.dart';

class MonteCarloException implements Exception {
  const MonteCarloException(this.message);
  final String message;

  @override
  String toString() => 'MonteCarloException: $message';
}

/// Tek bir mumun önceki kapanışa göre oran dörtlüsü.
class BarRatio {
  const BarRatio({
    required this.openRatio,
    required this.highRatio,
    required this.lowRatio,
    required this.closeRatio,
  });

  final double openRatio;
  final double highRatio;
  final double lowRatio;
  final double closeRatio;
}

/// Blok önyüklemeli (block bootstrap) Monte Carlo süzgeci sonucu.
///
/// Not: `replay_historical_sessions` proje kısıtı gereği (Kısıt 2 & 3, K7) taşınmamıştır.
class MonteCarloResult {
  const MonteCarloResult({
    required this.replays,
    required this.seed,
    required this.blockSize,
    required this.barsSimulated,
    required this.pTarget,
    required this.pTarget1,
    required this.pStop,
    required this.pNeither,
    required this.pGreen,
    required this.avgR,
    required this.avgRConfidenceLow,
    required this.avgRConfidenceHigh,
    required this.winShareOfDecided,
    required this.breakevenShareNeeded,
    required this.p5Close,
    required this.medianClose,
    required this.p95Close,
    required this.approved,
    required this.verdict,
  });

  final int replays;
  final int seed;
  final int blockSize;
  final int barsSimulated;

  /// Ana hedefe (target2) stop'tan önce ulaşma olasılığı (0–1).
  final double pTarget;

  /// En az 1. hedefe (1R) ulaşma olasılığı (0–1).
  final double pTarget1;

  /// Stop seviyesine değme olasılığı (aynı mumda ikisi de görülürse muhafazakâr olarak stop sayılır).
  final double pStop;

  /// Süre sonunda ne stop ne ana hedefe ulaşmış olma olasılığı.
  final double pNeither;

  /// İşlemin kârda kapanma olasılığı.
  final double pGreen;

  /// Senaryoların ortalama R getirisi.
  final double avgR;

  /// Ortalama R için %95 güven aralığı alt sınırı.
  final double avgRConfidenceLow;

  /// Ortalama R için %95 güven aralığı üst sınırı.
  final double avgRConfidenceHigh;

  final double winShareOfDecided;
  final double breakevenShareNeeded;
  final double p5Close;
  final double medianClose;
  final double p95Close;
  final bool approved;
  final String verdict;

  Map<String, Object?> toJson() => {
        'replays': replays,
        'seed': seed,
        'blockSize': blockSize,
        'barsSimulated': barsSimulated,
        'pTarget': pTarget,
        'pTarget1': pTarget1,
        'pStop': pStop,
        'pNeither': pNeither,
        'pGreen': pGreen,
        'avgR': avgR,
        'avgRConfidenceLow': avgRConfidenceLow,
        'avgRConfidenceHigh': avgRConfidenceHigh,
        'winShareOfDecided': winShareOfDecided,
        'breakevenShareNeeded': breakevenShareNeeded,
        'p5Close': p5Close,
        'medianClose': medianClose,
        'p95Close': p95Close,
        'approved': approved,
        'verdict': verdict,
      };
}

/// Blok önyükleme (block bootstrap) tabanlı Monte Carlo simülatörü.
///
/// Python referansındaki `i % seans` dilimlemesi yerine ardışık mum blokları örneklenir (R4).
/// Böylece oynaklık kümelenmesi korunur ve sahte saat dilimi varsayımı ortadan kalkar.
class MonteCarloSimulator {
  const MonteCarloSimulator({
    this.replays = 2500,
    this.blockSize = 4,
    this.seed = 19,
    this.minAvgR = 0.05,
    this.minHistoryBars = 50,
  });

  final int replays;
  final int blockSize;
  final int seed;
  final double minAvgR;
  final int minHistoryBars;

  static const double _coinFlipThreshold = 0.04;
  static const double _strongThreshold = 0.14;

  /// Geçmiş kapanmış mumlardan (son giriş mumu hariç) ardışık oran dizisi üretir.
  List<BarRatio> buildRatioSeries(List<Candle> closedBars) {
    if (closedBars.length < minHistoryBars) {
      throw MonteCarloException(
        'Monte Carlo için en az $minHistoryBars kapanmış mum gerekli (mevcut: ${closedBars.length})',
      );
    }
    final hist = closedBars.sublist(0, closedBars.length - 1);
    final ratios = <BarRatio>[];
    for (var i = 1; i < hist.length; i++) {
      final pc = hist[i - 1].close;
      if (pc <= 0) continue;
      final b = hist[i];
      ratios.add(BarRatio(
        openRatio: b.open / pc,
        highRatio: b.high / pc,
        lowRatio: b.low / pc,
        closeRatio: b.close / pc,
      ));
    }
    if (ratios.length < blockSize + 2) {
      throw const MonteCarloException('Yeterli geçerli mum oranı üretilemedi');
    }
    return ratios;
  }

  /// Çıkış planını blok önyükleme ile [replays] kez simüle eder.
  MonteCarloResult simulate(
    ExitPlan plan,
    List<Candle> closedBars, {
    int? overrideSeed,
    int? overrideReplays,
  }) {
    final ratios = buildRatioSeries(closedBars);
    final entry = plan.entryPrice;
    final stop = plan.stop;
    final target1 = plan.target1;
    final target2 = plan.target2;
    final risk = entry - stop;
    if (risk <= 0) {
      throw const MonteCarloException('Risk sıfır veya negatif olamaz');
    }

    final rTarget2 = (target2 - entry) / risk;
    final nReplays = overrideReplays ?? replays;
    final usedSeed = overrideSeed ?? seed;
    final barsToReplay = plan.maxHoldBars;
    final effBlock = math.max(1, math.min(blockSize, ratios.length));
    final maxStartIdx = ratios.length - effBlock;

    final rng = math.Random(usedSeed);

    var cntTarget = 0;
    var cntTarget1 = 0;
    var cntStop = 0;
    var cntNeither = 0;
    var cntGreen = 0;

    final rValues = List<double>.filled(nReplays, 0.0);
    final closes = List<double>.filled(nReplays, 0.0);

    for (var n = 0; n < nReplays; n++) {
      var p = entry;
      String? outcome;
      var hitT1 = false;
      var step = 0;

      while (step < barsToReplay) {
        final startIdx = maxStartIdx > 0 ? rng.nextInt(maxStartIdx + 1) : 0;
        for (var j = 0; j < effBlock && step < barsToReplay; j++, step++) {
          final r = ratios[startIdx + j];
          final hi = p * r.highRatio;
          final lo = p * r.lowRatio;
          final cl = p * r.closeRatio;

          if (outcome == null) {
            // Muhafazakâr kural: aynı mumda hem stop hem hedef görülürse STOP sayılır!
            if (lo <= stop) {
              outcome = 'stop';
            } else {
              if (hi >= target1) hitT1 = true;
              if (hi >= target2) {
                outcome = 'target';
              }
            }
          }
          p = cl;
        }
      }

      if (hitT1) cntTarget1++;
      closes[n] = p;

      if (outcome == 'target') {
        cntTarget++;
        cntGreen++;
        rValues[n] = rTarget2;
      } else if (outcome == 'stop') {
        cntStop++;
        rValues[n] = -1.0;
      } else {
        cntNeither++;
        if (p > entry) cntGreen++;
        rValues[n] = (p - entry) / risk;
      }
    }

    final pTarget = cntTarget / nReplays;
    final pTarget1 = cntTarget1 / nReplays;
    final pStop = cntStop / nReplays;
    final pNeither = cntNeither / nReplays;
    final pGreen = cntGreen / nReplays;

    var sumR = 0.0;
    for (final rv in rValues) {
      sumR += rv;
    }
    final avgR = sumR / nReplays;

    var sqDiff = 0.0;
    for (final rv in rValues) {
      final d = rv - avgR;
      sqDiff += d * d;
    }
    final stdR = nReplays > 1 ? math.sqrt(sqDiff / (nReplays - 1)) : 0.0;
    final halfWidth = nReplays > 1 ? 1.96 * (stdR / math.sqrt(nReplays)) : 0.0;
    final ciLow = avgR - halfWidth;
    final ciHigh = avgR + halfWidth;

    closes.sort();
    double pct(double q) {
      final idx = (q * closes.length).floor().clamp(0, closes.length - 1);
      return closes[idx];
    }

    final evenShare = 1.0 / (1.0 + rTarget2);
    final decided = pTarget + pStop;
    final winShare = decided > 0 ? pTarget / decided : 0.0;
    final diff = winShare - evenShare;

    final String head;
    if (decided <= 0) {
      head = 'Hedef veya Stopa Ulaşmadı (Nötr)';
    } else if (diff >= _strongThreshold) {
      head = 'Güçlü Hedef Eğilimi';
    } else if (diff >= _coinFlipThreshold) {
      head = 'Hedef Eğilimli';
    } else if (diff > -_coinFlipThreshold) {
      head = 'Başabaşa Yakın / Yazı-Tura';
    } else if (diff > -_strongThreshold) {
      head = 'Stop Eğilimli';
    } else {
      head = 'Güçlü Stop Eğilimi';
    }

    final approved = decided > 0 && (avgR >= minAvgR) && (diff >= -0.01 || pGreen >= 0.54);
    final verdict = '$head: Hedef %${(pTarget * 100).toStringAsFixed(1)} vs Stop %${(pStop * 100).toStringAsFixed(1)} · '
        'Ort. R ${avgR >= 0 ? '+' : ''}${avgR.toStringAsFixed(2)}R '
        '(%95 GA: [${ciLow.toStringAsFixed(2)}R, ${ciHigh.toStringAsFixed(2)}R])';

    return MonteCarloResult(
      replays: nReplays,
      seed: usedSeed,
      blockSize: effBlock,
      barsSimulated: barsToReplay,
      pTarget: double.parse(pTarget.toStringAsFixed(4)),
      pTarget1: double.parse(pTarget1.toStringAsFixed(4)),
      pStop: double.parse(pStop.toStringAsFixed(4)),
      pNeither: double.parse(pNeither.toStringAsFixed(4)),
      pGreen: double.parse(pGreen.toStringAsFixed(4)),
      avgR: double.parse(avgR.toStringAsFixed(3)),
      avgRConfidenceLow: double.parse(ciLow.toStringAsFixed(3)),
      avgRConfidenceHigh: double.parse(ciHigh.toStringAsFixed(3)),
      winShareOfDecided: double.parse(winShare.toStringAsFixed(4)),
      breakevenShareNeeded: double.parse(evenShare.toStringAsFixed(4)),
      p5Close: double.parse(pct(0.05).toStringAsFixed(6)),
      medianClose: double.parse(pct(0.50).toStringAsFixed(6)),
      p95Close: double.parse(pct(0.95).toStringAsFixed(6)),
      approved: approved,
      verdict: verdict,
    );
  }
}

