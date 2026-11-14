import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/notifications/notification_engine.dart';
import 'src/screens/ayar_screen.dart';
import 'src/screens/oneri_screen.dart';
import 'src/screens/ozet_screen.dart';
import 'src/screens/sinyal_screen.dart';
import 'src/state/pusula_controller.dart';
import 'src/storage/sqlite_storage.dart';
import 'src/theme/gunduz_theme.dart';
import 'src/widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  StorageBundle storage;
  try {
    storage = await StorageBundle.open();
  } catch (e) {
    debugPrint('Pusula yerel depo açılamadı, bellek deposuna geçiliyor: $e');
    storage = StorageBundle.inMemory();
  }

  final notificationGateway = FlutterLocalNotificationGateway();
  try {
    await notificationGateway.initialize();
  } catch (e) {
    debugPrint('Pusula bildirim kanalları başlatılamadı: $e');
  }

  runApp(
    ProviderScope(
      overrides: [
        storageBundleProvider.overrideWithValue(storage),
        notificationGatewayProvider.overrideWithValue(notificationGateway),
        liveNetworkEnabledProvider.overrideWithValue(true),
        demoSeedProvider.overrideWithValue(false),
      ],
      child: const PusulaApp(),
    ),
  );
}

class PusulaApp extends ConsumerWidget {
  const PusulaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pusulaControllerProvider);
    final isDark = state.settings.darkMode;

    return MaterialApp(
      title: 'Pusula',
      debugShowCheckedModeBanner: false,
      theme: GunduzTheme.light(),
      darkTheme: GunduzTheme.dark(),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      themeAnimationDuration: state.settings.shouldSimplifyAnimations
          ? Duration.zero
          : const Duration(milliseconds: 200),
      home: const PusulaHomeShell(),
    );
  }
}

class PusulaHomeShell extends ConsumerStatefulWidget {
  const PusulaHomeShell({super.key});

  @override
  ConsumerState<PusulaHomeShell> createState() => _PusulaHomeShellState();
}

class _PusulaHomeShellState extends ConsumerState<PusulaHomeShell> {
  int _selectedIndex = 0;
  final TextEditingController _searchController = TextEditingController();

  static const List<Widget> _pages = [
    OzetScreen(),
    OneriScreen(),
    SinyalScreen(),
    AyarScreen(),
  ];

  static const List<String> _tabLabels = [
    'Özet',
    'Öneri',
    'Sinyal',
    'Ayar',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    ref.read(searchQueryProvider.notifier).state = value;
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(searchQueryProvider.notifier).state = '';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pusulaControllerProvider);
    final controller = ref.read(pusulaControllerProvider.notifier);
    final palette = PusulaPalette.of(context);
    final query = ref.watch(searchQueryProvider);
    final width = MediaQuery.sizeOf(context).width;
    final wide = isWideLayout(context);
    final extendedRail = width >= 1180;
    final simplifyAnim =
        state.settings.shouldSimplifyAnimations || (MediaQuery.maybeDisableAnimationsOf(context) ?? false);

