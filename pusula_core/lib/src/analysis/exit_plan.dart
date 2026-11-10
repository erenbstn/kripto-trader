import 'dart:math' as math;

import '../bist/bist_rules.dart';
import '../model/market.dart';
import 'setups.dart';

class ExitPlanException implements Exception {
  const ExitPlanException(this.message);
  final String message;

  @override
  String toString() => 'ExitPlanException: $message';
}

/// Bir sinyal için girişten önce kilitlenen çıkış planı.
class ExitPlan {
  const ExitPlan({
    required this.instrument,
    required this.interval,
    required this.primarySetup,
    required this.entryPrice,
    required this.entryZoneLow,
    required this.entryZoneHigh,
    required this.stop,
    required this.stopRule,
    required this.stopLabel,
    required this.stopDistancePct,
    required this.target1,
    required this.target1R,
    required this.target2,
    required this.target2R,
    required this.breakevenTrigger,
    required this.rewardRisk,
    required this.maxHoldBars,
    required this.maxHoldDuration,
    required this.invalidationRule,
    this.limitWarning,
  });

  final Instrument instrument;
  final BarInterval interval;
  final SetupType primarySetup;
  final double entryPrice;
  final double entryZoneLow;
  final double entryZoneHigh;
  final double stop;
  final String stopRule;
  final String stopLabel;

  /// Giriş fiyatına göre stop uzaklığı (%).
  final double stopDistancePct;

  /// 1. kademeli kâr alma seviyesi (varsayılan 1R; ulaşıldığında stop başabaşa çekilir).
  final double target1;
  final double target1R;

  /// Ana hedef seviyesi (varsayılan 2R).
  final double target2;
  final double target2R;

  /// Başabaş tetikleme seviyesi.
  final double breakevenTrigger;

  /// Ana hedefe göre Ödül/Risk (R:R) oranı.
  final double rewardRisk;
  final int maxHoldBars;
  final Duration maxHoldDuration;

  /// Kurulumu geçersiz kılan açık koşul (ekranda ve raporda gösterilir).
  final String invalidationRule;

  /// BIST için tavan/taban yakınlığı veya açılış boşluğu uyarısı.
  final String? limitWarning;
}

/// Yapı (OR-Mid / OR-Low) ve ATR tabanlı çıkış planı oluşturucu.
class ExitPlanner {
  const ExitPlanner({
    this.target1R = 1.0,
    this.target2R = 2.0,
    this.breakevenAtR = 1.0,
  });

  final double target1R;
  final double target2R;
  final double breakevenAtR;

  static double _smartRound(double val, Instrument ins) {
    if (ins.market == Market.bist) {
      return BistRules.roundToTick(val);
    }
    if (val >= 1000) return double.parse(val.toStringAsFixed(2));
    if (val >= 10) return double.parse(val.toStringAsFixed(3));
    if (val >= 1) return double.parse(val.toStringAsFixed(4));
    if (val >= 0.01) return double.parse(val.toStringAsFixed(6));
    return double.parse(val.toStringAsFixed(8));
  }

