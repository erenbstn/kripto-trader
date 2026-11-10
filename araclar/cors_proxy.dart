// Yerel PC (Chrome / Web) önizlemesi için salt-okunur CORS köprüsü.
// Yalnızca 127.0.0.1:8787 üzerinde dinler ve yalnızca Pusula'nın beyaz listedeki
// açık piyasa veri uçlarına (Yahoo Finance, İş Yatırım, Binance) GET isteği iletir.
import 'dart:io';

const Set<String> _allowedHosts = {
  'query1.finance.yahoo.com',
  'query2.finance.yahoo.com',
  'www.isyatirim.com.tr',
  'data-api.binance.vision',
  'api.binance.com',
  'api1.binance.com',
  'fapi.binance.com',
};

Future<void> main(List<String> args) async {
  final port = args.isNotEmpty ? (int.tryParse(args.first) ?? 8787) : 8787;
  final HttpServer server;
  try {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  } on SocketException {
    // Port zaten kullanımda (köprü zaten çalışıyor).
    return;
  }

  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 12)
    ..userAgent = 'Mozilla/5.0 (compatible; pusula/0.1)';

  await for (final HttpRequest req in server) {
    req.response.headers
      ..set('Access-Control-Allow-Origin', '*')
      ..set('Access-Control-Allow-Methods', 'GET, OPTIONS')
      ..set('Access-Control-Allow-Headers', '*');

    if (req.method == 'OPTIONS') {
      req.response.statusCode = HttpStatus.noContent;
      await req.response.close();
      continue;
    }

    if (req.method != 'GET' || req.uri.path != '/proxy') {
      req.response.statusCode = HttpStatus.notFound;
      req.response.write('Yalnizca GET /proxy?url=... desteklenir.');
      await req.response.close();
      continue;
    }

    final rawUrl = req.uri.queryParameters['url'];
    final target = rawUrl != null ? Uri.tryParse(rawUrl) : null;
    if (target == null || target.scheme != 'https' || !_allowedHosts.contains(target.host)) {
      req.response.statusCode = HttpStatus.forbidden;
      req.response.write('Desteklenmeyen hedef sunucu.');
      await req.response.close();
      continue;
    }

    try {
      final upstreamReq = await client.getUrl(target);
      upstreamReq.headers.set('Accept', 'application/json');
      final upstreamResp = await upstreamReq.close().timeout(const Duration(seconds: 15));
      req.response.statusCode = upstreamResp.statusCode;
      req.response.headers.contentType = ContentType.json;
      await upstreamResp.pipe(req.response);
    } catch (e) {
      req.response.statusCode = HttpStatus.badGateway;
      req.response.write('Ust sunucu hatasi: ${e.runtimeType}');
      await req.response.close();
    }
  }
}

