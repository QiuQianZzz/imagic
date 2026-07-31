import '../utils/version.dart';

/// 更新资产类型，决定下载后的安装方式。
enum AssetType {
  /// 绿色版 zip，下载后自动解压替换并重启。
  zip,

  /// exe 安装程序，下载后启动由用户完成安装。
  exe,

  /// MSIX 安装包，下载后启动由用户完成安装。
  msix,
}

/// GitHub Release 中的候选更新信息。
class UpdateInfo {
  final Version version;

  /// 原始 tag，如 `v0.1.0-beta.2`。
  final String tagName;

  /// Release 标题，如 `[Release] v0.1.0`。
  final String title;

  /// 更新日志正文。
  final String body;

  final String publishedAt;

  /// 资产类型（zip/exe/msix），决定安装方式。
  final AssetType assetType;

  /// 资产文件名，如 `imagic-0.1.0-windows.zip`。
  final String assetName;

  final int assetSize;

  /// 期望 SHA-256（GitHub API 的 `digest`，去掉 `sha256:` 前缀）。
  final String assetSha256;

  final String assetUrl;

  const UpdateInfo({
    required this.version,
    required this.tagName,
    required this.title,
    required this.body,
    required this.publishedAt,
    required this.assetType,
    required this.assetName,
    required this.assetSize,
    required this.assetSha256,
    required this.assetUrl,
  });
}
