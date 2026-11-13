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
  final storage = await StorageBundle.open();
  final notificationGateway = FlutterLocalNotificationGateway();
  await notificationGateway.initialize();

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

  static const List<Widget> _pages = [
    OzetScreen(),
    OneriScreen(),
    SinyalScreen(),
    AyarScreen(),
  ];

  static const List<String> _titles = [
    'Pusula · Özet',
    'Pusula · Haftalık Öneri ve Geçmiş',
    'Pusula · Sinyal ve Kısa Vade',
    'Pusula · Ayarlar',
  ];

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pusulaControllerProvider);
    final controller = ref.read(pusulaControllerProvider.notifier);
    final palette = PusulaPalette.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final wide = isWideLayout(context);
    final extendedRail = width >= 1180;

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        bottom: state.isLoading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  value: state.scanProgress,
                  minHeight: 2,
                  color: palette.accent,
                  backgroundColor: palette.border,
                ),
              )
            : null,
        actions: [
          if (wide && state.statusMessage != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Text(
                    state.statusMessage!,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: palette.textDim),
                  ),
                ),
              ),
            ),
          IconButton(
            key: const Key('btn_refresh_live_data'),
            tooltip: 'Canlı BIST ve Kripto Fiyatlarını Yenile',
            onPressed: state.isLoading ? null : () => controller.refreshLiveMarketData(forceRefresh: true),
            icon: state.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
          ),
        ],
      ),
      body: wide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  extended: extendedRail,
                  labelType: extendedRail ? NavigationRailLabelType.none : NavigationRailLabelType.all,
                  onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Icon(Icons.explore_outlined, color: palette.accent, size: 26),
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
                Expanded(child: _pages[_selectedIndex]),
              ],
            )
          : _pages[_selectedIndex],
      bottomNavigationBar: wide
          ? null
          : Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 1,
                  ),
                ),
              ),
              child: NavigationBar(
                selectedIndex: _selectedIndex,
                onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.donut_large_outlined),
                    selectedIcon: Icon(Icons.donut_large),
                    label: 'Özet',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.fact_check_outlined),
                    selectedIcon: Icon(Icons.fact_check),
                    label: 'Öneri',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.radar_outlined),
                    selectedIcon: Icon(Icons.radar),
                    label: 'Sinyal',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.tune_outlined),
                    selectedIcon: Icon(Icons.tune),
                    label: 'Ayar',
                  ),
                ],
              ),
            ),
    );
  }
}
