import 'dart:math' as math;

import '../model/candle.dart';

/// ADX ve yönlü hareket göstergesi çıktısı.
class AdxResult {
  const AdxResult({
    required this.adx,
    required this.plusDi,
    required this.minusDi,
  });

  final double adx;
  final double plusDi;
  final double minusDi;
}

/// Gerçekleşen oynaklık çıktısı.
class RealizedVolatility {
  const RealizedVolatility({
    required this.barStdPct,
    required this.annualizedPct,
  });

  /// Mum başına yüzde getiri standart sapması (%).
  final double barStdPct;

  /// Yıllıklandırılmış oynaklık (%).
  final double annualizedPct;
}

/// Teknik analiz göstergeleri.
///
/// `wilderRsi` ve `computeAtr` Python referans motorundaki (`agents/scanner_agent.py`)
/// formüllerle birebir aynı sonucu üretir.
class Indicators {
  const Indicators._();

  /// Wilder RSI hesaplaması. Yeterli kapanış yoksa (`closes.length < period + 1`) `null` döner.
  static double? wilderRsi(List<double> closes, {int period = 14}) {
    if (period <= 0 || closes.length < period + 1) return null;
    final gains = <double>[];
    final losses = <double>[];
    for (var i = 1; i < closes.length; i++) {
      final diff = closes[i] - closes[i - 1];
      gains.add(diff > 0 ? diff : 0.0);
      losses.add(diff < 0 ? -diff : 0.0);
    }
    var avgG = 0.0;
    var avgL = 0.0;
    for (var i = 0; i < period; i++) {
      avgG += gains[i];
      avgL += losses[i];
    }
    avgG /= period;
    avgL /= period;
    for (var i = period; i < gains.length; i++) {
      avgG = (avgG * (period - 1) + gains[i]) / period;
      avgL = (avgL * (period - 1) + losses[i]) / period;
    }
    if (avgL == 0.0) return 100.0;
    return 100.0 - (100.0 / (1.0 + avgG / avgL));
  }

  /// Son [period] mumun Gerçek Ortalama Aralığı (ATR).
  /// Python referansındaki `compute_atr` ile birebir uyumludur.
  static double computeAtr(List<Candle> bars, {int period = 14}) {
    if (bars.isEmpty || period <= 0) return 0.0;
    final trs = <double>[];
    double? prevC;
    for (final b in bars) {
      var tr = b.high - b.low;
      if (prevC != null) {
        final hc = (b.high - prevC).abs();
        final lc = (b.low - prevC).abs();
        if (hc > tr) tr = hc;
        if (lc > tr) tr = lc;
      }
      trs.add(tr);
      prevC = b.close;
    }
    final start = trs.length > period ? trs.length - period : 0;
    final use = trs.sublist(start);
    if (use.isEmpty) return 0.0;
    var sum = 0.0;
    for (final v in use) {
      sum += v;
    }
    return sum / use.length;
  }

  /// Basit hareketli ortalama (SMA). Yeterli veri yoksa `null` döner.
  static double? sma(List<double> values, int period) {
    if (period <= 0 || values.length < period) return null;
    var sum = 0.0;
    for (var i = values.length - period; i < values.length; i++) {
      sum += values[i];
    }
    return sum / period;
  }

  /// Üstel hareketli ortalama (EMA) dizisi. İlk [period] eleman SMA ile başlatılır.
  static List<double> emaSeries(List<double> values, int period) {
    if (period <= 0 || values.length < period) return const [];
    final k = 2.0 / (period + 1);
    var sum = 0.0;
    for (var i = 0; i < period; i++) {
      sum += values[i];
    }
    var cur = sum / period;
    final out = <double>[cur];
    for (var i = period; i < values.length; i++) {
      cur = values[i] * k + cur * (1.0 - k);
      out.add(cur);
    }
    return out;
  }

  /// Son EMA değeri. Yeterli veri yoksa `null` döner.
  static double? ema(List<double> values, int period) {
    final s = emaSeries(values, period);
    return s.isEmpty ? null : s.last;
  }

