import '../analysis/confidence_score.dart';
import '../analysis/regime.dart';
import '../analysis/setups.dart';
import '../model/candle.dart';
import '../model/market.dart';
import '../util/clock.dart';

/// Sinyal yaşam döngüsü durumları:
/// `açık → hedef1 → hedef2 | stop | süre doldu | geçersiz`
enum SignalStatus {
  open('açık', isTerminal: false),
  target1('hedef1', isTerminal: false),
  target2('hedef2', isTerminal: true),
  stop('stop', isTerminal: true),
  expired('süre doldu', isTerminal: true),
  invalidated('geçersiz', isTerminal: true);

  const SignalStatus(this.label, {required this.isTerminal});

  final String label;

  /// Sinyal nihai sonuca ulaştı mı? (`open` ve `target1` hâlâ izlenir).
  final bool isTerminal;
}

/// Kalıcı sinyal kaydı.
class SignalRecord {
  const SignalRecord({
    required this.id,
    required this.instrument,
    required this.interval,
    required this.strategy,
    required this.allSetups,
    required this.strategyVersion,
    required this.entryZoneLow,
    required this.entryZoneHigh,
    required this.entryPrice,
    required this.initialStop,
    required this.currentStop,
    required this.target1,
    required this.target2,
    required this.rewardRisk,
    required this.confidence,
    required this.rationale,
    required this.invalidationRule,
    required this.regime,
    required this.dataSource,
    required this.dataAgeMs,
    required this.dataStale,
    required this.createdAt,
    required this.expiresAt,
    required this.status,
    this.isWeeklyProposal = false,
    this.allocatedWeightPct,
    this.target1HitAt,
    this.closedAt,
    this.exitPrice,
    this.exitReason,
    this.realizedR,
    this.realizedPct,
    this.breakevenStop = false,
    this.lastProcessedBarTimeMs,
  });

  final String id;
  final Instrument instrument;
  final BarInterval interval;
  final SetupType strategy;
  final List<SetupType> allSetups;
  final String strategyVersion;
  final double entryZoneLow;
  final double entryZoneHigh;
  final double entryPrice;
  final double initialStop;
  final double currentStop;
  final double target1;
  final double target2;
  final double rewardRisk;
  final ConfidenceBreakdown confidence;
  final String rationale;
  final String invalidationRule;
  final MarketRegime regime;
  final String dataSource;
  final int dataAgeMs;
  final bool dataStale;
  final DateTime createdAt;
  final DateTime expiresAt;
  final SignalStatus status;

  /// Haftalık öneri listesinin parçası mı, yoksa kısa vadeli sinyal mi?
  final bool isWeeklyProposal;

  /// Haftalık öneride ayrılan bütçe ağırlığı (%).
  final double? allocatedWeightPct;

  final DateTime? target1HitAt;
  final DateTime? closedAt;
  final double? exitPrice;
  final String? exitReason;
  final double? realizedR;
  final double? realizedPct;
  final bool breakevenStop;
  final int? lastProcessedBarTimeMs;

  bool get isActive => !status.isTerminal;
  bool get isClosed => status.isTerminal;

  double get initialRiskPerUnit => entryPrice - initialStop;

  Duration get dataAge => Duration(milliseconds: dataAgeMs);

