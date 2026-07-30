import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import '../constants/image_formats.dart';

/// Windows 注册表工具：文件关联 + 开机自启动。
///
/// 所有写入仅落在 HKEY_CURRENT_USER 下，不需要管理员权限。
/// 绿色版 / 安装器 / MSIX 装的 Imagic 都能用同一套逻辑增删关联。
///
/// 所有改动方法的返回值为 true 表示全部步骤成功；false 表示部分或全部
/// 步骤失败（注册表项可能处于中间状态，调用方不应更新持久化状态）。
class WindowsRegistry {
  WindowsRegistry._();

  static const String kProgId = 'Imagic.Image';
  static const String kAutoRunValueName = 'Imagic';

  // Shell 通知常量（win32 包未导出，自行定义）
  static const int shcneAssocChanged = 0x08000000;
  static const int shcnfIdlist = 0x0000;

  /// 当前 exe 绝对路径（使用 resolvedExecutable，确保永远是完整绝对路径；
  /// 若用 executable 可能返回相对路径导致注册表中的自启动 / 打开命令失效）
  static String get _exePath => Platform.resolvedExecutable;

  /// 注册文件关联。返回 true 表示所有扩展名 + ProgId 均写入成功。
  static bool registerFileAssociation() {
    final exe = _exePath;
    final command = '"$exe" "%1"';
    final iconValue = '"$exe",0';
    var allOk = true;

    using((arena) {
      final phkResult = arena<IntPtr>();
      final lpdwDisposition = arena<Uint32>();

      // 写 ProgId 默认值：HKCU\Software\Classes\Imagic.Image
      final progIdRoot =
          'Software\\Classes\\$kProgId'.toNativeUtf16(allocator: arena);
      if (RegCreateKeyEx(
            HKEY_CURRENT_USER,
            progIdRoot,
            0,
            nullptr,
            REG_OPTION_NON_VOLATILE,
            KEY_SET_VALUE,
            nullptr,
            phkResult,
            lpdwDisposition,
          ) ==
          ERROR_SUCCESS) {
        const friendlyName = 'Imagic 图片查看器';
        final friendlyNameNative = friendlyName.toNativeUtf16(allocator: arena);
        final ok = RegSetValueEx(
              phkResult.value,
              nullptr,
              0,
              REG_SZ,
              friendlyNameNative.cast<Uint8>(),
              (friendlyName.length + 1) * 2,
            ) ==
            ERROR_SUCCESS;
        RegCloseKey(phkResult.value);
        allOk = allOk && ok;
      } else {
        allOk = false;
      }

      // 写 ProgId DefaultIcon：HKCU\Software\Classes\Imagic.Image\DefaultIcon
      // 与 Inno Setup 脚本对齐，确保应用内开关与安装器行为一致
      final iconSubKey =
          'Software\\Classes\\$kProgId\\DefaultIcon'.toNativeUtf16(allocator: arena);
      if (RegCreateKeyEx(
            HKEY_CURRENT_USER,
            iconSubKey,
            0,
            nullptr,
            REG_OPTION_NON_VOLATILE,
            KEY_SET_VALUE,
            nullptr,
            phkResult,
            lpdwDisposition,
          ) ==
          ERROR_SUCCESS) {
        final iconNative = iconValue.toNativeUtf16(allocator: arena);
        final ok = RegSetValueEx(
              phkResult.value,
              nullptr,
              0,
              REG_SZ,
              iconNative.cast<Uint8>(),
              (iconValue.length + 1) * 2,
            ) ==
            ERROR_SUCCESS;
        RegCloseKey(phkResult.value);
        allOk = allOk && ok;
      } else {
        allOk = false;
      }

      // 写 ProgId 命令：HKCU\Software\Classes\Imagic.Image\shell\open\command
      final progIdSubKey =
          'Software\\Classes\\$kProgId\\shell\\open\\command'.toNativeUtf16(allocator: arena);
      if (RegCreateKeyEx(
            HKEY_CURRENT_USER,
            progIdSubKey,
            0,
            nullptr,
            REG_OPTION_NON_VOLATILE,
            KEY_SET_VALUE,
            nullptr,
            phkResult,
            lpdwDisposition,
          ) ==
          ERROR_SUCCESS) {
        final cmdNative = command.toNativeUtf16(allocator: arena);
        final ok = RegSetValueEx(
              phkResult.value,
              nullptr,
              0,
              REG_SZ,
              cmdNative.cast<Uint8>(),
              (command.length + 1) * 2,
            ) ==
            ERROR_SUCCESS;
        RegCloseKey(phkResult.value);
        allOk = allOk && ok;
      } else {
        allOk = false;
      }

      // 写每个扩展名：只覆盖 HKCU\Software\Classes\.<ext> 的默认值（ProgId 指针）。
      // 不删整个扩展名键，避免破坏 OpenWithProgids 等用户或其他软件写入的子键。
      for (final ext in kSupportedExtensions) {
        final extSubKey = 'Software\\Classes\\$ext'.toNativeUtf16(allocator: arena);
        if (RegCreateKeyEx(
              HKEY_CURRENT_USER,
              extSubKey,
              0,
              nullptr,
              REG_OPTION_NON_VOLATILE,
              KEY_SET_VALUE,
              nullptr,
              phkResult,
              lpdwDisposition,
            ) ==
            ERROR_SUCCESS) {
          final progIdNative = kProgId.toNativeUtf16(allocator: arena);
          final ok = RegSetValueEx(
                phkResult.value,
                nullptr,
                0,
                REG_SZ,
                progIdNative.cast<Uint8>(),
                (kProgId.length + 1) * 2,
              ) ==
              ERROR_SUCCESS;
          RegCloseKey(phkResult.value);
          allOk = allOk && ok;
        } else {
          allOk = false;
        }
        // 回读验证：确保默认值真的被改成了 kProgId
        // （可能被其他软件通过更高优先级的 UserChoice 覆盖）
        final actual = _regGetString(
          HKEY_CURRENT_USER,
          'Software\\Classes\\$ext',
          null,
        );
        if (actual != kProgId) {
          allOk = false;
        }
      }
    });

    _shellNotifyAssocChanged();
    return allOk;
  }

