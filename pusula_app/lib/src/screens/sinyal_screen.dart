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
  InvestmentHorizon? _horizonFilter;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pusulaControllerProvider);
    final p = PusulaPalette.of(context);
    final query = ref.watch(searchQueryProvider).trim().toLowerCase();
    final shortTerm = state.currentReport.shortTermReport;
    final scan = state.lastScan;
    final misses = scan == null ? const <ScanCandidate>[] : [for (final c in scan.nearMisses) if (!c.weekly) c];
    final alloc = state.currentReport.newAllocation;
    final breakdown = HorizonBudgetBreakdown.compute(
      totalBudget: state.settings.budgetAmount,
      allocation: alloc,
      activeDailySignals: state.effectiveShortTermSignals,
    );
    final recAllocBySymbol = <String, double>{
      for (final r in alloc.recommendations)
        r.instrument.symbol: state.settings.budgetAmount * r.weightPct / 100.0,
    };

    double? allocFor(SignalRecord sig) {
      if (!sig.isActive) return null;
      if (classifyHorizon(sig) == InvestmentHorizon.daily) {
        return breakdown.dailyPerSignalTry > 0 ? breakdown.dailyPerSignalTry : null;
      }
      final recTry = recAllocBySymbol[sig.instrument.symbol];
      return (recTry != null && recTry > 0) ? recTry : null;
    }

    final signals = [
      for (final s in state.allSignals)
        if ((_market == null || s.instrument.market == _market) &&
            (_status == _StatusFilter.all ||
                (_status == _StatusFilter.open && s.isActive) ||
                (_status == _StatusFilter.closed && s.isClosed)) &&
            (_horizonFilter == null || classifyHorizon(s) == _horizonFilter) &&
            (!state.settings.isUserSelectedMode || state.settings.favoriteSymbols.contains(s.instrument.symbol)) &&
            (query.isEmpty ||
                s.instrument.symbol.toLowerCase().contains(query) ||
                s.instrument.short.toLowerCase().contains(query) ||
                s.instrument.name.toLowerCase().contains(query)))
          s,
    ];

    Widget horizonChip(Key key, String label, InvestmentHorizon? target) {
      final selected = _horizonFilter == target;
      return InkWell(
        key: key,
        borderRadius: BorderRadius.circular(999),
        onTap: () => setState(() => _horizonFilter = target),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? p.accentSoft : p.card,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? p.accent : p.border.withValues(alpha: 0.7)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? p.accent : p.text,
            ),
          ),
        ),
      );
    }

    return PageBody(
      primaryFlex: 5,
      secondaryFlex: 6,
      primary: [
        const DisclaimerBanner(),
        const SectionTitle(
          'Kısa vade haftalık raporu',
          subtitle: 'Son 7 gün · Sadece Spot gerçekleşen sonuçlar',
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
            subtitle: 'Eşik altı · Zorla sinyal yok',
          ),
          RejectedCandidatesCard(candidates: misses),
        ],
      ],
      secondary: [
        SectionTitle(
          'Sinyal günlüğü',
          subtitle: '${signals.length} kayıt · Sadece Spot · Günlük kalan limit: ${Fmt.currencyTry(breakdown.dailyLimitTry)}',
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              horizonChip(const Key('sinyal_horizon_all'), 'Tümü', null),
              const SizedBox(width: 8),
              horizonChip(const Key('sinyal_horizon_daily'), 'Günlük', InvestmentHorizon.daily),
              const SizedBox(width: 8),
              horizonChip(const Key('sinyal_horizon_weekly'), 'Haftalık', InvestmentHorizon.weekly),
              const SizedBox(width: 8),
              horizonChip(const Key('sinyal_horizon_multiweek'), 'Birkaç Haftalık', InvestmentHorizon.multiWeek),
              const SizedBox(width: 8),
              horizonChip(const Key('sinyal_horizon_monthly'), 'Aylık / Uzun Vade', InvestmentHorizon.monthlyLong),
            ],
          ),
        ),
        const Gap(10),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            SegmentedButton<Market?>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment<Market?>(value: null, label: Text('Tümü')),
                ButtonSegment<Market?>(value: Market.bist, label: Text('BIST (₺)')),
                ButtonSegment<Market?>(value: Market.crypto, label: Text('Kripto (\$)')),
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
                ? 'Onaylı spot kurulumu henüz yok.'
                : 'Süzgeç veya vade seçimini değiştir.',
          )
        else
          for (final sig in signals) ...[
            SignalCard(
              signal: sig,
              currentPrice: state.priceOf(sig.instrument),
              allocatedTry: allocFor(sig),
              usdTryRate: state.settings.usdTryRate,
            ),
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
                  'Küçük örneklem (${stats.closedSignals} sinyal) · Düşük istatistiksel güven.',
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
