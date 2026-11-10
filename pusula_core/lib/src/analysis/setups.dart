import 'dart:math' as math;

import '../bist/bist_calendar.dart';
import '../bist/bist_rules.dart';
import '../model/candle.dart';
import '../model/market.dart';
import 'indicators.dart';
import 'regime.dart';

/// 6 teknik kurulum türü.
enum SetupType {
  orb('orb', 'Açılış Aralığı Kırılımı (ORB)', isBreakout: true),
  breakout20('breakout_20d', '20-Bar Zirve Kırılımı', isBreakout: true),
  bullFlag('bull_flag', 'Boğa Bayrağı Kırılımı', isBreakout: true),
  reclaimMa20('reclaim_ma20', 'MA20 Ortalamasını Geri Kazanım', isBreakout: false),
  oversoldBounce('oversold_bounce', 'RSI Aşırı Satım Tepkisi', isBreakout: false),
  vwapBreakout('vwap_breakout', 'VWAP + Hacim Kırılımı', isBreakout: true);

  const SetupType(this.code, this.label, {required this.isBreakout});

  final String code;
  final String label;

  /// Kırılım kurulumları yalnızca uygun rejimde (Boğa veya Yatay) çalışır; Ayı rejiminde elenir.
  final bool isBreakout;

  static SetupType fromCode(String code) =>
      values.firstWhere((v) => v.code == code || v.name == code, orElse: () => SetupType.orb);
}

/// Seans açılış aralığı (Opening Range) bilgisi.
class OpeningRange {
  const OpeningRange({
    required this.high,
    required this.low,
    required this.mid,
    required this.afterBarsCount,
  });

  final double high;
  final double low;
  final double mid;
  final int afterBarsCount;
}

/// Tespit edilen kurulum özeti (yalnızca kapanmış mumlardan üretilir).
class SetupDetection {
  const SetupDetection({
    required this.instrument,
    required this.interval,
    required this.setups,
    required this.primarySetup,
    required this.lastClose,
    required this.triggerLevel,
    required this.entryZoneLow,
    required this.entryZoneHigh,
    required this.openingRangeHigh,
    required this.openingRangeLow,
    required this.atr14,
    required this.rsi14,
    required this.ma20,
    required this.vwap,
    required this.volumeRatio,
    required this.takerBuyRatio,
    required this.lastClosedBarTime,
    required this.rationale,
  });

  final Instrument instrument;
  final BarInterval interval;
  final List<SetupType> setups;
  final SetupType primarySetup;
  final double lastClose;
  final double triggerLevel;
  final double entryZoneLow;
  final double entryZoneHigh;
  final double openingRangeHigh;
  final double openingRangeLow;
  final double atr14;
  final double rsi14;
  final double ma20;
  final double vwap;
  final double volumeRatio;
  final double takerBuyRatio;
  final DateTime lastClosedBarTime;
  final String rationale;
}

/// 6 kurulumu kapanmış mumlar üzerinde tarayan sınıf.
///
/// Kural:
/// - Kripto: `5m` veya `1h` dilimlerinde çalışır.
/// - BIST: yalnızca `1h` veya `1d` dilimlerinde çalışır (`5m` veya `15m` scalp desteklenmez).
/// - Kapanmamış (`forming`) mum kesinlikle kullanılmaz.
/// - Ayı (`MarketRegime.bear`) rejiminde kırılım kurulumları (`isBreakout == true`) süzülür.
class SetupScanner {
  const SetupScanner({this.orMinutes = 15});

  final int orMinutes;

  /// Bu piyasa ve dilim çifti tarama için geçerli mi?
  static bool isSupportedInterval(Market market, BarInterval interval) {
    if (market == Market.bist) {
      return interval == BarInterval.h1 || interval == BarInterval.d1;
    }
    return interval == BarInterval.m5 || interval == BarInterval.h1;
  }

