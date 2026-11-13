import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pusula_core/pusula_core.dart';

import 'apk_downloader_stub.dart' if (dart.library.io) 'apk_downloader_io.dart';

/// Uygulama sürümü (SemVer + Android versionCode).
class AppVersion {
  const AppVersion({
    required this.major,
    required this.minor,
    required this.patch,
    this.buildNumber = 0,
  });

  final int major;
  final int minor;
  final int patch;
  final int buildNumber;

  String get semver => '$major.$minor.$patch';
  String get label => buildNumber > 0 ? 'v$semver+$buildNumber' : 'v$semver';

  /// `v1.2.0+5`, `1.2.0` veya `pusula-v1.2.0+5.apk` gibi metinlerden sürüm çıkarır.
  static AppVersion? tryParse(String raw) {
    final m = RegExp(r'v?(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?').firstMatch(raw.trim());
    if (m == null) return null;
    return AppVersion(
      major: int.parse(m.group(1)!),
      minor: int.parse(m.group(2)!),
      patch: int.parse(m.group(3)!),
      buildNumber: m.group(4) != null ? int.parse(m.group(4)!) : 0,
    );
  }

  /// Bu sürüm [other] sürümünden daha yeni mi?
  /// İki tarafta da `buildNumber > 0` varsa Android `versionCode` esas alınır; yoksa SemVer karşılaştırılır.
  bool isNewerThan(AppVersion other) {
    if (buildNumber > 0 && other.buildNumber > 0) {
      if (buildNumber != other.buildNumber) return buildNumber > other.buildNumber;
    }
    if (major != other.major) return major > other.major;
    if (minor != other.minor) return minor > other.minor;
    if (patch != other.patch) return patch > other.patch;
    return buildNumber > other.buildNumber;
  }

  @override
  bool operator ==(Object other) =>
      other is AppVersion &&
      other.major == major &&
      other.minor == minor &&
      other.patch == patch &&
      other.buildNumber == buildNumber;

  @override
  int get hashCode => Object.hash(major, minor, patch, buildNumber);
}

/// GitHub Releases üzerinde yayımlanan tek bir APK sürümü.
class AppReleaseInfo {
  const AppReleaseInfo({
    required this.version,
    required this.tagName,
    required this.assetName,
    required this.downloadUrl,
    required this.sizeBytes,
    required this.releaseNotes,
    this.publishedAt,
  });

  final AppVersion version;
  final String tagName;
  final String assetName;
  final String downloadUrl;
  final int sizeBytes;
  final String releaseNotes;
  final DateTime? publishedAt;

  String get sizeLabel {
    if (sizeBytes <= 0) return '';
    final mb = sizeBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1).replaceAll('.', ',')} MB';
  }
}

enum UpdateStatus {
  idle,
  checking,
  upToDate,
  available,
  downloading,
  permissionRequired,
  readyToInstall,
  error,
}

class AppUpdateState {
  const AppUpdateState({
    required this.status,
    required this.currentVersion,
    this.availableRelease,
    this.downloadProgress,
    this.message,
  });

  const AppUpdateState.idle()
      : status = UpdateStatus.idle,
        currentVersion = AppUpdateService.fallbackVersion,
        availableRelease = null,
        downloadProgress = null,
        message = null;

  final UpdateStatus status;
  final AppVersion currentVersion;
  final AppReleaseInfo? availableRelease;
  final double? downloadProgress;
  final String? message;

  AppUpdateState copyWith({
    UpdateStatus? status,
    AppVersion? currentVersion,
    AppReleaseInfo? availableRelease,
    bool clearRelease = false,
    double? downloadProgress,
    bool clearProgress = false,
    String? message,
    bool clearMessage = false,
  }) =>
      AppUpdateState(
        status: status ?? this.status,
        currentVersion: currentVersion ?? this.currentVersion,
        availableRelease: clearRelease ? null : (availableRelease ?? this.availableRelease),
        downloadProgress: clearProgress ? null : (downloadProgress ?? this.downloadProgress),
        message: clearMessage ? null : (message ?? this.message),
      );
}

class AppUpdateCheckOutcome {
  const AppUpdateCheckOutcome({
    required this.currentVersion,
    this.latestRelease,
    required this.updateAvailable,
  });

  final AppVersion currentVersion;
  final AppReleaseInfo? latestRelease;
  final bool updateAvailable;
}

/// GitHub Releases üzerinden ücretsiz uygulama içi APK güncelleyici servisi.
class AppUpdateService {
  AppUpdateService({
    HttpFetcher? fetcher,
    MethodChannel? channel,
    this.isWebOverride,
  })  : _fetcher = fetcher ?? NetworkHttpFetcher(),
        _ownsFetcher = fetcher == null,
        _channel = channel ?? const MethodChannel('app.pusula/update');

  static const AppVersion fallbackVersion = AppVersion(major: 1, minor: 0, patch: 0, buildNumber: 1);

  final HttpFetcher _fetcher;
  final bool _ownsFetcher;
  final MethodChannel _channel;
  final bool? isWebOverride;

  bool get _isWeb => isWebOverride ?? kIsWeb;

  static final RegExp _repoRegex = RegExp(r'^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$');

  static bool isValidGitHubRepo(String repo) => _repoRegex.hasMatch(repo.trim());

