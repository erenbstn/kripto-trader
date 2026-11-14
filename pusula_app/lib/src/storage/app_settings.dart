import 'package:pusula_core/pusula_core.dart';

/// Uygulama içi kullanıcı ayarları.
///
/// K6 Gizlilik Kuralı: Kullanıcının bütçe tutarı yalnızca cihazda yerel olarak saklanır;
/// loglara veya dış ağ isteklerine asla yazılmaz.
class AppSettings {
  const AppSettings({
    this.budgetAmount = 100000.0,
    this.riskAppetite = RiskAppetite.balanced,
    this.darkMode = true,
    this.reduceAnimations = false,
    this.batterySaverMode = false,
    this.notifySignal = true,
    this.notifyOutcome = true,
    this.notifyReport = true,
    this.notifySystem = true,
    this.quietHoursEnabled = true,
    this.quietStartHourTrt = 23,
    this.quietEndHourTrt = 8,
    this.maxDailyNotifications = 20,
    this.liveMonitorEnabled = false,
    this.activeStrategyVersion = kStrategyVersion,
    this.updateRepo = 'erenbstn/kripto-trader',
    this.autoCheckUpdates = true,
    this.favoriteSymbols = const ['THYAO', 'ASELS', 'BTCUSDT', 'SOLUSDT'],
    this.customBistSymbols = const [],
    this.scanOnlyFavorites = false,
    this.scanAllBistUniverse = false,
  });

  /// Kullanıcının referans portföy bütçesi (TL). Yalnızca ağırlık tutarı gösterimi içindir.
  final double budgetAmount;
  final RiskAppetite riskAppetite;

  /// Varsayılan açık tema ("GÜNDÜZ"); true ise koyu tema kullanılır.
  final bool darkMode;

  /// "Animasyonları azalt" erişilebilirlik tercihi.
  final bool reduceAnimations;

  /// Pil tasarrufu modu (açıksa 3D halka düz 2D çizilir ve geçişler anlık olur).
  final bool batterySaverMode;

  final bool notifySignal;
  final bool notifyOutcome;
  final bool notifyReport;
  final bool notifySystem;

  final bool quietHoursEnabled;
  final int quietStartHourTrt;
  final int quietEndHourTrt;
  final int maxDailyNotifications;

  /// Kullanıcı tarafından açılan kalıcı bildirimli "Canlı İzleme" ön plan servisi.
  final bool liveMonitorEnabled;

  final String activeStrategyVersion;

  /// GitHub Releases otomatik APK güncelleme deposu ("kullanici/depo"). Boşsa denetim yapılmaz.
  final String updateRepo;

  /// Uygulama açılışında GitHub Releases üzerinden sessiz güncelleme denetimi.
  final bool autoCheckUpdates;

  /// Kullanıcının yıldızladığı favori hisse ve kripto sembolleri.
  final List<String> favoriteSymbols;

  /// Kullanıcının BIST kataloğu dışında veya hızlı erişim için eklediği ek hisse kodları.
  final List<String> customBistSymbols;

  /// true ise piyasa taramasında yalnızca favori varlıklar taranır.
  final bool scanOnlyFavorites;

  /// true ise BIST tarafında tüm Borsa İstanbul hisse kataloğu taranır.
  final bool scanAllBistUniverse;

  /// Animasyonların sadeleştirilmesi gerekiyor mu? (Kısıt 10).
  bool get shouldSimplifyAnimations => reduceAnimations || batterySaverMode;

  bool isFavorite(String symbol) {
    final clean = symbol.trim().toUpperCase();
    if (clean.isEmpty) return false;
    return favoriteSymbols.any((s) => s.trim().toUpperCase() == clean);
  }

  AppSettings copyWith({
    double? budgetAmount,
    RiskAppetite? riskAppetite,
    bool? darkMode,
    bool? reduceAnimations,
    bool? batterySaverMode,
    bool? notifySignal,
    bool? notifyOutcome,
    bool? notifyReport,
    bool? notifySystem,
    bool? quietHoursEnabled,
    int? quietStartHourTrt,
    int? quietEndHourTrt,
    int? maxDailyNotifications,
    bool? liveMonitorEnabled,
    String? activeStrategyVersion,
    String? updateRepo,
    bool? autoCheckUpdates,
    List<String>? favoriteSymbols,
    List<String>? customBistSymbols,
    bool? scanOnlyFavorites,
    bool? scanAllBistUniverse,
  }) =>
      AppSettings(
        budgetAmount: budgetAmount ?? this.budgetAmount,
        riskAppetite: riskAppetite ?? this.riskAppetite,
        darkMode: darkMode ?? this.darkMode,
        reduceAnimations: reduceAnimations ?? this.reduceAnimations,
        batterySaverMode: batterySaverMode ?? this.batterySaverMode,
        notifySignal: notifySignal ?? this.notifySignal,
        notifyOutcome: notifyOutcome ?? this.notifyOutcome,
        notifyReport: notifyReport ?? this.notifyReport,
        notifySystem: notifySystem ?? this.notifySystem,
        quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
        quietStartHourTrt: quietStartHourTrt ?? this.quietStartHourTrt,
        quietEndHourTrt: quietEndHourTrt ?? this.quietEndHourTrt,
        maxDailyNotifications: maxDailyNotifications ?? this.maxDailyNotifications,
        liveMonitorEnabled: liveMonitorEnabled ?? this.liveMonitorEnabled,
        activeStrategyVersion: activeStrategyVersion ?? this.activeStrategyVersion,
        updateRepo: updateRepo ?? this.updateRepo,
        autoCheckUpdates: autoCheckUpdates ?? this.autoCheckUpdates,
        favoriteSymbols: favoriteSymbols ?? this.favoriteSymbols,
        customBistSymbols: customBistSymbols ?? this.customBistSymbols,
        scanOnlyFavorites: scanOnlyFavorites ?? this.scanOnlyFavorites,
        scanAllBistUniverse: scanAllBistUniverse ?? this.scanAllBistUniverse,
      );

