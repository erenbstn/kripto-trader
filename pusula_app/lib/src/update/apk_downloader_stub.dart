/// Web ve Android dışı platformlar için yer tutucu APK indirici.
Future<String> downloadApkToFile({
  required Uri uri,
  required String destinationPath,
  void Function(double progress)? onProgress,
}) {
  throw UnsupportedError('APK indirme yalnızca Android cihazda desteklenir.');
}

