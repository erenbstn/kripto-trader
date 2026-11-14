import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pusula_core/pusula_core.dart';

import '../state/pusula_controller.dart';
import '../theme/gunduz_theme.dart';
import '../widgets/common.dart';
import '../widgets/recommendation_card.dart';

/// Sekme 2 — Öneri + Geçmiş.
///
/// Önce geçen haftanın gerçekleşen sonucu (ilk haftada "Geçen hafta raporu: henüz veri yok"),
/// sonra bu haftanın yeni BIST ve kripto önerileri. Geçmiş sekmesinde ileriye dönük performans
/// eğrisi ve rapor arşivi bulunur.
class OneriScreen extends ConsumerStatefulWidget {
  const OneriScreen({super.key});

  @override
  ConsumerState<OneriScreen> createState() => _OneriScreenState();
}

class _OneriScreenState extends ConsumerState<OneriScreen> {
  bool _showHistoryTab = false;
  Market? _marketFilter;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pusulaControllerProvider);
    final tabs = _TabSwitch(
      showHistory: _showHistoryTab,
      onChanged: (v) => setState(() => _showHistoryTab = v),
    );

    final header = <Widget>[const DisclaimerBanner(), const Gap(12), tabs];

    if (_showHistoryTab) {
      return PageBody(
        primary: [...header, const Gap(14), _PerformanceCard(state: state)],
        secondary: [
          const SectionTitle('Haftalık rapor arşivi'),
          ..._archive(context, state),
        ],
      );
    }

    return PageBody(
      primaryFlex: 4,
      secondaryFlex: 7,
      primary: [...header, const Gap(14), _LastWeekCard(review: state.currentReport.lastWeekReview)],
      secondary: _recommendations(context, state),
    );
  }

  List<Widget> _recommendations(BuildContext context, PusulaAppState state) {
    final alloc = state.currentReport.newAllocation;
    final query = ref.watch(searchQueryProvider).trim().toLowerCase();
    bool matches(Instrument ins) =>
        query.isEmpty ||
        ins.symbol.toLowerCase().contains(query) ||
        ins.short.toLowerCase().contains(query) ||
        ins.name.toLowerCase().contains(query);

    final recs = <WeeklyRecommendation>[
      if (_marketFilter == null || _marketFilter == Market.bist)
        for (final r in alloc.bistRecommendations)
          if (matches(r.instrument)) r,
      if (_marketFilter == null || _marketFilter == Market.crypto)
        for (final r in alloc.cryptoRecommendations)
          if (matches(r.instrument)) r,
    ];
    final scan = state.lastScan;
    final weeklyMisses = scan == null ? const <ScanCandidate>[] : [for (final c in scan.nearMisses) if (c.weekly) c];

    return [
      const SectionTitle(
        '2. Bu Haftanın Yeni Önerileri',
        subtitle: 'Kripto 4 saatlik, BIST günlük kapanmış mum kurulumları. Ağırlıklar risk bütçesinden türetilir.',
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: SegmentedButton<Market?>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment<Market?>(value: null, label: Text('Tümü')),
            ButtonSegment<Market?>(value: Market.bist, label: Text('BIST')),
            ButtonSegment<Market?>(value: Market.crypto, label: Text('Kripto')),
          ],
          selected: {_marketFilter},
          onSelectionChanged: (sel) => setState(() => _marketFilter = sel.first),
        ),
      ),
      const Gap(12),
      if (recs.isEmpty)
        EmptyNote(
          icon: Icons.savings_outlined,
          title: 'Bu hafta net fırsat yok, nakitte kal.',
          body: scan == null && !state.isDemo
              ? 'Henüz tarama yapılmadı; değerlendirme ilk taramadan sonra görünür.'
              : (weeklyMisses.isEmpty
                  ? 'Taranan varlıklarda güven eşiğini geçen haftalık kurulum çıkmadı.'
                  : '${weeklyMisses.length} aday kurulum buldu ama süzgeçlerden geçemedi; ayrıntı aşağıda.'),
        )
      else
        LayoutBuilder(
          builder: (context, c) {
            final twoCol = c.maxWidth >= 720 && recs.length > 1;
            final w = twoCol ? (c.maxWidth - 14) / 2 : c.maxWidth;
            return Wrap(
              spacing: 14,
              runSpacing: 12,
              children: [
                for (final rec in recs)
                  SizedBox(
                    width: w,
                    child: RecommendationDetailCard(
                      recommendation: rec,
                      budgetAmount: state.settings.budgetAmount,
                      currentPrice: state.priceOf(rec.instrument),
                    ),
                  ),
              ],
            );
          },
        ),
      if (weeklyMisses.isNotEmpty) ...[
        const SectionTitle('Elenen haftalık adaylar', subtitle: 'Kurulum bulundu, ancak bir süzgeç reddetti.'),
        Card(
          child: Column(
            children: [
              for (final (i, c) in weeklyMisses.take(8).indexed) ...[
                if (i > 0) const Divider(),
                _CandidateRow(candidate: c),
              ],
            ],
          ),
        ),
      ],
    ];
  }

  List<Widget> _archive(BuildContext context, PusulaAppState state) {
    final p = PusulaPalette.of(context);
    if (state.archivedReports.isEmpty) {
      return const [
        EmptyNote(
          icon: Icons.inventory_2_outlined,
          title: 'Arşiv boş',
          body: 'Her hafta üretilen rapor burada saklanır.',
        ),
      ];
    }
    return [
      Card(
        child: Column(
          children: [
            for (final (i, rep) in state.archivedReports.indexed) ...[
              if (i > 0) const Divider(),
              ListTile(
                title: Text(
                  '${Fmt.dateTrt(rep.weekStart)} haftası',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                subtitle: Text(
                  '${rep.newAllocation.bistRecommendations.length} BIST, '
                  '${rep.newAllocation.cryptoRecommendations.length} kripto önerisi · '
                  'nakit ${Fmt.pct(rep.newAllocation.cashWeightPct, decimals: 0)}',
                ),
                trailing: rep.lastWeekReview.hasData
                    ? SignedMetricChip(value: rep.lastWeekReview.weightedPortfolioReturnPct, suffix: '', prefix: '%')
                    : Text('sonuç yok', style: TextStyle(fontSize: 11.5, color: p.textDim)),
              ),
            ],
          ],
        ),
      ),
    ];
  }
}