  /// Kripto veya BIST için seans açılış aralığını (ORB) hesaplar.
  static OpeningRange? computeOpeningRange(
    Instrument instrument,
    BarInterval interval,
    List<Candle> closedBars, {
    int orMinutes = 15,
  }) {
    if (closedBars.length < 8) return null;

    if (instrument.market == Market.crypto && interval == BarInterval.m5) {
      final nOr = math.max(1, orMinutes ~/ interval.minutes);
      if (closedBars.length < nOr + 2) return null;
      final lastDt = closedBars.last.openTime;
      final sessionHour = (lastDt.hour ~/ 4) * 4;
      final sessionStart = DateTime.utc(lastDt.year, lastDt.month, lastDt.day, sessionHour);
      final startMs = sessionStart.millisecondsSinceEpoch;

      var sBars = [for (final b in closedBars) if (b.openTimeMs >= startMs) b];
      if (sBars.length <= nOr) {
        final prevMs = startMs - 4 * 3600 * 1000;
        sBars = [for (final b in closedBars) if (b.openTimeMs >= prevMs) b];
      }
      if (sBars.length <= nOr) {
        final take = math.min(closedBars.length, 36);
        sBars = closedBars.sublist(closedBars.length - take);
      }
      if (sBars.length <= nOr) return null;
      final orSlice = sBars.sublist(0, nOr);
      final afterSlice = sBars.sublist(nOr);
      var oh = orSlice.first.high;
      var ol = orSlice.first.low;
      for (final b in orSlice) {
        if (b.high > oh) oh = b.high;
        if (b.low < ol) ol = b.low;
      }
      return OpeningRange(high: oh, low: ol, mid: (oh + ol) / 2.0, afterBarsCount: afterSlice.length);
    }

    if (instrument.market == Market.bist && interval == BarInterval.h1) {
      // BIST saatlikte günün ilk saati (açılış mumu) OR kabul edilir.
      final lastTrt = BistCalendar.toTrt(closedBars.last.openTime);
      final dayBars = [
        for (final b in closedBars)
          if (_sameTrtDay(BistCalendar.toTrt(b.openTime), lastTrt)) b,
      ];
      if (dayBars.length >= 2) {
        final first = dayBars.first;
        return OpeningRange(
          high: first.high,
          low: first.low,
          mid: (first.high + first.low) / 2.0,
          afterBarsCount: dayBars.length - 1,
        );
      }
    }

    // 1h kripto veya 1d BIST için: son seans öncesi 3 mumluk baz aralık
    final nOr = 3;
    final look = math.min(closedBars.length, 10);
    final slice = closedBars.sublist(closedBars.length - look);
    if (slice.length <= nOr) return null;
    final orSlice = slice.sublist(0, nOr);
    var oh = orSlice.first.high;
    var ol = orSlice.first.low;
    for (final b in orSlice) {
      if (b.high > oh) oh = b.high;
      if (b.low < ol) ol = b.low;
    }
    return OpeningRange(high: oh, low: ol, mid: (oh + ol) / 2.0, afterBarsCount: slice.length - nOr);
  }

