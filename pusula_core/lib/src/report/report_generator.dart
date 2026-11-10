import '../journal/signal_journal.dart';
import '../model/market.dart';
import '../util/clock.dart';
import 'weekly_report.dart';
import 'weighting.dart';

/// Sinyal günlüğünden Pazar günü haftalık raporunu üreten ve arşivleyen motor.
///
/// Kısıt 2: Raporlardaki getiriler yalnızca sistemin ileriye dönük ürettiği sinyallerin
/// gerçekleşen sonuçlarıdır. İlk haftada (kayıt yokken) "Geçen hafta raporu: henüz veri yok"
/// döndürülür; asla geçmiş mumlardan veri uydurulmaz.
class WeeklyReportGenerator {
  WeeklyReportGenerator({
    required this.journalStore,
    required this.reportStore,
    this.allocator = const PortfolioWeightAllocator(),
    Clock? clock,
  }) : _clock = clock ?? systemClock;

  final SignalJournalStore journalStore;
  final WeeklyReportStore reportStore;
  final PortfolioWeightAllocator allocator;
  final Clock _clock;

  /// Pazar günü raporunu (1. Geçen hafta raporu → 2. Kısa vade raporu → 3. Yeni öneriler) üretir ve arşivler.
  Future<WeeklyReport> generate({
    required List<SignalRecord> newCandidates,
    RiskAppetite appetite = RiskAppetite.balanced,
    double totalBudget = 100000.0,
    Map<Instrument, double> currentPrices = const {},
    Duration lookbackWindow = const Duration(days: 7),
    bool saveProposalsToJournal = true,
  }) async {
    final now = _clock().toUtc();
    final weekStart = now.subtract(lookbackWindow);

    final pastSignals = await journalStore.allSignals(since: weekStart, until: now);
    final pastProposals = [for (final s in pastSignals) if (s.isWeeklyProposal) s];
    final pastShortTerm = [for (final s in pastSignals) if (!s.isWeeklyProposal) s];

    // 1. ÖNCE GEÇEN HAFTA RAPORU
    final lastWeek = _buildLastWeekReview(pastProposals, currentPrices);

    // 2. SONRA KISA VADE HAFTALIK RAPORU (Kripto ve BIST ayrı)
    final cryptoShort = _buildShortTermSummary(
      Market.crypto,
      [for (final s in pastShortTerm) if (s.instrument.market == Market.crypto) s],
    );
    final bistShort = _buildShortTermSummary(
      Market.bist,
      [for (final s in pastShortTerm) if (s.instrument.market == Market.bist) s],
    );
    final shortTerm = ShortTermWeeklyReport(crypto: cryptoShort, bist: bistShort);

    // 3. SONRA YENİ HAFTANIN ÖNERİLERİ VE BÜTÇE AĞIRLIKLARI
    final allocation = allocator.allocate(
      newCandidates,
      appetite: appetite,
      totalBudget: totalBudget,
    );

    if (saveProposalsToJournal) {
      for (final rec in allocation.recommendations) {
        await journalStore.save(rec.signal);
      }
    }

    final reportId = 'weekly_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final report = WeeklyReport(
      id: reportId,
      weekStart: weekStart,
      weekEnd: now,
      generatedAt: now,
      lastWeekReview: lastWeek,
      shortTermReport: shortTerm,
      newAllocation: allocation,
    );

