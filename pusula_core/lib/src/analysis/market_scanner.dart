import '../bist/bist_universe.dart';
import '../crypto/crypto_universe.dart';
import '../data/market_data_service.dart';
import '../journal/signal_journal.dart';
import '../model/candle.dart';
import '../model/market.dart';
import '../util/clock.dart';
import 'multi_timeframe.dart';
import 'regime.dart';
import 'setups.dart';
import 'signal_engine.dart';

/// Bir piyasada taranacak tek zaman dilimi.
class ScanIntervalPlan {
  const ScanIntervalPlan(this.interval, {required this.weekly});

  final BarInterval interval;

  /// Bu dilimden çıkan sinyal haftalık öneri mi (bütçe ağırlığı alır), kısa vade sinyali mi?
  final bool weekly;
}

/// Bir piyasanın tarama planı: evren, rejim referansı, dilimler ve eşzamanlı sinyal sınırı.
class MarketScanPlan {
  const MarketScanPlan({
    required this.market,
    required this.instruments,
    required this.benchmark,
    required this.benchmarkInterval,
    required this.intervals,
    this.maxOpenSignals = 4,
    this.ownRegimeSymbols = const {},
  });

  /// Kripto: sabit 10 sembol (CryptoUniverse). 1 saat = kısa vade, 4 saat = haftalık salınım.
  ///
  /// Kripto varlıkları birbiriyle yüksek bağıntılıdır; aynı anda 4'ten fazla açık sinyal
  /// tek bir BTC hareketine aşırı maruz kalmak demektir. Altın/gümüş vekilleri (PAXG, XAG)
  /// BTC rejimiyle değil kendi trendleriyle değerlendirilir.
  factory MarketScanPlan.crypto() => const MarketScanPlan(
        market: Market.crypto,
        instruments: CryptoUniverse.instruments,
        benchmark: CryptoUniverse.benchmark,
        benchmarkInterval: BarInterval.h4,
        intervals: [
          ScanIntervalPlan(BarInterval.h1, weekly: false),
          ScanIntervalPlan(BarInterval.h4, weekly: true),
        ],
        maxOpenSignals: 4,
        ownRegimeSymbols: CryptoUniverse.commodityProxies,
      );

  /// BIST: 1 saat = kısa vade (1–3 gün), günlük = haftalık salınım önerisi. 5 dk scalp yok.
  factory MarketScanPlan.bist(List<Instrument> instruments) => MarketScanPlan(
        market: Market.bist,
        instruments: instruments,
        benchmark: BistUniverse.benchmark,
        benchmarkInterval: BarInterval.d1,
        intervals: const [
          ScanIntervalPlan(BarInterval.h1, weekly: false),
          ScanIntervalPlan(BarInterval.d1, weekly: true),
        ],
        maxOpenSignals: 5,
      );

  final Market market;
  final List<Instrument> instruments;
  final Instrument benchmark;
  final BarInterval benchmarkInterval;
  final List<ScanIntervalPlan> intervals;

  /// Bu piyasada aynı anda izlenebilecek en fazla açık sinyal.
  final int maxOpenSignals;

  /// Rejimi referans endeks yerine kendi üst dilim serisinden okunan semboller.
  final Set<String> ownRegimeSymbols;
}

/// Taramada değerlendirilen tek aday (onaylanan veya elenen) — ekranda "neden?" sorusunu cevaplar.
class ScanCandidate {
  const ScanCandidate({
    required this.instrument,
    required this.interval,
    required this.weekly,
    required this.approved,
    required this.stage,
    required this.reason,
    this.setups = const [],
    this.confidenceTotal,
  });

  final Instrument instrument;
  final BarInterval interval;
  final bool weekly;
  final bool approved;
  final String stage;
  final String reason;
  final List<SetupType> setups;
  final int? confidenceTotal;

  String get stageLabel => FunnelStage.label(stage);

  /// Teknik bir kurulum bulundu mu (sonradan elenmiş olsa bile)?
  bool get hadSetup => setups.isNotEmpty;
}

/// Tek bir tarama turunun dürüst özeti.
class ScanOutcome {
  const ScanOutcome({
    required this.startedAt,
    required this.finishedAt,
    required this.candidates,
    required this.newSignals,
    required this.transitions,
    required this.regimes,
    required this.fetchFailures,
    required this.seriesByKey,
    required this.activeSignalCount,
  });

