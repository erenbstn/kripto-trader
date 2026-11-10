// Canlı duman testi: gerçek uçlardan veri çeker ve özet yazar. Elle çalıştırılır:
//   dart run tool/smoke.dart
// Birim testlerinin parçası değildir (ağ gerektirir).
import 'dart:io';

import 'package:pusula_core/pusula_core.dart';

Future<void> main(List<String> args) async {
  final http = NetworkHttpFetcher();
  final svc = MarketDataService(providers: [
    BinanceProvider(http),
    YahooProvider(http),
    IsYatirimProvider(http),
  ]);
  const cal = BistCalendar();
  final now = DateTime.now().toUtc();
  stdout.writeln('BIST şu an: ${cal.phaseAt(now).name} · sonraki açılış (UTC): ${cal.nextOpen(now)}');

  stdout.writeln('\n== Kripto (1h) ==');
  for (final ins in CryptoUniverse.instruments) {
    try {
      final s = await svc.candles(ins, BarInterval.h1, limit: 100);
      stdout.writeln('${ins.short.padRight(6)} ${s.closed.length} mum · son ${s.lastPrice} · ${s.source}');
    } on MarketDataException catch (e) {
      stdout.writeln('${ins.short.padRight(6)} HATA: ${e.reasons}');
    }
  }

  stdout.writeln('\n== BIST evreni (günlük) ==');
  final symbols = args.contains('--all') ? BistUniverse.candidates : BistUniverse.candidates.take(12).toList();
  final daily = <String, List<Candle>>{};
  for (final ins in symbols) {
    try {
      final s = await svc.candles(ins, BarInterval.d1, limit: 120);
      daily[ins.symbol] = s.closed;
    } on MarketDataException {
      daily[ins.symbol] = const [];
    }
  }
  final sel = const BistUniverseFilter().select(daily, now: now);
  stdout.writeln('Seçilen ${sel.selected.length}/${symbols.length}:');
  for (final i in sel.selected) {
    stdout.writeln('  ${i.symbol.padRight(6)} ${(sel.turnover[i.symbol]! / 1e9).toStringAsFixed(2)} mlr TL/gün');
  }
  for (final r in sel.rejected) {
    stdout.writeln('  - ${r.symbol.padRight(6)} elendi: ${r.reason}');
  }

  stdout.writeln('\n== BIST saatlik + endeks + yedek kaynak ==');
  final thy = await svc.candles(const Instrument.bist('THYAO'), BarInterval.h1, limit: 60);
  stdout.writeln('THYAO 1h: ${thy.closed.length} mum · ${thy.source} · gecikme ${thy.dataDelay.inMinutes} dk');
  final xu = await svc.candles(BistUniverse.benchmark, BarInterval.d1, limit: 60);
  stdout.writeln('XU100 1d: ${xu.closed.length} mum · son ${xu.lastPrice}');
  final isy = await IsYatirimProvider(http)
      .fetchCandles(const Instrument.bist('THYAO'), BarInterval.d1, limit: 30, now: now);
  stdout.writeln('İş Yatırım THYAO 1d: ${isy.closed.length} mum · son kapanış ${isy.closed.last.close}');

  stdout.writeln('\n== Sağlayıcı sağlığı ==');
  for (final h in svc.health) {
    stdout.writeln('${h.label}: başarı ${h.successCount}, hata ${h.failureCount}'
        '${h.lastError == null ? '' : ' · son hata: ${h.lastError}'}');
  }
  http.close();
}
