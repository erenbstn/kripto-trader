import '../model/candle.dart';
import '../model/market.dart';
import 'indicators.dart';

/// Piyasa rejimi sınıflandırması.
enum MarketRegime {
  bull('Boğa', 1.0),
  sideways('Yatay', 0.85),
  bear('Ayı', 0.5);

  const MarketRegime(this.label, this.riskMultiplier);

  /// Kullanıcıya dönük Türkçe etiket.
  final String label;

  /// Ayı rejiminde risk payı yarıya iner (K3, K7).
  final double riskMultiplier;
}

/// Referans endeks / varlık (BTCUSDT veya XU100) üzerinden hesaplanan rejim raporu.
class RegimeReport {
  const RegimeReport({
    required this.benchmark,
    required this.regime,
    required this.lastClose,
    required this.emaFast,
    required this.emaSlow,
    required this.emaFastSlopePct,
    required this.adx,
    required this.barVolatilityPct,
    required this.summary,
  });

  final Instrument benchmark;
  final MarketRegime regime;
  final double lastClose;
  final double emaFast;
  final double emaSlow;

  /// Hızlı EMA'nın son 5 mumdaki yüzde değişimi.
  final double emaFastSlopePct;
  final double adx;
  final double barVolatilityPct;
  final String summary;

  double get riskMultiplier => regime.riskMultiplier;

  Map<String, Object?> toJson() => {
        'benchmark': benchmark.id,
        'regime': regime.name,
        'lastClose': lastClose,
        'emaFast': emaFast,
        'emaSlow': emaSlow,
        'emaFastSlopePct': emaFastSlopePct,
        'adx': adx,
        'barVolatilityPct': barVolatilityPct,
        'summary': summary,
      };

  static RegimeReport fromJson(Map<String, Object?> j) => RegimeReport(
        benchmark: Instrument.parseId(j['benchmark'] as String),
        regime: MarketRegime.values.byName(j['regime'] as String),
        lastClose: (j['lastClose'] as num).toDouble(),
        emaFast: (j['emaFast'] as num).toDouble(),
        emaSlow: (j['emaSlow'] as num).toDouble(),
        emaFastSlopePct: (j['emaFastSlopePct'] as num).toDouble(),
        adx: (j['adx'] as num).toDouble(),
        barVolatilityPct: (j['barVolatilityPct'] as num).toDouble(),
        summary: j['summary'] as String,
      );
}

/// BTCUSDT ve XU100 için EMA50/200 eğimi + ADX + gerçekleşen oynaklık tabanlı rejim tespitçisi.
class RegimeDetector {
  const RegimeDetector({
    this.fastEmaPeriod = 50,
    this.slowEmaPeriod = 200,
    this.adxPeriod = 14,
    this.trendAdxThreshold = 18.0,
    this.highBarVolatilityPct = 3.8,
  });

  final int fastEmaPeriod;
  final int slowEmaPeriod;
  final int adxPeriod;
  final double trendAdxThreshold;
  final double highBarVolatilityPct;

  RegimeReport detect(Instrument benchmark, List<Candle> closedBars) {
    if (closedBars.length < 30) {
      final last = closedBars.isEmpty ? 0.0 : closedBars.last.close;
      return RegimeReport(
        benchmark: benchmark,
        regime: MarketRegime.sideways,
        lastClose: last,
        emaFast: last,
        emaSlow: last,
        emaFastSlopePct: 0.0,
        adx: 15.0,
        barVolatilityPct: 0.0,
        summary: '${benchmark.short} için yeterli geçmiş mum yok (${closedBars.length}); varsayılan Yatay rejim.',
      );
    }

    final closes = [for (final c in closedBars) c.close];
    final last = closes.last;

    final effFast = closedBars.length >= fastEmaPeriod ? fastEmaPeriod : 20;
    final effSlow = closedBars.length >= slowEmaPeriod ? slowEmaPeriod : (closedBars.length >= 60 ? 50 : 30);

    final fastSeries = Indicators.emaSeries(closes, effFast);
    final slowSeries = Indicators.emaSeries(closes, effSlow);
    final emaFast = fastSeries.isEmpty ? last : fastSeries.last;
    final emaSlow = slowSeries.isEmpty ? last : slowSeries.last;

    var slopePct = 0.0;
    if (fastSeries.length >= 6) {
      final prevFast = fastSeries[fastSeries.length - 6];
      if (prevFast > 0) {
        slopePct = ((emaFast / prevFast) - 1.0) * 100.0;
      }
    }

    final adxRes = Indicators.adx(closedBars, period: adxPeriod);
    final adxVal = adxRes?.adx ?? 16.0;
    final plusDi = adxRes?.plusDi ?? 20.0;
    final minusDi = adxRes?.minusDi ?? 20.0;

    final volRes = Indicators.realizedVolatility(
      closedBars,
      period: 20,
      barsPerYear: benchmark.market == Market.crypto ? 365.0 : 252.0,
    );
    final barVol = volRes?.barStdPct ?? 1.0;

    final MarketRegime regime;
    final String reason;

    final aboveFast = last > emaFast;
    final fastAboveSlow = emaFast >= emaSlow * 0.998;
    final belowFast = last < emaFast;
    final fastBelowSlow = emaFast <= emaSlow * 1.002;

    if (belowFast &&
        ((fastBelowSlow && slopePct < -0.05) ||
            (adxVal >= trendAdxThreshold && minusDi > plusDi && slopePct < 0) ||
            (barVol >= highBarVolatilityPct && slopePct < -0.15))) {
      regime = MarketRegime.bear;
      reason = 'Fiyat EMA$effFast altında, eğim ${slopePct.toStringAsFixed(2)}%, ADX ${adxVal.toStringAsFixed(1)} (Ayı rejimi — risk yarıya iner)';
    } else if (aboveFast &&
        fastAboveSlow &&
        slopePct > 0.03 &&
        (adxVal >= trendAdxThreshold || plusDi > minusDi * 1.15)) {
      regime = MarketRegime.bull;
      reason = 'Fiyat EMA$effFast/$effSlow üzerinde, eğim +${slopePct.toStringAsFixed(2)}%, ADX ${adxVal.toStringAsFixed(1)} (Boğa rejimi)';
    } else {
      regime = MarketRegime.sideways;
      reason = 'Yatay/kararsız görünüm (Eğim ${slopePct.toStringAsFixed(2)}%, ADX ${adxVal.toStringAsFixed(1)}, Oynaklık %${barVol.toStringAsFixed(2)})';
    }

    return RegimeReport(
      benchmark: benchmark,
      regime: regime,
      lastClose: last,
      emaFast: emaFast,
      emaSlow: emaSlow,
      emaFastSlopePct: slopePct,
      adx: adxVal,
      barVolatilityPct: barVol,
      summary: '${benchmark.short}: ${regime.label} — $reason',
    );
  }
}
