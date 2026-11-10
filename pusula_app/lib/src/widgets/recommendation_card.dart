import 'package:flutter/material.dart';
import 'package:pusula_core/pusula_core.dart';

import '../theme/gunduz_theme.dart';

/// Haftalık öneri veya 3D halka dilimi için detaylı analiz kartı (DEVIR.md Faz 5.3).
class RecommendationDetailCard extends StatelessWidget {
  const RecommendationDetailCard({
    super.key,
    required this.recommendation,
    required this.budgetAmount,
  });

  final WeeklyRecommendation recommendation;
  final double budgetAmount;

  static String _fmtPrice(double v, Market market) {
    final decimals = market == Market.bist ? 2 : (v >= 1000 ? 0 : 2);
    return v.toStringAsFixed(decimals).replaceAll('.', ',');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rec = recommendation;
    final sig = rec.signal;
    final market = rec.instrument.market;
    final isBist = market == Market.bist;
    final tlAmount = budgetAmount * rec.weightPct / 100.0;
    final accentColor = isBist ? GunduzColors.accent : GunduzColors.coral;
    final ageMinutes = (sig.dataAgeMs / 60000).round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isBist ? 'BIST' : 'KRİPTO',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: accentColor,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${rec.instrument.symbol}${rec.instrument.name.isNotEmpty ? " · ${rec.instrument.name}" : ""}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${sig.strategy.label} · Güven Skoru ${rec.confidence.total}/100',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? GunduzColors.darkTextSecondary : GunduzColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '%${rec.weightPct.toStringAsFixed(1).replaceAll('.', ',')} Ağırlık',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                      ),
                    ),
                    Text(
                      '≈ ${tlAmount.toStringAsFixed(0)} TL${rec.estimatedLots != null ? " (${rec.estimatedLots} lot)" : ""}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? GunduzColors.darkTextSecondary : GunduzColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            DataProvenanceBadge(
              sourceLabel: sig.dataSource,
              ageMinutes: ageMinutes,
              isStale: sig.dataStale,
            ),
            const SizedBox(height: 12),
            Text(
              'Neden seçildi: ${sig.rationale}',
              style: const TextStyle(fontSize: 13, height: 1.35),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? GunduzColors.darkSubtleSurface : GunduzColors.subtleSurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _MetricItem(
                    label: 'Giriş Bölgesi',
                    value: '${_fmtPrice(sig.entryZoneLow, market)} – ${_fmtPrice(sig.entryZoneHigh, market)}',
                  ),
                  _MetricItem(
                    label: 'Kademe 1 (1R)',
                    value: _fmtPrice(sig.target1, market),
                  ),
                  _MetricItem(
                    label: 'Kademe 2 (2R)',
                    value: _fmtPrice(sig.target2, market),
                  ),
                  _MetricItem(
                    label: 'Stop Seviyesi',
                    value: '${_fmtPrice(sig.initialStop, market)} (-%${rec.stopDistancePct.toStringAsFixed(1).replaceAll('.', ',')})',
                  ),
                  _MetricItem(
                    label: 'Ödül / Risk',
                    value: '${sig.rewardRisk.toStringAsFixed(1).replaceAll('.', ',')}R',
                  ),
                  _MetricItem(
                    label: 'Açık Risk Payı',
                    value: '%${rec.riskContributionPct.toStringAsFixed(2).replaceAll('.', ',')}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Geçersiz kılma koşulu: ${sig.invalidationRule}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? GunduzColors.darkTextSecondary : GunduzColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Temel Riskler ve Notlar:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            for (final risk in rec.keyRisks)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    Expanded(
                      child: Text(
                        risk,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  const _MetricItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? GunduzColors.darkTextSecondary : GunduzColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
