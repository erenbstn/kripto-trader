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

/// Sekme 1 — Özet (Phantom esintili koyu kapsül düzeni).
///
/// Üstte büyük portföy bütçesi kahraman rakamı, Nakit Koruma kapsülü, etkileşimli 3B/2B
/// bütçe dağılım halkası, son tarama hunisi ve sağ/alt akışta yatay haftalık öneri kartları
/// ile çerçevesiz piyasa/sinyal satırları yer alır.
class OzetScreen extends ConsumerWidget {
  const OzetScreen({super.key});

  bool _matchesQuery(Instrument ins, String q) {
    if (q.isEmpty) return true;
    return ins.symbol.toLowerCase().contains(q) ||
        ins.short.toLowerCase().contains(q) ||
        ins.name.toLowerCase().contains(q);
  }

  void _showSliceModal(BuildContext context, DonutSliceData slice, PusulaAppState state) {
    final budget = state.settings.budgetAmount;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      constraints: const BoxConstraints(maxWidth: 640),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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

  void _showBudgetRiskSheet(BuildContext context, PusulaController controller) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      constraints: const BoxConstraints(maxWidth: 560),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final st = ref.watch(pusulaControllerProvider);
          final p = PusulaPalette.of(ctx);
          final s = st.settings;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Portföy Bütçesi & Risk İştahı',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Kapat',
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const Gap(6),
                  Text(
                    'Referans bütçe yalnızca TL ağırlık hesabında kullanılır; cihaz dışına gönderilmez.',
                    style: TextStyle(fontSize: 12.5, color: p.textDim, height: 1.35),
                  ),
                  const Gap(14),
                  Text(
                    Fmt.currencyTry(s.budgetAmount),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  Slider(
                    value: s.budgetAmount.clamp(25000.0, 500000.0),
                    min: 25000.0,
                    max: 500000.0,
                    divisions: 19,
                    label: Fmt.tl(s.budgetAmount),
                    onChanged: controller.updateBudget,
                  ),
                  const Gap(8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final amt in const [50000.0, 100000.0, 250000.0, 500000.0])
                        ChoiceChip(
                          label: Text('${(amt / 1000).toStringAsFixed(0)}B ₺'),
                          selected: (s.budgetAmount - amt).abs() < 1,
                          onSelected: (_) => controller.updateBudget(amt),
                        ),
                    ],
                  ),
                  const Gap(16),
                  Text('Risk İştahı', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.textDim)),
                  const Gap(8),
                  SegmentedButton<RiskAppetite>(
                    showSelectedIcon: false,
                    segments: [
                      for (final app in RiskAppetite.values)
                        ButtonSegment<RiskAppetite>(value: app, label: Text(app.label)),
                    ],
                    selected: {s.riskAppetite},
                    onSelectionChanged: (sel) => controller.updateRiskAppetite(sel.first),
                  ),
                  const Gap(12),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showSignalModal(BuildContext context, SignalRecord sig, double? currentPrice) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      constraints: const BoxConstraints(maxWidth: 640),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SymbolAvatarBadge(instrument: sig.instrument, size: 36),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${sig.instrument.short} · Teknik Kurulum',
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
                const Gap(8),
                const DisclaimerBanner(),
                const Gap(12),
                SignalCard(signal: sig, currentPrice: currentPrice),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pusulaControllerProvider);
    final controller = ref.read(pusulaControllerProvider.notifier);
    final query = ref.watch(searchQueryProvider).trim().toLowerCase();
    final p = PusulaPalette.of(context);
    final disableAnim = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final flat2D = state.settings.shouldSimplifyAnimations || disableAnim;
    final alloc = state.currentReport.newAllocation;

    final rawSignals = state.isDemo ? state.activeSignals : state.activeShortTermSignals;
    final openSignals = [
      for (final s in rawSignals)
        if (_matchesQuery(s.instrument, query)) s,
    ];
    final weeklyRecs = [
      for (final r in alloc.recommendations)
        if (_matchesQuery(r.instrument, query)) r,
    ];
    final cryptoQuotes = [
      for (final q in state.cryptoQuotes)
        if (_matchesQuery(q.instrument, query)) q,
    ];
    final bistQuotes = [
      for (final q in state.bistQuotes)
        if (_matchesQuery(q.instrument, query)) q,
    ];

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
        _PhantomHeroSection(
          state: state,
          onSelectBudget: () => _showBudgetRiskSheet(context, controller),
        ),
        const Gap(12),
        _PhantomCashCapsule(
          state: state,
          onTap: () => _showBudgetRiskSheet(context, controller),
        ),
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
        if (weeklyRecs.isNotEmpty) ...[
          SectionTitle(
            'Haftalık Öneriler (${weeklyRecs.length}) ›',
            subtitle: 'Kripto 4s ve BIST günlük onaylı ağırlık dağılımı.',
          ),
          SizedBox(
            height: 146,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: weeklyRecs.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (ctx, i) {
                final rec = weeklyRecs[i];
                final tlAmount = state.settings.budgetAmount * rec.weightPct / 100.0;
                return InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _showSliceModal(
                    ctx,
                    DonutSliceData(
                      id: 'rec_${rec.instrument.symbol}',
                      label: rec.instrument.short,
                      categoryLabel: rec.instrument.market == Market.bist ? 'BIST' : 'Kripto',
                      weightPct: rec.weightPct,
                      color: SymbolAvatarBadge.badgeColor(rec.instrument),
                      subtitle: '${rec.signal.strategy.label} · Güven ${rec.confidence.total}/100',
                      recommendation: rec,
                    ),
                    state,
                  ),
                  child: Container(
                    width: 156,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: p.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: p.border.withValues(alpha: 0.65)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            SymbolAvatarBadge(instrument: rec.instrument, size: 40),
                            Tag(Fmt.pct(rec.weightPct, decimals: 0), color: p.accent),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rec.instrument.short,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${Fmt.currencyTry(tlAmount)} · Skor ${rec.confidence.total}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: p.profit),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        SectionTitle(
          state.isDemo
              ? 'Açık Sinyaller (${openSignals.length}) ›'
              : 'Kısa Vade Sinyaller (${openSignals.length}) ›',
          subtitle: query.isEmpty ? 'Dokunarak giriş, stop ve hedef merdivenini inceleyin.' : '"$query" için süzüldü',
        ),
        if (openSignals.isEmpty)
          EmptyNote(
            icon: Icons.radar,
            title: query.isNotEmpty ? 'Aramayla eşleşen sinyal yok' : 'Açık kısa vade sinyali yok',
            body: state.lastScan == null && !state.isDemo
                ? 'İlk tarama tamamlandığında, onaylanan kurulumlar burada görünür.'
                : 'Son taramada eşiği geçen kısa vade kurulumu çıkmadı. Pusula zorla sinyal üretmez.',
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(
                children: [
                  for (final (i, sig) in openSignals.indexed) ...[
                    if (i > 0) Divider(color: p.border.withValues(alpha: 0.45)),
                    _PhantomSignalRow(
                      signal: sig,
                      currentPrice: state.priceOf(sig.instrument),
                      onTap: () => _showSignalModal(context, sig, state.priceOf(sig.instrument)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        const SectionTitle(
          'Piyasa ›',
          subtitle: 'Kripto Binance anlık, BIST Yahoo/İş Yatırım ~15 dk gecikmeli.',
        ),
        if (cryptoQuotes.isEmpty && bistQuotes.isEmpty)
          EmptyNote(
            icon: Icons.show_chart,
            title: query.isNotEmpty ? 'Eşleşen varlık bulunamadı' : 'Fiyat verisi henüz yok',
            body: query.isNotEmpty
                ? 'Farklı bir hisse kodu (ör. THYAO) veya kripto adı (ör. BTC) deneyin.'
                : 'Tarama tamamlandığında 10 kripto varlığı ve BIST izleme listesi burada listelenir.',
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (cryptoQuotes.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Tag('KRİPTO', color: p.coral),
                          const SizedBox(width: 8),
                          Text('Binance Spot · anlık', style: TextStyle(fontSize: 11.5, color: p.textDim)),
                        ],
                      ),
                    ),
                    for (final (i, q) in cryptoQuotes.indexed) ...[
                      if (i > 0) Divider(color: p.border.withValues(alpha: 0.35)),
                      _PhantomQuoteRow(quote: q),
                    ],
                  ],
                  if (cryptoQuotes.isNotEmpty && bistQuotes.isNotEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
                  if (bistQuotes.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Tag('BIST', color: p.accent),
                          const SizedBox(width: 8),
                          Text('Yahoo Finance · ~15 dk', style: TextStyle(fontSize: 11.5, color: p.textDim)),
                        ],
                      ),
                    ),
                    for (final (i, q) in bistQuotes.indexed) ...[
                      if (i > 0) Divider(color: p.border.withValues(alpha: 0.35)),
                      _PhantomQuoteRow(quote: q),
                    ],
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
                  if (i > 0) Divider(indent: 52, color: p.border.withValues(alpha: 0.45)),
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

/// Phantom ana ekranı gibi dev sol hizalı portföy bütçesi, seçici ve durum/değişim rozeti.
class _PhantomHeroSection extends StatelessWidget {
  const _PhantomHeroSection({
    required this.state,
    required this.onSelectBudget,
  });

  final PusulaAppState state;
  final VoidCallback onSelectBudget;

  @override
  Widget build(BuildContext context) {
    final p = PusulaPalette.of(context);
    final alloc = state.currentReport.newAllocation;
    final budget = state.settings.budgetAmount;
    final investedTry = budget * alloc.investedWeightPct / 100.0;
    final has = alloc.hasRecommendations;
    final scan = state.lastScan;

    final String statusHeadline;
    if (has) {
      statusHeadline = '${alloc.recommendations.length} öneri · ${Fmt.currencyTry(investedTry)} aktif';
    } else if (scan == null && !state.isDemo) {
      statusHeadline = 'Şimdilik nakitte';
    } else if (scan != null && scan.noData) {
      statusHeadline = 'Veri alınamadı';
    } else {
      statusHeadline = 'Bu hafta nakitte kal';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          key: const Key('btn_hero_budget_selector'),
          onTap: onSelectBudget,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Portföy Bütçesi · ${alloc.appetite.label} Risk',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: p.textDim),
                ),
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: p.textDim),
              ],
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          Fmt.currencyTry(budget),
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w800,
            color: p.text,
            letterSpacing: -1.4,
            height: 1.08,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              statusHeadline,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: has ? p.profit : p.textDim,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (has ? p.profit : p.neutral).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                has ? '+${Fmt.pct(alloc.investedWeightPct, decimals: 0)}' : 'Nakit %${alloc.cashWeightPct.round()}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: has ? p.profit : p.textDim,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            if (state.regimes[Market.crypto] != null)
              RegimeChip(marketLabel: 'Kripto', regime: state.regimes[Market.crypto]!.regime),
            if (state.regimes[Market.bist] != null)
              RegimeChip(marketLabel: 'BIST', regime: state.regimes[Market.bist]!.regime),
          ],
        ),
      ],
    );
  }
}

