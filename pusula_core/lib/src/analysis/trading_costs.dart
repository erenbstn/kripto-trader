import '../model/market.dart';
import 'exit_plan.dart';

/// Bir çıkış planının işlem maliyeti karşısındaki durumu.
class CostImpact {
  const CostImpact({
    required this.roundTripCostPct,
    required this.costShareOfRisk,
    required this.netRewardRisk,
  });

  /// Alış + satış toplam maliyeti (komisyon + makas/kayma tahmini), fiyatın yüzdesi.
  final double roundTripCostPct;

  /// Maliyetin 1R'ye (stop mesafesine) oranı. 0,25 → maliyet riskin dörtte birini yiyor.
  final double costShareOfRisk;

  /// Maliyet düşüldükten sonra ana hedefe göre net Ödül/Risk.
  final double netRewardRisk;
}

/// Gerçek piyasa koşullarına uyum için işlem maliyeti varsayımları (K9).
///
/// Değerler tahmindir, aracı kuruma göre değişir; kullanıcıya "varsayım" olarak gösterilir.
/// - Kripto: spot piyasa alıcı komisyonu ~%0,10 × 2 yön = %0,20.
/// - BIST: komisyon + BSMV ~%0,10 × 2 yön + makas/kayma payı ~%0,10 = %0,30.
class TradingCosts {
  const TradingCosts({
    this.cryptoRoundTripPct = 0.20,
    this.bistRoundTripPct = 0.30,
  });

  final double cryptoRoundTripPct;
  final double bistRoundTripPct;

  double roundTripPct(Market market) => market == Market.bist ? bistRoundTripPct : cryptoRoundTripPct;

  /// Planın stop mesafesine göre maliyet etkisini hesaplar.
  ///
  /// Net R:R = (brüt R − maliyetR) / (1 + maliyetR): kazançtan maliyet düşer, kayba maliyet eklenir.
  CostImpact impact(ExitPlan plan) {
    final cost = roundTripPct(plan.instrument.market);
    final stopPct = plan.stopDistancePct > 0 ? plan.stopDistancePct : 0.01;
    final costR = cost / stopPct;
    final net = (plan.rewardRisk - costR) / (1.0 + costR);
    return CostImpact(
      roundTripCostPct: cost,
      costShareOfRisk: double.parse(costR.toStringAsFixed(3)),
      netRewardRisk: double.parse(net.toStringAsFixed(2)),
    );
  }
}
