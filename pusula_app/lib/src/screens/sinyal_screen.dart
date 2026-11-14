import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pusula_core/pusula_core.dart';

import '../state/pusula_controller.dart';
import '../theme/gunduz_theme.dart';
import '../widgets/common.dart';
import '../widgets/signal_card.dart';
import 'oneri_screen.dart' show RejectedCandidatesCard;

enum _StatusFilter { all, open, closed }

/// Sekme 3 — Sinyal.
///
/// Kısa vade haftalık karnesi (kripto ve BIST ayrı), elenen adaylar ve tüm sinyal günlüğü.
class SinyalScreen extends ConsumerStatefulWidget {
  const SinyalScreen({super.key});

  @override
  ConsumerState<SinyalScreen> createState() => _SinyalScreenState();
}

class _SinyalScreenState extends ConsumerState<SinyalScreen> {
  Market? _market;
  _StatusFilter _status = _StatusFilter.all;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pusulaControllerProvider);
    final query = ref.watch(searchQueryProvider).trim().toLowerCase();
    final shortTerm = state.currentReport.shortTermReport;
    final scan = state.lastScan;
    final misses = scan == null ? const <ScanCandidate>[] : [for (final c in scan.nearMisses) if (!c.weekly) c];

    final signals = [
      for (final s in state.allSignals)
        if ((_market == null || s.instrument.market == _market) &&
            (_status == _StatusFilter.all ||
                (_status == _StatusFilter.open && s.isActive) ||
                (_status == _StatusFilter.closed && s.isClosed)) &&
            (query.isEmpty ||
                s.instrument.symbol.toLowerCase().contains(query) ||
                s.instrument.short.toLowerCase().contains(query) ||
                s.instrument.name.toLowerCase().contains(query)))
          s,
    ];

    return PageBody(
      primaryFlex: 5,
      secondaryFlex: 6,
      primary: [
        const DisclaimerBanner(),
        const SectionTitle(
          'Kısa vade haftalık raporu',
          subtitle: 'Son 7 günde üretilen kısa vade sinyallerinin gerçekleşen sonuçları.',
        ),
        _MarketStatsCard(
          title: 'Kripto Kısa Vade Özeti',
          market: Market.crypto,
          stats: shortTerm.crypto,
        ),
        const Gap(10),
        _MarketStatsCard(
          title: 'Borsa İstanbul Kısa Vade Özeti',
          market: Market.bist,
          stats: shortTerm.bist,
        ),
        if (misses.isNotEmpty) ...[
          const SectionTitle(
            'Elenen kısa vade adayları',
            subtitle: 'Kurulum bulundu, ancak bir süzgeç reddetti. Zorla sinyal üretilmez.',
          ),
          RejectedCandidatesCard(candidates: misses),
        ],
      ],
      secondary: [
        SectionTitle('Sinyal günlüğü', subtitle: '${state.allSignals.length} kayıt · en yeni üstte'),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            SegmentedButton<Market?>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment<Market?>(value: null, label: Text('Tümü')),
                ButtonSegment<Market?>(value: Market.bist, label: Text('BIST')),
                ButtonSegment<Market?>(value: Market.crypto, label: Text('Kripto')),
              ],
              selected: {_market},
              onSelectionChanged: (sel) => setState(() => _market = sel.first),
            ),
            SegmentedButton<_StatusFilter>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: _StatusFilter.all, label: Text('Hepsi')),
                ButtonSegment(value: _StatusFilter.open, label: Text('Açık')),
                ButtonSegment(value: _StatusFilter.closed, label: Text('Kapanan')),
              ],
              selected: {_status},
              onSelectionChanged: (sel) => setState(() => _status = sel.first),
            ),
          ],
        ),
        const Gap(12),
        if (signals.isEmpty)
          EmptyNote(
            icon: Icons.inbox_outlined,
            title: state.allSignals.isEmpty ? 'Günlük boş' : 'Bu süzgeçte kayıt yok',
            body: state.allSignals.isEmpty
                ? 'Pusula yalnızca hunideki tüm süzgeçleri geçen kurulumları kaydeder. '
                    'Henüz onaylanan sinyal yok; bu da bir bilgidir.'
                : 'Süzgeçleri değiştirerek diğer kayıtları görebilirsin.',
          )
        else
          for (final sig in signals) ...[
            SignalCard(signal: sig, currentPrice: state.priceOf(sig.instrument)),
            const Gap(10),
          ],
      ],
    );
  }
}

class _MarketStatsCard extends StatelessWidget {
  const _MarketStatsCard({
    required this.title,
    required this.market,
    required this.stats,
  });

  final String title;
  final Market market;
  final ShortTermMarketSummary stats;

  @override
  Widget build(BuildContext context) {
    final p = PusulaPalette.of(context);
    final accent = MarketTag.colorOf(context, market);
    final hasClosed = stats.closedSignals > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 20,
                  decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(3)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                ),
                if (hasClosed) SignedMetricChip(value: stats.totalReturnPct, suffix: '', prefix: '%', decimals: 2),
              ],
            ),
            const Gap(12),
            if (!stats.hasData)
              Text(
                'Son 7 günde bu piyasada kısa vade sinyali üretilmedi.',
                style: TextStyle(fontSize: 12.5, color: p.textDim),
              )
            else ...[
              Row(
                children: [
                  Expanded(child: StatTile(label: 'Sinyal', value: '${stats.totalSignals}', hint: '${stats.openSignals} açık')),
                  Expanded(
                    child: StatTile(
                      label: 'İsabet',
                      value: hasClosed ? Fmt.pct(stats.winRatePct, decimals: 0) : '—',
                      hint: '${stats.closedSignals} kapanan',
                    ),
                  ),
                  Expanded(
                    child: StatTile(
                      label: 'Ortalama R',
                      value: hasClosed ? Fmt.r(stats.avgR) : '—',
                      valueColor: !hasClosed ? null : (stats.avgR > 0 ? p.profit : (stats.avgR < 0 ? p.loss : null)),
                    ),
                  ),
                ],
              ),
              if (stats.closedSignals > 0 && stats.closedSignals < 30) ...[
                const Gap(8),
                Text(
                  'Örneklem küçük (${stats.closedSignals} kapanan sinyal): bu oranlar istatistiksel olarak güvenilir değildir.',
                  style: TextStyle(fontSize: 11.5, color: p.textDim, height: 1.35),
                ),
              ],
              if (stats.byStrategy.isNotEmpty) ...[
                const Gap(10),
                for (final b in stats.byStrategy)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(b.strategyLabel, style: TextStyle(fontSize: 12, color: p.textDim)),
                        ),
                        Text(
                          '${b.signalCount} sinyal'
                          '${b.closedCount > 0 ? ' · ${Fmt.r(b.avgR)}' : ''}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
