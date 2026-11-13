import 'package:flutter/material.dart';
import 'package:pusula_core/pusula_core.dart';

import '../theme/gunduz_theme.dart';
import 'common.dart';

/// Haftalık öneri veya bütçe halkası dilimi için detaylı analiz kartı.
///
/// Bilgi sırası karar sırasını izler: ne (varlık + ağırlık) → nereden nereye (fiyat merdiveni) →
/// neden (gerekçe) → ne zaman vazgeçilir (geçersiz kılma) → neye güveniliyor (güven dökümü, riskler).
class RecommendationDetailCard extends StatefulWidget {
  const RecommendationDetailCard({
    super.key,
    required this.recommendation,
    required this.budgetAmount,
    this.currentPrice,
    this.initiallyExpanded = false,
  });

  final WeeklyRecommendation recommendation;
  final double budgetAmount;
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
                  child: Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          label: 'Bütçe ağırlığı',
                          value: Fmt.pct(rec.weightPct),
                          valueColor: accent,
                          big: true,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: StatTile(
                          label: 'Tutar karşılığı',
                          value: '≈ ${Fmt.tl(amount)}',
                          hint: rec.estimatedLots != null ? '≈ ${rec.estimatedLots} lot' : null,
                        ),
                      ),
                      StatTile(
                        label: 'Açık risk payı',
                        value: Fmt.pct(rec.riskContributionPct, decimals: 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                PriceLadder(
                  market: market,
                  stop: sig.initialStop,
                  entry: sig.entryPrice,
                  target1: sig.target1,
                  target2: sig.target2,
                  current: widget.currentPrice,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 20,
                  runSpacing: 10,
                  children: [
                    StatTile(
                      label: 'Giriş bölgesi',
                      value: '${Fmt.price(sig.entryZoneLow, market)} – ${Fmt.price(sig.entryZoneHigh, market)}',
                    ),
                    StatTile(
                      label: 'Stop mesafesi',
                      value: '-${Fmt.pct(rec.stopDistancePct)}',
                      valueColor: p.loss,
                    ),
                    StatTile(label: 'Ödül / Risk', value: '${Fmt.number(sig.rewardRisk, decimals: 1)}R'),
                  ],
                ),
                const SizedBox(height: 12),
                Text(sig.rationale, style: const TextStyle(fontSize: 13, height: 1.4)),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.do_not_disturb_on_outlined, size: 15, color: p.coral),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Geçersiz kılma: ${sig.invalidationRule}',
                        style: TextStyle(fontSize: 12, color: p.textDim, height: 1.35, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DataProvenanceBadge(
                  sourceLabel: sig.dataSource,
                  ageMinutes: (sig.dataAgeMs / 60000).round(),
                  isStale: sig.dataStale,
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Güven dökümü ve riskler',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.accent),
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
                  const SizedBox(height: 10),
                  const Text('Temel riskler', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  for (final risk in rec.keyRisks)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 6, right: 8),
                            child: Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(color: p.textDim, shape: BoxShape.circle),
                            ),
                          ),
                          Expanded(
                            child: Text(risk, style: TextStyle(fontSize: 12, color: p.textDim, height: 1.35)),
                          ),
                        ],
                      ),
                    ),
                  Text(
                    'Komisyon ve kayma tahmini (kripto ~%0,20, BIST ~%0,30 gidiş-dönüş) güven skoruna dahildir; '
                    'gerçek maliyet aracı kuruma göre değişir.',
                    style: TextStyle(fontSize: 11, color: p.textDim, height: 1.35),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
