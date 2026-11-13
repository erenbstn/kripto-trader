import 'dart:math' as math;

import '../analysis/regime.dart';
import '../analysis/setups.dart';
import '../journal/signal_journal.dart';
import '../util/clock.dart';

/// Aşırı uyum (overfitting) yasağı için zorunlu en az kapanmış sinyal sayısı (Kısıt 9, DEVIR.md 6.3).
const int kMinClosedSignalsForTuning = 30;

/// Wilson %95 güven aralığı hesaplayıcısı.
class WilsonInterval {
  const WilsonInterval({required this.low, required this.high});

  final double low;
  final double high;

  /// [wins] kazanan ve [total] toplam kapanmış sinyal için %95 Wilson güven aralığını ([0.0, 1.0]) döndürür.
  static WilsonInterval compute95({required int wins, required int total}) {
    if (total <= 0) {
      return const WilsonInterval(low: 0.0, high: 1.0);
    }
    const z = 1.959963984540054;
    const z2 = z * z;
    final n = total.toDouble();
    final p = (wins / n).clamp(0.0, 1.0);

    final denom = 1.0 + z2 / n;
    final center = (p + z2 / (2.0 * n)) / denom;
    final halfWidth = (z * math.sqrt((p * (1.0 - p)) / n + z2 / (4.0 * n * n))) / denom;

    return WilsonInterval(
      low: (center - halfWidth).clamp(0.0, 1.0),
      high: (center + halfWidth).clamp(0.0, 1.0),
    );
  }
}

/// Bir stratejinin (ve isteğe bağlı olarak rejimin) kapanmış sinyallerden hesaplanan istatistiği.
class StrategyPerformanceStats {
  const StrategyPerformanceStats({
    required this.strategy,
    this.regime,
    required this.closedCount,
    required this.winCount,
    required this.winRate,
    required this.avgR,
    required this.wilson95Low,
    required this.wilson95High,
    required this.observationNoteTr,
  });

  final SetupType strategy;
  final MarketRegime? regime;
  final int closedCount;
  final int winCount;
  final double winRate;
  final double avgR;
  final double wilson95Low;
  final double wilson95High;
  final String observationNoteTr;

  /// Kısıt 9: En az 30 kapanmış sinyal birikmeden parametre değiştirilemez.
  bool get isEligibleForTuning => closedCount >= kMinClosedSignalsForTuning;
}

/// Tek bir kurulum stratejisinin sürümlenebilir parametreleri.
class StrategyParameters {
  const StrategyParameters({
    this.minConfidenceScore = 55,
    this.minVolumeRatio = 1.15,
    this.atrStopMultiplier = 1.5,
    this.enabledInSideways = true,
  });

  final int minConfidenceScore;
  final double minVolumeRatio;
  final double atrStopMultiplier;
  final bool enabledInSideways;

  StrategyParameters copyWith({
    int? minConfidenceScore,
    double? minVolumeRatio,
    double? atrStopMultiplier,
    bool? enabledInSideways,
  }) =>
      StrategyParameters(
        minConfidenceScore: minConfidenceScore ?? this.minConfidenceScore,
        minVolumeRatio: minVolumeRatio ?? this.minVolumeRatio,
        atrStopMultiplier: atrStopMultiplier ?? this.atrStopMultiplier,
        enabledInSideways: enabledInSideways ?? this.enabledInSideways,
      );

  @override
  bool operator ==(Object other) =>
      other is StrategyParameters &&
      other.minConfidenceScore == minConfidenceScore &&
      (other.minVolumeRatio - minVolumeRatio).abs() < 1e-9 &&
      (other.atrStopMultiplier - atrStopMultiplier).abs() < 1e-9 &&
      other.enabledInSideways == enabledInSideways;

  @override
  int get hashCode => Object.hash(minConfidenceScore, minVolumeRatio, atrStopMultiplier, enabledInSideways);

  Map<String, Object?> toJson() => {
        'minConfidenceScore': minConfidenceScore,
        'minVolumeRatio': minVolumeRatio,
        'atrStopMultiplier': atrStopMultiplier,
        'enabledInSideways': enabledInSideways,
      };