  final DateTime startedAt;
  final DateTime finishedAt;
  final List<ScanCandidate> candidates;
  final List<SignalRecord> newSignals;
  final List<SignalTransitionEvent> transitions;
  final Map<Market, RegimeReport> regimes;

  /// Verisi alınamayan varlıklar ve nedenleri (kısaltılmış; URL veya sır içermez).
  final Map<Instrument, String> fetchFailures;
  final Map<String, CandleSeries> seriesByKey;

  /// Tarama sonunda günlükte açık duran sinyal sayısı.
  final int activeSignalCount;

  CandleSeries? seriesFor(Instrument ins, BarInterval iv) => seriesByKey[MarketScanner.seriesKey(ins, iv)];

  /// Değerlendirilen farklı varlık sayısı.
  int get scannedInstrumentCount => {for (final c in candidates) c.instrument}.length;

  /// Teknik kurulum bulunan aday sayısı.
  int get setupCount => candidates.where((c) => c.hadSetup).length;

  int get approvedCount => newSignals.length;

  /// Aşama bazında eleme sayıları (onaylananlar hariç).
  Map<String, int> get rejectionsByStage {
    final out = <String, int>{};
    for (final c in candidates) {
      if (c.approved) continue;
      out[c.stage] = (out[c.stage] ?? 0) + 1;
    }
    return out;
  }

  /// Kurulum bulunup sonradan elenen adaylar (en bilgilendirici olanlar).
  List<ScanCandidate> get nearMisses => [
        for (final c in candidates)
          if (!c.approved && c.hadSetup) c,
      ];

  /// Hiç veri alınamadıysa tarama geçersizdir; "fırsat yok" denemez, "veri yok" denir.
  bool get noData => candidates.isNotEmpty && candidates.every((c) => c.stage == FunnelStage.fetch);

  /// Ne yeni ne açık sinyal var: nakitte kalınır.
  bool get cashOnly => newSignals.isEmpty && activeSignalCount == 0;

  String get summaryTr {
    if (candidates.isEmpty) return 'Taranacak varlık yok.';
    if (noData) {
      return 'Hiçbir varlık için veri alınamadı (${fetchFailures.length} hata). Fırsat değerlendirmesi yapılamadı.';
    }
    final head = '$scannedInstrumentCount varlık tarandı · $setupCount kurulum bulundu · $approvedCount onaylandı';
    final failNote = fetchFailures.isEmpty ? '' : ' · ${fetchFailures.length} varlıkta veri alınamadı';
    if (approvedCount > 0) return '$head$failNote.';
    if (activeSignalCount > 0) {
      return '$head$failNote. Yeni fırsat yok; $activeSignalCount açık sinyal izleniyor.';
    }
    return '$head$failNote. Eşiği geçen fırsat yok — nakitte kalmak da bir karardır.';
  }
}

/// Analiz hunisini tüm evren üzerinde koşturan, sonuçları sinyal günlüğüne işleyen orkestratör.
///
/// Sıra:
/// 1. Açık sinyallerin sonucu kapanmış mumlarla izlenir (hedef / stop / süre).
/// 2. Her piyasa için rejim okunur.
/// 3. Her varlık × dilim için huni çalışır; elenen her aday gerekçesiyle kaydedilir.
/// 4. Onaylananlar güven skoruna göre sıralanır ve piyasa başına eşzamanlı sinyal sınırına kadar
///    günlüğe yazılır.
///
/// Tek bir varlığın veri hatası taramayı durdurmaz. Geçmiş mumlarda strateji sınaması YAPILMAZ:
/// yalnızca en son kapanmış mum değerlendirilir (Kısıt 2).
class MarketScanner {
  MarketScanner({
    required this.data,
    required this.journal,
    SignalEngine? engine,
    this.regimeDetector = const RegimeDetector(),
    this.cooldownBars = 6,
    this.signalBarLimit = 220,
    this.higherBarLimit = 150,
    Clock? clock,
  })  : _clock = clock ?? systemClock,
        engine = engine ?? SignalEngine(clock: clock),
        _tracker = SignalOutcomeTracker(store: journal, clock: clock);

  final MarketDataService data;
  final SignalJournalStore journal;
  final SignalEngine engine;
  final RegimeDetector regimeDetector;

  /// Stop olan bir varlık × dilim için yeniden sinyal üretmeden önce beklenecek mum sayısı.
  /// Aynı düşüşte art arda "intikam" sinyalleri üretmeyi engeller.
  final int cooldownBars;
  final int signalBarLimit;
  final int higherBarLimit;
  final Clock _clock;
  final SignalOutcomeTracker _tracker;