/// Phantom'daki `Cash $8.64` kapsülüyle birebir aynı yapıda `Nakit Koruma` kapsülü.
class _PhantomCashCapsule extends StatelessWidget {
  const _PhantomCashCapsule({
    required this.state,
    required this.onTap,
  });

  final PusulaAppState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = PusulaPalette.of(context);
    final alloc = state.currentReport.newAllocation;
    final budget = state.settings.budgetAmount;
    final cashTry = budget * alloc.cashWeightPct / 100.0;
    final riskFraction =
        alloc.appetite.maxTotalRiskPct <= 0 ? 0.0 : alloc.totalOpenRiskPct / alloc.appetite.maxTotalRiskPct;

    return InkWell(
      key: const Key('phantom_cash_capsule'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: p.border.withValues(alpha: 0.6)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: p.subtle,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.payments_outlined, size: 19, color: p.textDim),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nakit Koruma',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'BIST ${Fmt.pct(alloc.bistTotalWeightPct, decimals: 0)} · Kripto ${Fmt.pct(alloc.cryptoTotalWeightPct, decimals: 0)}',
                        style: TextStyle(fontSize: 11.5, color: p.textDim, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Fmt.currencyTry(cashTry),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      Fmt.pct(alloc.cashWeightPct, decimals: 0),
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: p.textDim),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            MeterBar(fraction: riskFraction, color: riskFraction > 0.85 ? p.coral : p.profit, height: 5),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Açık risk ${Fmt.pct(alloc.totalOpenRiskPct, decimals: 2)} / sınır ${Fmt.pct(alloc.appetite.maxTotalRiskPct)}',
                  style: TextStyle(fontSize: 11, color: p.textDim, fontWeight: FontWeight.w600),
                ),
                Text(
                  'Ayarla ›',
                  style: TextStyle(fontSize: 11, color: p.accent, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PhantomSignalRow extends StatelessWidget {
  const _PhantomSignalRow({
    required this.signal,
    required this.currentPrice,
    required this.onTap,
  });

  final SignalRecord signal;
  final double? currentPrice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = PusulaPalette.of(context);
    final price = currentPrice ?? signal.entryPrice;
    final pctToT2 = signal.entryPrice <= 0 ? 0.0 : ((signal.target2 - signal.entryPrice) / signal.entryPrice) * 100.0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            SymbolAvatarBadge(instrument: signal.instrument, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    signal.instrument.short,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '${signal.strategy.label} · Güven ${signal.confidence.total}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: p.textDim),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${Fmt.price(price, signal.instrument.market)} ${Fmt.currency(signal.instrument.market)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  'Hedef ${Fmt.pct(pctToT2, decimals: 1, signed: true)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: p.profit,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PhantomQuoteRow extends StatelessWidget {
  const _PhantomQuoteRow({required this.quote});

  final LiveMarketQuote quote;

  @override
  Widget build(BuildContext context) {
    final p = PusulaPalette.of(context);
    final chg = quote.changePct;
    final up = chg > 0.005;
    final down = chg < -0.005;
    final color = up ? p.profit : (down ? p.loss : p.neutral);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          SymbolAvatarBadge(instrument: quote.instrument, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        quote.instrument.short,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (quote.isStale) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.warning_amber_rounded, size: 13, color: p.coral),
                    ],
                  ],
                ),
                Text(
                  quote.instrument.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: p.textDim),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Fmt.price(quote.lastPrice, quote.instrument.market),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                Fmt.pct(chg, decimals: 2, signed: true),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.accentSoft,
        borderRadius: BorderRadius.circular(18),
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
        borderRadius: BorderRadius.circular(14),
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

/// Son taramanın hunisi: kaç varlık tarandı, kaçında kurulum bulundu, kaçı onaylandı.
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