    return Scaffold(
      body: SafeArea(
        bottom: !wide,
        child: Stack(
          children: [
            if (wide)
              Row(
                children: [
                  NavigationRail(
                    selectedIndex: _selectedIndex,
                    extended: extendedRail,
                    labelType: extendedRail ? NavigationRailLabelType.none : NavigationRailLabelType.all,
                    onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
                    leading: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: _PhantomAvatarBadge(isLoading: state.isLoading),
                    ),
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.donut_large_outlined),
                        selectedIcon: Icon(Icons.donut_large),
                        label: Text('Özet'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.fact_check_outlined),
                        selectedIcon: Icon(Icons.fact_check),
                        label: Text('Öneri'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.radar_outlined),
                        selectedIcon: Icon(Icons.radar),
                        label: Text('Sinyal'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.tune_outlined),
                        selectedIcon: Icon(Icons.tune),
                        label: Text('Ayar'),
                      ),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: Column(
                      children: [
                        _PhantomWideHeader(
                          title: 'Pusula · ${_tabLabels[_selectedIndex]}',
                          searchController: _searchController,
                          query: query,
                          isLoading: state.isLoading,
                          statusMessage: state.statusMessage,
                          onSearchChanged: _onSearchChanged,
                          onClearSearch: _clearSearch,
                          onRefresh: () => controller.refreshLiveMarketData(forceRefresh: true),
                        ),
                        if (state.isLoading)
                          LinearProgressIndicator(
                            value: state.scanProgress,
                            minHeight: 2,
                            color: palette.accent,
                            backgroundColor: palette.border,
                          ),
                        Expanded(child: _pages[_selectedIndex]),
                      ],
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  _PhantomMobileTopBar(
                    tabs: _tabLabels,
                    selectedIndex: _selectedIndex,
                    isLoading: state.isLoading,
                    onSelect: (idx) => setState(() => _selectedIndex = idx),
                  ),
                  if (state.isLoading)
                    LinearProgressIndicator(
                      value: state.scanProgress,
                      minHeight: 2,
                      color: palette.accent,
                      backgroundColor: palette.border,
                    ),
                  Expanded(child: _pages[_selectedIndex]),
                ],
              ),

            // Phantom tarzı üst yüzen durum kapsülü ("Portföy güncel" / "Tarama tamamlandı")
            // Üst sekme kapsüllerini örtmemek için sekme şeridinin hemen altında süzülür.
            Positioned(
              top: wide ? 68 : 58,
              left: 16,
              right: 16,
              child: Align(
                alignment: Alignment.topCenter,
                child: _PhantomToastCapsule(
                  key: const Key('phantom_toast_capsule'),
                  visible: state.toastVisible && (state.toastMessage?.isNotEmpty ?? false),
                  message: state.toastMessage ?? '',
                  positive: state.toastPositive,
                  isLoading: state.isLoading,
                  simplifyAnimations: simplifyAnim,
                  onDismiss: controller.dismissToast,
                ),
              ),
            ),

            // Mobilde altta yüzen arama + lavanta hızlı tarama düğmesi
            if (!wide)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _PhantomBottomSearchBar(
                  searchController: _searchController,
                  query: query,
                  isLoading: state.isLoading,
                  onSearchChanged: _onSearchChanged,
                  onClearSearch: _clearSearch,
                  onRefresh: () => controller.refreshLiveMarketData(forceRefresh: true),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PhantomAvatarBadge extends StatelessWidget {
  const _PhantomAvatarBadge({required this.isLoading});
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final p = PusulaPalette.of(context);
    return Container(
      width: 38,
      height: 38,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF26D07C), Color(0xFFAB9FF2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(Icons.explore_rounded, color: Color(0xFF08080A), size: 22),
          if (isLoading)
            const SizedBox(
              width: 38,
              height: 38,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFAB9FF2),
              ),
            )
          else
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.profit,
                  border: Border.all(color: p.background, width: 1.8),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PhantomMobileTopBar extends StatelessWidget {
  const _PhantomMobileTopBar({
    required this.tabs,
    required this.selectedIndex,
    required this.isLoading,
    required this.onSelect,
  });

  final List<String> tabs;
  final int selectedIndex;
  final bool isLoading;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = PusulaPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          _PhantomAvatarBadge(isLoading: isLoading),
          const SizedBox(width: 10),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  for (var i = 0; i < tabs.length; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    _PillTabItem(
                      label: tabs[i],
                      selected: selectedIndex == i,
                      palette: p,
                      onTap: () => onSelect(i),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PillTabItem extends StatelessWidget {
  const _PillTabItem({
    required this.label,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final PusulaPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? palette.accent : palette.card;
    final fg = selected ? (palette.isDark ? const Color(0xFF08080A) : Colors.white) : palette.textDim;

    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: selected ? null : Border.all(color: palette.border.withValues(alpha: 0.65)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: fg,
              letterSpacing: -0.1,
            ),
          ),
        ),
      ),
    );
  }
}

class _PhantomWideHeader extends StatelessWidget {
  const _PhantomWideHeader({
    required this.title,
    required this.searchController,
    required this.query,
    required this.isLoading,
    required this.statusMessage,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onRefresh,
  });

  final String title;
  final TextEditingController searchController;
  final String query;
  final bool isLoading;
  final String? statusMessage;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final p = PusulaPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 14, 28, 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4),
          ),
          const SizedBox(width: 16),
          if (statusMessage != null)
            Expanded(
              child: Text(
                statusMessage!,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: p.textDim),
              ),
            )
          else
            const Spacer(),
          const SizedBox(width: 16),
          SizedBox(
            width: 260,
            child: _SearchPillField(
              controller: searchController,
              query: query,
              onChanged: onSearchChanged,
              onClear: onClearSearch,
            ),
          ),
          const SizedBox(width: 10),
          _LavenderRefreshCircle(
            isLoading: isLoading,
            onPressed: onRefresh,
          ),
        ],
      ),
    );
  }
}

