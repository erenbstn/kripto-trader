import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pusula_core/pusula_core.dart';

import '../state/pusula_controller.dart';
import '../theme/gunduz_theme.dart';
import '../widgets/recommendation_card.dart';

/// Sekme 2 — Öneri + Geçmiş ekranı (DEVIR.md Faz 5.3).
/// Önce geçen haftanın gerçekleşen sonucu (ilk haftada "Geçen hafta raporu: henüz veri yok"),
/// sonra bu haftanın yeni BIST ve Kripto önerileri; ayrıca Geçmiş arşivi ve ileriye dönük performans eğrisi.
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
    final report = state.currentReport;
    final alloc = report.newAllocation;
    final lastWeek = report.lastWeekReview;

    final filteredRecs = <WeeklyRecommendation>[
      if (_marketFilter == null || _marketFilter == Market.bist) ...alloc.bistRecommendations,
      if (_marketFilter == null || _marketFilter == Market.crypto) ...alloc.cryptoRecommendations,
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        const DisclaimerBanner(),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('tab_oneri_current'),
                style: OutlinedButton.styleFrom(
                  backgroundColor: !_showHistoryTab ? GunduzColors.accent : null,
                  foregroundColor: !_showHistoryTab ? Colors.white : null,
                ),
                onPressed: () => setState(() => _showHistoryTab = false),
                child: const Text('Bu Hafta Önerileri'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                key: const Key('tab_oneri_history'),
                style: OutlinedButton.styleFrom(
                  backgroundColor: _showHistoryTab ? GunduzColors.accent : null,
                  foregroundColor: _showHistoryTab ? Colors.white : null,
                ),
                onPressed: () => setState(() => _showHistoryTab = true),
                child: const Text('Geçmiş Arşivi'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (!_showHistoryTab) ...[
          // 1. ÖNCE: Geçen Hafta Sonucu (DEVIR.md Faz 3.1 ve 5.3)
          Card(
            key: const Key('last_week_review_card'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.history_edu_outlined, size: 18, color: GunduzColors.accent),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '1. Geçen Hafta Önerilerinin Sonucu',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (!lastWeek.hasData) ...[
                    Text(
                      lastWeek.emptyMessage,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Not: Geçmiş mumlarda strateji sınaması (backtest) yapılmaz. Raporlardaki getiriler yalnızca sistemin ileriye dönük ürettiği sinyallerin gerçekleşen sonuçlarıdır.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ] else ...[
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        SignedMetricChip(value: lastWeek.weightedPortfolioReturnPct, suffix: '% Ağırlıklı Getiri'),
                        Text(
                          'Kazanma Oranı: %${lastWeek.winRatePct.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          // 2. SONRA: Bu Haftanın Yeni Önerileri (BIST ve Kripto ayrı filtreli)
          const Text(
            '2. Bu Haftanın Yeni Önerileri',
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
              selected: {_marketFilter},
              onSelectionChanged: (sel) => setState(() => _marketFilter = sel.first),
            ),
          ),
          const SizedBox(height: 10),
          if (filteredRecs.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Bu hafta net fırsat yok, nakitte kal.'),
              ),
            )
          else
            for (final rec in filteredRecs) ...[
              RecommendationDetailCard(
                recommendation: rec,
                budgetAmount: state.settings.budgetAmount,
              ),
              const SizedBox(height: 12),
            ],
        ] else ...[
          // Geçmiş Arşivi ve İleriye Dönük Performans Eğrisi
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'İleriye Dönük Performans Eğrisi (100 Bazlı)',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  if (state.performanceCurve.isEmpty)
                    const Text(
                      'Henüz tamamlanmış hafta verisi yok. Sistem geçmiş veride backtest yapmaz; performans eğrisi yalnızca ileriye dönük gerçekleşen haftalık raporlardan oluşur.',
                      style: TextStyle(fontSize: 13),
                    )
                  else
                    for (final pt in state.performanceCurve)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(pt.date.toIso8601String().substring(0, 10)),
                            SignedMetricChip(value: pt.weeklyReturnPct, suffix: '% Haftalık'),
                            Text(
                              'Endeks: ${pt.cumulativeIndex.toStringAsFixed(2).replaceAll('.', ',')}',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Haftalık Rapor Arşivi',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          for (final rep in state.archivedReports) ...[
            Card(
              child: ListTile(
                title: Text(
                  'Hafta: ${rep.weekStart.toIso8601String().substring(0, 10)} → ${rep.weekEnd.toIso8601String().substring(0, 10)}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                subtitle: Text(
                  '${rep.lastWeekReview.hasData ? "+%${rep.lastWeekReview.weightedPortfolioReturnPct}" : rep.lastWeekReview.emptyMessage} · '
                  '${rep.newAllocation.bistRecommendations.length} BIST, ${rep.newAllocation.cryptoRecommendations.length} Kripto önerisi',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }
}
