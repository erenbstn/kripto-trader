import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pusula_core/pusula_core.dart';

import '../state/pusula_controller.dart';
import '../theme/gunduz_theme.dart';

/// Sekme 3 — Sinyal ekranı (DEVIR.md Faz 5.3).
/// Kısa vade haftalık raporu (Kripto ve BIST ayrı) + canlı sinyal akışı.
class SinyalScreen extends ConsumerStatefulWidget {
  const SinyalScreen({super.key});

  @override
  ConsumerState<SinyalScreen> createState() => _SinyalScreenState();
}

class _SinyalScreenState extends ConsumerState<SinyalScreen> {
  Market? _filter;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pusulaControllerProvider);
    final shortTerm = state.currentReport.shortTermReport;
    final signals = _filter == null
        ? state.allSignals
        : state.allSignals.where((s) => s.instrument.market == _filter).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        const DisclaimerBanner(),
        const SizedBox(height: 14),
        const Text(
          'Kısa Vade Haftalık Raporu (BIST ve Kripto Ayrı)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        _MarketStatsCard(
          title: 'Kripto Kısa Vade Özeti',
          accent: GunduzColors.coral,
          stats: shortTerm.crypto,
        ),
        const SizedBox(height: 10),
        _MarketStatsCard(
          title: 'Borsa İstanbul Kısa Vade Özeti',
          accent: GunduzColors.accent,
          stats: shortTerm.bist,
        ),
        const SizedBox(height: 18),
        const Text(
          'Sinyal Günlüğü ve Canlı Akış',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: SegmentedButton<Market?>(
            segments: const [
              ButtonSegment<Market?>(value: null, label: Text('Tümü')),
              ButtonSegment<Market?>(value: Market.bist, label: Text('BIST')),
              ButtonSegment<Market?>(value: Market.crypto, label: Text('Kripto')),
            ],
            selected: {_filter},
            onSelectionChanged: (sel) => setState(() => _filter = sel.first),
          ),
        ),
        const SizedBox(height: 10),
        for (final sig in signals) ...[
          _SignalRecordCard(signal: sig),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _MarketStatsCard extends StatelessWidget {
  const _MarketStatsCard({
    required this.title,
    required this.accent,
    required this.stats,
  });

  final String title;
  final Color accent;
  final ShortTermMarketSummary stats;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 18,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
                SignedMetricChip(value: stats.totalReturnPct, suffix: '% Getiri'),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                Text('Toplam Sinyal: ${stats.totalSignals}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                Text('Açık: ${stats.openSignals}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                Text('Kapanan: ${stats.closedSignals}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                Text(
                  'Kazanma Oranı: %${stats.winRatePct.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                Text(
                  'Ortalama R: ${stats.avgR.toStringAsFixed(2).replaceAll('.', ',')}R',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            if (stats.bestSignalSummary != null) ...[
              const SizedBox(height: 6),
              Text(
                'En İyi: ${stats.bestSignalSummary} · En Kötü: ${stats.worstSignalSummary ?? "-"}',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? GunduzColors.darkTextSecondary : GunduzColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SignalRecordCard extends StatelessWidget {
  const _SignalRecordCard({required this.signal});

  final SignalRecord signal;

  static String _statusLabel(SignalStatus s) {
    switch (s) {
      case SignalStatus.open:
        return 'AÇIK';
      case SignalStatus.target1:
        return 'HEDEF 1 (Başabaş Korumalı)';
      case SignalStatus.target2:
        return 'HEDEF 2 (+2R Kapandı)';
      case SignalStatus.stop:
        return 'STOP (-1R Kapandı)';
      case SignalStatus.expired:
        return 'SÜRE DOLDU';
      case SignalStatus.invalidated:
        return 'GEÇERSİZ';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBist = signal.instrument.market == Market.bist;
    final accent = isBist ? GunduzColors.accent : GunduzColors.coral;

    return Card(
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
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isBist ? 'BIST' : 'KRİPTO',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: accent),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${signal.instrument.symbol} · ${signal.strategy.label}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: signal.isActive
                        ? GunduzColors.accent.withValues(alpha: 0.12)
                        : GunduzColors.profitGreen.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _statusLabel(signal.status),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: signal.isActive ? GunduzColors.accent : GunduzColors.profitGreen,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(signal.rationale, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            Text(
              'Giriş: ${signal.entryZoneLow.toStringAsFixed(2).replaceAll('.', ',')}–${signal.entryZoneHigh.toStringAsFixed(2).replaceAll('.', ',')} · Stop: ${signal.currentStop.toStringAsFixed(2).replaceAll('.', ',')} · 1R: ${signal.target1.toStringAsFixed(2).replaceAll('.', ',')} · 2R: ${signal.target2.toStringAsFixed(2).replaceAll('.', ',')}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Güven Skoru: ${signal.confidence.total}/100 (Monte Carlo: +${signal.confidence.monteCarloScore}/15)',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                if (signal.realizedR != null)
                  SignedMetricChip(value: signal.realizedR!, suffix: 'R Gerçekleşen'),
              ],
            ),
            const SizedBox(height: 6),
            DataProvenanceBadge(
              sourceLabel: signal.dataSource,
              ageMinutes: (signal.dataAgeMs / 60000).round(),
              isStale: signal.dataStale,
            ),
          ],
        ),
      ),
    );
  }
}