  SignalRecord copyWith({
    double? currentStop,
    SignalStatus? status,
    bool? isWeeklyProposal,
    DateTime? target1HitAt,
    DateTime? closedAt,
    double? exitPrice,
    String? exitReason,
    double? realizedR,
    double? realizedPct,
    bool? breakevenStop,
    int? lastProcessedBarTimeMs,
    double? allocatedWeightPct,
  }) =>
      SignalRecord(
        id: id,
        instrument: instrument,
        interval: interval,
        strategy: strategy,
        allSetups: allSetups,
        strategyVersion: strategyVersion,
        entryZoneLow: entryZoneLow,
        entryZoneHigh: entryZoneHigh,
        entryPrice: entryPrice,
        initialStop: initialStop,
        currentStop: currentStop ?? this.currentStop,
        target1: target1,
        target2: target2,
        rewardRisk: rewardRisk,
        confidence: confidence,
        rationale: rationale,
        invalidationRule: invalidationRule,
        regime: regime,
        dataSource: dataSource,
        dataAgeMs: dataAgeMs,
        dataStale: dataStale,
        createdAt: createdAt,
        expiresAt: expiresAt,
        status: status ?? this.status,
        isWeeklyProposal: isWeeklyProposal ?? this.isWeeklyProposal,
        allocatedWeightPct: allocatedWeightPct ?? this.allocatedWeightPct,
        target1HitAt: target1HitAt ?? this.target1HitAt,
        closedAt: closedAt ?? this.closedAt,
        exitPrice: exitPrice ?? this.exitPrice,
        exitReason: exitReason ?? this.exitReason,
        realizedR: realizedR ?? this.realizedR,
        realizedPct: realizedPct ?? this.realizedPct,
        breakevenStop: breakevenStop ?? this.breakevenStop,
        lastProcessedBarTimeMs: lastProcessedBarTimeMs ?? this.lastProcessedBarTimeMs,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'instrument': instrument.id,
        'interval': interval.code,
        'strategy': strategy.code,
        'allSetups': [for (final s in allSetups) s.code],
        'strategyVersion': strategyVersion,
        'entryZoneLow': entryZoneLow,
        'entryZoneHigh': entryZoneHigh,
        'entryPrice': entryPrice,
        'initialStop': initialStop,
        'currentStop': currentStop,
        'target1': target1,
        'target2': target2,
        'rewardRisk': rewardRisk,
        'confidence': confidence.toJson(),
        'rationale': rationale,
        'invalidationRule': invalidationRule,
        'regime': regime.name,
        'dataSource': dataSource,
        'dataAgeMs': dataAgeMs,
        'dataStale': dataStale,
        'createdAt': createdAt.toUtc().millisecondsSinceEpoch,
        'expiresAt': expiresAt.toUtc().millisecondsSinceEpoch,
        'status': status.name,
        'isWeeklyProposal': isWeeklyProposal,
        'allocatedWeightPct': allocatedWeightPct,
        'target1HitAt': target1HitAt?.toUtc().millisecondsSinceEpoch,
        'closedAt': closedAt?.toUtc().millisecondsSinceEpoch,
        'exitPrice': exitPrice,
        'exitReason': exitReason,
        'realizedR': realizedR,
        'realizedPct': realizedPct,
        'breakevenStop': breakevenStop,
        'lastProcessedBarTimeMs': lastProcessedBarTimeMs,
      };