  static String seriesKey(Instrument ins, BarInterval iv) => '${ins.id}|${iv.code}';

  Future<ScanOutcome> scan(
    List<MarketScanPlan> plans, {
    bool forceRefresh = false,
    void Function(int done, int total)? onProgress,
  }) async {
    final startedAt = _clock().toUtc();
    final memo = <String, CandleSeries?>{};
    final failures = <Instrument, String>{};

    Future<CandleSeries?> fetch(Instrument ins, BarInterval iv, int limit) async {
      final key = seriesKey(ins, iv);
      if (memo.containsKey(key)) return memo[key];
      CandleSeries? got;
      try {
        got = await data.candles(ins, iv, limit: limit, forceRefresh: forceRefresh);
      } catch (e) {
        // Tek varlığın hatası (ağ, biçim, CORS) taramayı durdurmaz.
        failures[ins] = _shortError(e);
      }
      memo[key] = got;
      return got;
    }

    // 1. Açık sinyallerin sonucunu izle
    final transitions = <SignalTransitionEvent>[];
    for (final sig in await journal.activeSignals()) {
      final s = await fetch(sig.instrument, sig.interval, signalBarLimit);
      if (s == null || s.closed.isEmpty) continue;
      final r = await _tracker.evaluateSignal(sig, s.closed);
      transitions.addAll(r.events);
    }

    final candidates = <ScanCandidate>[];
    final newSignals = <SignalRecord>[];
    final regimes = <Market, RegimeReport>{};

    var total = 0;
    for (final p in plans) {
      total += p.instruments.length * p.intervals.length;
    }
    var done = 0;

    for (final plan in plans) {
      // 2. Piyasa rejimi
      final bench = await fetch(plan.benchmark, plan.benchmarkInterval, 260);
      final marketRegime = regimeDetector.detect(plan.benchmark, bench?.closed ?? const []);
      regimes[plan.market] = marketRegime;

      final active = await journal.activeSignals(market: plan.market);
      final recentlyClosed = await journal.allSignals(
        market: plan.market,
        since: startedAt.subtract(const Duration(days: 10)),
      );
      final pending = <({SignalRecord record, ScanIntervalPlan ip})>[];

      // 3. Varlık × dilim hunisi
      for (final ins in plan.instruments) {
        for (final ip in plan.intervals) {
          done++;
          onProgress?.call(done, total);

          if (active.any((a) => a.instrument == ins && a.isWeeklyProposal == ip.weekly)) {
            candidates.add(ScanCandidate(
              instrument: ins,
              interval: ip.interval,
              weekly: ip.weekly,
              approved: false,
              stage: FunnelStage.duplicate,
              reason: 'Bu varlıkta zaten açık bir ${ip.weekly ? 'haftalık öneri' : 'kısa vade sinyali'} izleniyor',
            ));
            continue;
          }

          final cooldownUntil = _cooldownUntil(recentlyClosed, ins, ip.interval);
          if (cooldownUntil != null && startedAt.isBefore(cooldownUntil)) {
            candidates.add(ScanCandidate(
              instrument: ins,
              interval: ip.interval,
              weekly: ip.weekly,
              approved: false,
              stage: FunnelStage.cooldown,
              reason: 'Son sinyal stop oldu; $cooldownBars mumluk bekleme süresi dolmadan yeni sinyal üretilmez',
            ));
            continue;
          }

          final series = await fetch(ins, ip.interval, signalBarLimit);
          if (series == null) {
            candidates.add(ScanCandidate(
              instrument: ins,
              interval: ip.interval,
              weekly: ip.weekly,
              approved: false,
              stage: FunnelStage.fetch,
              reason: 'Veri alınamadı: ${failures[ins] ?? 'bilinmeyen hata'}',
            ));
            continue;
          }

          final higherIv = MultiTimeframeAnalyzer.higherIntervalFor(plan.market, ip.interval);
          final higher = higherIv == ip.interval ? series : await fetch(ins, higherIv, higherBarLimit);

          // Emtia vekilleri gibi referansla bağıntısı düşük varlıklar kendi trendiyle değerlendirilir.
          final regime = plan.ownRegimeSymbols.contains(ins.symbol) && higher != null
              ? regimeDetector.detect(ins, higher.closed)
              : marketRegime;

          final eval = engine.evaluate(
            signalSeries: series,
            higherClosedBars: higher?.closed ?? const [],
            regime: regime,
            previousDayClose: _previousDayClose(plan.market, ip.interval, series, higher),
            isWeeklyProposal: ip.weekly,
          );

          final rec = eval.signalRecord;
          if (eval.approved && rec != null) {
            if (await journal.byId(rec.id) != null) {
              candidates.add(ScanCandidate(
                instrument: ins,
                interval: ip.interval,
                weekly: ip.weekly,
                approved: false,
                stage: FunnelStage.duplicate,
                reason: 'Bu mum için sinyal daha önce üretildi ve sonuçlandı',
                setups: eval.detection?.setups ?? const [],
                confidenceTotal: eval.confidence?.total,
              ));
            } else {
              pending.add((record: rec, ip: ip));
            }
          } else {
            candidates.add(ScanCandidate(
              instrument: ins,
              interval: ip.interval,
              weekly: ip.weekly,
              approved: false,
              stage: eval.stage,
              reason: eval.reason,
              setups: eval.detection?.setups ?? const [],
              confidenceTotal: eval.confidence?.total,
            ));
          }
        }
      }

      // 4. Eşzamanlı sinyal sınırı: en yüksek güvenli adaylar öncelikli
      pending.sort((a, b) {
        final c = b.record.confidence.total.compareTo(a.record.confidence.total);
        return c != 0 ? c : b.record.rewardRisk.compareTo(a.record.rewardRisk);
      });
      var slots = plan.maxOpenSignals - active.length;
      for (final p in pending) {
        final rec = p.record;
        if (slots > 0) {
          await journal.save(rec);
          newSignals.add(rec);
          slots--;
          candidates.add(ScanCandidate(
            instrument: rec.instrument,
            interval: rec.interval,
            weekly: p.ip.weekly,
            approved: true,
            stage: FunnelStage.approved,
            reason: 'Sinyal onaylandı (Güven: ${rec.confidence.total}/100)',
            setups: rec.allSetups,
            confidenceTotal: rec.confidence.total,
          ));
        } else {
          candidates.add(ScanCandidate(
            instrument: rec.instrument,
            interval: rec.interval,
            weekly: p.ip.weekly,
            approved: false,
            stage: FunnelStage.portfolio,
            reason: 'Onaylandı ama ${plan.market == Market.bist ? 'BIST' : 'kripto'} için eşzamanlı '
                '${plan.maxOpenSignals} açık sinyal sınırı dolu (bağıntı riski)',
            setups: rec.allSetups,
            confidenceTotal: rec.confidence.total,
          ));
        }
      }
    }

    final activeAfter = await journal.activeSignals();
    return ScanOutcome(
      startedAt: startedAt,
      finishedAt: _clock().toUtc(),
      candidates: candidates,
      newSignals: newSignals,
      transitions: transitions,
      regimes: regimes,
      fetchFailures: failures,
      seriesByKey: {
        for (final e in memo.entries)
          if (e.value != null) e.key: e.value!,
      },
      activeSignalCount: activeAfter.length,
    );
  }

