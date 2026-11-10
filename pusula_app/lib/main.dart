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
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
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