  static StrategyParameters fromJson(Map<String, Object?> j) => StrategyParameters(
        minConfidenceScore: (j['minConfidenceScore'] as num?)?.toInt() ?? 55,
        minVolumeRatio: (j['minVolumeRatio'] as num?)?.toDouble() ?? 1.15,
        atrStopMultiplier: (j['atrStopMultiplier'] as num?)?.toDouble() ?? 1.5,
        enabledInSideways: (j['enabledInSideways'] as bool?) ?? true,
      );
}

/// Sürümlü ve geri alınabilir strateji yapılandırma kaydı (DEVIR.md Faz 6.2).
class StrategyVersionRecord {
  const StrategyVersionRecord({
    required this.version,
    this.parentVersion,
    required this.createdAt,
    required this.rationale,
    required this.byStrategy,
  });

  final String version;
  final String? parentVersion;
  final DateTime createdAt;
  final String rationale;
  final Map<SetupType, StrategyParameters> byStrategy;

  factory StrategyVersionRecord.baseline({DateTime? createdAt}) => StrategyVersionRecord(
        version: kStrategyVersion,
        parentVersion: null,
        createdAt: (createdAt ?? DateTime.utc(2026, 4, 1)).toUtc(),
        rationale: 'Strateji $kStrategyVersion taban parametreleri (K7 + K9 huni iyileştirmeleri).',
        byStrategy: {
          for (final s in SetupType.values) s: const StrategyParameters(),
        },
      );

  StrategyParameters paramsFor(SetupType setup) => byStrategy[setup] ?? const StrategyParameters();

  Map<String, Object?> toJson() => {
        'version': version,
        'parentVersion': parentVersion,
        'createdAt': createdAt.toUtc().millisecondsSinceEpoch,
        'rationale': rationale,
        'byStrategy': {
          for (final e in byStrategy.entries) e.key.code: e.value.toJson(),
        },
      };

  static StrategyVersionRecord fromJson(Map<String, Object?> j) {
    final rawMap = (j['byStrategy'] as Map?)?.cast<String, Object?>() ?? const {};
    return StrategyVersionRecord(
      version: j['version'] as String,
      parentVersion: j['parentVersion'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch((j['createdAt'] as num).toInt(), isUtc: true),
      rationale: j['rationale'] as String,
      byStrategy: {
        for (final s in SetupType.values)
          s: rawMap[s.code] is Map
              ? StrategyParameters.fromJson((rawMap[s.code] as Map).cast<String, Object?>())
              : const StrategyParameters(),
      },
    );
  }
}

/// Sürümlü strateji ayarlarını saklayan ve tek dokunuşla geri alabilen depo.
abstract class StrategyVersionStore {
  Future<StrategyVersionRecord> active();
  Future<List<StrategyVersionRecord>> history();
  Future<void> applyNewVersion(StrategyVersionRecord nextVersion);
  Future<StrategyVersionRecord?> rollbackToPrevious();
  Future<StrategyVersionRecord?> rollbackToVersion(String version);
}

class MemoryStrategyVersionStore implements StrategyVersionStore {
  MemoryStrategyVersionStore({StrategyVersionRecord? initial}) {
    final base = initial ?? StrategyVersionRecord.baseline();
    _history.add(base);
    _activeVersion = base.version;
  }

  final List<StrategyVersionRecord> _history = [];
  late String _activeVersion;

  @override
  Future<StrategyVersionRecord> active() async =>
      _history.firstWhere((v) => v.version == _activeVersion, orElse: () => _history.last);

  @override
  Future<List<StrategyVersionRecord>> history() async => List.unmodifiable(_history.reversed);

  @override
  Future<void> applyNewVersion(StrategyVersionRecord nextVersion) async {
    _history.removeWhere((v) => v.version == nextVersion.version);
    _history.add(nextVersion);
    _activeVersion = nextVersion.version;
  }

  @override
  Future<StrategyVersionRecord?> rollbackToPrevious() async {
    final current = await active();
    if (current.parentVersion != null) {
      return rollbackToVersion(current.parentVersion!);
    }
    if (_history.length >= 2) {
      final prev = _history[_history.length - 2];
      _activeVersion = prev.version;
      return prev;
    }
    return null;
  }

  @override
  Future<StrategyVersionRecord?> rollbackToVersion(String version) async {
    final idx = _history.indexWhere((v) => v.version == version);
    if (idx < 0) return null;
    _activeVersion = _history[idx].version;
    return _history[idx];
  }
}

/// Kendini geliştirme değerlendirme çıktısı.
class StrategyOptimizationProposal {
  const StrategyOptimizationProposal({
    required this.currentVersion,
    required this.statsByStrategy,
    required this.statsByRegime,
    required this.canModifyParameters,
    this.proposedVersion,
    required this.summaryReportTr,
  });