  DateTime? _cooldownUntil(List<SignalRecord> recent, Instrument ins, BarInterval iv) {
    DateTime? latest;
    for (final s in recent) {
      if (s.instrument != ins || s.interval != iv) continue;
      if (s.status != SignalStatus.stop || s.breakevenStop) continue;
      final closedAt = s.closedAt;
      if (closedAt == null) continue;
      final until = closedAt.add(Duration(milliseconds: iv.ms * cooldownBars));
      if (latest == null || until.isAfter(latest)) latest = until;
    }
    return latest;
  }

  /// BIST tavan/taban denetimi için referans kapanış.
  static double? _previousDayClose(
    Market market,
    BarInterval signalIv,
    CandleSeries series,
    CandleSeries? higher,
  ) {
    if (market != Market.bist) return null;
    if (signalIv == BarInterval.d1) {
      final c = series.closed;
      return c.length >= 2 ? c[c.length - 2].close : null;
    }
    final d = higher?.closed;
    return (d == null || d.isEmpty) ? null : d.last.close;
  }

  /// Hata metnini kısaltır; tam URL veya sorgu dizesi günlüğe/ekrana taşınmaz (K6).
  static String _shortError(Object e) {
    var msg = e.toString();
    final q = msg.indexOf('http');
    if (q >= 0) msg = msg.substring(0, q).trimRight();
    if (msg.length > 120) msg = '${msg.substring(0, 120)}…';
    return msg.isEmpty ? e.runtimeType.toString() : msg;
  }
}
