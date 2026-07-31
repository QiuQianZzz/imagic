import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:imagic/core/models/update_info.dart';
import 'package:imagic/core/services/update_service.dart';
import 'package:imagic/core/utils/version.dart';

UpdateInfo _update({String sha = ''}) => UpdateInfo(
      version: Version.parse('0.2.0'),
      tagName: 'v0.2.0',
      title: '[Release] v0.2.0',
      body: 'notes',
      publishedAt: '',
      assetType: AssetType.zip,
      assetName: 'imagic-0.2.0-windows.zip',
      assetSize: 0,
      assetSha256: sha,
      assetUrl: 'https://example.com/imagic-0.2.0-windows.zip',
    );

void main() {
  test('downloadToFile writes body and reports progress', () async {
    final bytes = utf8.encode('hello imagic update');
    final client = MockClient((_) async => http.Response.bytes(bytes, 200));
    final service = UpdateService(client: client);
    final tempDir = await Directory.systemTemp.createTemp('imagic_test_');
    addTearDown(() => tempDir.delete(recursive: true));
    final dest = '${tempDir.path}/update.zip';

    await service.downloadToFile(_update(), dest);

    expect(await File(dest).readAsBytes(), bytes);
    expect(service.downloadProgress, 1.0);
  });

  test('downloadToFile throws on non-200', () async {
    final client = MockClient((_) async => http.Response('oops', 500));
    final service = UpdateService(client: client);
    final tempDir = await Directory.systemTemp.createTemp('imagic_test_');
    addTearDown(() => tempDir.delete(recursive: true));

    await expectLater(
      service.downloadToFile(_update(), '${tempDir.path}/update.zip'),
      throwsA(isA<UpdateDownloadException>()),
    );
  });

  test('sha256Of returns lowercase hex digest', () async {
    final bytes = utf8.encode('the quick brown fox');
    final tempDir = await Directory.systemTemp.createTemp('imagic_test_');
    addTearDown(() => tempDir.delete(recursive: true));
    final file = File('${tempDir.path}/x.bin');
    await file.writeAsBytes(bytes);

    final service = UpdateService(client: MockClient((_) async => http.Response('', 200)));
    expect(await service.sha256Of(file.path), sha256.convert(bytes).toString());
  });

  test('install fails when sha256 does not match', () async {
    if (!Platform.isWindows) return;
    final bytes = utf8.encode('fake zip bytes');
    final client = MockClient((_) async => http.Response.bytes(bytes, 200));
    final service = UpdateService(client: client);

    final result =
        await service.downloadAndInstall(_update(sha: 'f' * 64));

    expect(result.success, isFalse);
    expect(result.error, contains('SHA-256'));
    expect(service.stage, UpdateStage.error);
  });

  test('install refuses when digest is missing', () async {
    if (!Platform.isWindows) return;
    final bytes = utf8.encode('fake zip bytes');
    final client = MockClient((_) async => http.Response.bytes(bytes, 200));
    final service = UpdateService(client: client);

    final result = await service.downloadAndInstall(_update());

    expect(result.success, isFalse);
    expect(result.error, contains('SHA-256'));
  });

  group('writeInstallerScript', () {
    test('script contains all required paths and commands', () async {
      final service = UpdateService(client: MockClient((_) async => http.Response('', 200)));
      final tempDir = await Directory.systemTemp.createTemp('imagic_script_test_');
      addTearDown(() => tempDir.delete(recursive: true));

      final assetPath = '${tempDir.path}\\update.zip';
      final scriptPath = await service.writeInstallerScript(assetPath, tempDir.path);
      final content = await File(scriptPath).readAsString();

      // 核心变量与命令齐全
      expect(content, contains('set "ZIP=$assetPath"'));
      expect(content, contains('set "TEMPDIR=${tempDir.path}"'));
      expect(content, contains('tar -xf "%ZIP%" -C "%EXTRACTED%"'));
      expect(content, contains('robocopy "%EXTRACTED%" "%APPDIR%"'));
      expect(content, contains('start "" "%EXEPATH%"'));
      // 退出码检查
      expect(content, contains('if errorlevel 1'));
      expect(content, contains('if errorlevel 8'));
      // 错误日志路径：Dart 源码中 \\u 会被解析为单反斜杠写入 bat，bat 中为 %TEMPDIR%\update_error.log
      expect(content, contains(r'%TEMPDIR%\update_error.log'));
      // 确认 bat 文件里不是两个连续反斜杠（bat 虽能容忍，但不规范）
      expect(content, isNot(contains(r'%TEMPDIR%\\update_error.log')));
    });

    test('script handles paths with spaces', () async {
      final service = UpdateService(client: MockClient((_) async => http.Response('', 200)));
      final tempDir = await Directory.systemTemp.createTemp('imagic space test_');
      addTearDown(() => tempDir.delete(recursive: true));

      final assetPath = '${tempDir.path}\\my update.zip';
      final scriptPath = await service.writeInstallerScript(assetPath, tempDir.path);
      final content = await File(scriptPath).readAsString();

      // 含空格的路径应被引号包裹
      expect(content, contains('set "ZIP=$assetPath"'));
    });
  });
}
