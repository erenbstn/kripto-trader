import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pusula_core/pusula_core.dart';

import '../state/pusula_controller.dart';
import '../theme/gunduz_theme.dart';
import '../update/app_updater.dart';
import '../widgets/common.dart';
import '../widgets/donut_3d_chart.dart';
import '../widgets/recommendation_card.dart';
import '../widgets/signal_card.dart';

/// Sekme 1 — Özet.
///
/// Bilgi hiyerarşisi: (1) bu haftanın kararı — yatırım mı nakit mi, (2) bütçe halkası,
/// (3) son taramanın dürüst dökümü, (4) açık sinyaller, (5) piyasa şeridi, (6) son bildirimler.
class OzetScreen extends ConsumerWidget {
  const OzetScreen({super.key});

  void _showSliceModal(BuildContext context, DonutSliceData slice, PusulaAppState state) {
    final budget = state.settings.budgetAmount;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      constraints: const BoxConstraints(maxWidth: 640),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final p = PusulaPalette.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
                        tooltip: 'Kapat',
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
                      budgetAmount: budget,
                      currentPrice: state.priceOf(slice.recommendation!.instrument),
                      initiallyExpanded: true,
                    )
                  else
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            StatTile(
                              label: slice.label,
                              value: Fmt.pct(slice.weightPct),
                              hint: '≈ ${Fmt.tl(budget * slice.weightPct / 100.0)}',
                              big: true,
                            ),
                            const SizedBox(height: 8),
                            Text(slice.subtitle, style: TextStyle(fontSize: 13, color: p.textDim, height: 1.35)),
                            const SizedBox(height: 6),
                            Text(
                              'Nakit bir bekleme odası değil, bir pozisyondur: eşiği geçen fırsat olmadığında '
                              'sermayeyi korur ve bir sonraki kurulum için hazır tutar.',
                              style: TextStyle(fontSize: 12.5, color: p.textDim, height: 1.35),
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
    final p = PusulaPalette.of(context);
    final disableAnim = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final flat2D = state.settings.shouldSimplifyAnimations || disableAnim;
    final shortTerm = state.activeShortTermSignals;
    final openSignals = state.isDemo ? state.activeSignals : shortTerm;

    return PageBody(
      primary: [
        const DisclaimerBanner(),
        if (state.updateState.status == UpdateStatus.available ||
            state.updateState.status == UpdateStatus.downloading ||
            state.updateState.status == UpdateStatus.permissionRequired ||
            state.updateState.status == UpdateStatus.readyToInstall) ...[
          const Gap(8),
          _UpdateBanner(
            updateState: state.updateState,
            onDownload: controller.downloadAndInstallUpdate,
          ),
        ],
        if (state.isDemo) ...[const Gap(8), const _DemoBanner()],
        const Gap(12),
        _DecisionCard(state: state),
        const Gap(12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Donut3DChart(
              slices: state.donutSlices,
              flat2D: flat2D,
              budgetAmount: state.settings.budgetAmount,
              onSliceTap: (slice) => _showSliceModal(context, slice, state),
            ),
          ),
        ),
        if (!state.isDemo) ...[
          const Gap(12),
          _ScanSummaryCard(state: state, onScan: () => controller.refreshLiveMarketData(forceRefresh: true)),
        ],
      ],
      secondary: [
        SectionTitle(
          state.isDemo ? 'Açık sinyaller (${openSignals.length})' : 'Kısa vade açık sinyaller (${openSignals.length})',
          subtitle: state.isDemo ? null : 'Haftalık öneriler bütçe halkasında ve Öneri sekmesinde.',
        ),
        if (openSignals.isEmpty)
          EmptyNote(
            icon: Icons.radar,
            title: 'Açık kısa vade sinyali yok',
            body: state.lastScan == null
                ? 'İlk tarama tamamlandığında, onaylanan kurulumlar burada görünür.'
                : 'Son taramada eşiği geçen kısa vade kurulumu çıkmadı. Pusula zorla sinyal üretmez.',
          )
        else
          for (final sig in openSignals) ...[
            SignalCard(signal: sig, currentPrice: state.priceOf(sig.instrument), compact: true),
            const Gap(10),
          ],
        const SectionTitle('Piyasa', subtitle: 'Kripto 24 saatlik, BIST günlük değişim. BIST verisi ~15 dk gecikmelidir.'),
        if (state.cryptoQuotes.isEmpty && state.bistQuotes.isEmpty)
          const EmptyNote(
            icon: Icons.show_chart,
            title: 'Fiyat verisi henüz yok',
            body: 'Tarama tamamlandığında 10 kripto varlığı ve BIST izleme listesi burada listelenir.',
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (state.cryptoQuotes.isNotEmpty) ...[
                    Row(
                      children: [
                        Tag('KRİPTO', color: p.coral),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Binance · anlık',
                            style: TextStyle(fontSize: 11.5, color: p.textDim),
                          ),
                        ),
                      ],
                    ),
                    const Gap(10),
                    _QuoteGrid(quotes: state.cryptoQuotes),
                  ],
                  if (state.cryptoQuotes.isNotEmpty && state.bistQuotes.isNotEmpty)
                    const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Divider()),
                  if (state.bistQuotes.isNotEmpty) ...[
                    Row(
                      children: [
                        Tag('BIST', color: p.accent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Yahoo Finance / İş Yatırım · ~15 dk gecikmeli',
                            style: TextStyle(fontSize: 11.5, color: p.textDim),
                          ),
                        ),
                      ],
                    ),
                    const Gap(10),
                    _QuoteGrid(quotes: state.bistQuotes),
                  ],
                ],
              ),
            ),
          ),
        const SectionTitle('Son bildirimler'),
        if (state.recentNotifications.isEmpty)
          const EmptyNote(
            icon: Icons.notifications_none,
            title: 'Henüz bildirim yok',
            body: 'Yeni kurulum, hedef ve stop olayları yalnızca bu cihazda yerel bildirim olarak gösterilir.',
          )
        else
          Card(
            child: Column(
              children: [
                for (final (i, notif) in state.recentNotifications.take(5).indexed) ...[
                  if (i > 0) const Divider(indent: 52),
                  ListTile(
                    dense: true,
                    leading: Icon(
                      switch (notif.channel.id) {
                        'pusula_signal' => Icons.bolt_outlined,
                        'pusula_outcome' => Icons.flag_outlined,
                        'pusula_report' => Icons.article_outlined,
                        _ => Icons.info_outline,
                      },
                      color: notif.channel.highPriority ? p.coral : p.accent,
                    ),
                    title: Text(notif.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    subtitle: Text(notif.body, style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// Yeni APK sürümü hazır olduğunda Özet ekranının üstünde gösterilen güncelleme çubuğu.
class _UpdateBanner extends StatelessWidget {
  const _UpdateBanner({required this.updateState, required this.onDownload});

  final AppUpdateState updateState;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final p = PusulaPalette.of(context);
    final rel = updateState.availableRelease;
    final downloading = updateState.status == UpdateStatus.downloading;
    final permNeeded = updateState.status == UpdateStatus.permissionRequired;
    final title = rel != null
        ? 'Pusula ${rel.version.label} güncellemesi hazır${rel.sizeLabel.isNotEmpty ? ' (${rel.sizeLabel})' : ''}'
        : 'Yeni uygulama güncellemesi hazır';

    return Container(
      key: const Key('banner_app_update'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.accentSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.accent.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.system_update_outlined, size: 18, color: p.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: p.accent),
                ),
              ),
              if (!downloading)
                FilledButton(
                  key: const Key('btn_banner_update_now'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  onPressed: onDownload,
                  child: Text(permNeeded ? 'Tekrar Dene' : 'Güncelle'),
                ),
            ],
          ),
          if (updateState.message != null) ...[
            const SizedBox(height: 6),
            Text(
              updateState.message!,
              style: TextStyle(fontSize: 12, color: p.text, height: 1.3),
            ),
          ],
          if (downloading) ...[
            const SizedBox(height: 8),
            MeterBar(fraction: updateState.downloadProgress ?? 0.0, color: p.accent),
          ],
        ],
      ),
    );
  }
}

/// Örnek veri kipinde görünür uyarı: ekrandaki sinyaller gerçek değildir.
class _DemoBanner extends StatelessWidget {
  const _DemoBanner();

  @override
  Widget build(BuildContext context) {
    final p = PusulaPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: p.coral.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.coral.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.science_outlined, size: 16, color: p.coral),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'ÖRNEK VERİ · Ağsız önizleme kipi. Bu ekrandaki sinyal ve fiyatlar gerçek değildir.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.coral, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ekranın en önemli öğesi: bu haftanın kararı. Fırsat yoksa bunu büyük harflerle ve dürüstçe söyler.
class _DecisionCard extends StatelessWidget {
  const _DecisionCard({required this.state});

  final PusulaAppState state;

  @override
  Widget build(BuildContext context) {
    final p = PusulaPalette.of(context);
    final alloc = state.currentReport.newAllocation;
    final has = alloc.hasRecommendations;
    final scan = state.lastScan;
    final riskFraction = alloc.appetite.maxTotalRiskPct <= 0 ? 0.0 : alloc.totalOpenRiskPct / alloc.appetite.maxTotalRiskPct;

    final String headline;
    final String detail;
    if (has) {
      headline = '${alloc.recommendations.length} öneri · ${Fmt.pct(alloc.investedWeightPct, decimals: 0)} yatırım';
      detail = '${alloc.bistRecommendations.length} BIST, ${alloc.cryptoRecommendations.length} kripto. '
          'Kalan ${Fmt.pct(alloc.cashWeightPct, decimals: 0)} nakitte bekliyor.';
    } else if (scan == null && !state.isDemo) {
      headline = 'Şimdilik nakitte';
      detail = 'Henüz tarama yapılmadı. İlk tarama bitene kadar hiçbir öneri gösterilmez.';
    } else if (scan != null && scan.noData) {
      headline = 'Veri alınamadı';
      detail = 'Piyasa verisine ulaşılamadığı için değerlendirme yapılamadı. Bu bir "fırsat yok" sonucu değildir.';
    } else {
      headline = 'Bu hafta nakitte kal';
      detail = 'Eşiği geçen haftalık fırsat yok. Sermayeyi korumak da bir karardır.';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'BU HAFTANIN KARARI',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: p.textDim),
                  ),
                ),
                Tag('Risk: ${alloc.appetite.label}', color: p.accent),
              ],
            ),
            const Gap(8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (has ? p.accent : p.neutral).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    has ? Icons.explore : Icons.savings_outlined,
                    color: has ? p.accent : p.neutral,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    headline,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.15),
                  ),
                ),
              ],
            ),
            const Gap(8),
            Text(detail, style: TextStyle(fontSize: 13, color: p.textDim, height: 1.4)),
            const Gap(14),
            Row(
              children: [
                Expanded(
                  child: StatTile(label: 'Nakit', value: Fmt.pct(alloc.cashWeightPct, decimals: 0), big: true),
                ),
                Expanded(
                  child: StatTile(
                    label: 'BIST',
                    value: Fmt.pct(alloc.bistTotalWeightPct, decimals: 0),
                    valueColor: p.accent,
                    big: true,
                  ),
                ),
                Expanded(
                  child: StatTile(
                    label: 'Kripto',
                    value: Fmt.pct(alloc.cryptoTotalWeightPct, decimals: 0),
                    valueColor: p.coral,
                    big: true,
                  ),
                ),
              ],
            ),
            const Gap(14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Açık risk ${Fmt.pct(alloc.totalOpenRiskPct, decimals: 2)} / sınır ${Fmt.pct(alloc.appetite.maxTotalRiskPct)}',
                    style: TextStyle(fontSize: 12, color: p.textDim, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const Gap(6),
            MeterBar(fraction: riskFraction, color: riskFraction > 0.85 ? p.coral : p.profit),
            if (state.regimes.isNotEmpty) ...[
              const Gap(12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (state.regimes[Market.crypto] != null)
                    RegimeChip(marketLabel: 'Kripto', regime: state.regimes[Market.crypto]!.regime),
                  if (state.regimes[Market.bist] != null)
                    RegimeChip(marketLabel: 'BIST', regime: state.regimes[Market.bist]!.regime),
                ],
              ),
            ],
            if (alloc.scalingNotes.isNotEmpty) ...[
              const Gap(10),
              for (final n in alloc.scalingNotes)
                Text('• $n', style: TextStyle(fontSize: 11.5, color: p.textDim, height: 1.35)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Son taramanın hunisi: kaç varlık tarandı, kaçında kurulum bulundu, kaçı onaylandı ve
/// elenenler hangi aşamada elendi. "Neden öneri yok?" sorusunun cevabı buradadır.
class _ScanSummaryCard extends StatelessWidget {
  const _ScanSummaryCard({required this.state, required this.onScan});

  final PusulaAppState state;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final p = PusulaPalette.of(context);
    final scan = state.lastScan;

    if (scan == null) {
      return EmptyNote(
        icon: Icons.travel_explore,
        title: state.isLoading ? 'Piyasa taranıyor…' : 'Tarama bekleniyor',
        body: state.isLoading
            ? '10 kripto varlığı ve BIST izleme listesi kapanmış mumlarla değerlendiriliyor.'
            : 'Tarama; veri tazeliği, kurulum kalitesi, işlem maliyeti, Monte Carlo ve güven eşiği süzgeçlerinden geçer.',
        action: state.isLoading
            ? null
            : FilledButton.icon(
                onPressed: onScan,
                icon: const Icon(Icons.radar, size: 18),
                label: const Text('Şimdi tara'),
              ),
      );
    }

    final rejections = scan.rejectionsByStage.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    Widget step(String label, int value, Color color) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$value',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.5),
              ),
              Text(label, style: TextStyle(fontSize: 11.5, color: p.textDim, fontWeight: FontWeight.w600)),
            ],
          ),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CardHeader(
              icon: Icons.filter_alt_outlined,
              title: 'Son tarama',
              trailing: Text(
                Fmt.dateTimeTrt(scan.finishedAt),
                style: TextStyle(fontSize: 11.5, color: p.textDim),
              ),
            ),
            const Gap(14),
            Row(
              children: [
                step('varlık tarandı', scan.scannedInstrumentCount, p.text),
                Icon(Icons.chevron_right, color: p.border),
                const SizedBox(width: 8),
                step('kurulum bulundu', scan.setupCount, p.accent),
                Icon(Icons.chevron_right, color: p.border),
                const SizedBox(width: 8),
                step('onaylandı', scan.approvedCount, scan.approvedCount > 0 ? p.profit : p.neutral),
              ],
            ),
            if (rejections.isNotEmpty) ...[
              const Gap(14),
              Text('Elenme nedenleri', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: p.textDim)),
              const Gap(6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final e in rejections)
                    Tag(
                      '${FunnelStage.label(e.key)} · ${e.value}',
                      color: e.key == FunnelStage.fetch || e.key == FunnelStage.data ? p.coral : p.neutral,
                    ),
                ],
              ),
            ],
            if (scan.fetchFailures.isNotEmpty) ...[
              const Gap(10),
              Text(
                'Veri alınamayan: ${scan.fetchFailures.keys.map((i) => i.short).take(8).join(', ')}'
                '${scan.fetchFailures.length > 8 ? '…' : ''}',
                style: TextStyle(fontSize: 12, color: p.coral, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Fiyat kutucukları: genişliğe göre 2–4 sütun; iç içe kaydırma kullanmaz.
class _QuoteGrid extends StatelessWidget {
  const _QuoteGrid({required this.quotes});

  final List<LiveMarketQuote> quotes;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = (c.maxWidth / 132).floor().clamp(2, 5);
        final w = (c.maxWidth - (cols - 1) * 8) / cols;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final q in quotes) SizedBox(width: w, child: _QuoteTile(quote: q)),
          ],
        );
      },
    );
  }
}

class _QuoteTile extends StatelessWidget {
  const _QuoteTile({required this.quote});

  final LiveMarketQuote quote;

  @override
  Widget build(BuildContext context) {
    final p = PusulaPalette.of(context);
    final chg = quote.changePct;
    final up = chg > 0.005;
    final down = chg < -0.005;
    final color = up ? p.profit : (down ? p.loss : p.neutral);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: p.subtle,
        borderRadius: BorderRadius.circular(10),
        border: quote.isStale ? Border.all(color: p.coral.withValues(alpha: 0.6)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  quote.instrument.short,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                ),
              ),
              if (quote.isStale) Icon(Icons.warning_amber_rounded, size: 13, color: p.coral),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            Fmt.price(quote.lastPrice, quote.instrument.market),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          Row(
            children: [
              Icon(up ? Icons.arrow_drop_up : (down ? Icons.arrow_drop_down : Icons.remove), size: 16, color: color),
              Text(
                Fmt.pct(chg, decimals: 2, signed: true),
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