  /// 取消文件关联。返回 true 表示所有清理成功。
  /// 即使某些键本就不存在（已清理过），也视为成功。
  static bool unregisterFileAssociation() {
    var allOk = true;
    using((arena) {
      final phkResult = arena<IntPtr>();
      for (final ext in kSupportedExtensions) {
        final extSubKey = 'Software\\Classes\\$ext'.toNativeUtf16(allocator: arena);
        // 不删整个扩展名键（它可能含有 OpenWithProgids 等其他软件写入的子键，
        // 若有子键 RegDeleteKey 会返回 ERROR_DIR_NOT_EMPTY 失败）。
        // 只打开它然后删除默认值，即清除 ProgId 指针。
        if (RegOpenKeyEx(HKEY_CURRENT_USER, extSubKey, 0, KEY_SET_VALUE, phkResult) ==
            ERROR_SUCCESS) {
          try {
            final result = RegDeleteValue(phkResult.value, nullptr);
            if (result != ERROR_SUCCESS && result != ERROR_FILE_NOT_FOUND) {
              allOk = false;
            }
          } finally {
            RegCloseKey(phkResult.value);
          }
        }
        // 不存在视为成功（已清理过）
      }
      // 递归删除 ProgId 节点
      _regDeleteTree(HKEY_CURRENT_USER, 'Software\\Classes\\$kProgId');
    });

    _shellNotifyAssocChanged();
    return allOk;
  }

  /// 检测文件关联是否已注册
  static bool isFileAssociationRegistered() {
    if (kSupportedExtensions.isEmpty) return false;
    final firstExt = kSupportedExtensions.first;
    return _regGetString(HKEY_CURRENT_USER, 'Software\\Classes\\$firstExt', null) ==
        kProgId;
  }

  /// 启用开机自启动。返回 true 表示写入成功。
  static bool enableAutoStart() {
    final exe = _exePath;
    final value = '"$exe"';
    var ok = false;
    using((arena) {
      final phkResult = arena<IntPtr>();
      final lpdwDisposition = arena<Uint32>();
      final runSubKey =
          'Software\\Microsoft\\Windows\\CurrentVersion\\Run'.toNativeUtf16(allocator: arena);
      if (RegCreateKeyEx(
            HKEY_CURRENT_USER,
            runSubKey,
            0,
            nullptr,
            REG_OPTION_NON_VOLATILE,
            KEY_SET_VALUE,
            nullptr,
            phkResult,
            lpdwDisposition,
          ) ==
          ERROR_SUCCESS) {
        final valueName = kAutoRunValueName.toNativeUtf16(allocator: arena);
        final valueNative = value.toNativeUtf16(allocator: arena);
        ok = RegSetValueEx(
              phkResult.value,
              valueName,
              0,
              REG_SZ,
              valueNative.cast<Uint8>(),
              (value.length + 1) * 2,
            ) ==
            ERROR_SUCCESS;
        RegCloseKey(phkResult.value);
      }
    });
    return ok;
  }

