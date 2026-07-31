import 'package:package_info_plus/package_info_plus.dart';

/// 应用版本信息服务。
///
/// 版本号单一来源是 `pubspec.yaml` 的 `version` 字段：
/// flutter 构建时会把它注入到 Windows exe 的版本资源
/// （windows/runner/Runner.rc 的 FLUTTER_VERSION 宏），
/// 运行时通过 package_info_plus 读取，保证与发布 tag 完全一致。
///
/// 在 [init] 中预加载，之后通过 [version] / [buildNumber] 同步读取，
/// 避免 UI 侧到处 FutureBuilder。
class AppVersionService {
  AppVersionService._();

  static final AppVersionService instance = AppVersionService._();

  static const String _fallbackVersion = '0.1.0';
  static const String _fallbackBuild = '1';

  String _version = _fallbackVersion;
  String _buildNumber = _fallbackBuild;

  /// 语义化版本号，如 `0.1.0`。
  String get version => _version;

  /// 构建号，如 `1`。
  String get buildNumber => _buildNumber;

  /// 预加载版本信息。应在 main() 中调用一次。
  /// 读取失败时回退到默认值，不阻断应用启动。
  Future<void> init() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.isNotEmpty) _version = info.version;
      if (info.buildNumber.isNotEmpty) _buildNumber = info.buildNumber;
    } catch (_) {
      // 平台不支持 / 版本资源读取失败时保持默认值，避免应用无法启动
    }
  }

  /// 展示用完整版本字符串，如 `0.1.0 (1)`。
  String get displayVersion =>
      _buildNumber.isEmpty ? _version : '$_version ($_buildNumber)';
}