  final StrategyVersionRecord currentVersion;
  final Map<SetupType, StrategyPerformanceStats> statsByStrategy;
  final Map<(SetupType, MarketRegime), StrategyPerformanceStats> statsByRegime;

  /// En az bir stratejide >= 30 kapanmış sinyal birikti ve anlamlı parametre önerisi üretildi mi?
  final bool canModifyParameters;

  /// `canModifyParameters == false` ise her zaman `null` döner (Kısıt 9).
  final StrategyVersionRecord? proposedVersion;
  final String summaryReportTr;
}

/// Sinyal günlüğünden istatistik çıkaran ve >= 30 kapanmış sinyal kuralına uyarak
/// sürümlü strateji güncellemesi öneren motor (DEVIR.md Faz 6).
class StrategyOptimizer {
  StrategyOptimizer({
    required this.journalStore,
    required this.versionStore,
    Clock? clock,
  }) : _clock = clock ?? systemClock;

  final SignalJournalStore journalStore;
  final StrategyVersionStore versionStore;
  final Clock _clock;

  static StrategyPerformanceStats _computeStats(
    SetupType strategy,
    List<SignalRecord> closedSignals, {
    MarketRegime? regime,
  }) {
    final n = closedSignals.length;
    final wins = closedSignals.where((s) => (s.realizedR ?? 0.0) > 0).length;
    final winRate = n == 0 ? 0.0 : wins / n;
    final avgR = n == 0
        ? 0.0
        : closedSignals.fold<double>(0.0, (a, b) => a + (b.realizedR ?? 0.0)) / n;
    final wilson = WilsonInterval.compute95(wins: wins, total: n);

    final lowPct = (wilson.low * 100).toStringAsFixed(1).replaceAll('.', ',');
    final highPct = (wilson.high * 100).toStringAsFixed(1).replaceAll('.', ',');
    final wrPct = (winRate * 100).toStringAsFixed(1).replaceAll('.', ',');
    final avgRStr = avgR.toStringAsFixed(2).replaceAll('.', ',');

    final String note;
    if (n < kMinClosedSignalsForTuning) {
      note = '${strategy.label}: Yetersiz örneklem ($n/$kMinClosedSignalsForTuning kapanmış sinyal). '
          'Aşırı uyum yasağı gereği parametre değiştirilmez; yalnızca gözlem: '
          'Kazanma oranı %$wrPct (Wilson %95 GA: [%$lowPct – %$highPct]), Ort. ${avgRStr}R.';
    } else {
      note = '${strategy.label}: Yeterli örneklem ($n/$kMinClosedSignalsForTuning+ kapanmış sinyal). '
          'Kazanma oranı %$wrPct (Wilson %95 GA: [%$lowPct – %$highPct]), Ort. ${avgRStr}R.';
    }

    return StrategyPerformanceStats(
      strategy: strategy,
      regime: regime,
      closedCount: n,
      winCount: wins,
      winRate: winRate,
      avgR: avgR,
      wilson95Low: wilson.low,
      wilson95High: wilson.high,
      observationNoteTr: note,
    );
  }

