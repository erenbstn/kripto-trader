import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pusula_app/src/notifications/notification_engine.dart';
import 'package:pusula_app/src/state/pusula_controller.dart';
import 'package:pusula_app/src/storage/sqlite_storage.dart';
import 'package:pusula_app/src/update/app_updater.dart';
import 'package:pusula_core/pusula_core.dart';

class _FakeFetcher implements HttpFetcher {
  _FakeFetcher(this.handler);
  final Future<String> Function(Uri uri, Map<String, String>? headers) handler;

  @override
  Future<String> getText(
    Uri uri, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 12),
  }) =>
      handler(uri, headers);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppVersion ve GitHub Releases ayrıştırma', () {
    test('etiket ve APK dosya adından sürüm ve build numarasını doğru çıkarır', () {
      final v1 = AppVersion.tryParse('v1.2.3+14');
      expect(v1, isNotNull);
      expect(v1!.semver, '1.2.3');
      expect(v1.buildNumber, 14);
      expect(v1.label, 'v1.2.3+14');

      final v2 = AppVersion.tryParse('pusula-v1.2.4.apk');
      expect(v2, isNotNull);
      expect(v2!.semver, '1.2.4');
      expect(v2.buildNumber, 0);

      expect(v1.isNewerThan(const AppVersion(major: 1, minor: 2, patch: 3, buildNumber: 13)), isTrue);
      expect(const AppVersion(major: 1, minor: 2, patch: 3, buildNumber: 13).isNewerThan(v1), isFalse);
      expect(v2.isNewerThan(const AppVersion(major: 1, minor: 2, patch: 3, buildNumber: 0)), isTrue);
    });

    test('yalnızca güvenli GitHub HTTPS APK bağlantılarını kabul eder', () {
      expect(
        AppUpdateService.isTrustedDownloadUri(
          Uri.parse('https://github.com/eren/kripto-trader/releases/download/v1.0.1+2/pusula.apk'),
        ),
        isTrue,
      );
      expect(
        AppUpdateService.isTrustedDownloadUri(
          Uri.parse('https://objects.githubusercontent.com/github-production-release-asset/pusula.apk'),
        ),
        isTrue,
      );
      expect(
        AppUpdateService.isTrustedDownloadUri(Uri.parse('http://github.com/eren/repo/pusula.apk')),
        isFalse,
      );
      expect(
        AppUpdateService.isTrustedDownloadUri(Uri.parse('https://evil.example.com/pusula.apk')),
        isFalse,
      );
    });

    test('parseReleaseJson taslak olmayan sürümdeki .apk varlığını bulur', () {
      final parsed = AppUpdateService.parseReleaseJson({
        'draft': false,
        'tag_name': 'v1.1.0+3',
        'name': 'Pusula v1.1.0+3',
        'body': 'Yeni sürüm notları',
        'assets': [
          {
            'name': 'checksums.txt',
            'size': 256,
            'browser_download_url': 'https://github.com/eren/kripto-trader/releases/download/v1.1.0+3/checksums.txt',
          },
          {
            'name': 'pusula-v1.1.0+3.apk',
            'size': 24117248,
            'browser_download_url':
                'https://github.com/eren/kripto-trader/releases/download/v1.1.0+3/pusula-v1.1.0+3.apk',
          },
        ],
      });

      expect(parsed, isNotNull);
      expect(parsed!.version, const AppVersion(major: 1, minor: 1, patch: 0, buildNumber: 3));
      expect(parsed.assetName, 'pusula-v1.1.0+3.apk');
      expect(parsed.sizeLabel, '23,0 MB');
    });

    test('checkLatest yeni sürüm bulunduğunda updateAvailable true döner', () async {
      final service = AppUpdateService(
        isWebOverride: true,
        fetcher: _FakeFetcher((uri, headers) async {
          expect(uri.toString(), 'https://api.github.com/repos/eren/kripto-trader/releases/latest');
          return jsonEncode({
            'draft': false,
            'tag_name': 'v1.0.1+2',
            'assets': [
              {
                'name': 'pusula-v1.0.1+2.apk',
                'size': 20971520,
                'browser_download_url':
                    'https://github.com/eren/kripto-trader/releases/download/v1.0.1+2/pusula-v1.0.1+2.apk',
              },
            ],
          });
        }),
      );

      final outcome = await service.checkLatest(repo: 'eren/kripto-trader');
      expect(outcome.currentVersion, AppUpdateService.fallbackVersion);
      expect(outcome.updateAvailable, isTrue);
      expect(outcome.latestRelease?.version.label, 'v1.0.1+2');
    });

    test('PusulaController depo kaydedip yeni sürümü duruma yansıtır', () async {
      final service = AppUpdateService(
        isWebOverride: true,
        fetcher: _FakeFetcher((uri, headers) async => jsonEncode({
              'draft': false,
              'tag_name': 'v1.3.0+8',
              'assets': [
                {
                  'name': 'pusula-v1.3.0+8.apk',
                  'size': 15728640,
                  'browser_download_url':
                      'https://github.com/eren/kripto-trader/releases/download/v1.3.0+8/pusula-v1.3.0+8.apk',
                },
              ],
            })),
      );

      final container = ProviderContainer(
        overrides: [
          storageBundleProvider.overrideWithValue(StorageBundle.inMemory()),
          notificationGatewayProvider.overrideWithValue(MemoryNotificationGateway()),
          appUpdateServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);

      final ctrl = container.read(pusulaControllerProvider.notifier);
      await ctrl.ready;
      await ctrl.updateGitHubRepo('eren/kripto-trader');
      await ctrl.checkForAppUpdate();

      final st = container.read(pusulaControllerProvider);
      expect(st.settings.updateRepo, 'eren/kripto-trader');
      expect(st.updateState.status, UpdateStatus.available);
      expect(st.updateState.availableRelease?.version.label, 'v1.3.0+8');
    });
  });
}

