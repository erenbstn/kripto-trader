import '../model/candle.dart';
import '../model/market.dart';
import 'indicators.dart';

/// Üst zaman dilimi trend yönü.
enum HigherTimeframeTrend {
  bullish('Yükseliş Trendi'),
  neutral('Yatay / Nötr'),
  bearish('Düşüş Trendi');

  const HigherTimeframeTrend(this.label);
  final String label;
}

/// Çok zaman dilimli (sinyal dilimi + üst dilim) teyit sonucu.
class MultiTimeframeConfirmation {
  const MultiTimeframeConfirmation({
    required this.signalInterval,
    required this.higherInterval,
    required this.trend,
    required this.aligned,
    required this.ema20,
    required this.ema50,
    required this.rsi14,
    required this.summary,
  });

  final BarInterval signalInterval;
  final BarInterval higherInterval;
  final HigherTimeframeTrend trend;

  /// Long sinyal için üst dilim destekliyor mu? (`bullish` ise true).
  final bool aligned;
  final double ema20;
  final double ema50;
  final double rsi14;
  final String summary;

  /// Kırılım sinyallerini engellemesi gereken sert ters trend var mı?
  bool get blocksBreakout => trend == HigherTimeframeTrend.bearish;
}

/// Sinyal dilimini bir üst zaman diliminin trendiyle doğrulayan sınıf.
class MultiTimeframeAnalyzer {
  const MultiTimeframeAnalyzer();

  /// Sinyal dilimine karşılık gelen üst zaman dilimini döndürür.
  static BarInterval higherIntervalFor(Market market, BarInterval signalInterval) {
    if (market == Market.bist) {
      // BIST 4 saatlik desteklemez (YahooProvider kısıtı); 1h -> 1d, 1d -> 1d (uzun periyot)
      return BarInterval.d1;
    }
    switch (signalInterval) {
      case BarInterval.m5:
      case BarInterval.m15:
        return BarInterval.h1;
      case BarInterval.h1:
        return BarInterval.h4;
      case BarInterval.h4:
      case BarInterval.d1:
        return BarInterval.d1;
    }
  }

  /// Üst dilim kapanmış mumlarını inceleyerek trend uyumunu değerlendirir.
  MultiTimeframeConfirmation evaluate({
    required Market market,
    required BarInterval signalInterval,
    required List<Candle> higherClosedBars,
  }) {
    final higherIv = higherIntervalFor(market, signalInterval);
    if (higherClosedBars.length < 25) {
      final last = higherClosedBars.isEmpty ? 0.0 : higherClosedBars.last.close;
      return MultiTimeframeConfirmation(
        signalInterval: signalInterval,
        higherInterval: higherIv,
        trend: HigherTimeframeTrend.neutral,
        aligned: false,
        ema20: last,
        ema50: last,
        rsi14: 50.0,
        summary: 'Üst dilim (${higherIv.code}) için yeterli mum yok; nötr kabul edildi.',
      );
    }

    final closes = [for (final b in higherClosedBars) b.close];
    final last = closes.last;
    final ema20Series = Indicators.emaSeries(closes, 20);
    final ema20 = ema20Series.isEmpty ? last : ema20Series.last;
    final slowP = closes.length >= 50 ? 50 : 30;
    final ema50Series = Indicators.emaSeries(closes, slowP);
    final ema50 = ema50Series.isEmpty ? last : ema50Series.last;
    final rsi = Indicators.wilderRsi(closes, period: 14) ?? 50.0;

    var slope = 0.0;
    if (ema20Series.length >= 4) {
      final prev = ema20Series[ema20Series.length - 4];
      if (prev > 0) slope = ((ema20 / prev) - 1.0) * 100.0;
    }

    final HigherTimeframeTrend trend;
    if (last >= ema20 && ema20 >= ema50 * 0.997 && rsi >= 46.0 && slope >= -0.05) {
      trend = HigherTimeframeTrend.bullish;
    } else if (last < ema20 && ema20 < ema50 && (rsi < 44.0 || slope < -0.10)) {
      trend = HigherTimeframeTrend.bearish;
    } else {
      trend = HigherTimeframeTrend.neutral;
    }

    final aligned = trend == HigherTimeframeTrend.bullish;
    return MultiTimeframeConfirmation(
      signalInterval: signalInterval,
      higherInterval: higherIv,
      trend: trend,
      aligned: aligned,
      ema20: ema20,
      ema50: ema50,
      rsi14: rsi,
      summary: 'Üst dilim (${higherIv.code}): ${trend.label} '
          '(EMA20 ${ema20.toStringAsFixed(2)}, EMA$slowP ${ema50.toStringAsFixed(2)}, RSI ${rsi.toStringAsFixed(1)})',
    );
  }
}
