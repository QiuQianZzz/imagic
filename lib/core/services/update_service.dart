import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../models/update_channel.dart';
import '../models/update_info.dart';
import '../utils/app_install_type.dart';
import '../utils/version.dart';

/// 检查更新的结果状态。
enum UpdateCheckStatus {
  /// 已是最新版本。
  upToDate,

  /// 发现更高版本。
  updateAvailable,

  /// 检查失败（网络异常 / 接口异常等）。
  error,
}

/// 更新安装所处的阶段。
enum UpdateStage { idle, downloading, verifying, installing, done, error }

/// 一次更新检查的结果。
class UpdateCheckResult {
  final UpdateCheckStatus status;
  final UpdateInfo? update;
  final String? error;

  const UpdateCheckResult({required this.status, this.update, this.error});
}

/// 一次更新安装的结果。
class UpdateInstallResult {
  final bool success;
  final String? error;

  const UpdateInstallResult({required this.success, this.error});
}

/// 更新检查服务：查询 GitHub Releases，按渠道过滤并选取最高候选版本。
///
/// 单例通过 [UpdateService.instance] 获取；构造时可注入 [http.Client]
/// 与仓库坐标，便于单元测试。
class UpdateService extends ChangeNotifier {
  UpdateService({
    http.Client? client,
    String? repoOwner,
    String? repoName,
    AppInstallType? installType,
  }) : _client = client ?? http.Client(),
       _repoOwner = repoOwner ?? _defaultOwner,
       _repoName = repoName ?? _defaultName,
       _installType = installType ?? AppInstallTypeDetector.detect();

  static const String _defaultOwner = 'QiuQianZzz';
  static const String _defaultName = 'imagic';

  /// 全局单例，使用默认仓库与真实网络。
  static final UpdateService instance = UpdateService();

  final http.Client _client;
  final String _repoOwner;
  final String _repoName;
  final AppInstallType _installType;

  bool _checking = false;
  UpdateCheckResult? _lastResult;
  UpdateStage _stage = UpdateStage.idle;
  double? _downloadProgress;
  String? _installError;
  DateTime? _lastCheck;

  /// 是否正在检查。
  bool get checking => _checking;

  /// 最近一次检查结果。
  UpdateCheckResult? get lastResult => _lastResult;

  /// 更新安装所处阶段。
  UpdateStage get stage => _stage;

  /// 下载进度 0~1；未在下载时为 `null`。
  double? get downloadProgress => _downloadProgress;

  /// 安装失败原因。
  String? get installError => _installError;