  /// Tespit edilen kurulumdan tam çıkış planı üretir.
  ///
  /// [previousDayClose] BIST hisselerinde günlük ±%10 tavan/taban yakınlığını denetlemek için kullanılır.
  ExitPlan build(
    SetupDetection detection, {
    String stopRule = 'auto',
    double? previousDayClose,
  }) {
    final ins = detection.instrument;
    final entry = _smartRound(detection.lastClose, ins);
    if (entry <= 0) {
      throw ExitPlanException('Geçersiz giriş fiyatı: $entry');
    }

    final orHigh = detection.openingRangeHigh;
    final orLow = detection.openingRangeLow;
    final atr = detection.atr14 > 0 ? detection.atr14 : entry * 0.008;

    late double rawStop;
    late String chosenRule;
    late String stopLabel;

    final maxPct = ins.market == Market.bist ? 0.055 : 0.038;
    final minPct = ins.market == Market.bist ? 0.008 : 0.0035;

    if (stopRule == 'auto') {
      final orMid = (orHigh + orLow) / 2.0;
      final distMidPct = (entry - orMid) / entry;
      final distLowPct = (entry - orLow) / entry;
      if (distMidPct >= minPct && distMidPct <= maxPct) {
        rawStop = orMid;
        chosenRule = 'or_mid';
        stopLabel = 'Açılış Aralığı Orta Noktası (OR-Mid)';
      } else if (distLowPct >= minPct && distLowPct <= maxPct * 1.15) {
        rawStop = orLow;
        chosenRule = 'or_low';
        stopLabel = 'Açılış Aralığı Dip Seviyesi (OR-Low)';
      } else {
        var atrDist = math.max(atr * 1.8, entry * minPct);
        atrDist = math.min(atrDist, entry * maxPct);
        rawStop = entry - atrDist;
        chosenRule = 'atr';
        stopLabel = '1.8x ATR(14) Oynaklık Stopu';
      }
    } else if (stopRule == 'or_mid') {
      rawStop = (orHigh + orLow) / 2.0;
      chosenRule = 'or_mid';
      stopLabel = 'Açılış Aralığı Orta Noktası (OR-Mid)';
    } else if (stopRule == 'or_low') {
      rawStop = orLow;
      chosenRule = 'or_low';
      stopLabel = 'Açılış Aralığı Dip Seviyesi (OR-Low)';
    } else {
      final atrDist = math.max(atr * 1.8, entry * minPct);
      rawStop = entry - atrDist;
      chosenRule = 'atr';
      stopLabel = '1.8x ATR(14) Oynaklık Stopu';
    }

    final minStopDist = entry * minPct;
    if ((entry - rawStop) < minStopDist) {
      rawStop = entry - math.max(minStopDist, atr * 1.5);
      stopLabel = '$stopLabel (Asgari Koruma Bandı)';
    }

    var stopPrice = _smartRound(rawStop, ins);
    if (ins.market == Market.bist && stopPrice >= entry) {
      stopPrice = BistRules.roundToTick(entry - BistRules.tickSize(entry) * 2);
    }
    if (stopPrice >= entry) {
      throw ExitPlanException('Stop fiyatı ($stopPrice) giriş fiyatının ($entry) altında olmalı');
    }

    final riskPerUnit = entry - stopPrice;
    final riskPct = (riskPerUnit / entry) * 100.0;
    if (riskPct < 0.15) {
      throw ExitPlanException('Stop mesafesi çok dar (%${riskPct.toStringAsFixed(2)})');
    }

    var t1 = _smartRound(entry + riskPerUnit * target1R, ins);
    var t2 = _smartRound(entry + riskPerUnit * target2R, ins);
    var be = _smartRound(entry + riskPerUnit * breakevenAtR, ins);

    if (ins.market == Market.bist) {
      if (t1 <= entry) t1 = BistRules.roundToTick(entry + BistRules.tickSize(entry));
      if (t2 <= t1) t2 = BistRules.roundToTick(t1 + BistRules.tickSize(t1));
      if (be <= entry) be = t1;
    }

    final rr = double.parse(((t2 - entry) / riskPerUnit).toStringAsFixed(2));

    // Tutma süresi sınırı
    final int maxHoldBars;
    final Duration maxHoldDuration;
    switch (detection.interval) {
      case BarInterval.m5:
        maxHoldBars = 48; // 4 saat
        maxHoldDuration = const Duration(hours: 4);
      case BarInterval.m15:
        maxHoldBars = 32; // 8 saat
        maxHoldDuration = const Duration(hours: 8);
      case BarInterval.h1:
        maxHoldBars = ins.market == Market.bist ? 24 : 24; // BIST ~3 işlem günü, kripto 24 saat
        maxHoldDuration = ins.market == Market.bist ? const Duration(days: 3) : const Duration(hours: 24);
      case BarInterval.h4:
        maxHoldBars = 18;
        maxHoldDuration = const Duration(days: 3);
      case BarInterval.d1:
        maxHoldBars = 5; // 5 işlem günü (haftalık salınım)
        maxHoldDuration = const Duration(days: 7);
    }

    String? limitWarning;
    if (ins.market == Market.bist) {
      final refClose = previousDayClose ?? entry;
      if (BistRules.isAtLimit(entry, refClose, tolerancePct: 1.0)) {
        limitWarning =
            'Fiyat günlük ±%${BistRules.dailyLimitPct.toStringAsFixed(0)} tavan/taban sınırına yakın; emir/stop kayması riski yüksek.';
      } else {
        final limits = BistRules.dailyLimits(refClose);
        if (t2 > limits.ceiling) {
          limitWarning =
              '2R hedefi ($t2 TL) bugünkü tavan fiyatın (${limits.ceiling} TL) üzerinde; çok günlü taşınabilir (açılış boşluğu riski).';
        }
      }
    }

    final cur = ins.currency;
    final invalidation =
        '${detection.interval.code} mum kapanışı $stopPrice $cur altına inerse veya fiyat doğrudan $stopPrice $cur stop seviyesine değerse kurulum geçersiz olur.';

    return ExitPlan(
      instrument: ins,
      interval: detection.interval,
      primarySetup: detection.primarySetup,
      entryPrice: entry,
      entryZoneLow: _smartRound(detection.entryZoneLow, ins),
      entryZoneHigh: _smartRound(detection.entryZoneHigh, ins),
      stop: stopPrice,
      stopRule: chosenRule,
      stopLabel: stopLabel,
      stopDistancePct: double.parse(riskPct.toStringAsFixed(3)),
      target1: t1,
      target1R: target1R,
      target2: t2,
      target2R: target2R,
      breakevenTrigger: be,
      rewardRisk: rr,
      maxHoldBars: maxHoldBars,
      maxHoldDuration: maxHoldDuration,
      invalidationRule: invalidation,
      limitWarning: limitWarning,
    );
  }
}