/// İki seçenekli sekme anahtarı (Bu hafta / Geçmiş).
class _TabSwitch extends StatelessWidget {
  const _TabSwitch({required this.showHistory, required this.onChanged});

  final bool showHistory;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = PusulaPalette.of(context);

    Widget tab(Key key, String label, IconData icon, bool selected, VoidCallback onTap) => Expanded(
          child: Semantics(
            button: true,
            selected: selected,
            child: InkWell(
              key: key,
              borderRadius: BorderRadius.circular(10),
              onTap: onTap,
              child: Container(
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? p.card : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: selected ? Border.all(color: p.border) : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 16, color: selected ? p.accent : p.textDim),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                        color: selected ? p.accent : p.textDim,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: p.subtle, borderRadius: BorderRadius.circular(13)),
      child: Row(
        children: [
          tab(const Key('tab_oneri_current'), 'Bu Hafta', Icons.event_available_outlined, !showHistory,
              () => onChanged(false)),
          tab(const Key('tab_oneri_history'), 'Geçmiş', Icons.history, showHistory, () => onChanged(true)),
        ],
      ),
    );
  }
}

class _LastWeekCard extends StatelessWidget {
  const _LastWeekCard({required this.review});

  final LastWeekReview review;

  @override
  Widget build(BuildContext context) {
    final p = PusulaPalette.of(context);
    return Card(
      key: const Key('last_week_review_card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CardHeader(icon: Icons.fact_check_outlined, title: '1. Geçen Hafta Önerilerinin Sonucu'),
            const Gap(12),
            if (!review.hasData) ...[
              Text(review.emptyMessage, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
              const Gap(6),
              Text(
                'Geçmiş mumlarda strateji sınaması (backtest) yapılmaz. Buradaki getiriler yalnızca sistemin '
                'ileriye dönük ürettiği önerilerin gerçekleşen sonuçlarıdır; veri uydurulmaz.',
                style: TextStyle(fontSize: 12.5, color: p.textDim, height: 1.4),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      label: 'Ağırlıklı getiri',
                      value: Fmt.pct(review.weightedPortfolioReturnPct, decimals: 2, signed: true),
                      valueColor: review.weightedPortfolioReturnPct > 0
                          ? p.profit
                          : (review.weightedPortfolioReturnPct < 0 ? p.loss : p.text),
                      hint: review.weightedPortfolioReturnPct > 0
                          ? 'kazanç'
                          : (review.weightedPortfolioReturnPct < 0 ? 'kayıp' : 'başabaş'),
                      big: true,
                    ),
                  ),
                  Expanded(
                    child: StatTile(
                      label: 'İsabet',
                      value: Fmt.pct(review.winRatePct, decimals: 0),
                      hint: '${review.outcomes.length} öneri',
                      big: true,
                    ),
                  ),
                ],
              ),
              const Gap(12),
              for (final o in review.outcomes)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 64,
                        child: Text(o.instrument.short, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                      ),
                      Expanded(
                        child: Text(
                          o.note,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5, color: p.textDim),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SignedMetricChip(value: o.realizedPct, suffix: '', prefix: '%', decimals: 2),
                    ],
                  ),
                ),
              if (review.lessonsLearned.isNotEmpty) ...[
                const Gap(8),
                const Text('Ne öğrendik', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                const Gap(4),
                for (final l in review.lessonsLearned)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text('• $l', style: TextStyle(fontSize: 12, color: p.textDim, height: 1.35)),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _PerformanceCard extends StatelessWidget {
  const _PerformanceCard({required this.state});

  final PusulaAppState state;

  @override
  Widget build(BuildContext context) {
    final p = PusulaPalette.of(context);
    final curve = state.performanceCurve;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CardHeader(icon: Icons.show_chart, title: 'İleriye Dönük Performans Eğrisi'),
            const Gap(4),
            Text('100 bazlı bileşik endeks · yalnızca gerçekleşen haftalar', style: TextStyle(fontSize: 12, color: p.textDim)),
            const Gap(12),
            if (curve.isEmpty)
              Text(
                'Henüz tamamlanmış hafta verisi yok. Sistem geçmiş veride backtest yapmaz; eğri yalnızca '
                'ileriye dönük gerçekleşen haftalık raporlardan oluşur.',
                style: TextStyle(fontSize: 13, color: p.textDim, height: 1.4),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      label: 'Endeks',
                      value: Fmt.number(curve.last.cumulativeIndex),
                      big: true,
                    ),
                  ),
                  SignedMetricChip(value: curve.last.cumulativeReturnPct, suffix: ' toplam', prefix: '%', decimals: 2),
                ],
              ),
              const Gap(10),
              Sparkline(values: [for (final pt in curve) pt.cumulativeIndex]),
              const Gap(10),
              for (final pt in curve.reversed.take(8))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(Fmt.dateTrt(pt.date), style: const TextStyle(fontSize: 12.5))),
                      SignedMetricChip(value: pt.weeklyReturnPct, suffix: ' haftalık', prefix: '%', decimals: 2),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 64,
                        child: Text(
                          Fmt.number(pt.cumulativeIndex),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Elenen aday satırı: varlık, bulunan kurulum ve reddeden süzgeç.
class _CandidateRow extends StatelessWidget {
  const _CandidateRow({required this.candidate});

  final ScanCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final p = PusulaPalette.of(context);
    final c = candidate;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MarketTag(c.instrument.market),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${c.instrument.short} · ${c.interval.code}',
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                ),
              ),
              Tag(c.stageLabel, color: p.neutral),
            ],
          ),
          const Gap(4),
          if (c.setups.isNotEmpty)
            Text(
              c.setups.map((s) => s.label).join(' + '),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.textDim),
            ),
          Text(c.reason, style: TextStyle(fontSize: 12, color: p.textDim, height: 1.35)),
        ],
      ),
    );
  }
}

/// Sinyal ekranının da kullandığı elenen aday listesi kartı.
class RejectedCandidatesCard extends StatelessWidget {
  const RejectedCandidatesCard({super.key, required this.candidates, this.limit = 8});

  final List<ScanCandidate> candidates;
  final int limit;

  @override
  Widget build(BuildContext context) => Card(
        child: Column(
          children: [
            for (final (i, c) in candidates.take(limit).indexed) ...[
              if (i > 0) const Divider(),
              _CandidateRow(candidate: c),
            ],
          ],
        ),
      );
}
