import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:imagic/core/models/update_channel.dart';
import 'package:imagic/core/models/update_info.dart';
import 'package:imagic/core/services/update_service.dart';
import 'package:imagic/core/utils/app_install_type.dart';
import 'package:imagic/core/utils/version.dart';

Map<String, dynamic> _asset(String name, {String digest = 'sha256:abc123'}) => {
      'name': name,
      'size': 100,
      'digest': digest,
      'browser_download_url':
          'https://github.com/QiuQianZzz/imagic/releases/download/x/$name',
    };

Map<String, dynamic> _release(
  String tag, {
  List<String>? assets,
  bool draft = false,
  String body = 'notes',
}) =>
    {
      'tag_name': tag,
      'name': '[Release] $tag',
      'body': body,
      'draft': draft,
      'assets': assets == null
          ? []
          : assets.map((n) => _asset(n)).toList(),
    };

UpdateService _serviceWith(
  List<Map<String, dynamic>> releases, {
  AppInstallType installType = AppInstallType.portable,
}) {
  final client = MockClient((request) async {
    expect(request.url.host, 'api.github.com');
    return http.Response(
      jsonEncode(releases),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
  return UpdateService(client: client, installType: installType);
}

void main() {
  final releases = [
    _release('v0.1.0', assets: ['imagic-0.1.0-windows.zip']),
    _release('v0.1.0-beta.2', assets: ['imagic-0.1.0-beta.2-windows.zip']),
    _release('v0.2.0', assets: ['imagic-0.2.0-windows.zip']),
    _release('v0.2.0-rc.1', assets: ['imagic-0.2.0-rc.1-windows.zip']),
    _release('v1.0.0', assets: ['imagic-1.0.0-windows.zip'], draft: true),
    _release('v0.3.0'),
  ];

  test('stable channel picks latest stable release', () async {
    final service = _serviceWith(releases);
    final result = await service.checkForUpdates(
      channel: UpdateChannel.stable,
      current: Version.parse('0.1.0'),
    );
    expect(result.status, UpdateCheckStatus.updateAvailable);
    expect(result.update!.tagName, 'v0.2.0');
  });

  test('stable channel upToDate when current equals latest', () async {
    final service = _serviceWith(releases);
    final result = await service.checkForUpdates(
      channel: UpdateChannel.stable,
      current: Version.parse('0.2.0'),
    );
    expect(result.status, UpdateCheckStatus.upToDate);
  });

  test('stable channel skips newer release without zip asset', () async {
    final service = _serviceWith(releases);
    final result = await service.checkForUpdates(
      channel: UpdateChannel.stable,
      current: Version.parse('0.2.0'),
    );
    expect(result.status, UpdateCheckStatus.upToDate);
  });

  test('beta channel picks latest prerelease only', () async {
    final service = _serviceWith(releases);
    final result = await service.checkForUpdates(
      channel: UpdateChannel.beta,
      current: Version.parse('0.1.0'),
    );
    expect(result.status, UpdateCheckStatus.updateAvailable);
    expect(result.update!.tagName, 'v0.2.0-rc.1');
  });

  test('beta channel ignores releases lower than current', () async {
    final service = _serviceWith(releases);
    final result = await service.checkForUpdates(
      channel: UpdateChannel.beta,
      current: Version.parse('0.2.0'),
    );
    expect(result.status, UpdateCheckStatus.upToDate);
  });

  test('all channel picks highest across both types', () async {
    final service = _serviceWith(releases);
    final result = await service.checkForUpdates(
      channel: UpdateChannel.all,
      current: Version.parse('0.1.0'),
    );
    expect(result.status, UpdateCheckStatus.updateAvailable);
    expect(result.update!.tagName, 'v0.2.0');
  });

  test('digest sha256 prefix is stripped', () async {
    final service = _serviceWith([_release('v0.2.0', assets: ['imagic-0.2.0-windows.zip'])]);
    final result = await service.checkForUpdates(
      channel: UpdateChannel.stable,
      current: Version.parse('0.1.0'),
    );
    expect(result.update!.assetSha256, 'abc123');
  });

  test('non-200 response reports error', () async {
    final client = MockClient((_) async => http.Response('oops', 500));
    final service = UpdateService(client: client);
    final result = await service.checkForUpdates(
      channel: UpdateChannel.stable,
      current: Version.parse('0.1.0'),
    );
    expect(result.status, UpdateCheckStatus.error);
    expect(result.error, contains('500'));
  });

  test('network exception reports error', () async {
    final client = MockClient((_) async => throw Exception('network down'));
    final service = UpdateService(client: client);
    final result = await service.checkForUpdates(
      channel: UpdateChannel.stable,
      current: Version.parse('0.1.0'),
    );
    expect(result.status, UpdateCheckStatus.error);
  });

  group('asset type detection', () {
    test('portable prefers zip over exe and msix', () async {
      final service = _serviceWith(
        [_release('v0.2.0', assets: [
          'imagic-0.2.0-setup.exe',
          'imagic-0.2.0-windows.zip',
          'imagic-0.2.0.msix',
        ])],
        installType: AppInstallType.portable,
      );
      final result = await service.checkForUpdates(
        channel: UpdateChannel.stable,
        current: Version.parse('0.1.0'),
      );
      expect(result.update!.assetType, AssetType.zip);
    });

    test('installer prefers exe over zip and msix', () async {
      final service = _serviceWith(
        [_release('v0.2.0', assets: [
          'imagic-0.2.0-windows.zip',
          'imagic-0.2.0-setup.exe',
          'imagic-0.2.0.msix',
        ])],
        installType: AppInstallType.installer,
      );
      final result = await service.checkForUpdates(
        channel: UpdateChannel.stable,
        current: Version.parse('0.1.0'),
      );
      expect(result.update!.assetType, AssetType.exe);
    });

    test('msix install type only picks msix asset', () async {
      final service = _serviceWith(
        [_release('v0.2.0', assets: [
          'imagic-0.2.0-windows.zip',
          'imagic-0.2.0-setup.exe',
          'imagic-0.2.0.msix',
        ])],
        installType: AppInstallType.msix,
      );
      final result = await service.checkForUpdates(
        channel: UpdateChannel.stable,
        current: Version.parse('0.1.0'),
      );
      expect(result.update!.assetType, AssetType.msix);
    });

    test('portable falls back to exe when no zip', () async {
      final service = _serviceWith(
        [_release('v0.2.0', assets: [
          'imagic-0.2.0-setup.exe',
          'imagic-0.2.0.msix',
        ])],
        installType: AppInstallType.portable,
      );
      final result = await service.checkForUpdates(
        channel: UpdateChannel.stable,
        current: Version.parse('0.1.0'),
      );
      expect(result.update!.assetType, AssetType.exe);
    });

    test('installer falls back to msix when no exe', () async {
      final service = _serviceWith(
        [_release('v0.2.0', assets: [
          'imagic-0.2.0-windows.zip',
          'imagic-0.2.0.msix',
        ])],
        installType: AppInstallType.installer,
      );
      final result = await service.checkForUpdates(
        channel: UpdateChannel.stable,
        current: Version.parse('0.1.0'),
      );
      expect(result.update!.assetType, AssetType.msix);
    });

    test('msix bundle extension is matched', () async {
      final service = _serviceWith(
        [_release('v0.2.0', assets: ['imagic-0.2.0.msixbundle'])],
        installType: AppInstallType.msix,
      );
      final result = await service.checkForUpdates(
        channel: UpdateChannel.stable,
        current: Version.parse('0.1.0'),
      );
      expect(result.update!.assetType, AssetType.msix);
    });

    test('exe with installer keyword is matched', () async {
      final service = _serviceWith(
        [_release('v0.2.0', assets: ['Imagic-0.2.0-installer.exe'])],
        installType: AppInstallType.installer,
      );
      final result = await service.checkForUpdates(
        channel: UpdateChannel.stable,
        current: Version.parse('0.1.0'),
      );
      expect(result.update!.assetType, AssetType.exe);
    });

    test('release without matching asset is skipped', () async {
      final service = _serviceWith(
        [_release('v0.2.0', assets: ['imagic-0.2.0-linux.tar.gz'])],
        installType: AppInstallType.portable,
      );
      final result = await service.checkForUpdates(
        channel: UpdateChannel.stable,
        current: Version.parse('0.1.0'),
      );
      expect(result.status, UpdateCheckStatus.upToDate);
    });
  });
}
