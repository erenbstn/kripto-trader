import 'package:flutter/material.dart';
import 'package:pusula_core/pusula_core.dart';

import '../theme/gunduz_theme.dart';
import 'common.dart';

/// Haftalık / uzun vade öneri kartı (Sadece Spot · kesin TL tutar ve adet planı).
class RecommendationDetailCard extends StatefulWidget {
  const RecommendationDetailCard({
    super.key,
    required this.recommendation,
    required this.budgetAmount,
    this.usdTryRate = 36.50,
    this.currentPrice,
    this.initiallyExpanded = false,
  });

  final WeeklyRecommendation recommendation;
  final double budgetAmount;
  final double usdTryRate;
  final double? currentPrice;
  final bool initiallyExpanded;

  @override
  State<RecommendationDetailCard> createState() => _RecommendationDetailCardState();
}

class _RecommendationDetailCardState extends State<RecommendationDetailCard> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final p = PusulaPalette.of(context);
    final rec = widget.recommendation;
    final sig = rec.signal;
    final market = rec.instrument.market;
    final accent = MarketTag.colorOf(context, market);
    final amount = widget.budgetAmount * rec.weightPct / 100.0;
    final plan = OrderSizingPlan.fromSignal(
      signal: sig,
      allocatedTry: amount,
      usdTryRate: widget.usdTryRate,
    );

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
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
                            children: [
                              MarketTag(market),
                              Tag(plan.horizon.label, color: p.profit),
                              Tag('SPOT', color: p.accent),
                              Tag(sig.regime.label, color: p.neutral),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            rec.instrument.symbol,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4),
                          ),
                          if (rec.instrument.name.isNotEmpty)
                            Text(rec.instrument.name, style: TextStyle(fontSize: 12.5, color: p.textDim)),
                          const SizedBox(height: 2),
                          Text(
                            sig.strategy.label,
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: accent),
                          ),
                        ],
                      ),
                    ),
                    ConfidenceRing(score: rec.confidence.total, size: 58),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: p.subtle, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: StatTile(
                              label: 'Alım (₺)',
                              value: Fmt.currencyTry(amount),
                              valueColor: p.profit,
                              hint: Fmt.pct(rec.weightPct),
                              big: true,
                            ),
                          ),
                          Expanded(
                            child: StatTile(
                              label: 'Alınacak',
                              value: plan.qtyBuyLabel(),
                              hint: '@ ${Fmt.priceWithCurrency(sig.entryPrice, market)}',
                            ),
                          ),
                          StatTile(
                            label: 'Risk',
                            value: Fmt.pct(rec.riskContributionPct, decimals: 2),
                          ),
                        ],
                      ),
                      const Divider(height: 14),
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          Text(
                            'Hedef 1: ${plan.qtyT1Label()} sat @ ${Fmt.priceWithCurrency(sig.target1, market)}',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: p.profit),
                          ),
                          Text(
                            'Hedef 2: ${plan.qtyT2Label()} sat @ ${Fmt.priceWithCurrency(sig.target2, market)}',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: p.profit),
                          ),
                          Text(
                            'Stop: ${plan.qtyStopLabel()} sat @ ${Fmt.priceWithCurrency(sig.initialStop, market)}',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: p.loss),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                PriceLadder(
                  market: market,
                  stop: sig.initialStop,
                  entry: sig.entryPrice,
                  target1: sig.target1,
                  target2: sig.target2,
                  current: widget.currentPrice,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 18,
                  runSpacing: 8,
                  children: [
                    StatTile(
                      label: 'Giriş',
                      value: '${Fmt.priceWithCurrency(sig.entryZoneLow, market)}–${Fmt.priceWithCurrency(sig.entryZoneHigh, market)}',
                    ),
                    StatTile(
                      label: 'Stop',
                      value: '-${Fmt.pct(rec.stopDistancePct)}',
                      valueColor: p.loss,
                    ),
                    StatTile(label: 'Ö/R', value: '${Fmt.number(sig.rewardRisk, decimals: 1)}R'),
                  ],
                ),
                const SizedBox(height: 10),
                Text(sig.rationale, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, height: 1.35)),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.do_not_disturb_on_outlined, size: 14, color: p.coral),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'İptal: ${sig.invalidationRule}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, color: p.textDim, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                DataProvenanceBadge(
                  sourceLabel: sig.dataSource,
                  ageMinutes: (sig.dataAgeMs / 60000).round(),
                  isStale: sig.dataStale,
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Güven & riskler',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: p.accent),
                    ),
                  ),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 20, color: p.accent),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConfidenceBars(breakdown: rec.confidence),
                  const SizedBox(height: 8),
                  for (final risk in rec.keyRisks)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text('• $risk', style: TextStyle(fontSize: 11.5, color: p.textDim, height: 1.3)),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
