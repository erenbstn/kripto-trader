import 'package:flutter/foundation.dart';
import 'package:pusula_core/pusula_core.dart';

import '../storage/app_settings.dart';

/// Tek bir varlığın canlı piyasa fiyat özeti (Özet ekranındaki piyasa şeridinde gösterilir).
class LiveMarketQuote {
  const LiveMarketQuote({
    required this.instrument,
    required this.lastPrice,
    required this.changePct,
    required this.sourceLabel,
    required this.ageMinutes,
    required this.isStale,
  });

  final Instrument instrument;
  final double lastPrice;

  /// Kripto için son 24 saatlik, BIST için önceki günlük kapanışa göre değişim (%).
  final double changePct;
  final String sourceLabel;
  final int ageMinutes;
  final bool isStale;
}

/// Web (Chrome) ve Android uyumlu HTTP istemcisi.
/// Android'de doğrudan hedefe bağlanır; Web (Chrome) üzerinde Yahoo Finance ve İş Yatırım
/// CORS kısıtlamasına takılmamak için önce yerel PC köprüsünü (127.0.0.1:8787) dener.
class PusulaHttpFetcher implements HttpFetcher {
  PusulaHttpFetcher({NetworkHttpFetcher? delegate})
      : _delegate = delegate ?? NetworkHttpFetcher(sendUserAgent: !kIsWeb);

  final NetworkHttpFetcher _delegate;

  static const Set<String> _corsRestrictedWebHosts = {
    'query1.finance.yahoo.com',
    'query2.finance.yahoo.com',
    'www.isyatirim.com.tr',
  };

  @override
  Future<String> getText(
    Uri uri, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    if (kIsWeb && _corsRestrictedWebHosts.contains(uri.host)) {
      final proxyUri = Uri.parse(
        'http://127.0.0.1:8787/proxy?url=${Uri.encodeComponent(uri.toString())}',
      );
      try {
        return await _delegate.getText(proxyUri, headers: headers, timeout: timeout);
      } catch (_) {
        // Yerel köprü çalışmıyorsa doğrudan isteği dene.
      }
    }
    return _delegate.getText(uri, headers: headers, timeout: timeout);
  }

  void close() => _delegate.close();
}

/// Canlı izlenen BIST hisseleri (likiditesi en yüksek çekirdek liste). Rejim referansı XU100 ayrıca okunur.
/// Tam Borsa İstanbul (BIST) hisse kataloğunu (kayıtlı tüm BIST hisseleri + kullanıcının ekledikleri) döner.
List<Instrument> buildBistCatalog(AppSettings settings) {
  final seen = <String>{};
  final result = <Instrument>[];

  void add(Instrument ins) {
    final key = ins.symbol.trim().toUpperCase();
    if (key.isEmpty || key == BistUniverse.benchmark.symbol || !seen.add(key)) return;
    result.add(ins);
  }

  for (final ins in kWatchedBistStocks) {
    add(ins);
  }
  for (final sym in settings.customBistSymbols) {
    add(BistUniverse.instrumentFor(sym));
  }
  for (final ins in BistUniverse.candidates) {
    add(ins);
  }
  return result;
}

/// Taramada değerlendirilecek BIST hisselerini ayarlara göre belirler.
List<Instrument> buildWatchedBistForScan(AppSettings settings) {
  final seen = <String>{};
  final pool = <Instrument>[];

  void add(Instrument ins) {
    final key = ins.symbol.trim().toUpperCase();
    if (key.isEmpty || key == BistUniverse.benchmark.symbol || !seen.add(key)) return;
    pool.add(ins);
  }

  if (settings.scanAllBistUniverse) {
    for (final ins in buildBistCatalog(settings)) {
      add(ins);
    }
  } else {
    for (final ins in kWatchedBistStocks) {
      add(ins);
    }
    for (final sym in settings.customBistSymbols) {
      add(BistUniverse.instrumentFor(sym));
    }
    for (final fav in settings.favoriteSymbols) {
      final clean = fav.trim().toUpperCase();
      if (!CryptoUniverse.contains(clean)) {
        add(BistUniverse.instrumentFor(clean));
      }
    }
  }

  if (!settings.scanOnlyFavorites) return pool;
  return [
    for (final ins in pool)
      if (settings.isFavorite(ins.symbol)) ins,
  ];
}

/// Taramada değerlendirilecek kripto paraları yalnızca kullanıcının belirlediği 10 kripto ile sınırlar.
List<Instrument> buildWatchedCryptoForScan(AppSettings settings) {
  if (!settings.scanOnlyFavorites) return CryptoUniverse.instruments;
  return [
    for (final ins in CryptoUniverse.instruments)
      if (settings.isFavorite(ins.symbol)) ins,
  ];
}

const List<Instrument> kWatchedBistStocks = [
  Instrument.bist('THYAO', name: 'Türk Hava Yolları'),
  Instrument.bist('ASELS', name: 'Aselsan'),
  Instrument.bist('AKBNK', name: 'Akbank'),
  Instrument.bist('GARAN', name: 'Garanti BBVA'),
  Instrument.bist('TUPRS', name: 'Tüpraş'),
  Instrument.bist('BIMAS', name: 'BİM Mağazaları'),
  Instrument.bist('KCHOL', name: 'Koç Holding'),
  Instrument.bist('ISCTR', name: 'İş Bankası (C)'),
  Instrument.bist('SAHOL', name: 'Sabancı Holding'),
  Instrument.bist('EREGL', name: 'Erdemir'),
  Instrument.bist('SISE', name: 'Şişecam'),
  Instrument.bist('TCELL', name: 'Turkcell'),
  Instrument.bist('PGSUS', name: 'Pegasus'),
  Instrument.bist('ASTOR', name: 'Astor Enerji'),
  Instrument.bist('FROTO', name: 'Ford Otosan'),
  Instrument.bist('EKGYO', name: 'Emlak Konut GYO'),
];
