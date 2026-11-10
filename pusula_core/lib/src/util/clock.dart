/// Test edilebilirlik için saat ve bekleme soyutlaması.
typedef Clock = DateTime Function();
typedef Sleeper = Future<void> Function(Duration d);

DateTime systemClock() => DateTime.now().toUtc();
Future<void> systemSleep(Duration d) => Future<void>.delayed(d);
