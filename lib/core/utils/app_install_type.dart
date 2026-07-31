import 'dart:io';

import 'package:path/path.dart' as p;

/// 当前应用的安装形式，决定更新时应优先下载哪种资产。
enum AppInstallType {
  /// MSIX 安装版，运行在 WindowsApps 沙盒中。
  msix,

  /// exe 安装版（Inno Setup 等），有卸载程序。
  installer,

  /// 绿色版（zip 解压），可任意目录运行。
  portable,
}

/// 检测当前应用的安装形式。
class AppInstallTypeDetector {
  AppInstallTypeDetector._();

  /// Inno Setup 默认卸载程序文件名。
  static const _innoUninstaller = 'unins000.exe';

  /// 检测当前应用的安装形式。
  ///
  /// - MSIX：可执行文件路径包含 `WindowsApps`（沙盒安装目录）
  /// - 安装版：exe 同目录存在 Inno Setup 卸载程序 `unins000.exe`
  /// - 绿色版：以上都不满足
  static AppInstallType detect() {
    if (!Platform.isWindows) return AppInstallType.portable;

    final exePath = Platform.resolvedExecutable;

    // MSIX 安装路径形如：
    // C:\Program Files\WindowsApps\QiuQianZzz.Imagic_0.1.0.0_x64__...\imagic.exe
    if (exePath.contains('WindowsApps')) {
      return AppInstallType.msix;
    }

    // Inno Setup 安装版会在应用目录生成 unins000.exe
    final exeDir = File(exePath).parent.path;
    final uninstaller = File(p.join(exeDir, _innoUninstaller));
    if (uninstaller.existsSync()) {
      return AppInstallType.installer;
    }

    return AppInstallType.portable;
  }
}
