import 'package:pusula_core/pusula_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// MarketScanner uçtan uca testleri: sahte sağlayıcı + sentetik mumlar, gerçek ağ yok.
void main() {
  const btc = Instrument.crypto('BTCUSDT');
  const sol = Instrument.crypto('SOLUSDT');
  const eth = Instrument.crypto('ETHUSDT');
  const paxg = Instrument.crypto('PAXGUSDT');
  final lastClose = DateTime.utc(2026, 11, 12, 14, 0);

  late FakeClock clock;
  late StubProvider provider;
  late MemorySignalJournalStore journal;

  /// Hangi semboller kırılım serisi alacak; kalanlar yatay seri alır.
  late Set<String> bullish;

  /// Hangi semboller için sağlayıcı hata fırlatacak.
  late Set<String> failing;

  /// Referans (BTC) düşüş trendinde mi?
  late bool bearBenchmark;

  MarketScanner buildScanner({int cooldownBars = 6}) {
    final svc = MarketDataService(
      providers: [provider],
      clock: clock.call,
      limiter: testLimiter(clock, minGap: Duration.zero),
    );
    return MarketScanner(
      data: svc,
      journal: journal,
      clock: clock.call,
      cooldownBars: cooldownBars,
      engine: SignalEngine(
        clock: clock.call,
        monteCarlo: const MonteCarloSimulator(replays: 500, seed: 5),
      ),
    );
  }

  MarketScanPlan plan(List<Instrument> instruments, {int maxOpen = 4, Set<String> ownRegime = const {}}) =>
      MarketScanPlan(
        market: Market.crypto,
        instruments: instruments,
        benchmark: btc,
        benchmarkInterval: BarInterval.h4,
        intervals: const [ScanIntervalPlan(BarInterval.h1, weekly: false)],
        maxOpenSignals: maxOpen,
        ownRegimeSymbols: ownRegime,
      );

  setUp(() {
    clock = FakeClock(lastClose.add(const Duration(minutes: 1)));
    journal = MemorySignalJournalStore();
    bullish = {};
    failing = {};
    bearBenchmark = false;
    provider = StubProvider('binance')
      ..behavior = (ins, iv, limit, now) {
        if (failing.contains(ins.symbol)) throw ProviderException('binance', 'kapalı');
        final List<Candle> bars;
        if (ins == btc && iv == BarInterval.h4 && bearBenchmark) {
          bars = downtrendBars(lastBarClose: lastClose, interval: iv);
        } else if (bullish.contains(ins.symbol) || (ins == btc && iv == BarInterval.h4)) {
          bars = bullBreakoutBars(lastBarClose: lastClose, interval: iv, count: 220);
        } else {
          bars = flatBars(lastBarClose: lastClose, interval: iv);
        }
        return seriesOf(ins, iv, bars, now, source: 'binance');
      };
  });

  test('fırsat yoksa dürüstçe nakitte kalır: sinyal üretmez, günlük boş kalır', () async {
    final out = await buildScanner().scan([plan(const [sol, eth])]);

    expect(out.newSignals, isEmpty);
    expect(out.approvedCount, 0);
    expect(out.cashOnly, isTrue);
    expect(out.noData, isFalse);
    expect(out.scannedInstrumentCount, 2);
    expect(out.rejectionsByStage[FunnelStage.scanner], 2);
    expect(out.summaryTr, contains('nakitte'));
    expect(journal.length, 0);
    expect(out.regimes[Market.crypto], isNotNull);
  });

  test('onaylanan kurulum günlüğe bir kez yazılır; ikinci tarama aynı sinyali çoğaltmaz', () async {
    bullish = {'SOLUSDT'};
    final scanner = buildScanner();

    final first = await scanner.scan([plan(const [sol, eth])]);
    expect(first.approvedCount, 1, reason: first.candidates.map((c) => '${c.instrument.short}:${c.reason}').join(' | '));
    expect(first.newSignals.single.instrument, sol);
    expect(first.newSignals.single.isWeeklyProposal, isFalse);
    expect(first.cashOnly, isFalse);
    expect(journal.length, 1);
    expect(first.seriesFor(sol, BarInterval.h1), isNotNull);

    clock.advance(const Duration(minutes: 5));
    final second = await scanner.scan([plan(const [sol, eth])]);
    expect(second.newSignals, isEmpty);
    expect(journal.length, 1);
    final solCand = second.candidates.firstWhere((c) => c.instrument == sol);
    expect(solCand.stage, FunnelStage.duplicate);
    expect(second.summaryTr, contains('1 açık sinyal izleniyor'));
  });

  test('tek varlığın veri hatası taramayı durdurmaz; hepsi düşerse "fırsat yok" değil "veri yok" denir', () async {
    bullish = {'SOLUSDT'};
    failing = {'ETHUSDT'};
    final partial = await buildScanner().scan([plan(const [sol, eth])]);
    expect(partial.fetchFailures.keys, contains(eth));
    expect(partial.approvedCount, 1);
    expect(partial.candidates.firstWhere((c) => c.instrument == eth).stage, FunnelStage.fetch);
    expect(partial.noData, isFalse);

    journal = MemorySignalJournalStore();
    failing = {'SOLUSDT', 'ETHUSDT', 'BTCUSDT'};
    final none = await buildScanner().scan([plan(const [sol, eth])]);
    expect(none.noData, isTrue);
    expect(none.newSignals, isEmpty);
    expect(none.summaryTr, contains('veri alınamadı'));
    expect(none.summaryTr, isNot(contains('nakitte')));
  });

  test('eşzamanlı açık sinyal sınırı: fazlası "portfolio" aşamasında bekletilir', () async {
    bullish = {'SOLUSDT', 'ETHUSDT'};
    final out = await buildScanner().scan([plan(const [sol, eth], maxOpen: 1)]);
    expect(out.approvedCount, 1);
    expect(journal.length, 1);
    expect(out.rejectionsByStage[FunnelStage.portfolio], 1);
    expect(out.nearMisses.single.stage, FunnelStage.portfolio);
  });

  test('açık sinyalin stop sonucu izlenir ve aynı varlıkta bekleme süresi uygulanır', () async {
    bullish = {'SOLUSDT'};
    final scanner = buildScanner();
    final first = await scanner.scan([plan(const [sol])]);
    final opened = first.newSignals.single;

    // Sonraki saatlik mum stopun altına sarkar.
    final nextClose = lastClose.add(const Duration(hours: 1));
    clock.now = nextClose.add(const Duration(minutes: 1));
    provider.behavior = (ins, iv, limit, now) {
      final base = bullBreakoutBars(lastBarClose: lastClose, interval: iv, count: 220);
      if (ins == sol && iv == BarInterval.h1) {
        final crash = opened.initialStop * 0.99;
        base.add(Candle(
          openTimeMs: lastClose.millisecondsSinceEpoch,
          open: opened.entryPrice,
          high: opened.entryPrice * 1.001,
          low: crash,
          close: crash,
          volume: 3000,
          quoteVolume: 3000 * crash,
        ));
      }
      return seriesOf(ins, iv, base, now, source: 'binance');
    };

    final second = await scanner.scan([plan(const [sol])], forceRefresh: true);
    expect(second.transitions.single.newStatus, SignalStatus.stop);
    expect((await journal.byId(opened.id))!.realizedR, -1.0);
    expect(second.newSignals, isEmpty);
    expect(second.candidates.single.stage, FunnelStage.cooldown);
    expect(second.cashOnly, isTrue);
  });

  test('Ayı rejiminde kırılım sinyali üretilmez; emtia vekili kendi trendiyle değerlendirilir', () async {
    bullish = {'SOLUSDT', 'PAXGUSDT'};
    bearBenchmark = true;
    final out = await buildScanner().scan([
      plan(const [sol, paxg], ownRegime: const {'PAXGUSDT'}),
    ]);

    expect(out.regimes[Market.crypto]!.regime, MarketRegime.bear);
    final solCand = out.candidates.firstWhere((c) => c.instrument == sol);
    expect(solCand.approved, isFalse);
    expect(solCand.stage, FunnelStage.scanner);

    expect(out.newSignals.map((s) => s.instrument), [paxg]);
    expect(out.newSignals.single.regime, MarketRegime.bull);
  });

  test('varsayılan planlar: kripto evreni sabit 10 sembol, 1 saat kısa vade + 4 saat haftalık', () {
    final crypto = MarketScanPlan.crypto();
    expect(crypto.instruments.length, 10);
    expect(crypto.instruments, CryptoUniverse.instruments);
    expect(crypto.intervals.map((i) => (i.interval, i.weekly)), [(BarInterval.h1, false), (BarInterval.h4, true)]);
    expect(SetupScanner.isSupportedInterval(Market.crypto, BarInterval.h4), isTrue);

    final bist = MarketScanPlan.bist(const [Instrument.bist('THYAO')]);
    expect(bist.intervals.map((i) => (i.interval, i.weekly)), [(BarInterval.h1, false), (BarInterval.d1, true)]);
    expect(bist.benchmark, BistUniverse.benchmark);
  });

  test('ilerleme geri çağrısı her varlık × dilim için bir kez çağrılır', () async {
    final seen = <(int, int)>[];
    await buildScanner().scan([plan(const [sol, eth])], onProgress: (d, t) => seen.add((d, t)));
    expect(seen, [(1, 2), (2, 2)]);
  });
}
