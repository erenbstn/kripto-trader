import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pusula_core/pusula_core.dart';

import '../state/pusula_controller.dart';
import '../theme/gunduz_theme.dart';
import '../widgets/donut_3d_chart.dart';
import '../widgets/recommendation_card.dart';

/// Sekme 1 — Özet ekranı (DEVIR.md Faz 5.3).
/// Haftanın kısa özeti, dokunulup döndürülebilen 3D bütçe halkası, açık sinyaller,
/// son bildirimler ve görünür "Yatırım tavsiyesi değildir" şeridi.
class OzetScreen extends ConsumerWidget {
  const OzetScreen({super.key});

  void _showSliceModal(BuildContext context, DonutSliceData slice, double budgetAmount) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${slice.label} · ${slice.categoryLabel} Dilim Detayı',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const DisclaimerBanner(),
                  const SizedBox(height: 12),
                  if (slice.recommendation != null)
                    RecommendationDetailCard(
                      recommendation: slice.recommendation!,
                      budgetAmount: budgetAmount,
                    )
                  else
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${slice.label} (%${slice.weightPct.toStringAsFixed(1).replaceAll('.', ',')})',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 6),
                            Text(slice.subtitle),
                            const SizedBox(height: 8),
                            Text(
                              'Tutar karşılığı: ≈ ${(budgetAmount * slice.weightPct / 100.0).toStringAsFixed(0)} TL',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pusulaControllerProvider);
    final controller = ref.read(pusulaControllerProvider.notifier);
    final alloc = state.currentReport.newAllocation;
    final disableAnim = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final flat2D = state.settings.shouldSimplifyAnimations || disableAnim;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        const DisclaimerBanner(),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Haftalık Portföy Pusulası',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: GunduzColors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Risk: ${alloc.appetite.label}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: GunduzColors.accent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  alloc.summaryMessage,
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _PillBadge(
                      label: 'BIST Toplam: %${alloc.bistTotalWeightPct.toStringAsFixed(1).replaceAll('.', ',')}',
                      color: GunduzColors.accent,
                    ),
                    _PillBadge(
                      label: 'Kripto Toplam: %${alloc.cryptoTotalWeightPct.toStringAsFixed(1).replaceAll('.', ',')}',
                      color: GunduzColors.coral,
                    ),
                    _PillBadge(
                      label: 'Açık Risk: %${alloc.totalOpenRiskPct.toStringAsFixed(2).replaceAll('.', ',')}',
                      color: GunduzColors.profitGreen,
                    ),
                    _PillBadge(
                      label: 'Nakit: %${alloc.cashWeightPct.toStringAsFixed(1).replaceAll('.', ',')}',
                      color: GunduzColors.neutralSlate,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Donut3DChart(
              slices: state.donutSlices,
              flat2D: flat2D,
              budgetAmount: state.settings.budgetAmount,
              onSliceTap: (slice) => _showSliceModal(context, slice, state.settings.budgetAmount),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Açık Sinyaller (${state.activeSignals.length})',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        for (final sig in state.activeSignals) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (sig.instrument.market == Market.bist
                                  ? GunduzColors.accent
                                  : GunduzColors.coral)
                              .withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          sig.instrument.market == Market.bist ? 'BIST' : 'KRİPTO',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: sig.instrument.market == Market.bist
                                ? GunduzColors.accent
                                : GunduzColors.coral,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${sig.instrument.symbol} · ${sig.strategy.label}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text(
                        'Güven ${sig.confidence.total}/100',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Giriş Bölgesi: ${sig.entryZoneLow.toStringAsFixed(2).replaceAll('.', ',')} – ${sig.entryZoneHigh.toStringAsFixed(2).replaceAll('.', ',')} · Stop: ${sig.currentStop.toStringAsFixed(2).replaceAll('.', ',')} · Hedef 2R: ${sig.target2.toStringAsFixed(2).replaceAll('.', ',')}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  DataProvenanceBadge(
                    sourceLabel: sig.dataSource,
                    ageMinutes: (sig.dataAgeMs / 60000).round(),
                    isStale: sig.dataStale,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Canlı Piyasa Fiyatları (Kripto & BIST)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
            TextButton.icon(
              onPressed: state.isLoading ? null : () => controller.refreshLiveMarketData(),
              icon: const Icon(Icons.sync, size: 16),
              label: Text(state.isLoading ? 'Yenileniyor...' : 'Canlı Yenile'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kripto Evreni (Binance Spot / Futures · Anlık)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: GunduzColors.coral),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final q in state.cryptoQuotes) _LiveQuoteChip(quote: q),
                  ],
                ),
                const Divider(height: 22),
                const Text(
                  'Borsa İstanbul İzleme (Yahoo Finance / İş Yatırım · ~15 dk Gecikmeli)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: GunduzColors.accent),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final q in state.bistQuotes) _LiveQuoteChip(quote: q),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Son Yerel Bildirimler',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
            TextButton.icon(
              onPressed: () => controller.triggerSampleNotification(),
              icon: const Icon(Icons.notifications_active_outlined, size: 16),
              label: const Text('Örnek Bildirim'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (final notif in state.recentNotifications.take(5)) ...[
          Card(
            child: ListTile(
              dense: true,
              leading: Icon(
                Icons.notifications_none,
                color: notif.channel.highPriority ? GunduzColors.coral : GunduzColors.accent,
              ),
              title: Text(
                notif.title,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                notif.body,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _PillBadge extends StatelessWidget {
  const _PillBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _LiveQuoteChip extends StatelessWidget {
  const _LiveQuoteChip({required this.quote});

  final LiveMarketQuote quote;

  static String _formatPrice(double p, Market m) {
    if (m == Market.bist) {
      return '${p.toStringAsFixed(2).replaceAll('.', ',')} TL';
    }
    if (p >= 1000) return '${p.toStringAsFixed(2).replaceAll('.', ',')} \$';
    if (p >= 1) return '${p.toStringAsFixed(3).replaceAll('.', ',')} \$';
    return '${p.toStringAsFixed(4).replaceAll('.', ',')} \$';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chg = quote.changePct;
    final chgColor = chg > 0.001
        ? GunduzColors.profitGreen
        : (chg < -0.001 ? GunduzColors.lossRed : GunduzColors.neutralSlate);
    final sign = chg > 0.001 ? '+' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? GunduzColors.darkSubtleSurface : GunduzColors.subtleSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? GunduzColors.darkBorder : GunduzColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            quote.instrument.short,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 6),
          Text(
            _formatPrice(quote.lastPrice, quote.instrument.market),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 5),
          Text(
            '$sign%${chg.toStringAsFixed(2).replaceAll('.', ',')}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: chgColor,
            ),
          ),
        ],
      ),
    );
  }
}