  Map<String, Object?> toJson() => {
        'budgetAmount': budgetAmount,
        'riskAppetite': riskAppetite.name,
        'darkMode': darkMode,
        'reduceAnimations': reduceAnimations,
        'batterySaverMode': batterySaverMode,
        'notifySignal': notifySignal,
        'notifyOutcome': notifyOutcome,
        'notifyReport': notifyReport,
        'notifySystem': notifySystem,
        'quietHoursEnabled': quietHoursEnabled,
        'quietStartHourTrt': quietStartHourTrt,
        'quietEndHourTrt': quietEndHourTrt,
        'maxDailyNotifications': maxDailyNotifications,
        'liveMonitorEnabled': liveMonitorEnabled,
        'activeStrategyVersion': activeStrategyVersion,
        'updateRepo': updateRepo,
        'autoCheckUpdates': autoCheckUpdates,
        'favoriteSymbols': favoriteSymbols,
        'customBistSymbols': customBistSymbols,
        'scanOnlyFavorites': scanOnlyFavorites,
        'scanAllBistUniverse': scanAllBistUniverse,
      };

  static List<String>? _readStringList(Object? raw) {
    if (raw is! List) return null;
    return [
      for (final item in raw)
        if (item is String && item.trim().isNotEmpty) item.trim().toUpperCase(),
    ];
  }

  static AppSettings fromJson(Map<String, Object?> j) => AppSettings(
        budgetAmount: (j['budgetAmount'] as num?)?.toDouble() ?? 100000.0,
        riskAppetite: j['riskAppetite'] is String
            ? RiskAppetite.values.firstWhere(
                (e) => e.name == j['riskAppetite'],
                orElse: () => RiskAppetite.balanced,
              )
            : RiskAppetite.balanced,
        darkMode: (j['darkMode'] as bool?) ?? true,
        reduceAnimations: (j['reduceAnimations'] as bool?) ?? false,
        batterySaverMode: (j['batterySaverMode'] as bool?) ?? false,
        notifySignal: (j['notifySignal'] as bool?) ?? true,
        notifyOutcome: (j['notifyOutcome'] as bool?) ?? true,
        notifyReport: (j['notifyReport'] as bool?) ?? true,
        notifySystem: (j['notifySystem'] as bool?) ?? true,
        quietHoursEnabled: (j['quietHoursEnabled'] as bool?) ?? true,
        quietStartHourTrt: (j['quietStartHourTrt'] as num?)?.toInt() ?? 23,
        quietEndHourTrt: (j['quietEndHourTrt'] as num?)?.toInt() ?? 8,
        maxDailyNotifications: (j['maxDailyNotifications'] as num?)?.toInt() ?? 20,
        liveMonitorEnabled: (j['liveMonitorEnabled'] as bool?) ?? false,
        activeStrategyVersion: (j['activeStrategyVersion'] as String?) ?? '2.0.0',
        updateRepo: (j['updateRepo'] as String?) ?? 'erenbstn/kripto-trader',
        autoCheckUpdates: (j['autoCheckUpdates'] as bool?) ?? true,
        favoriteSymbols: _readStringList(j['favoriteSymbols']) ?? const ['THYAO', 'ASELS', 'BTCUSDT', 'SOLUSDT'],
        customBistSymbols: _readStringList(j['customBistSymbols']) ?? const [],
        scanOnlyFavorites: (j['scanOnlyFavorites'] as bool?) ?? false,
        scanAllBistUniverse: (j['scanAllBistUniverse'] as bool?) ?? false,
      );
}

/// Ayarlar deposu soyut arayüzü.
abstract class SettingsStore {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
}

class MemorySettingsStore implements SettingsStore {
  AppSettings _current = const AppSettings();

  @override
  Future<AppSettings> load() async => _current;

  @override
  Future<void> save(AppSettings settings) async {
    _current = settings;
  }
}

