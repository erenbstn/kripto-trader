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

/// Tek sinyal kartı. [compact] Özet ekranındaki kısa görünüm; tam görünüm gerekçeyi de gösterir.
class SignalCard extends StatelessWidget {
  const SignalCard({
    super.key,
    required this.signal,
    this.currentPrice,
    this.compact = false,
  });

  final SignalRecord signal;
  final double? currentPrice;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = PusulaPalette.of(context);
    final s = signal;
    final market = s.instrument.market;
    final st = signalStatusStyle(p, s);
    final now = DateTime.now().toUtc();

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
                          Tag(s.isWeeklyProposal ? 'HAFTALIK · ${s.interval.code}' : 'KISA VADE · ${s.interval.code}',
                              color: p.neutral),
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
            const SizedBox(height: 12),
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
                  SignedMetricChip(value: s.realizedR!, suffix: 'R gerçekleşen', decimals: 2),
                  if (s.realizedPct != null) SignedMetricChip(value: s.realizedPct!, suffix: '', prefix: '%', decimals: 2),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (s.status == SignalStatus.target1 && s.isActive)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Stop başabaşa (${Fmt.price(s.currentStop, market)}) çekildi; kalan pozisyon ana hedefi bekliyor.',
                  style: TextStyle(fontSize: 12, color: p.profit, fontWeight: FontWeight.w600),
                ),
              ),
            Text(
              'Giriş bölgesi ${Fmt.price(s.entryZoneLow, market)} – ${Fmt.price(s.entryZoneHigh, market)} ${Fmt.currency(market)}'
              ' · Ö/R ${Fmt.number(s.rewardRisk, decimals: 1)}'
              ' · Monte Carlo +${s.confidence.monteCarloScore}/15',
              style: TextStyle(fontSize: 12, color: p.textDim, height: 1.35),
            ),
            if (!compact) ...[
              const SizedBox(height: 6),
              Text(
                s.rationale,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, height: 1.4),
              ),
              if (s.exitReason != null) ...[
                const SizedBox(height: 6),
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
