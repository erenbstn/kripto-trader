import '../model/candle.dart';
import '../model/market.dart';

/// Piyasa akışı, alıcı baskısı, emir defteri bilgisi ve vadeli fonlama raporu.
///
/// K7 / R6 kuralı:
/// - 20 seviyelik emir defteri dengesi (`orderbookBidAskRatio`) kolay manipüle edildiği için
///   veto girdisinden çıkarılmıştır; yalnızca bilgi alanı olarak saklanır.
/// - Vadeli fonlama oranı (`fundingRatePct > maxFundingRatePct`) vetosu korunmuştur.
class WhaleReport {
  const WhaleReport({
    required this.instrument,
    required this.takerBuyPct,
    required this.flowLabel,
    required this.orderbookBidAskRatio,
    required this.orderbookInfoNote,
    required this.fundingRatePct,
    required this.veto,
    required this.vetoReason,
  });

  final Instrument instrument;
  final double takerBuyPct;
  final String flowLabel;

  /// Bilgi amaçlı emir defteri alış/satış oranı (karar/veto ağırlığı yoktur).
  final double? orderbookBidAskRatio;
  final String orderbookInfoNote;

  /// Vadeli fonlama oranı (%). Kripto dışında `0.0` olur.
  final double fundingRatePct;

  /// Yalnızca aşırı pozitif fonlama oranında (`fundingRatePct > maxFundingRatePct`) true olur.
  final bool veto;
  final String vetoReason;
}

class WhaleAnalyzer {
  const WhaleAnalyzer({this.maxFundingRatePct = 0.20});

  /// Long squeeze riskine karşı vadeli fonlama oranı üst sınırı (%).
  final double maxFundingRatePct;

  WhaleReport evaluate(
    Instrument instrument,
    List<Candle> closedBars, {
    double fundingRatePct = 0.01,
    double? orderbookBidAskRatio,
  }) {
    var takerBuyRatio = 0.52;
    if (closedBars.length >= 5) {
      final recent = closedBars.sublist(closedBars.length - 5);
      var totQv = 0.0;
      var buyQv = 0.0;
      var hasTaker = false;
      for (final b in recent) {
        totQv += b.quoteVolume;
        if (b.takerBuyQuote != null) {
          buyQv += b.takerBuyQuote!;
          hasTaker = true;
        }
      }
      if (hasTaker && totQv > 0) {
        takerBuyRatio = (buyQv / totQv).clamp(0.0, 1.0);
      }
    }

    final String flowLabel;
    if (takerBuyRatio >= 0.58) {
      flowLabel = 'Güçlü Alıcı Baskısı (Agresif Alım)';
    } else if (takerBuyRatio >= 0.52) {
      flowLabel = 'Pozitif Alıcı Akışı';
    } else if (takerBuyRatio <= 0.42) {
      flowLabel = 'Satıcı Ağırlıklı Akış';
    } else {
      flowLabel = 'Dengeli Akış';
    }

    // Emir defteri oranı yalnızca bilgi alanıdır, veto üretmez (R6).
    final String obNote;
    if (orderbookBidAskRatio == null) {
      obNote = 'Emir defteri anlık görüntüsü yok (yalnızca bilgi alanı)';
    } else {
      obNote = 'Emir defteri alış/satış oranı: ${orderbookBidAskRatio.toStringAsFixed(2)}x (bilgi amaçlı, karar dışı)';
    }

    final veto = instrument.market == Market.crypto && fundingRatePct > maxFundingRatePct;
    final vetoReason = veto
        ? 'Vadeli fonlama oranı aşırı şişmiş (+%${fundingRatePct.toStringAsFixed(3)} > %${maxFundingRatePct.toStringAsFixed(2)}): Long sıkışması riski yüksek.'
        : '';

    return WhaleReport(
      instrument: instrument,
      takerBuyPct: double.parse((takerBuyRatio * 100.0).toStringAsFixed(1)),
      flowLabel: flowLabel,
      orderbookBidAskRatio: orderbookBidAskRatio,
      orderbookInfoNote: obNote,
      fundingRatePct: fundingRatePct,
      veto: veto,
      vetoReason: vetoReason,
    );
  }
}