  /// 禁用开机自启动。返回 true 表示成功（值不存在也视为成功）。
  static bool disableAutoStart() {
    var ok = false;
    using((arena) {
      final phkResult = arena<IntPtr>();
      final runSubKey =
          'Software\\Microsoft\\Windows\\CurrentVersion\\Run'.toNativeUtf16(allocator: arena);
      if (RegOpenKeyEx(HKEY_CURRENT_USER, runSubKey, 0, KEY_SET_VALUE, phkResult) ==
          ERROR_SUCCESS) {
        final valueName = kAutoRunValueName.toNativeUtf16(allocator: arena);
        final result = RegDeleteValue(phkResult.value, valueName);
        // 值不存在视为成功
        ok = result == ERROR_SUCCESS || result == ERROR_FILE_NOT_FOUND;
        RegCloseKey(phkResult.value);
      } else {
        // 键不存在视为成功
        ok = true;
      }
    });
    return ok;
  }

  /// 检测自启动是否已启用
  static bool isAutoStartEnabled() {
    return _regGetString(
          HKEY_CURRENT_USER,
          'Software\\Microsoft\\Windows\\CurrentVersion\\Run',
          kAutoRunValueName,
        ).isNotEmpty;
  }

  // ------- 内部辅助 -------

  /// 读取注册表字符串值。valueName 为 null 时读取默认值。
  static String _regGetString(int rootKey, String subKey, String? valueName) {
    return using((arena) {
      final phkResult = arena<IntPtr>();
      final lpSubKey = subKey.toNativeUtf16(allocator: arena);
      if (RegOpenKeyEx(rootKey, lpSubKey, 0, KEY_QUERY_VALUE, phkResult) !=
          ERROR_SUCCESS) {
        return '';
      }
      try {
        final lpValueName =
            valueName?.toNativeUtf16(allocator: arena) ?? nullptr;
        final lpType = arena<Uint32>();
        final lpcbData = arena<Uint32>();

        // 第一次查询：拿长度
        if (RegQueryValueEx(
              phkResult.value,
              lpValueName,
              nullptr,
              lpType,
              nullptr,
              lpcbData,
            ) !=
            ERROR_SUCCESS) {
          return '';
        }
        if (lpType.value != REG_SZ && lpType.value != REG_EXPAND_SZ) {
          return '';
        }
        // 第二次查询：拿数据
        final lpData = arena<Uint8>(lpcbData.value);
        if (RegQueryValueEx(
              phkResult.value,
              lpValueName,
              nullptr,
              nullptr,
              lpData,
              lpcbData,
            ) !=
            ERROR_SUCCESS) {
          return '';
        }
        // UTF-16 字节转 Dart 字符串（去掉末尾 null 终止符）
        final pwsz = lpData.cast<Utf16>();
        return pwsz.toDartString();
      } finally {
        RegCloseKey(phkResult.value);
      }
    });
  }

  /// 递归删除注册表子树（等价于 SHDeleteKey）
  /// 通过自己实现的递归删除，避免依赖未导出的 SHDeleteKey。
  static void _regDeleteTree(int rootKey, String subKey) {
    using((arena) {
      final phkResult = arena<IntPtr>();
      final lpSubKey = subKey.toNativeUtf16(allocator: arena);
      if (RegOpenKeyEx(rootKey, lpSubKey, 0,
              KEY_ENUMERATE_SUB_KEYS | DELETE | KEY_QUERY_VALUE, phkResult) !=
          ERROR_SUCCESS) {
        return;
      }
      try {
        // 枚举子键并递归删除
        final lpName = arena<Uint16>(256).cast<Utf16>();
        final lpcchName = arena<Uint32>();
        while (true) {
          lpcchName.value = 256;
          final result = RegEnumKey(phkResult.value, 0, lpName, lpcchName.value);
          if (result != ERROR_SUCCESS) break;
          final childName = lpName.toDartString();
          _regDeleteTree(phkResult.value, childName);
        }
      } finally {
        RegCloseKey(phkResult.value);
      }
      // 删除自己
      RegDeleteKey(rootKey, lpSubKey);
    });
  }

  /// 通过 DynamicLibrary 调用 shell32 的 SHChangeNotify
  static void _shellNotifyAssocChanged() {
    try {
      final shell32 = DynamicLibrary.open('shell32.dll');
      final pfn = shell32.lookupFunction<
          Void Function(Int32, Uint32, IntPtr, IntPtr),
          void Function(int, int, int, int)>('SHChangeNotify');
      pfn(shcneAssocChanged, shcnfIdlist, 0, 0);
    } catch (_) {
      // 极旧版 Windows 可能没有该函数，忽略错误（最坏结果只是资源管理器不刷新）
    }
  }
}
