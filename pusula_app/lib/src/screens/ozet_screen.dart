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
enum _MarketListFilter { all, favorites, bist, crypto }

class OzetScreen extends ConsumerStatefulWidget {
  const OzetScreen({super.key});

  @override
  ConsumerState<OzetScreen> createState() => _OzetScreenState();
}

class _OzetScreenState extends ConsumerState<OzetScreen> {
  _MarketListFilter _marketFilter = _MarketListFilter.all;

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
                      usdTryRate: state.settings.usdTryRate,
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
                            Text(slice.subtitle, style: TextStyle(fontSize: 13, color: p.textDim)),
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
      builder: (_) => _BudgetRiskSheet(controller: controller),
    );
  }

  void _showSignalModal(
    BuildContext context,
    SignalRecord sig,
    double? currentPrice, {
    double? allocatedTry,
    double usdTryRate = 36.50,
  }) {
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
                        '${sig.instrument.short} · Spot Kurulum',
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
                SignalCard(
                  signal: sig,
                  currentPrice: currentPrice,
                  allocatedTry: allocatedTry,
                  usdTryRate: usdTryRate,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pusulaControllerProvider);
    final controller = ref.read(pusulaControllerProvider.notifier);
    final query = ref.watch(searchQueryProvider).trim().toLowerCase();
    final p = PusulaPalette.of(context);
    final disableAnim = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final flat2D = state.settings.shouldSimplifyAnimations || disableAnim;
    final alloc = state.currentReport.newAllocation;

    final rawSignals = state.isDemo ? state.effectiveActiveSignals : state.effectiveShortTermSignals;
    final dailySignals = [
      for (final s in state.effectiveShortTermSignals)
        if (classifyHorizon(s) == InvestmentHorizon.daily) s,
    ];
    final breakdown = HorizonBudgetBreakdown.compute(
      totalBudget: state.settings.budgetAmount,
      allocation: alloc,
      activeDailySignals: dailySignals,
    );
    final openSignals = [
      for (final s in rawSignals)
        if (_matchesQuery(s.instrument, query)) s,
    ];
    final weeklyRecs = [
      for (final r in alloc.recommendations)
        if (_matchesQuery(r.instrument, query)) r,
    ];
    final recAllocBySymbol = {
      for (final r in alloc.recommendations)
        r.instrument.symbol.toUpperCase(): state.settings.budgetAmount * r.weightPct / 100.0,
    };
    final bistCatalog = buildBistCatalog(state.settings);
    final showCryptoSection = _marketFilter == _MarketListFilter.all ||
        _marketFilter == _MarketListFilter.favorites ||
        _marketFilter == _MarketListFilter.crypto;
    final showBistSection = _marketFilter == _MarketListFilter.all ||
        _marketFilter == _MarketListFilter.favorites ||
        _marketFilter == _MarketListFilter.bist;

    final cryptoQuotes = [
      if (showCryptoSection)
        for (final q in state.cryptoQuotes)
          if (CryptoUniverse.contains(q.instrument.symbol) &&
              _matchesQuery(q.instrument, query) &&
              (_marketFilter != _MarketListFilter.favorites ||
                  state.settings.isFavorite(q.instrument.symbol)))
            q,
    ];
    final bistQuotes = [
      if (showBistSection)
        for (final q in state.bistQuotes)
          if (_matchesQuery(q.instrument, query) &&
              (_marketFilter != _MarketListFilter.favorites ||
                  (q.instrument.symbol != BistUniverse.benchmark.symbol &&
                      state.settings.isFavorite(q.instrument.symbol))))
            q,
    ];

    final listedSymbols = <String>{
      for (final q in bistQuotes) q.instrument.symbol.toUpperCase(),
      for (final q in cryptoQuotes) q.instrument.symbol.toUpperCase(),
    };

    final extraLookupInstruments = <Instrument>[];
    if (query.isNotEmpty && showBistSection) {
      for (final ins in bistCatalog) {
        if (!listedSymbols.contains(ins.symbol.toUpperCase()) && _matchesQuery(ins, query)) {
          extraLookupInstruments.add(ins);
          if (extraLookupInstruments.length >= 8) break;
        }
      }
      final cleanQuery = BistUniverse.normalizeSymbol(query);
      if (RegExp(r'^[A-Z0-9]{3,6}$').hasMatch(cleanQuery) &&
          !CryptoUniverse.contains(cleanQuery) &&
          !listedSymbols.contains(cleanQuery) &&
          !extraLookupInstruments.any((i) => i.symbol.toUpperCase() == cleanQuery)) {
        extraLookupInstruments.add(BistUniverse.instrumentFor(cleanQuery));
      }
    } else if (query.isEmpty && _marketFilter == _MarketListFilter.favorites) {
      for (final sym in state.settings.favoriteSymbols) {
        final clean = sym.trim().toUpperCase();
        if (clean.isEmpty || listedSymbols.contains(clean)) continue;
        final isCrypto = CryptoUniverse.contains(clean);
        if (isCrypto && showCryptoSection) {
          extraLookupInstruments.add(
            CryptoUniverse.instruments.firstWhere((c) => c.symbol == clean),
          );
        } else if (!isCrypto && showBistSection && clean != BistUniverse.benchmark.symbol) {
          extraLookupInstruments.add(BistUniverse.instrumentFor(clean));
        }
      }
    }

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
          breakdown: breakdown,
          onSelectBudget: () => _showBudgetRiskSheet(context, controller),
        ),
        const Gap(12),
        _PhantomCashCapsule(
          state: state,
          breakdown: breakdown,
          onTap: () => _showBudgetRiskSheet(context, controller),
        ),
        const Gap(12),
        HorizonBudgetSummaryCard(
          breakdown: breakdown,
          userSelectedMode: state.settings.isUserSelectedMode,
          selectedCount: state.settings.favoriteSymbols.length,
          onModeChanged: (userSel) => controller.setPortfolioSelectionMode(userSelected: userSel),
          onPickAssets: () => _openUniverseBrowser(context),
          onEditBudget: () => _showBudgetRiskSheet(context, controller),
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
            'Önerilen Portföy (${weeklyRecs.length}) ›',
            subtitle: 'Sadece Spot · Alım tutarı & adet',
          ),
          SizedBox(
            height: 162,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: weeklyRecs.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (ctx, i) {
                final rec = weeklyRecs[i];
                final tlAmount = state.settings.budgetAmount * rec.weightPct / 100.0;
                final plan = OrderSizingPlan.fromSignal(
                  signal: rec.signal,
                  allocatedTry: tlAmount,
                  usdTryRate: state.settings.usdTryRate,
                );
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
                      subtitle: '${plan.horizon.label} · ${rec.signal.strategy.label}',
                      recommendation: rec,
                    ),
                    state,
                  ),
                  child: Container(
                    width: 172,
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
                            SymbolAvatarBadge(instrument: rec.instrument, size: 38),
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
                            Text(
                              plan.horizon.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: p.textDim),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${Fmt.currencyTry(tlAmount)} · ${plan.qtyBuyLabel()} AL',
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
          'Günlük & Aktif Sinyaller (${openSignals.length}) ›',
          subtitle: query.isEmpty ? 'Kalan Limit · Al/Sat Adet' : '"$query"',
        ),
        if (openSignals.isEmpty)
          EmptyNote(
            icon: Icons.radar,
            title: query.isNotEmpty ? 'Eşleşen sinyal yok' : 'Aktif sinyal yok',
            body: state.lastScan == null && !state.isDemo
                ? 'Tarama bekleniyor.'
                : 'Seçili kriterde onaylı sinyal yok.',
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(
                children: [
                  for (final (i, sig) in openSignals.indexed) ...[
                    if (i > 0) Divider(color: p.border.withValues(alpha: 0.45)),
                    Builder(
                      builder: (context) {
                        final isDaily = classifyHorizon(sig) == InvestmentHorizon.daily;
                        final allocTry = isDaily
                            ? breakdown.dailyPerSignalTry
                            : (recAllocBySymbol[sig.instrument.symbol.toUpperCase()] ?? 0.0);
                        return _PhantomSignalRow(
                          signal: sig,
                          currentPrice: state.priceOf(sig.instrument),
                          allocatedTry: allocTry,
                          usdTryRate: state.settings.usdTryRate,
                          onTap: () => _showSignalModal(
                            context,
                            sig,
                            state.priceOf(sig.instrument),
                            allocatedTry: allocTry,
                            usdTryRate: state.settings.usdTryRate,
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Expanded(
              child: SectionTitle(
                'Piyasa ›',
                subtitle: 'BIST (₺) · Kripto 10 coin (\$)',
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FilledButton.tonalIcon(
                key: const Key('btn_open_universe_browser'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                onPressed: () => _openUniverseBrowser(context),
                icon: const Icon(Icons.star_border_rounded, size: 17),
                label: Text('BIST (${bistCatalog.length}) & Favoriler', style: const TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterPillChip(
                key: const Key('filter_market_all'),
                label: 'Tümü',
                selected: _marketFilter == _MarketListFilter.all,
                onTap: () => setState(() => _marketFilter = _MarketListFilter.all),
              ),
              const SizedBox(width: 8),
              _FilterPillChip(
                key: const Key('filter_market_favorites'),
                label: '★ Favoriler',
                selected: _marketFilter == _MarketListFilter.favorites,
                onTap: () => setState(() => _marketFilter = _MarketListFilter.favorites),
              ),
              const SizedBox(width: 8),
              _FilterPillChip(
                key: const Key('filter_market_bist'),
                label: 'BIST (₺)',
                selected: _marketFilter == _MarketListFilter.bist,
                onTap: () => setState(() => _marketFilter = _MarketListFilter.bist),
              ),
              const SizedBox(width: 8),
              _FilterPillChip(
                key: const Key('filter_market_crypto'),
                label: 'Kripto (\$)',
                selected: _marketFilter == _MarketListFilter.crypto,
                onTap: () => setState(() => _marketFilter = _MarketListFilter.crypto),
              ),
            ],
          ),
        ),
        const Gap(10),
        if (cryptoQuotes.isEmpty && bistQuotes.isEmpty && extraLookupInstruments.isEmpty)
          EmptyNote(
            icon: _marketFilter == _MarketListFilter.favorites ? Icons.star_outline_rounded : Icons.show_chart,
            title: _marketFilter == _MarketListFilter.favorites
                ? 'Henüz favori varlık yok'
                : (query.isNotEmpty ? 'Eşleşen varlık bulunamadı' : 'Fiyat verisi henüz yok'),
            body: _marketFilter == _MarketListFilter.favorites
                ? 'Hisse veya kripto satırındaki yıldız (☆) simgesine dokunarak ya da BIST Kataloğu üzerinden favori ekleyin.'
                : (query.isNotEmpty
                    ? 'Farklı bir BIST hisse kodu (ör. THYAO, FROTO) veya listedeki 10 kriptodan birini deneyin.'
                    : 'Tarama başlatabilir veya BIST Kataloğu üzerinden grafik açmadan tekil hisse fiyatına bakabilirsiniz.'),
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
                          Tag('KRİPTO (\$)', color: p.coral),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '10 coin · Binance anlık',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11.5, color: p.textDim),
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (final (i, q) in cryptoQuotes.indexed) ...[
                      if (i > 0) Divider(color: p.border.withValues(alpha: 0.35)),
                      _PhantomQuoteRow(
                        quote: q,
                        isFavorite: state.settings.isFavorite(q.instrument.symbol),
                        onToggleFavorite: () => controller.toggleFavorite(q.instrument),
                      ),
                    ],
                  ],
                  if (cryptoQuotes.isNotEmpty && bistQuotes.isNotEmpty)
                    const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
                  if (bistQuotes.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Tag('BIST (₺)', color: p.accent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Yahoo Finance · ~15 dk',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11.5, color: p.textDim),
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (final (i, q) in bistQuotes.indexed) ...[
                      if (i > 0) Divider(color: p.border.withValues(alpha: 0.35)),
                      _PhantomQuoteRow(
                        quote: q,
                        isFavorite: state.settings.isFavorite(q.instrument.symbol),
                        showFavoriteButton: q.instrument.symbol != BistUniverse.benchmark.symbol,
                        onToggleFavorite: () => controller.toggleFavorite(q.instrument),
                      ),
                    ],
                  ],
                  if (extraLookupInstruments.isNotEmpty) ...[
                    if (cryptoQuotes.isNotEmpty || bistQuotes.isNotEmpty)
                      const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Tag(
                            _marketFilter == _MarketListFilter.favorites ? 'FAVORİ FİYAT' : 'BIST KATALOĞU (₺)',
                            color: p.accent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Grafik açmadan anlık fiyat al',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11.5, color: p.textDim),
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (final (i, ins) in extraLookupInstruments.indexed) ...[
                      if (i > 0) Divider(color: p.border.withValues(alpha: 0.35)),
                      _CatalogLookupRow(
                        instrument: ins,
                        isFavorite: state.settings.isFavorite(ins.symbol),
                        onToggleFavorite: () => controller.toggleFavorite(ins),
                        onFetchQuote: () => controller.fetchSingleQuote(ins),
                      ),
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

  void _openUniverseBrowser(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: PusulaPalette.of(context).background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _UniverseBrowserSheet(),
    );
  }
}

/// Phantom ana ekranı gibi dev sol hizalı portföy bütçesi, seçici ve durum/değişim rozeti.
class _PhantomHeroSection extends StatelessWidget {
  const _PhantomHeroSection({
    required this.state,
    required this.breakdown,
    required this.onSelectBudget,
  });

  final PusulaAppState state;
  final HorizonBudgetBreakdown breakdown;
  final VoidCallback onSelectBudget;

  @override
  Widget build(BuildContext context) {
    final p = PusulaPalette.of(context);
    final alloc = state.currentReport.newAllocation;
    final budget = state.settings.budgetAmount;
    final investedTry = breakdown.mainInvestedTry + breakdown.dailyLimitTry;
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
    required this.breakdown,
    required this.onTap,
  });

  final PusulaAppState state;
  final HorizonBudgetBreakdown breakdown;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = PusulaPalette.of(context);
    final alloc = state.currentReport.newAllocation;
    final budget = state.settings.budgetAmount;
    final cashTry = breakdown.cashReserveTry;
    final cashPct = budget > 0 ? (cashTry / budget) * 100.0 : alloc.cashWeightPct;
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
                        'Günlük Limit ${Fmt.currencyTry(breakdown.dailyLimitTry)} · BIST ${Fmt.pct(alloc.bistTotalWeightPct, decimals: 0)} · Kripto ${Fmt.pct(alloc.cryptoTotalWeightPct, decimals: 0)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                      Fmt.pct(cashPct, decimals: 0),
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
                Expanded(
                  child: Text(
                    'Risk ${Fmt.pct(alloc.totalOpenRiskPct, decimals: 2)} / ${Fmt.pct(alloc.appetite.maxTotalRiskPct)} · Bütçe Gir',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: p.textDim, fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  'Düzenle ›',
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
    this.allocatedTry = 0.0,
    this.usdTryRate = 36.50,
    required this.onTap,
  });

  final SignalRecord signal;
  final double? currentPrice;
  final double allocatedTry;
  final double usdTryRate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = PusulaPalette.of(context);
    final price = currentPrice ?? signal.entryPrice;
    final pctToT2 = signal.entryPrice <= 0 ? 0.0 : ((signal.target2 - signal.entryPrice) / signal.entryPrice) * 100.0;
    final horizon = classifyHorizon(signal);
    final plan = allocatedTry > 0
        ? OrderSizingPlan.fromSignal(signal: signal, allocatedTry: allocatedTry, usdTryRate: usdTryRate)
        : null;

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
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        signal.instrument.short,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                      ),
                      Tag(horizon.label, color: p.accent),
                    ],
                  ),
                  Text(
                    plan != null
                        ? '${Fmt.currencyTry(plan.allocatedTry)} · ${plan.qtyBuyLabel()} AL · H2 ${plan.qtyT2Label()} sat'
                        : '${signal.strategy.label} · Skor ${signal.confidence.total}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: plan != null ? p.profit : p.textDim, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Fmt.priceWithCurrency(price, signal.instrument.market),
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

class _BudgetRiskSheet extends ConsumerStatefulWidget {
  const _BudgetRiskSheet({required this.controller});

  final PusulaController controller;

  @override
  ConsumerState<_BudgetRiskSheet> createState() => _BudgetRiskSheetState();
}

class _BudgetRiskSheetState extends ConsumerState<_BudgetRiskSheet> {
  late final TextEditingController _budgetCtrl;

  @override
  void initState() {
    super.initState();
    final current = ref.read(pusulaControllerProvider).settings.budgetAmount;
    _budgetCtrl = TextEditingController(text: current.round().toString());
  }

  @override
  void dispose() {
    _budgetCtrl.dispose();
    super.dispose();
  }

  void _applyTypedBudget() {
    final parsed = parseTryInput(_budgetCtrl.text);
    if (parsed == null) return;
    widget.controller.updateBudget(parsed);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(pusulaControllerProvider);
    final p = PusulaPalette.of(context);
    final s = st.settings;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Bütçe, Mod & Risk (Spot)',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Kapat',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Gap(8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('input_custom_budget_try'),
                      controller: _budgetCtrl,
                      keyboardType: TextInputType.number,
                      onSubmitted: (_) => _applyTypedBudget(),
                      decoration: InputDecoration(
                        labelText: 'Portföy Bütçesi (₺)',
                        prefixText: '₺ ',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const Key('btn_apply_custom_budget'),
                    onPressed: _applyTypedBudget,
                    child: const Text('Uygula'),
                  ),
                ],
              ),
              const Gap(10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final amt in const [50000.0, 100000.0, 250000.0, 500000.0, 1000000.0])
                    ChoiceChip(
                      label: Text(amt >= 1000000 ? '1M ₺' : '${(amt / 1000).toStringAsFixed(0)}B ₺'),
                      selected: (s.budgetAmount - amt).abs() < 1,
                      onSelected: (_) {
                        _budgetCtrl.text = amt.round().toString();
                        widget.controller.updateBudget(amt);
                      },
                    ),
                ],
              ),
              const Gap(14),
              Text('Seçim Modu', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: p.textDim)),
              const Gap(6),
              PortfolioModeSelector(
                autoKey: const Key('sheet_btn_mode_auto'),
                customKey: const Key('sheet_btn_mode_custom'),
                userSelected: s.isUserSelectedMode,
                selectedCount: s.favoriteSymbols.length,
                onModeChanged: (userSel) => widget.controller.setPortfolioSelectionMode(userSelected: userSel),
              ),
              const Gap(14),
              Text('Risk İştahı', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: p.textDim)),
              const Gap(6),
              SegmentedButton<RiskAppetite>(
                showSelectedIcon: false,
                segments: [
                  for (final app in RiskAppetite.values)
                    ButtonSegment<RiskAppetite>(value: app, label: Text(app.label)),
                ],
                selected: {s.riskAppetite},
                onSelectionChanged: (sel) => widget.controller.updateRiskAppetite(sel.first),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhantomQuoteRow extends StatelessWidget {
  const _PhantomQuoteRow({
    required this.quote,
    required this.isFavorite,
    required this.onToggleFavorite,
    this.showFavoriteButton = true,
  });

  final LiveMarketQuote quote;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final bool showFavoriteButton;

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
                Fmt.priceWithCurrency(quote.lastPrice, quote.instrument.market),
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
          if (showFavoriteButton) ...[
            const SizedBox(width: 4),
            IconButton(
              key: Key('btn_fav_${quote.instrument.symbol}'),
              onPressed: onToggleFavorite,
              tooltip: isFavorite ? 'Favorilerden çıkar' : 'Favorilere ekle',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              padding: EdgeInsets.zero,
              icon: Icon(
                isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 20,
                color: isFavorite ? Colors.amber : p.textDim,
              ),
            ),
          ],
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
            ? '${state.settings.scanAllBistUniverse ? '10 kripto ve tüm BIST kataloğu' : '10 kripto ve seçili BIST listesi'} kapanmış mumlarla değerlendiriliyor.'
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

class _FilterPillChip extends StatelessWidget {
  const _FilterPillChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = PusulaPalette.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? p.accentSoft : p.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? p.accent : p.border.withValues(alpha: 0.7),
          ),
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
}

class _CatalogLookupRow extends StatefulWidget {
  const _CatalogLookupRow({
    required this.instrument,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onFetchQuote,
  });

  final Instrument instrument;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final Future<LiveMarketQuote?> Function() onFetchQuote;

  @override
  State<_CatalogLookupRow> createState() => _CatalogLookupRowState();
}

class _CatalogLookupRowState extends State<_CatalogLookupRow> {
  bool _loading = false;

  Future<void> _fetch() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await widget.onFetchQuote();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = PusulaPalette.of(context);
    final currSymbol = Fmt.currencySymbol(widget.instrument.market);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SymbolAvatarBadge(instrument: widget.instrument, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.instrument.short,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
                Text(
                  widget.instrument.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: p.textDim),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            key: Key('btn_fetch_quote_${widget.instrument.symbol}'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            ),
            onPressed: _loading ? null : _fetch,
            child: _loading
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : Text('Fiyatı Gör ($currSymbol)', style: const TextStyle(fontSize: 11.5)),
          ),
          const SizedBox(width: 4),
          IconButton(
            key: Key('btn_fav_${widget.instrument.symbol}'),
            onPressed: widget.onToggleFavorite,
            tooltip: widget.isFavorite ? 'Favorilerden çıkar' : 'Favorilere ekle',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            padding: EdgeInsets.zero,
            icon: Icon(
              widget.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 20,
              color: widget.isFavorite ? Colors.amber : p.textDim,
            ),
          ),
        ],
      ),
    );
  }
}

class _UniverseBrowserSheet extends ConsumerStatefulWidget {
  const _UniverseBrowserSheet();

  @override
  ConsumerState<_UniverseBrowserSheet> createState() => _UniverseBrowserSheetState();
}

class _UniverseBrowserSheetState extends ConsumerState<_UniverseBrowserSheet> {
  int _tab = 0; // 0 = BIST (₺), 1 = 10 Kripto ($)
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  final Set<String> _loadingSymbols = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchOne(PusulaController controller, Instrument ins) async {
    final key = ins.symbol.toUpperCase();
    if (_loadingSymbols.contains(key)) return;
    setState(() => _loadingSymbols.add(key));
    try {
      await controller.fetchSingleQuote(ins);
    } finally {
      if (mounted) {
        setState(() => _loadingSymbols.remove(key));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pusulaControllerProvider);
    final controller = ref.read(pusulaControllerProvider.notifier);
    final p = PusulaPalette.of(context);
    final bistCatalog = buildBistCatalog(state.settings);

    final bistQuotesMap = {
      for (final q in state.bistQuotes) q.instrument.symbol.toUpperCase(): q,
    };
    final cryptoQuotesMap = {
      for (final q in state.cryptoQuotes) q.instrument.symbol.toUpperCase(): q,
    };

    final q = _query.trim().toLowerCase();
    final filteredBist = [
      for (final ins in bistCatalog)
        if (q.isEmpty || ins.short.toLowerCase().contains(q) || ins.name.toLowerCase().contains(q)) ins,
    ];
    if (q.isEmpty) {
      filteredBist.sort((a, b) {
        final af = state.settings.isFavorite(a.symbol) ? 0 : 1;
        final bf = state.settings.isFavorite(b.symbol) ? 0 : 1;
        return af.compareTo(bf);
      });
    }

    final filteredCrypto = [
      for (final ins in CryptoUniverse.instruments)
        if (q.isEmpty || ins.short.toLowerCase().contains(q) || ins.name.toLowerCase().contains(q)) ins,
    ];

    final cleanUpper = BistUniverse.normalizeSymbol(_query);
    final canAddCustomBist = _tab == 0 &&
        cleanUpper.length >= 3 &&
        cleanUpper.length <= 6 &&
        RegExp(r'^[A-Z0-9]+$').hasMatch(cleanUpper) &&
        !CryptoUniverse.contains(cleanUpper) &&
        !bistCatalog.any((ins) => ins.symbol.toUpperCase() == cleanUpper);

    final activeList = _tab == 0 ? filteredBist : filteredCrypto;
    final quoteMap = _tab == 0 ? bistQuotesMap : cryptoQuotesMap;

    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.88,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.viewInsetsOf(context).bottom + 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: p.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Piyasa Kataloğu & Favoriler',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    key: const Key('btn_close_universe_browser'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Row(
                children: [
                  _FilterPillChip(
                    key: const Key('sheet_tab_bist'),
                    label: 'BIST (${bistCatalog.length}) · ₺',
                    selected: _tab == 0,
                    onTap: () => setState(() => _tab = 0),
                  ),
                  const SizedBox(width: 8),
                  _FilterPillChip(
                    key: const Key('sheet_tab_crypto'),
                    label: 'Kripto (${CryptoUniverse.instruments.length}) · \$',
                    selected: _tab == 1,
                    onTap: () => setState(() => _tab = 1),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('field_universe_search'),
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: _tab == 0
                      ? 'Hisse kodu veya adı ara (ör. THYAO, FROTO)…'
                      : 'Listedeki 10 kripto arasında ara (ör. BTC, ONDO)…',
                  prefixIcon: const Icon(Icons.search, size: 19),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    SwitchListTile.adaptive(
                      key: const Key('switch_sheet_scan_all_bist'),
                      dense: true,
                      title: Text('Tüm BIST hisselerini tara (${bistCatalog.length})',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      value: state.settings.scanAllBistUniverse,
                      onChanged: controller.toggleScanAllBistUniverse,
                    ),
                    const Divider(height: 1),
                    SwitchListTile.adaptive(
                      key: const Key('switch_sheet_scan_only_favorites'),
                      dense: true,
                      title: const Text('Yalnızca favori varlıkları tara',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      value: state.settings.scanOnlyFavorites,
                      onChanged: controller.toggleScanOnlyFavorites,
                    ),
                  ],
                ),
              ),
              if (canAddCustomBist) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: p.accentSoft,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: p.accent.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$cleanUpper · Özel BIST hissesi ekle ve favorile',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: p.accent),
                        ),
                      ),
                      FilledButton(
                        key: const Key('btn_add_custom_bist'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 34),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onPressed: () async {
                          await controller.addCustomBistSymbol(cleanUpper);
                        },
                        child: const Text('Ekle', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],
              if (_tab == 1) ...[
                const SizedBox(height: 8),
                Text(
                  'Kripto taraması ve fiyat ekranı yalnızca belirlediğin 10 kripto için aktiftir (\$).',
                  style: TextStyle(fontSize: 11.5, color: p.textDim),
                ),
              ],
              const SizedBox(height: 8),
              Expanded(
                child: activeList.isEmpty
                    ? Center(
                        child: Text(
                          'Aramayla eşleşen varlık bulunamadı.',
                          style: TextStyle(fontSize: 13, color: p.textDim),
                        ),
                      )
                    : ListView.separated(
                        itemCount: activeList.length,
                        separatorBuilder: (_, _) => Divider(height: 1, color: p.border.withValues(alpha: 0.35)),
                        itemBuilder: (ctx, idx) {
                          final ins = activeList[idx];
                          final symKey = ins.symbol.toUpperCase();
                          final quote = quoteMap[symKey];
                          final isFav = state.settings.isFavorite(symKey);
                          final isLoading = _loadingSymbols.contains(symKey);
                          final chg = quote?.changePct ?? 0.0;
                          final chgColor = chg > 0.005
                              ? p.profit
                              : (chg < -0.005 ? p.loss : p.neutral);

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                SymbolAvatarBadge(instrument: ins, size: 36),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        ins.short,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                                      ),
                                      Text(
                                        ins.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 11.5, color: p.textDim),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (quote != null)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        Fmt.priceWithCurrency(quote.lastPrice, ins.market),
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w800,
                                          fontFeatures: [FontFeature.tabularFigures()],
                                        ),
                                      ),
                                      Text(
                                        Fmt.pct(chg, decimals: 2, signed: true),
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: chgColor,
                                          fontFeatures: const [FontFeature.tabularFigures()],
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  FilledButton.tonal(
                                    key: Key('btn_sheet_fetch_${ins.symbol}'),
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size(0, 32),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    ),
                                    onPressed: isLoading ? null : () => _fetchOne(controller, ins),
                                    child: isLoading
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : Text(
                                            'Fiyatı Gör (${Fmt.currencySymbol(ins.market)})',
                                            style: const TextStyle(fontSize: 11.5),
                                          ),
                                  ),
                                const SizedBox(width: 4),
                                IconButton(
                                  key: Key('btn_sheet_fav_${ins.symbol}'),
                                  onPressed: () => controller.toggleFavorite(ins),
                                  tooltip: isFav ? 'Favorilerden çıkar' : 'Favorilere ekle',
                                  visualDensity: VisualDensity.compact,
                                  constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                                  padding: EdgeInsets.zero,
                                  icon: Icon(
                                    isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                                    size: 20,
                                    color: isFav ? Colors.amber : p.textDim,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
