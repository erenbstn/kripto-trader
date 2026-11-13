import 'package:flutter/foundation.dart';
import 'package:pusula_core/pusula_core.dart';

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