class _PhantomToastCapsule extends StatelessWidget {
  const _PhantomToastCapsule({
    super.key,
    required this.visible,
    required this.message,
    required this.positive,
    required this.isLoading,
    required this.simplifyAnimations,
    required this.onDismiss,
  });

  final bool visible;
  final String message;
  final bool positive;
  final bool isLoading;
  final bool simplifyAnimations;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final p = PusulaPalette.of(context);
    final duration = simplifyAnimations ? Duration.zero : const Duration(milliseconds: 280);
    final badgeColor = isLoading ? p.accent : (positive ? p.profit : p.loss);

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, -1.5),
        duration: duration,
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: visible ? 1.0 : 0.0,
          duration: duration,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onDismiss,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: p.isDark ? const Color(0xFF1E1E26) : p.card,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: p.border.withValues(alpha: 0.85)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: p.isDark ? 0.55 : 0.14),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: badgeColor),
                      child: Icon(
                        isLoading ? Icons.radar_rounded : (positive ? Icons.check_rounded : Icons.error_outline),
                        size: 15,
                        color: const Color(0xFF08080A),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Flexible(
                      child: Text(
                        message,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: p.text,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhantomBottomSearchBar extends StatelessWidget {
  const _PhantomBottomSearchBar({
    required this.searchController,
    required this.query,
    required this.isLoading,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onRefresh,
  });

  final TextEditingController searchController;
  final String query;
  final bool isLoading;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final p = PusulaPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            p.background.withValues(alpha: 0.0),
            p.background.withValues(alpha: 0.88),
            p.background,
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: _SearchPillField(
              controller: searchController,
              query: query,
              onChanged: onSearchChanged,
              onClear: onClearSearch,
            ),
          ),
          const SizedBox(width: 10),
          _LavenderRefreshCircle(
            isLoading: isLoading,
            onPressed: onRefresh,
          ),
        ],
      ),
    );
  }
}

class _SearchPillField extends StatelessWidget {
  const _SearchPillField({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final p = PusulaPalette.of(context);
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: p.isDark ? const Color(0xFF16161E).withValues(alpha: 0.94) : p.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: p.border.withValues(alpha: 0.85)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 20, color: p.textDim),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              key: const Key('input_global_search'),
              controller: controller,
              onChanged: onChanged,
              style: TextStyle(fontSize: 14, color: p.text, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'BIST veya Kripto ara…',
                hintStyle: TextStyle(fontSize: 14, color: p.textDim, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          if (query.isNotEmpty)
            GestureDetector(
              onTap: onClear,
              child: Icon(Icons.close_rounded, size: 18, color: p.textDim),
            ),
        ],
      ),
    );
  }
}

class _LavenderRefreshCircle extends StatelessWidget {
  const _LavenderRefreshCircle({
    required this.isLoading,
    required this.onPressed,
  });

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final p = PusulaPalette.of(context);
    final fg = p.isDark ? const Color(0xFF08080A) : Colors.white;
    return Tooltip(
      message: 'Canlı BIST ve Kripto Fiyatlarını Yenile',
      child: InkWell(
        key: const Key('btn_refresh_live_data'),
        onTap: isLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: p.accent,
            boxShadow: [
              BoxShadow(
                color: p.accent.withValues(alpha: 0.32),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: fg),
                )
              : Icon(Icons.radar_rounded, size: 24, color: fg),
        ),
      ),
    );
  }
}