  static SignalRecord fromJson(Map<String, Object?> j) => SignalRecord(
        id: j['id'] as String,
        instrument: Instrument.parseId(j['instrument'] as String),
        interval: BarInterval.parse(j['interval'] as String),
        strategy: SetupType.fromCode(j['strategy'] as String),
        allSetups: [for (final c in (j['allSetups'] as List? ?? const [])) SetupType.fromCode('$c')],
        strategyVersion: (j['strategyVersion'] as String?) ?? '2.0.0',
        entryZoneLow: (j['entryZoneLow'] as num).toDouble(),
        entryZoneHigh: (j['entryZoneHigh'] as num).toDouble(),
        entryPrice: (j['entryPrice'] as num).toDouble(),
        initialStop: (j['initialStop'] as num).toDouble(),
        currentStop: (j['currentStop'] as num).toDouble(),
        target1: (j['target1'] as num).toDouble(),
        target2: (j['target2'] as num).toDouble(),
        rewardRisk: (j['rewardRisk'] as num).toDouble(),
        confidence: ConfidenceBreakdown.fromJson((j['confidence'] as Map).cast<String, Object?>()),
        rationale: j['rationale'] as String,
        invalidationRule: (j['invalidationRule'] as String?) ?? '',
        regime: MarketRegime.values.byName(j['regime'] as String),
        dataSource: j['dataSource'] as String,
        dataAgeMs: (j['dataAgeMs'] as num).toInt(),
        dataStale: (j['dataStale'] as bool?) ?? false,
        createdAt: DateTime.fromMillisecondsSinceEpoch((j['createdAt'] as num).toInt(), isUtc: true),
        expiresAt: DateTime.fromMillisecondsSinceEpoch((j['expiresAt'] as num).toInt(), isUtc: true),
        status: SignalStatus.values.byName(j['status'] as String),
        isWeeklyProposal: (j['isWeeklyProposal'] as bool?) ?? false,
        allocatedWeightPct: (j['allocatedWeightPct'] as num?)?.toDouble(),
        target1HitAt: j['target1HitAt'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch((j['target1HitAt'] as num).toInt(), isUtc: true),
        closedAt: j['closedAt'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch((j['closedAt'] as num).toInt(), isUtc: true),
        exitPrice: (j['exitPrice'] as num?)?.toDouble(),
        exitReason: j['exitReason'] as String?,
        realizedR: (j['realizedR'] as num?)?.toDouble(),
        realizedPct: (j['realizedPct'] as num?)?.toDouble(),
        breakevenStop: (j['breakevenStop'] as bool?) ?? false,
        lastProcessedBarTimeMs: (j['lastProcessedBarTimeMs'] as num?)?.toInt(),
      );
}

/// Sinyal günlüğü kalıcı depo soyutlaması.
/// Uygulama SQLite sürümünü sağlar; çekirdek ve birim testler [MemorySignalJournalStore] kullanır.
abstract class SignalJournalStore {
  Future<void> save(SignalRecord record);
  Future<SignalRecord?> byId(String id);
  Future<List<SignalRecord>> activeSignals({Market? market});
  Future<List<SignalRecord>> allSignals({
    Market? market,
    DateTime? since,
    DateTime? until,
    bool? weeklyProposalsOnly,
  });
  Future<void> clear();
}

/// Bellek içi sinyal günlüğü deposu.
class MemorySignalJournalStore implements SignalJournalStore {
  final Map<String, SignalRecord> _records = {};

  @override
  Future<void> save(SignalRecord record) async {
    _records[record.id] = record;
  }

  @override
  Future<SignalRecord?> byId(String id) async => _records[id];

  @override
  Future<List<SignalRecord>> activeSignals({Market? market}) async {
    final out = [
      for (final r in _records.values)
        if (r.isActive && (market == null || r.instrument.market == market)) r,
    ];
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  @override
  Future<List<SignalRecord>> allSignals({
    Market? market,
    DateTime? since,
    DateTime? until,
    bool? weeklyProposalsOnly,
  }) async {
    final out = <SignalRecord>[];
    for (final r in _records.values) {
      if (market != null && r.instrument.market != market) continue;
      if (since != null && r.createdAt.isBefore(since.toUtc())) continue;
      if (until != null && r.createdAt.isAfter(until.toUtc())) continue;
      if (weeklyProposalsOnly != null && r.isWeeklyProposal != weeklyProposalsOnly) continue;
      out.add(r);
    }
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  @override
  Future<void> clear() async => _records.clear();

  int get length => _records.length;
}

/// Sinyal geçiş olayı (bildirim üretimi için).
class SignalTransitionEvent {
  const SignalTransitionEvent({
    required this.previousStatus,
    required this.newStatus,
    required this.signal,
    required this.message,
  });

  final SignalStatus previousStatus;
  final SignalStatus newStatus;
  final SignalRecord signal;
  final String message;
}

/// Açık sinyallerin yaşam döngüsünü kapanmış mumlarla izleyen sınıf.
///
/// Kurallar:
/// - Sonuç izleme mumun `high` ve `low` değerleriyle yapılır.
/// - Aynı mumda hem `stop` hem `hedef` görülürse muhafazakâr olarak **stop** sayılır.
/// - `target1` (1R) görüldüğünde durum `hedef1` olur ve `currentStop` giriş fiyatına (başabaş) çekilir.
/// - Süre dolduğunda (`now >= expiresAt`) sinyal `expired` (`süre doldu`) olarak son kapanıştan kapanır.
class SignalOutcomeTracker {
  SignalOutcomeTracker({
    required this.store,
    Clock? clock,
  }) : _clock = clock ?? systemClock;

  final SignalJournalStore store;
  final Clock _clock;

  /// Tek bir açık sinyali verilen kapanmış mumlarla günceller.
  Future<({SignalRecord updated, List<SignalTransitionEvent> events})> evaluateSignal(
    SignalRecord signal,
    List<Candle> closedBars, {
    DateTime? nowOverride,
  }) async {
    if (signal.isClosed) {
      return (updated: signal, events: const <SignalTransitionEvent>[]);
    }

    final now = (nowOverride ?? _clock()).toUtc();
    var cur = signal;
    final events = <SignalTransitionEvent>[];
    final risk = cur.initialRiskPerUnit > 0 ? cur.initialRiskPerUnit : cur.entryPrice * 0.01;

    final startMs = cur.lastProcessedBarTimeMs ?? cur.createdAt.millisecondsSinceEpoch;
    final newBars = [
      for (final b in closedBars)
        if (b.openTimeMs > startMs) b,
    ]..sort((a, b) => a.openTimeMs.compareTo(b.openTimeMs));

    for (final bar in newBars) {
      if (cur.isClosed) break;
      final barCloseTime = DateTime.fromMillisecondsSinceEpoch(
        bar.openTimeMs + cur.interval.ms,
        isUtc: true,
      );

      // 1. ÖNCE STOP KONTROLÜ (muhafazakâr kural: aynı mumda hem stop hem hedef varsa stop kazanır!)
      if (bar.low <= cur.currentStop) {
        final prevStatus = cur.status;
        final wasTarget1 = prevStatus == SignalStatus.target1;
        final exitP = cur.currentStop;
        // Eğer hedef1'e ulaşıldıktan sonra başabaş stop olduysa:
        // Pozisyonun ilk yarısı +1R'de realize edilmiş, kalan yarısı 0R'de kapanmış kabul edilir (+0.5R).
        final double rMult;
        final double pct;
        final String reason;
        if (wasTarget1) {
          final t1Pct = ((cur.target1 - cur.entryPrice) / cur.entryPrice) * 100.0;
          rMult = double.parse((((cur.target1 - cur.entryPrice) / risk) * 0.5).toStringAsFixed(2));
          pct = double.parse((t1Pct * 0.5).toStringAsFixed(2));
          reason = 'Hedef 1 sonrası başabaş stop (${exitP.toStringAsFixed(2)})';
        } else {
          rMult = double.parse(((exitP - cur.entryPrice) / risk).toStringAsFixed(2));
          pct = double.parse((((exitP - cur.entryPrice) / cur.entryPrice) * 100.0).toStringAsFixed(2));
          reason = 'Stop seviyesine değdi (${exitP.toStringAsFixed(2)})';
        }

        cur = cur.copyWith(
          status: SignalStatus.stop,
          closedAt: barCloseTime,
          exitPrice: exitP,
          exitReason: reason,
          realizedR: rMult,
          realizedPct: pct,
          breakevenStop: wasTarget1,
          lastProcessedBarTimeMs: bar.openTimeMs,
        );
        events.add(SignalTransitionEvent(
          previousStatus: prevStatus,
          newStatus: SignalStatus.stop,
          signal: cur,
          message: '${cur.instrument.short} stop oldu · '
              '${pct >= 0 ? '+' : ''}%${pct.toStringAsFixed(2)} · '
              '${rMult >= 0 ? '+' : ''}${rMult.toStringAsFixed(2)}R',
        ));
        break;
      }

      // 2. ANA HEDEF (target2) KONTROLÜ
      if (bar.high >= cur.target2) {
        final prevStatus = cur.status;
        final exitP = cur.target2;
        final rMult = double.parse(((exitP - cur.entryPrice) / risk).toStringAsFixed(2));
        final pct = double.parse((((exitP - cur.entryPrice) / cur.entryPrice) * 100.0).toStringAsFixed(2));

        cur = cur.copyWith(
          status: SignalStatus.target2,
          target1HitAt: cur.target1HitAt ?? barCloseTime,
          closedAt: barCloseTime,
          exitPrice: exitP,
          exitReason: 'Ana hedefe (Hedef 2) ulaştı (${exitP.toStringAsFixed(2)})',
          realizedR: rMult,
          realizedPct: pct,
          lastProcessedBarTimeMs: bar.openTimeMs,
        );
        events.add(SignalTransitionEvent(
          previousStatus: prevStatus,
          newStatus: SignalStatus.target2,
          signal: cur,
          message: '${cur.instrument.short} hedefe ulaştı · +%${pct.toStringAsFixed(1)} · ${rMult.toStringAsFixed(1)}R',
        ));
        break;
      }

      // 3. KADEMELİ HEDEF 1 (target1) VE BAŞABAŞA ÇEKME KONTROLÜ
      if (cur.status == SignalStatus.open && bar.high >= cur.target1) {
        final t1Pct = ((cur.target1 - cur.entryPrice) / cur.entryPrice) * 100.0;
        cur = cur.copyWith(
          status: SignalStatus.target1,
          currentStop: cur.entryPrice,
          target1HitAt: barCloseTime,
          lastProcessedBarTimeMs: bar.openTimeMs,
        );
        events.add(SignalTransitionEvent(
          previousStatus: SignalStatus.open,
          newStatus: SignalStatus.target1,
          signal: cur,
          message: '${cur.instrument.short} 1. hedefe ulaştı (+%${t1Pct.toStringAsFixed(1)}) · '
              'Stop başabaşa (${cur.entryPrice.toStringAsFixed(2)}) çekildi',
        ));
        continue;
      }

      // 4. SÜRE SINIRI KONTROLÜ (mum kapanış anı süreyi aştıysa)
      if (!barCloseTime.isBefore(cur.expiresAt)) {
        cur = _expireSignal(cur, bar.close, barCloseTime, risk, bar.openTimeMs, events);
        break;
      }

      cur = cur.copyWith(lastProcessedBarTimeMs: bar.openTimeMs);
    }

    // Yeni mum gelmemiş olsa bile saat itibarıyla süresi dolduysa kapat
    if (cur.isActive && !now.isBefore(cur.expiresAt) && closedBars.isNotEmpty) {
      cur = _expireSignal(cur, closedBars.last.close, now, risk, closedBars.last.openTimeMs, events);
    }

    if (cur != signal) {
      await store.save(cur);
    }
    return (updated: cur, events: events);
  }

  SignalRecord _expireSignal(
    SignalRecord cur,
    double lastClose,
    DateTime closedAt,
    double risk,
    int barTimeMs,
    List<SignalTransitionEvent> events,
  ) {
    final prevStatus = cur.status;
    final rMult = double.parse(((lastClose - cur.entryPrice) / risk).toStringAsFixed(2));
    final pct = double.parse((((lastClose - cur.entryPrice) / cur.entryPrice) * 100.0).toStringAsFixed(2));
    final next = cur.copyWith(
      status: SignalStatus.expired,
      closedAt: closedAt,
      exitPrice: lastClose,
      exitReason: 'Tutma süresi doldu (${lastClose.toStringAsFixed(2)})',
      realizedR: rMult,
      realizedPct: pct,
      lastProcessedBarTimeMs: barTimeMs,
    );
    events.add(SignalTransitionEvent(
      previousStatus: prevStatus,
      newStatus: SignalStatus.expired,
      signal: next,
      message: '${next.instrument.short} süre doldu · '
          '${pct >= 0 ? '+' : ''}%${pct.toStringAsFixed(2)} · '
          '${rMult >= 0 ? '+' : ''}${rMult.toStringAsFixed(2)}R',
    ));
    return next;
  }

  /// Açık bir sinyali geçersiz kılma koşulu nedeniyle kapatır.
  Future<SignalTransitionEvent?> invalidateSignal(
    String id, {
    required double currentPrice,
    required String reason,
    DateTime? nowOverride,
  }) async {
    final cur = await store.byId(id);
    if (cur == null || cur.isClosed) return null;
    final now = (nowOverride ?? _clock()).toUtc();
    final risk = cur.initialRiskPerUnit > 0 ? cur.initialRiskPerUnit : cur.entryPrice * 0.01;
    final rMult = double.parse(((currentPrice - cur.entryPrice) / risk).toStringAsFixed(2));
    final pct = double.parse((((currentPrice - cur.entryPrice) / cur.entryPrice) * 100.0).toStringAsFixed(2));
    final prev = cur.status;
    final updated = cur.copyWith(
      status: SignalStatus.invalidated,
      closedAt: now,
      exitPrice: currentPrice,
      exitReason: 'Geçersiz kılındı: $reason',
      realizedR: rMult,
      realizedPct: pct,
    );
    await store.save(updated);
    return SignalTransitionEvent(
      previousStatus: prev,
      newStatus: SignalStatus.invalidated,
      signal: updated,
      message: '${updated.instrument.short} geçersiz kılındı · $reason',
    );
  }
}