  static bool _sameTrtDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Verilen varlığın kapanmış mum serisinde kurulumları arar.
  ///
  /// [series.forming] kesinlikle okunmaz; yalnızca [series.closed] kullanılır.
  SetupDetection? analyze(
    CandleSeries series, {
    MarketRegime regime = MarketRegime.bull,
  }) {
    final ins = series.instrument;
    final iv = series.interval;
    if (!isSupportedInterval(ins.market, iv)) return null;

    final bars = series.closed;
    if (bars.length < 30) return null;

    final closes = [for (final b in bars) b.close];
    final highs = [for (final b in bars) b.high];
    final lows = [for (final b in bars) b.low];
    final qvols = [for (final b in bars) b.quoteVolume];

    final last = bars.last;
    final prev = bars[bars.length - 2];
    final cLast = last.close;
    final cPrev = prev.close;

    final rsiNow = Indicators.wilderRsi(closes, period: 14);
    final rsiPrev = Indicators.wilderRsi(closes.sublist(0, closes.length - 1), period: 14);
    final atr14 = Indicators.computeAtr(bars, period: 14);

    // RSI > 82 aşırı şişmiş mumları filtrele
    if (rsiNow != null && rsiNow > 82.0) return null;

    final ma20Now = Indicators.sma(closes, 20)!;
    final ma20Prev = Indicators.sma(closes.sublist(0, closes.length - 1), 20)!;

    var hi20Close = closes[closes.length - 21];
    var hi20High = highs[highs.length - 21];
    var volSum20 = 0.0;
    for (var i = bars.length - 21; i < bars.length - 1; i++) {
      if (closes[i] > hi20Close) hi20Close = closes[i];
      if (highs[i] > hi20High) hi20High = highs[i];
      volSum20 += qvols[i];
    }
    final avgVol20 = volSum20 > 0 ? volSum20 / 20.0 : 1.0;
    final volRatio = last.quoteVolume / avgVol20;

    final vwapVal = Indicators.vwap(bars, lookback: 24);

    // Boğa Bayrağı (Bull Flag): 15 bar öncesinden 5 bar öncesine en az %1.8 yükseliş direği
    // + son 5 bar dar sıkışma (%2.2 altı) + son kapanmış mum yukarı kırılım
    final poleBase = closes[closes.length - 16];
    final poleTop = closes[closes.length - 6];
    final poleRun = poleBase > 0 ? (poleTop / poleBase) - 1.0 : 0.0;
    var flagHigh = highs[highs.length - 6];
    var flagLow = lows[lows.length - 6];
    for (var i = bars.length - 6; i < bars.length - 1; i++) {
      if (highs[i] > flagHigh) flagHigh = highs[i];
      if (lows[i] < flagLow) flagLow = lows[i];
    }
    final flagRange = cLast > 0 ? (flagHigh - flagLow) / cLast : 1.0;

    final orbInfo = computeOpeningRange(ins, iv, bars, orMinutes: orMinutes);

    final rawSetups = <SetupType>[];
    var primaryLevel = hi20High;
    double? orHigh = orbInfo?.high;
    double? orLow = orbInfo?.low;

    // 1. ORB Kırılımı
    if (orbInfo != null && orbInfo.high > orbInfo.low) {
      final oh = orbInfo.high;
      final pctOverOrb = (cLast / oh - 1.0) * 100.0;
      if (cLast > oh &&
          (cPrev <= oh * 1.003 || orbInfo.afterBarsCount <= 6) &&
          pctOverOrb >= 0.01 &&
          pctOverOrb <= 3.5) {
        rawSetups.add(SetupType.orb);
        primaryLevel = oh;
      }
    }

    // 2. 20-Bar Zirve Kırılımı
    if (cLast > hi20Close && cPrev <= hi20Close && volRatio >= 1.1) {
      rawSetups.add(SetupType.breakout20);
      if (!rawSetups.contains(SetupType.orb)) {
        primaryLevel = hi20Close;
      }
    }

    // 3. Boğa Bayrağı Kırılımı
    if (poleRun >= 0.018 && flagRange <= 0.025 && cLast > flagHigh) {
      rawSetups.add(SetupType.bullFlag);
      if (rawSetups.length == 1) {
        primaryLevel = flagHigh;
      }
    }

    // 4. MA20 Geri Kazanım
    if (cPrev < ma20Prev && cLast > ma20Now && volRatio >= 1.15 && cLast > last.open) {
      rawSetups.add(SetupType.reclaimMa20);
      if (rawSetups.length == 1) {
        primaryLevel = ma20Now;
      }
    }

    // 5. RSI Aşırı Satım Tepkisi
    if (rsiPrev != null && rsiPrev < 32.0 && cLast > cPrev && cLast > last.open) {
      rawSetups.add(SetupType.oversoldBounce);
      if (rawSetups.length == 1) {
        primaryLevel = cPrev;
      }
    }

    // 6. VWAP + Hacim Kırılımı
    if (cPrev <= vwapVal && cLast > vwapVal && volRatio >= 1.4 && (rsiNow ?? 50.0) < 74.0) {
      rawSetups.add(SetupType.vwapBreakout);
      if (rawSetups.length == 1) {
        primaryLevel = vwapVal;
      }
    }

    // Rejim süzgeci: Ayı rejiminde kırılım kurulumları (isBreakout) devre dışı bırakılır.
    final filteredSetups = [
      for (final s in rawSetups)
        if (!(regime == MarketRegime.bear && s.isBreakout)) s,
    ];

    if (filteredSetups.isEmpty) return null;

    if (orHigh == null || orLow == null || orHigh <= orLow) {
      final refBars = bars.sublist(bars.length - 4, bars.length - 1);
      var rh = refBars.first.high;
      var rl = refBars.first.low;
      for (final b in refBars) {
        if (b.high > rh) rh = b.high;
        if (b.low < rl) rl = b.low;
      }
      if (rh <= rl) {
        rl = cLast - math.max(atr14 * 1.5, cLast * 0.008);
      }
      orHigh = rh;
      orLow = rl;
    }

    // Mum içi alıcı baskısı (son 5 kapanmış mum)
    var takerBuyRatio = 0.52;
    final recent5 = bars.sublist(bars.length - 5);
    var totQv = 0.0;
    var buyQv = 0.0;
    var hasTaker = false;
    for (final b in recent5) {
      totQv += b.quoteVolume;
      if (b.takerBuyQuote != null) {
        buyQv += b.takerBuyQuote!;
        hasTaker = true;
      }
    }
    if (hasTaker && totQv > 0) {
      takerBuyRatio = (buyQv / totQv).clamp(0.0, 1.0);
    }

    // Giriş bölgesi hesabı (BIST'te nokta değil bölge, fiyat adımına yuvarlanmış)
    final bandHalf = math.max(atr14 * 0.25, cLast * 0.0025);
    var zoneLow = math.min(primaryLevel, cLast - bandHalf * 0.5);
    var zoneHigh = math.max(cLast, primaryLevel) + bandHalf;
    var trig = primaryLevel;

    if (ins.market == Market.bist) {
      zoneLow = BistRules.roundToTick(zoneLow);
      zoneHigh = BistRules.roundToTick(zoneHigh);
      trig = BistRules.roundToTick(trig);
      if (zoneHigh <= zoneLow) {
        zoneHigh = BistRules.roundToTick(zoneLow + BistRules.tickSize(zoneLow));
      }
    }

    final labels = [for (final s in filteredSetups) s.label].join(' + ');
    final rationale = '${ins.short} (${iv.code}): $labels teyit edildi · '
        'Kapanış ${cLast.toStringAsFixed(ins.market == Market.bist ? 2 : 4)}, '
        'Hacim ${volRatio.toStringAsFixed(2)}x, RSI ${(rsiNow ?? 50.0).toStringAsFixed(1)}.';

    return SetupDetection(
      instrument: ins,
      interval: iv,
      setups: filteredSetups,
      primarySetup: filteredSetups.first,
      lastClose: cLast,
      triggerLevel: trig,
      entryZoneLow: zoneLow,
      entryZoneHigh: zoneHigh,
      openingRangeHigh: orHigh,
      openingRangeLow: orLow,
      atr14: atr14,
      rsi14: rsiNow ?? 50.0,
      ma20: ma20Now,
      vwap: vwapVal,
      volumeRatio: volRatio,
      takerBuyRatio: takerBuyRatio,
      lastClosedBarTime: last.openTime,
      rationale: rationale,
    );
  }
}

