import 'dart:io';

/// Güvenilir HTTPS kaynağından APK dosyasını akış (stream) ile diske indirir ve ilerleme bildirir.
Future<String> downloadApkToFile({
  required Uri uri,
  required String destinationPath,
  void Function(double progress)? onProgress,
}) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
  try {
    final req = await client.getUrl(uri);
    req.headers.set(HttpHeaders.userAgentHeader, 'Pusula-App-Updater/1.0');
    final resp = await req.close();
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw HttpException('İndirme sunucusu HTTP ${resp.statusCode} döndürdü.', uri: uri);
    }

    final file = File(destinationPath);
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    final tmpFile = File('$destinationPath.part');
    final sink = tmpFile.openWrite();
    final total = resp.contentLength;
    var received = 0;

    try {
      await for (final chunk in resp) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          onProgress?.call((received / total).clamp(0.0, 1.0));
        }
      }
      await sink.flush();
    } finally {
      await sink.close();
    }

    if (await file.exists()) {
      await file.delete();
    }
    await tmpFile.rename(file.path);
    onProgress?.call(1.0);
    return file.path;
  } finally {
    client.close(force: true);
  }
}

