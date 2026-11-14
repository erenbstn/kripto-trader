import 'package:flutter/material.dart';
import 'package:pusula_core/pusula_core.dart';

import '../theme/gunduz_theme.dart';
import 'common.dart';

/// Sinyal durumunun Türkçe etiketi, rengi ve ikonu (renk hiçbir zaman tek başına kullanılmaz).
({String label, Color color, IconData icon}) signalStatusStyle(PusulaPalette p, SignalRecord s) {
  switch (s.status) {
    case SignalStatus.open:
      return (label: 'AÇIK', color: p.accent, icon: Icons.radio_button_checked);
    case SignalStatus.target1:
      return (label: 'HEDEF 1 · BAŞABAŞ KORUMALI', color: p.profit, icon: Icons.shield_outlined);
    case SignalStatus.target2:
      return (label: 'HEDEFE ULAŞTI', color: p.profit, icon: Icons.check_circle_outline);
    case SignalStatus.stop:
      return s.breakevenStop
          ? (label: 'BAŞABAŞ KAPANDI', color: p.neutral, icon: Icons.remove_circle_outline)
          : (label: 'STOP OLDU', color: p.loss, icon: Icons.cancel_outlined);
    case SignalStatus.expired:
      return (label: 'SÜRE DOLDU', color: p.neutral, icon: Icons.timer_off_outlined);
    case SignalStatus.invalidated:
      return (label: 'GEÇERSİZ', color: p.neutral, icon: Icons.block);
  }
}

/// Tek sinyal kartı (Sadece Spot · bütçe verilirse kesin alım/satım adedi gösterir).
class SignalCard extends StatelessWidget {
  const SignalCard({
    super.key,
    required this.signal,
    this.currentPrice,
    this.allocatedTry,
    this.usdTryRate = 36.50,
    this.compact = false,
  });

  final SignalRecord signal;
  final double? currentPrice;
  final double? allocatedTry;
  final double usdTryRate;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = PusulaPalette.of(context);
    final s = signal;
    final market = s.instrument.market;
    final st = signalStatusStyle(p, s);
    final horizon = classifyHorizon(s);
    final now = DateTime.now().toUtc();
    final plan = (allocatedTry != null && allocatedTry! > 0)
        ? OrderSizingPlan.fromSignal(signal: s, allocatedTry: allocatedTry!, usdTryRate: usdTryRate)
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          MarketTag(market),
                          Tag(horizon.label, color: p.profit),
                          Tag('SPOT', color: p.accent),
                          Tag(st.label, color: st.color, icon: st.icon),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        s.instrument.short,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                      ),
                      Text(
                        s.strategy.label,
                        style: TextStyle(fontSize: 12.5, color: p.textDim, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ConfidenceRing(score: s.confidence.total, size: 50),
              ],
            ),
            if (plan != null && s.isActive) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: p.subtle, borderRadius: BorderRadius.circular(10)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alım: ${Fmt.currencyTry(plan.allocatedTry)} · ${plan.qtyBuyLabel()} AL',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: p.profit),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'H1: ${plan.qtyT1Label()} sat · H2: ${plan.qtyT2Label()} sat · Stop: ${plan.qtyStopLabel()} sat',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: p.textDim),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            PriceLadder(
              market: market,
              stop: s.initialStop,
              entry: s.entryPrice,
              target1: s.target1,
              target2: s.target2,
              current: s.isActive ? currentPrice : s.exitPrice,
            ),
            const SizedBox(height: 10),
            if (s.realizedR != null) ...[
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  SignedMetricChip(value: s.realizedR!, suffix: 'R', decimals: 2),
                  if (s.realizedPct != null) SignedMetricChip(value: s.realizedPct!, suffix: '', prefix: '%', decimals: 2),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (s.status == SignalStatus.target1 && s.isActive)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'Stop başabaş (${Fmt.priceWithCurrency(s.currentStop, market)})',
                  style: TextStyle(fontSize: 12, color: p.profit, fontWeight: FontWeight.w600),
                ),
              ),
            Text(
              'Giriş ${Fmt.priceWithCurrency(s.entryZoneLow, market)}–${Fmt.priceWithCurrency(s.entryZoneHigh, market)}'
              ' · Ö/R ${Fmt.number(s.rewardRisk, decimals: 1)}'
              ' · Monte Carlo +${s.confidence.monteCarloScore}/15',
              style: TextStyle(fontSize: 11.5, color: p.textDim, height: 1.3),
            ),
            if (!compact) ...[
              const SizedBox(height: 5),
              Text(
                s.rationale,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, height: 1.35),
              ),
              if (s.exitReason != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Sonuç: ${s.exitReason}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: st.color),
                ),
              ],
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DataProvenanceBadge(
                    sourceLabel: s.dataSource,
                    ageMinutes: (s.dataAgeMs / 60000).round(),
                    isStale: s.dataStale,
                  ),
                ),
                Text(
                  Fmt.ago(s.createdAt, now),
                  style: TextStyle(fontSize: 11, color: p.textDim),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