  /// Güvenlik: Yalnızca HTTPS ve resmi GitHub alan adlarından APK indirilir.
  static bool isTrustedDownloadUri(Uri uri) {
    if (uri.scheme != 'https') return false;
    final h = uri.host.toLowerCase();
    return h == 'github.com' || h == 'api.github.com' || h.endsWith('.githubusercontent.com');
  }

  /// GitHub Releases JSON yanıtından sürüm ve APK dosyasını ayıklar.
  static AppReleaseInfo? parseReleaseJson(Map<String, Object?> json) {
    if (json['draft'] == true) return null;
    final tag = '${json['tag_name'] ?? ''}'.trim();
    final name = '${json['name'] ?? ''}'.trim();
    final rawAssets = (json['assets'] as List?) ?? const [];

    Map<String, Object?>? apkAsset;
    for (final item in rawAssets) {
      if (item is! Map) continue;
      final m = item.cast<String, Object?>();
      final assetName = '${m['name'] ?? ''}'.toLowerCase();
      if (!assetName.endsWith('.apk')) continue;
      apkAsset = m;
      if (assetName.contains('release') || assetName.contains('pusula')) break;
    }
    if (apkAsset == null) return null;

    final assetName = '${apkAsset['name'] ?? ''}';
    final url = '${apkAsset['browser_download_url'] ?? ''}'.trim();
    final uri = Uri.tryParse(url);
    if (uri == null || !isTrustedDownloadUri(uri)) return null;

    final fromAsset = AppVersion.tryParse(assetName);
    final fromTag = AppVersion.tryParse(tag);
    final fromName = AppVersion.tryParse(name);
    var version = (fromAsset != null && fromAsset.buildNumber > 0) ? fromAsset : (fromTag ?? fromName ?? fromAsset);
    if (version == null) return null;

    final sizeBytes = (apkAsset['size'] as num?)?.toInt() ?? 0;
    final body = '${json['body'] ?? ''}'.trim();
    final publishedRaw = json['published_at'] as String?;

    return AppReleaseInfo(
      version: version,
      tagName: tag.isNotEmpty ? tag : version.label,
      assetName: assetName,
      downloadUrl: url,
      sizeBytes: sizeBytes,
      releaseNotes: body,
      publishedAt: publishedRaw != null ? DateTime.tryParse(publishedRaw)?.toUtc() : null,
    );
  }

  Future<AppVersion> installedVersion() async {
    if (_isWeb) return fallbackVersion;
    try {
      final map = await _channel.invokeMapMethod<String, dynamic>('getAppVersion');
      if (map == null) return fallbackVersion;
      final vName = '${map['versionName'] ?? '1.0.0'}';
      final vCode = (map['versionCode'] as num?)?.toInt() ?? 1;
      final parsed = AppVersion.tryParse(vName);
      if (parsed == null) return fallbackVersion;
      return AppVersion(
        major: parsed.major,
        minor: parsed.minor,
        patch: parsed.patch,
        buildNumber: vCode,
      );
    } on MissingPluginException {
      return fallbackVersion;
    } on PlatformException {
      return fallbackVersion;
    }
  }

  Future<AppUpdateCheckOutcome> checkLatest({required String repo}) async {
    final trimmed = repo.trim();
    if (!isValidGitHubRepo(trimmed)) {
      throw FormatException('GitHub deposu "kullanici/depo" biçiminde olmalıdır.');
    }
    final current = await installedVersion();
    final uri = Uri.parse('https://api.github.com/repos/$trimmed/releases/latest');
    final body = await _fetcher.getText(
      uri,
      headers: const {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      },
      timeout: const Duration(seconds: 12),
    );
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const FormatException('Beklenmeyen GitHub sürüm yanıtı.');
    }
    final release = parseReleaseJson(decoded.cast<String, Object?>());
    if (release == null) {
      return AppUpdateCheckOutcome(currentVersion: current, latestRelease: null, updateAvailable: false);
    }
    return AppUpdateCheckOutcome(
      currentVersion: current,
      latestRelease: release,
      updateAvailable: release.version.isNewerThan(current),
    );
  }

  Future<UpdateStatus> downloadAndInstall(
    AppReleaseInfo release, {
    void Function(double progress)? onProgress,
  }) async {
    if (_isWeb) {
      throw UnsupportedError('Web sürümünde sayfayı yenilemek yeterlidir; APK yalnızca Android içindir.');
    }
    final uri = Uri.parse(release.downloadUrl);
    if (!isTrustedDownloadUri(uri)) {
      throw ArgumentError('Güvenilmeyen güncelleme bağlantısı reddedildi.');
    }

    final allowed = await _channel.invokeMethod<bool>('canRequestPackageInstalls') ?? false;
    if (!allowed) {
      await _channel.invokeMethod<void>('openUnknownSourcesSettings');
      return UpdateStatus.permissionRequired;
    }

    final cacheDir = await _channel.invokeMethod<String>('getUpdateCacheDir');
    if (cacheDir == null || cacheDir.isEmpty) {
      throw StateError('Güncelleme önbellek klasörü açılamadı.');
    }

    final destPath = '$cacheDir/pusula-update.apk';
    final savedPath = await downloadApkToFile(
      uri: uri,
      destinationPath: destPath,
      onProgress: onProgress,
    );
    await _channel.invokeMethod<bool>('installApk', {'path': savedPath});
    return UpdateStatus.readyToInstall;
  }

  void dispose() {
    if (_ownsFetcher && _fetcher is NetworkHttpFetcher) {
      _fetcher.close();
    }
  }
}