  /// 检查是否有更新。
  ///
  /// [channel] 决定候选范围；[current] 为当前版本，高于它即视为有更新。
  /// [force] 为 true 时跳过会话内节流，强制请求 GitHub API。
  Future<UpdateCheckResult> checkForUpdates({
    required UpdateChannel channel,
    required Version current,
    bool force = false,
  }) async {
    // 会话内节流：5 分钟内重复检查直接返回上次结果，避免触发 GitHub 限流
    if (!force &&
        _lastResult != null &&
        _lastCheck != null &&
        DateTime.now().difference(_lastCheck!) < const Duration(minutes: 5)) {
      return _lastResult!;
    }
    _checking = true;
    _lastResult = null;
    // 重置安装状态，避免上次失败的错误信息残留到新一次检查
    _stage = UpdateStage.idle;
    _installError = null;
    _downloadProgress = null;
    notifyListeners();
    try {
      final uri = Uri.https(
        'api.github.com',
        '/repos/$_repoOwner/$_repoName/releases',
        {'per_page': '30'},
      );
      final resp = await _client
          .get(
            uri,
            headers: const {
              'User-Agent': 'imagic-updater',
              'Accept': 'application/vnd.github+json',
            },
          )
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) {
        final message = (resp.statusCode == 403 || resp.statusCode == 429)
            ? 'GitHub 接口请求过于频繁（${resp.statusCode}），请稍后再试'
            : 'GitHub 接口返回 ${resp.statusCode}';
        _lastResult = UpdateCheckResult(
          status: UpdateCheckStatus.error,
          error: message,
        );
        return _lastResult!;
      }
      final list = jsonDecode(utf8.decode(resp.bodyBytes)) as List<dynamic>;
      final latest = _latestCandidate(list, channel);
      if (latest == null || !(latest.version > current)) {
        _lastResult = UpdateCheckResult(status: UpdateCheckStatus.upToDate);
      } else {
        _lastResult = UpdateCheckResult(
          status: UpdateCheckStatus.updateAvailable,
          update: latest,
        );
      }
      return _lastResult!;
    } on TimeoutException {
      _lastResult = UpdateCheckResult(
        status: UpdateCheckStatus.error,
        error: '检查更新超时，请检查网络后重试',
      );
      return _lastResult!;
    } catch (e) {
      debugPrint('检查更新失败：$e');
      _lastResult = UpdateCheckResult(
        status: UpdateCheckStatus.error,
        error: '检查更新失败，请检查网络连接后重试',
      );
      return _lastResult!;
    } finally {
      _checking = false;
      _lastCheck = DateTime.now();
      notifyListeners();
    }
  }

  /// 在满足渠道的候选里取版本最高、且带 Windows 安装包的那个。
  UpdateInfo? _latestCandidate(List<dynamic> releases, UpdateChannel channel) {
    UpdateInfo? latest;
    for (final raw in releases) {
      final map = raw as Map<String, dynamic>;
      if (map['draft'] == true) continue;
      final tagName = (map['tag_name'] as String?) ?? '';
      Version version;
      try {
        version = Version.parse(tagName);
      } on FormatException {
        continue;
      }
      if (version.isPrerelease && channel == UpdateChannel.stable) {
        // 正式版渠道：跳过预发行版
        continue;
      }
      final found = _findWindowsAsset(map['assets']);
      if (found == null) continue;
      if (latest == null || version > latest.version) {
        latest = _buildUpdateInfo(map, found.asset, version, found.type);
      }
    }
    return latest;
  }

  /// 从资产的 `digest`（如 `sha256:xxxx`）中提取期望哈希。
  static String _extractSha256(String digest) => digest.startsWith('sha256:')
      ? digest.substring('sha256:'.length)
      : digest;

  /// 在 Release 资产中查找 Windows 安装包，优先级由当前安装形式决定：
  /// - MSIX → 仅 msix（沙盒环境无法用 zip/exe 替换）
  /// - 安装版 → exe > msix > zip（应使用安装程序更新）
  /// - 绿色版 → zip > exe > msix（优先自动替换）
  ({Map<String, dynamic> asset, AssetType type})? _findWindowsAsset(
    Object? assets,
  ) {
    if (assets is! List) return null;
    final priorities = switch (_installType) {
      AppInstallType.msix => [AssetType.msix],
      AppInstallType.installer => [
        AssetType.exe,
        AssetType.msix,
        AssetType.zip,
      ],
      AppInstallType.portable => [AssetType.zip, AssetType.exe, AssetType.msix],
    };
    for (final type in priorities) {
      for (final raw in assets) {
        final map = raw as Map<String, dynamic>;
        final name = (map['name'] as String?)?.toLowerCase() ?? '';
        if (_matchesAssetType(name, type)) {
          return (asset: map, type: type);
        }
      }
    }
    return null;
  }

  /// 判断资产文件名是否匹配指定类型。
  bool _matchesAssetType(String name, AssetType type) {
    switch (type) {
      case AssetType.zip:
        return name.endsWith('.zip') && name.contains('windows');
      case AssetType.exe:
        return name.endsWith('.exe') &&
            (name.contains('windows') ||
                name.contains('setup') ||
                name.contains('installer'));
      case AssetType.msix:
        return name.endsWith('.msix') || name.endsWith('.msixbundle');
    }
  }

  UpdateInfo _buildUpdateInfo(
    Map<String, dynamic> release,
    Map<String, dynamic> asset,
    Version version,
    AssetType assetType,
  ) {
    final digest = (asset['digest'] as String?) ?? '';
    return UpdateInfo(
      version: version,
      tagName: (release['tag_name'] as String?) ?? '',
      title: (release['name'] as String?) ?? '',
      body: (release['body'] as String?) ?? '',
      publishedAt: (release['published_at'] as String?) ?? '',
      assetType: assetType,
      assetName: (asset['name'] as String?) ?? '',
      assetSize: (asset['size'] as num?)?.toInt() ?? 0,
      assetSha256: _extractSha256(digest),
      assetUrl: (asset['browser_download_url'] as String?) ?? '',
    );
  }

  /// 下载更新包并安装（仅 Windows）。
  ///
  /// - zip 绿色版：下载 → 校验 → 生成批处理脚本 → 启动脚本（等待主进程
  ///   退出后覆盖文件并重启）。成功后主进程应尽快 `exit(0)`。
  /// - exe/msix 安装程序：下载 → 校验 → 启动安装程序，由用户接管剩余流程。
  ///   主进程无需退出，安装程序会引导用户完成安装。
  Future<UpdateInstallResult> downloadAndInstall(UpdateInfo update) async {
    if (!Platform.isWindows) {
      return const UpdateInstallResult(
        success: false,
        error: '自动更新仅支持 Windows',
      );
    }
    _stage = UpdateStage.downloading;
    _downloadProgress = 0;
    _installError = null;
    notifyListeners();
    await cleanupStaleTempDirs();
    final tempDir = await Directory.systemTemp.createTemp('imagic_update_');
    try {
      final assetPath = p.join(tempDir.path, update.assetName);
      await _downloadWithRetry(update, assetPath);

      _stage = UpdateStage.verifying;
      notifyListeners();
      final actual = await sha256Of(assetPath);
      final expected = update.assetSha256.toLowerCase();
      if (expected.isEmpty) {
        _fail('未获取到官方 SHA-256 校验值，为安全起见已中止更新');
        await tempDir.delete(recursive: true);
        return UpdateInstallResult(success: false, error: _installError);
      }
      if (actual != expected) {
        _fail('SHA-256 校验失败，下载文件可能被篡改或损坏');
        await tempDir.delete(recursive: true);
        return UpdateInstallResult(success: false, error: _installError);
      }

      _stage = UpdateStage.installing;
      notifyListeners();

      if (update.assetType == AssetType.zip) {
        // 绿色版：生成批处理脚本，等待主进程退出后自动替换并重启
        final scriptPath = await writeInstallerScript(assetPath, tempDir.path);
        // 直接传原始路径，让 dart:io 按 Windows 规则自动加引号；
        // 手动加引号会在路径含空格时导致 FormatException
        await Process.start(
          'cmd',
          ['/c', 'call', scriptPath],
          runInShell: false,
          mode: ProcessStartMode.detachedWithStdio,
        );
      } else {
        // exe/msix：启动安装程序，由用户接管
        // 第二个参数 '' 是 start 命令的窗口标题占位符，不可省略：
        // 若省略，start 会将 assetPath 误判为窗口标题而不启动程序
        await Process.start(
          'cmd',
          ['/c', 'start', '', assetPath],
          runInShell: false,
          mode: ProcessStartMode.detachedWithStdio,
        );
        // 临时目录由新版本启动时通过 cleanupStaleTempDirs() 清理，
        // 因安装过程中旧进程会被关闭，无法可靠地在此延迟清理
      }
      _stage = UpdateStage.done;
      notifyListeners();
      return const UpdateInstallResult(success: true);
    } on UpdateDownloadException catch (e) {
      _fail(e.message);
      await tempDir.delete(recursive: true);
      return UpdateInstallResult(success: false, error: _installError);
    } catch (e) {
      debugPrint('更新失败：$e');
      _fail('更新失败，请稍后重试');
      await tempDir.delete(recursive: true);
      return UpdateInstallResult(success: false, error: _installError);
    }
  }

  void _fail(String message) {
    _stage = UpdateStage.error;
    _installError = message;
    notifyListeners();
  }

  /// 清理上次残留的更新临时目录（失败 / 安装程序未清完的情况）。
  ///
  /// 在应用启动时调用，确保新版本启动后能清理由旧版本 exe/msix
  /// 安装流程遗留的临时文件。
  static Future<void> cleanupStaleTempDirs() async {
    try {
      await for (final entity in Directory.systemTemp.list()) {
        if (entity is Directory &&
            p.basename(entity.path).startsWith('imagic_update_')) {
          try {
            await entity.delete(recursive: true);
          } catch (_) {
            // 单个清理失败不阻塞更新主流程
          }
        }
      }
    } catch (_) {
      // 目录枚举失败忽略
    }
  }

  /// 带重试的下载，网络抖动时自动重试最多 3 次，指数退避。
  Future<void> _downloadWithRetry(
    UpdateInfo update,
    String destPath, {
    int maxAttempts = 3,
  }) async {
    // 整体开头重置一次进度，避免每次重试都跳回 0% 给用户视觉错乱。
    // downloadToFile 内部仍会在首次接收到数据时设置合理值。
    _downloadProgress = 0;
    notifyListeners();
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await downloadToFile(update, destPath, resetProgress: false);
        return;
      } on UpdateDownloadException catch (e) {
        if (attempt == maxAttempts) rethrow;
        final delay = Duration(seconds: 1 << (attempt - 1)); // 1s / 2s / 4s
        debugPrint('下载失败（第 $attempt / $maxAttempts 次）：$e，'
            '${delay.inSeconds}s 后重试');
        // 重试等待期间切为不确定进度，给用户明确的"重试中"信号
        _downloadProgress = null;
        notifyListeners();
        await Future.delayed(delay);
      }
    }
  }

  /// 流式下载安装包到 [destPath]，实时更新 [downloadProgress]。
  ///
  /// [resetProgress] 为 false 时由调用方（如 [_downloadWithRetry]）自行负责
  /// 在开头重置进度，避免每次重试进度跳回 0%。
  @visibleForTesting
  Future<void> downloadToFile(
    UpdateInfo update,
    String destPath, {
    bool resetProgress = true,
  }) async {
    if (resetProgress) {
      _downloadProgress = 0;
      notifyListeners();
    }
    final req = http.Request('GET', Uri.parse(update.assetUrl));
    final resp = await _client.send(req).timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200) {
      throw UpdateDownloadException('下载失败：HTTP ${resp.statusCode}');
    }
    final total = resp.contentLength ?? update.assetSize;
    if (total <= 0) {
      // 无法获取总大小（chunked 编码等），进度设为不确定
      _downloadProgress = null;
      notifyListeners();
    }
    final sink = File(destPath).openWrite();
    var received = 0;
    try {
      await for (final chunk in resp.stream.timeout(
        const Duration(minutes: 2),
      )) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          _downloadProgress = received / total;
        } else {
          _downloadProgress = null;
        }
        notifyListeners();
      }
    } catch (_) {
      await sink.close();
      rethrow;
    }
    await sink.close();
  }

  /// 流式计算文件 SHA-256（小写十六进制），避免一次性读入整个文件。
  @visibleForTesting
  Future<String> sha256Of(String filePath) async {
    final digest = await sha256.bind(File(filePath).openRead()).first;
    return digest.toString();
  }

  /// 生成更新批处理脚本：等待主进程退出 → 结束残留进程 → 解压覆盖 →
  /// 重启 → 清理临时文件。
  @visibleForTesting
  Future<String> writeInstallerScript(
    String assetPath,
    String tempDirPath,
  ) async {
    final appDir = Directory(Platform.resolvedExecutable).parent.path;
    final exeName = p.basename(Platform.resolvedExecutable);
    // p.join 规范化分隔符，避免 appDir 为驱动器根目录（如 D:\）时出现双反斜杠
    final exePath = p.join(appDir, exeName);
    final extracted = p.join(tempDirPath, 'extracted');
    final scriptPath = p.join(tempDirPath, 'update.bat');
    final content =
        '''
@echo off
setlocal
set "ZIP=$assetPath"
set "EXTRACTED=$extracted"
set "APPDIR=$appDir"
set "EXE=$exeName"
set "EXEPATH=$exePath"
set "TEMPDIR=$tempDirPath"
timeout /t 2 /nobreak >nul
taskkill /IM "%EXE%" /F >nul 2>&1
if not exist "%EXTRACTED%" mkdir "%EXTRACTED%"
tar -xf "%ZIP%" -C "%EXTRACTED%"
if errorlevel 1 (
    echo [%date% %time%] tar extraction failed >> "%TEMPDIR%\\update_error.log"
    start "" "%EXEPATH%"
    rmdir /s /q "%EXTRACTED%" >nul 2>&1
    del /q "%ZIP%" >nul 2>&1
    rmdir /s /q "%TEMPDIR%" >nul 2>&1
    exit /b 1
)
robocopy "%EXTRACTED%" "%APPDIR%" /E /IS /IT /NFL /NDL /NJH /NJS /NP >nul
if errorlevel 8 (
    echo [%date% %time%] robocopy failed with exit code %errorlevel% >> "%TEMPDIR%\\update_error.log"
)
start "" "%EXEPATH%"
rmdir /s /q "%EXTRACTED%" >nul 2>&1
del /q "%ZIP%" >nul 2>&1
rmdir /s /q "%TEMPDIR%" >nul 2>&1
endlocal
''';
    await File(scriptPath).writeAsString(content);
    return scriptPath;
  }
}

/// 下载过程中的可预期失败。
class UpdateDownloadException implements Exception {
  final String message;
  UpdateDownloadException(this.message);

  @override
  String toString() => message;
}
