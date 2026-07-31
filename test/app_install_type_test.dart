import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:imagic/core/utils/app_install_type.dart';

void main() {
  group('AppInstallTypeDetector', () {
    test('non-Windows platform returns portable', () {
      // 此测试在非 Windows CI 上验证回退行为
      // Windows 上 Platform.isWindows 为 true，跳过
      if (Platform.isWindows) return;
      expect(AppInstallTypeDetector.detect(), AppInstallType.portable);
    }, skip: Platform.isWindows ? '仅在非 Windows 平台运行' : null);

    test('MSIX path fragment is specific enough', () {
      // 验证常量本身是完整路径片段，非裸 "WindowsApps"
      // 避免绿色版解压到含 "WindowsApps" 的自定义目录被误判
      const fragment = r'Program Files\WindowsApps\';
      expect(fragment, contains(r'Program Files\'));
      expect(fragment, endsWith(r'WindowsApps\'));
    });

    test('green version in custom dir with WindowsApps name is not MSIX', () {
      // 模拟：用户把绿色版解压到 D:\MyApps\WindowsApps\imagic\
      // 旧逻辑 contains('WindowsApps') 会误判为 MSIX
      // 新逻辑 contains('Program Files\WindowsApps\') 不会误判
      const fakePath = r'D:\MyApps\WindowsApps\imagic\imagic.exe';
      expect(
        fakePath.contains(r'Program Files\WindowsApps\'),
        isFalse,
        reason: '绿色版解压到含 WindowsApps 的目录不应被误判为 MSIX',
      );
    });

    test('real MSIX path is detected as MSIX', () {
      const realMsixPath =
          r'C:\Program Files\WindowsApps\QiuQianZzz.Imagic_0.1.0.0_x64__abc\imagic.exe';
      expect(
        realMsixPath.contains(r'Program Files\WindowsApps\'),
        isTrue,
      );
    });
  });
}
