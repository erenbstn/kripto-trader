import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/background/background_scheduler.dart';
import 'src/notifications/notification_engine.dart';
import 'src/storage/app_settings.dart';
import 'src/storage/sqlite_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await StorageBundle.open();
  final notificationGateway = FlutterLocalNotificationGateway();
  await notificationGateway.initialize();
  final settings = await storage.settingsStore.load();
  final scheduler = BackgroundScheduler();
  await scheduler.syncSchedule(liveMonitorEnabled: settings.liveMonitorEnabled);

  runApp(
    ProviderScope(
      child: PusulaApp(
        initialSettings: settings,
      ),
    ),
  );
}

class PusulaApp extends StatelessWidget {
  const PusulaApp({
    super.key,
    this.initialSettings = const AppSettings(),
  });

  final AppSettings initialSettings;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pusula',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF6F4EF),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5B4BDB),
          surface: const Color(0xFFFFFFFF),
        ),
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Pusula · Kişisel Yatırım Asistanı'),
          backgroundColor: const Color(0xFFF6F4EF),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Pusula Çekirdek ve Yerel Depolama Hazır',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text(
                  'Yatırım tavsiyesi değildir · Yalnızca yerel analiz ve yerel bildirim.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