    await reportStore.save(report);
    return report;
  }

  LastWeekReview _buildLastWeekReview(
    List<SignalRecord> proposals,
    Map<Instrument, double> currentPrices,
  ) {
    if (proposals.isEmpty) {
      return const LastWeekReview.empty('Geçen hafta raporu: henüz veri yok');
    }

    final outcomes = <LastWeekAssetOutcome>[];
    final targetsHit = <String>[];
    final stopsHit = <String>[];
    var weightedRet = 0.0;
    var wins = 0;

    for (final sig in proposals) {
      final weight = sig.allocatedWeightPct ?? 10.0;
      final double pct;
      final double rMult;
      final double exitOrCur;
      final String note;

      if (sig.isClosed && sig.realizedPct != null && sig.realizedR != null) {
        pct = sig.realizedPct!;
        rMult = sig.realizedR!;
        exitOrCur = sig.exitPrice ?? sig.entryPrice;
        note = sig.exitReason ?? sig.status.label;
      } else {
        final curP = currentPrices[sig.instrument] ??
            (sig.status == SignalStatus.target1 ? sig.target1 : sig.entryPrice);
        exitOrCur = curP;
        final risk = sig.initialRiskPerUnit > 0 ? sig.initialRiskPerUnit : sig.entryPrice * 0.01;
        pct = double.parse((((curP - sig.entryPrice) / sig.entryPrice) * 100.0).toStringAsFixed(2));
        rMult = double.parse(((curP - sig.entryPrice) / risk).toStringAsFixed(2));
        note = sig.status == SignalStatus.target1
            ? 'Hedef 1 görüldü, stop başabaşta açık'
            : 'Açık pozisyon (anlık fiyatla değerlendirildi)';
      }

      final contrib = double.parse((weight * pct / 100.0).toStringAsFixed(3));
      weightedRet += contrib;

      if (sig.status == SignalStatus.target2 || sig.status == SignalStatus.target1) {
        targetsHit.add(sig.instrument.short);
      } else if (sig.status == SignalStatus.stop && !sig.breakevenStop) {
        stopsHit.add(sig.instrument.short);
      }

      if (pct > 0) wins++;

      outcomes.add(LastWeekAssetOutcome(
        instrument: sig.instrument,
        strategyCode: sig.strategy.code,
        weightPct: weight,
        entryPrice: sig.entryPrice,
        exitOrCurrentPrice: exitOrCur,
        realizedPct: pct,
        realizedR: rMult,
        weightedContributionPct: contrib,
        status: sig.status,
        note: note,
      ));
    }

    outcomes.sort((a, b) => b.realizedPct.compareTo(a.realizedPct));
    final best = outcomes.first;
    final worst = outcomes.last;
    final winRate = double.parse(((wins / outcomes.length) * 100.0).toStringAsFixed(1));
    final finalWeighted = double.parse(weightedRet.toStringAsFixed(2));

    final lessons = <String>[];
    if (targetsHit.isNotEmpty) {
      lessons.add('Hedefe ulaşan varlıklar (${targetsHit.join(', ')}) üst zaman dilimi ve hacim teyidi güçlü olanlardı.');
    }
    if (stopsHit.isNotEmpty) {
      lessons.add('Stop olan önerilerde (${stopsHit.join(', ')}) pozisyon ağırlığı sınırı sayesinde portföy etkisi sınırlı kaldı.');
    }
    if (proposals.any((p) => p.breakevenStop)) {
      lessons.add('1R hedefte stopun başabaşa çekilmesi kârı korudu ve zarara dönüşü engelledi.');
    }
    if (lessons.isEmpty) {
      lessons.add('Sinyaller planlanan risk sınırları içinde izlendi; nakit tamponu korundu.');
    }

    return LastWeekReview(
      hasData: true,
      emptyMessage: '',
      outcomes: outcomes,
      weightedPortfolioReturnPct: finalWeighted,
      targetsHit: targetsHit,
      stopsHit: stopsHit,
      winRatePct: winRate,
      bestOutcome: best,
      worstOutcome: worst,
      lessonsLearned: lessons,
    );
  }

  ShortTermMarketSummary _buildShortTermSummary(Market market, List<SignalRecord> signals) {
    if (signals.isEmpty) {
      return ShortTermMarketSummary.empty(market);
    }

    final closed = [for (final s in signals) if (s.isClosed && s.realizedR != null && s.realizedPct != null) s];
    final openCount = signals.length - closed.length;

    var totalPct = 0.0;
    var totalR = 0.0;
    var wins = 0;
    SignalRecord? best;
    SignalRecord? worst;

    for (final s in closed) {
      final pct = s.realizedPct!;
      final r = s.realizedR!;
      totalPct += pct;
      totalR += r;
      if (r > 0) wins++;
      if (best == null || r > best.realizedR!) best = s;
      if (worst == null || r < worst.realizedR!) worst = s;
    }

    final winRate = closed.isEmpty ? 0.0 : double.parse(((wins / closed.length) * 100.0).toStringAsFixed(1));
    final avgR = closed.isEmpty ? 0.0 : double.parse((totalR / closed.length).toStringAsFixed(2));

    // Strateji bazında döküm
    final byStratMap = <String, List<SignalRecord>>{};
    for (final s in signals) {
      byStratMap.putIfAbsent(s.strategy.code, () => []).add(s);
    }

    final breakdown = <StrategyBreakdownItem>[];
    for (final entry in byStratMap.entries) {
      final list = entry.value;
      final cls = [for (final s in list) if (s.isClosed && s.realizedR != null) s];
      final w = cls.where((s) => s.realizedR! > 0).length;
      final sumR = cls.fold<double>(0.0, (a, b) => a + b.realizedR!);
      final sumPct = cls.fold<double>(0.0, (a, b) => a + (b.realizedPct ?? 0.0));
      breakdown.add(StrategyBreakdownItem(
        strategyCode: entry.key,
        strategyLabel: list.first.strategy.label,
        signalCount: list.length,
        closedCount: cls.length,
        winRatePct: cls.isEmpty ? 0.0 : double.parse(((w / cls.length) * 100.0).toStringAsFixed(1)),
        avgR: cls.isEmpty ? 0.0 : double.parse((sumR / cls.length).toStringAsFixed(2)),
        totalReturnPct: double.parse(sumPct.toStringAsFixed(2)),
      ));
    }
    breakdown.sort((a, b) => b.signalCount.compareTo(a.signalCount));

    String? fmtSig(SignalRecord? s) {
      if (s == null) return null;
      final r = s.realizedR ?? 0.0;
      final p = s.realizedPct ?? 0.0;
      return '${s.instrument.short} (${s.strategy.label}): ${p >= 0 ? '+' : ''}%${p.toStringAsFixed(2)} (${r >= 0 ? '+' : ''}${r.toStringAsFixed(2)}R)';
    }

    return ShortTermMarketSummary(
      market: market,
      hasData: true,
      totalSignals: signals.length,
      closedSignals: closed.length,
      openSignals: openCount,
      totalReturnPct: double.parse(totalPct.toStringAsFixed(2)),
      winRatePct: winRate,
      avgR: avgR,
      bestSignalSummary: fmtSig(best),
      worstSignalSummary: fmtSig(worst),
      byStrategy: breakdown,
    );
  }
}