  /// Sinyal günlüğünü analiz eder; 30'un altında kapanmış sinyali olan stratejilere DOKUNMAZ.
  /// Yalnızca >= 30 kapanmış sinyali olan stratejilerde istatistiğe dayalı yeni sürüm önerir.
  Future<StrategyOptimizationProposal> evaluate({bool autoApplyIfEligible = false}) async {
    final current = await versionStore.active();
    final all = await journalStore.allSignals();
    final closed = [for (final s in all) if (s.isClosed && s.realizedR != null) s];

    final statsByStrategy = <SetupType, StrategyPerformanceStats>{};
    final statsByRegime = <(SetupType, MarketRegime), StrategyPerformanceStats>{};

    final nextMap = Map<SetupType, StrategyParameters>.from(current.byStrategy);
    final changeReasons = <String>[];

    for (final setup in SetupType.values) {
      final list = [for (final s in closed) if (s.strategy == setup) s];
      final st = _computeStats(setup, list);
      statsByStrategy[setup] = st;

      for (final reg in MarketRegime.values) {
        final regList = [for (final s in list) if (s.regime == reg) s];
        if (regList.isNotEmpty) {
          statsByRegime[(setup, reg)] = _computeStats(setup, regList, regime: reg);
        }
      }

      // KISIT 9: 30 kapanmış sinyalin altında hiçbir parametre değiştirilemez!
      if (!st.isEligibleForTuning) {
        continue;
      }

      final curParams = current.paramsFor(setup);
      // 1) Eğer >= 30 kapanmış sinyalde ort. R negatifse veya Wilson üst sınırı < 0.48 ise:
      //    Güven skoru eşiğini +5 artır, hacim çarpanını +0.10 sıkılaştır.
      if (st.avgR < 0.0 || st.wilson95High < 0.48) {
        final updated = curParams.copyWith(
          minConfidenceScore: (curParams.minConfidenceScore + 5).clamp(50, 80),
          minVolumeRatio: double.parse((curParams.minVolumeRatio + 0.10).clamp(1.0, 2.0).toStringAsFixed(2)),
        );
        if (updated != curParams) {
          nextMap[setup] = updated;
          changeReasons.add(
            '${setup.label} (${st.closedCount} sinyal, ort. ${st.avgR.toStringAsFixed(2)}R): '
            'güven eşiği ${curParams.minConfidenceScore}→${updated.minConfidenceScore}, '
            'hacim eşiği ${curParams.minVolumeRatio}→${updated.minVolumeRatio} sıkılaştırıldı.',
          );
        }
      } else if (st.avgR >= 0.45 && st.wilson95Low >= 0.50) {
        // 2) Eğer >= 30 kapanmış sinyalde hem ort. R >= +0.45R hem de Wilson %95 alt sınırı >= %50 ise:
        //    Güven skoru eşiğini -2 esnet (52 altına inmez).
        final updated = curParams.copyWith(
          minConfidenceScore: (curParams.minConfidenceScore - 2).clamp(52, 80),
        );
        if (updated != curParams) {
          nextMap[setup] = updated;
          changeReasons.add(
            '${setup.label} (${st.closedCount} sinyal, ort. +${st.avgR.toStringAsFixed(2)}R, '
            'Wilson alt sınır %${(st.wilson95Low * 100).toStringAsFixed(1)}): '
            'güven eşiği ${curParams.minConfidenceScore}→${updated.minConfidenceScore} olarak güncellendi.',
          );
        }
      }
    }

    if (changeReasons.isEmpty) {
      final eligibleCount = statsByStrategy.values.where((s) => s.isEligibleForTuning).length;
      final summary = eligibleCount == 0
          ? 'Hiçbir strateji henüz $kMinClosedSignalsForTuning kapanmış sinyal eşiğine ulaşmadı. '
              'Aşırı uyum (overfitting) yasağı gereği tüm parametreler v${current.version} sürümünde korundu.'
          : 'Değerlendirilen stratejilerde mevcut parametreler (v${current.version}) optimal sınırlar içinde; değişiklik gerekmedi.';
      return StrategyOptimizationProposal(
        currentVersion: current,
        statsByStrategy: statsByStrategy,
        statsByRegime: statsByRegime,
        canModifyParameters: false,
        proposedVersion: null,
        summaryReportTr: summary,
      );
    }

    final nextVerStr = _bumpMinorVersion(current.version);
    final proposed = StrategyVersionRecord(
      version: nextVerStr,
      parentVersion: current.version,
      createdAt: _clock().toUtc(),
      rationale: changeReasons.join(' '),
      byStrategy: nextMap,
    );

    if (autoApplyIfEligible) {
      await versionStore.applyNewVersion(proposed);
    }

    return StrategyOptimizationProposal(
      currentVersion: current,
      statsByStrategy: statsByStrategy,
      statsByRegime: statsByRegime,
      canModifyParameters: true,
      proposedVersion: proposed,
      summaryReportTr: 'Yeni strateji sürümü önerildi (v${current.version} → v$nextVerStr): ${changeReasons.join(" ")}',
    );
  }

  static String _bumpMinorVersion(String version) {
    final parts = version.split('.');
    if (parts.length != 3) return '2.2.0';
    final major = int.tryParse(parts[0]) ?? 2;
    final minor = (int.tryParse(parts[1]) ?? 0) + 1;
    return '$major.$minor.0';
  }
}

