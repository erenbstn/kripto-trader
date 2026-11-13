import 'dart:async';

import 'package:http/http.dart' as http;

import 'errors.dart';

/// Ağ erişimi soyutlaması. Testlerde sahte uygulama kullanılır; gerçek ağ çağrısı yapılmaz.
abstract class HttpFetcher {
  Future<String> getText(Uri uri, {Map<String, String>? headers, Duration timeout});
}

/// `package:http` tabanlı gerçek uygulama. Çerez, kimlik bilgisi veya anahtar göndermez.
class NetworkHttpFetcher implements HttpFetcher {
  NetworkHttpFetcher({
    http.Client? client,
    this.userAgent = 'Mozilla/5.0 (compatible; pusula/0.1)',
    this.sendUserAgent = true,
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String userAgent;
  final bool sendUserAgent;

  @override
  Future<String> getText(
    Uri uri, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final http.Response resp;
    try {
      resp = await _client
          .get(
            uri,
            headers: {
              if (sendUserAgent) 'User-Agent': userAgent,
              'Accept': 'application/json',
              ...?headers,
            },
          )
          .timeout(timeout);
    } on TimeoutException {
      throw HttpFetchException('zaman aşımı (${uri.host})');
    } catch (e) {
      // Hata metnine tam URL konmaz; yalnızca sunucu adı.
      throw HttpFetchException('bağlantı hatası (${uri.host}): ${e.runtimeType}');
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw HttpFetchException('HTTP ${resp.statusCode} (${uri.host})', status: resp.statusCode);
    }
    return resp.body;
  }

  void close() => _client.close();
}
