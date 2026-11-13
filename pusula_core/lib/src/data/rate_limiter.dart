import '../util/clock.dart';

/// Sunucu başına en az istek aralığı uygular ve 429/hata sonrası üstel geri çekilme tutar.
class RateLimiter {
  RateLimiter({
    this.minGap = const Duration(milliseconds: 350),
    this.baseCooldown = const Duration(seconds: 30),
    this.maxCooldown = const Duration(minutes: 15),
    Clock? clock,
    Sleeper? sleeper,
  })  : _clock = clock ?? systemClock,
        _sleep = sleeper ?? systemSleep;

  final Duration minGap;
  final Duration baseCooldown;
  final Duration maxCooldown;
  final Clock _clock;
  final Sleeper _sleep;

  final Map<String, DateTime> _nextAllowed = {};
  final Map<String, DateTime> _cooldownUntil = {};
  final Map<String, int> _strikes = {};

  /// Anahtar (sunucu adı) soğuma süresindeyse true.
  bool isCoolingDown(String key) {
    final until = _cooldownUntil[key];
    return until != null && _clock().isBefore(until);
  }

  DateTime? cooldownUntil(String key) => isCoolingDown(key) ? _cooldownUntil[key] : null;

  /// Bir sonraki isteğe kadar gerekiyorsa bekler ve yuvayı ayırır.
  Future<void> acquire(String key) async {
    final now = _clock();
    final next = _nextAllowed[key];
    if (next != null && now.isBefore(next)) {
      final wait = next.difference(now);
      _nextAllowed[key] = next.add(minGap);
      await _sleep(wait);
    } else {
      _nextAllowed[key] = now.add(minGap);
    }
  }

  void reportSuccess(String key) {
    _strikes.remove(key);
    _cooldownUntil.remove(key);
  }

  /// Hız sınırı veya art arda hata: soğuma süresi her seferinde iki katına çıkar.
  Duration reportThrottled(String key) {
    final n = (_strikes[key] ?? 0) + 1;
    _strikes[key] = n;
    var ms = baseCooldown.inMilliseconds * (1 << (n - 1).clamp(0, 10));
    if (ms > maxCooldown.inMilliseconds) ms = maxCooldown.inMilliseconds;
    final d = Duration(milliseconds: ms);
    _cooldownUntil[key] = _clock().add(d);
    return d;
  }
}