  /// Hacim ağırlıklı ortalama fiyat (VWAP). Son [lookback] mum üzerinden hesaplanır.
  static double vwap(List<Candle> bars, {int lookback = 24}) {
    if (bars.isEmpty) return 0.0;
    final start = bars.length > lookback ? bars.length - lookback : 0;
    final slice = bars.sublist(start);
    var totV = 0.0;
    var totPv = 0.0;
    for (final b in slice) {
      totV += b.volume;
      totPv += b.typical * b.volume;
    }
    return totV > 0 ? totPv / totV : bars.last.close;
  }

  /// Wilder ADX (Ortalama Yönlü Endeks) hesaplaması.
  /// En az `2 * period + 1` mum gerekir; aksi halde `null` döner.
  static AdxResult? adx(List<Candle> bars, {int period = 14}) {
    if (period <= 0 || bars.length < 2 * period + 1) return null;
    final tr = <double>[];
    final plusDm = <double>[];
    final minusDm = <double>[];

    for (var i = 1; i < bars.length; i++) {
      final cur = bars[i];
      final prev = bars[i - 1];
      final upMove = cur.high - prev.high;
      final downMove = prev.low - cur.low;
      plusDm.add((upMove > downMove && upMove > 0) ? upMove : 0.0);
      minusDm.add((downMove > upMove && downMove > 0) ? downMove : 0.0);
      final hl = cur.high - cur.low;
      final hc = (cur.high - prev.close).abs();
      final lc = (cur.low - prev.close).abs();
      tr.add(math.max(hl, math.max(hc, lc)));
    }

    var smoothTr = 0.0;
    var smoothPlus = 0.0;
    var smoothMinus = 0.0;
    for (var i = 0; i < period; i++) {
      smoothTr += tr[i];
      smoothPlus += plusDm[i];
      smoothMinus += minusDm[i];
    }

    final dxList = <double>[];
    double lastPlusDi = 0.0;
    double lastMinusDi = 0.0;

    void pushDx() {
      if (smoothTr <= 0) {
        dxList.add(0.0);
        return;
      }
      lastPlusDi = 100.0 * (smoothPlus / smoothTr);
      lastMinusDi = 100.0 * (smoothMinus / smoothTr);
      final denom = lastPlusDi + lastMinusDi;
      dxList.add(denom <= 0 ? 0.0 : 100.0 * (lastPlusDi - lastMinusDi).abs() / denom);
    }

    pushDx();
    for (var i = period; i < tr.length; i++) {
      smoothTr = smoothTr - (smoothTr / period) + tr[i];
      smoothPlus = smoothPlus - (smoothPlus / period) + plusDm[i];
      smoothMinus = smoothMinus - (smoothMinus / period) + minusDm[i];
      pushDx();
    }

    if (dxList.length < period) return null;
    var adxVal = 0.0;
    for (var i = 0; i < period; i++) {
      adxVal += dxList[i];
    }
    adxVal /= period;
    for (var i = period; i < dxList.length; i++) {
      adxVal = (adxVal * (period - 1) + dxList[i]) / period;
    }

    return AdxResult(adx: adxVal, plusDi: lastPlusDi, minusDi: lastMinusDi);
  }

  /// Gerçekleşen oynaklık: son [period] kapanış getirisinin örneklem standart sapması.
  static RealizedVolatility? realizedVolatility(
    List<Candle> bars, {
    int period = 20,
    double barsPerYear = 252.0,
  }) {
    if (period < 2 || bars.length < period + 1) return null;
    final rets = <double>[];
    for (var i = bars.length - period; i < bars.length; i++) {
      final prev = bars[i - 1].close;
      final cur = bars[i].close;
      if (prev <= 0 || cur <= 0) continue;
      rets.add((cur / prev - 1.0) * 100.0);
    }
    if (rets.length < 2) return null;
    final mean = rets.fold<double>(0.0, (a, b) => a + b) / rets.length;
    var sq = 0.0;
    for (final r in rets) {
      final d = r - mean;
      sq += d * d;
    }
    final stdPct = math.sqrt(sq / (rets.length - 1));
    return RealizedVolatility(
      barStdPct: stdPct,
      annualizedPct: stdPct * math.sqrt(barsPerYear),
    );
  }
}

