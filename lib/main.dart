import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/models/update_channel.dart';
import 'core/services/app_version_service.dart';
import 'core/services/settings_service.dart';
import 'core/services/single_instance_handler.dart';
import 'core/services/update_service.dart';
import 'core/utils/version.dart';
import 'core/utils/window_controls.dart';
import 'features/settings/ui/widgets/update_dialog.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // 单实例：初始化 MethodChannel 监听 C++ 端转发来的外部文件路径
  // 当用户在已有 Imagic 运行时双击图片文件，第二实例会把路径通过
  // 命名管道发给主实例，再通过 channel 推到 Dart 端
  SingleInstanceHandler.instance.init();

  // 预加载应用版本信息（来自 pubspec，构建时注入 exe 版本资源）
  await AppVersionService.instance.init();

  // 清理上次 exe/msix 更新可能残留的临时目录
  // 不阻塞启动：后台执行，失败也不影响应用运行
  unawaited(UpdateService.cleanupStaleTempDirs());

  await windowManager.ensureInitialized();
  await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
  await windowManager.setMinimumSize(const Size(800, 600));

  // 同步初始窗口最大化状态，避免 OS 以最大化恢复窗口时 notifier 卡在 false
  windowMaximizedNotifier.value = await windowManager.isMaximized();

  final settings = SettingsService();
  await settings.init();

  final initialFile = args.isNotEmpty && File(args.first).existsSync()
      ? args.first
      : null;

  final navigatorKey = GlobalKey<NavigatorState>();
  runApp(ImagicApp(
    initialFile: initialFile,
    settings: settings,
    navigatorKey: navigatorKey,
  ));

  // 启动时按设置自动检查更新；开关关闭时不检查
  if (settings.autoCheckUpdates) {
    unawaited(_checkUpdatesAtStartup(navigatorKey, settings.updateChannel));
  }
}

/// 启动后延迟片刻再检查更新（等首帧渲染完成、Navigator 可用），
/// 发现新版本时弹出更新对话框。
Future<void> _checkUpdatesAtStartup(
  GlobalKey<NavigatorState> navigatorKey,
  UpdateChannel channel,
) async {
  await Future<void>.delayed(const Duration(milliseconds: 800));
  final context = navigatorKey.currentContext;
  if (context == null) return;
  final updater = UpdateService.instance;
  final result = await updater.checkForUpdates(
    channel: channel,
    current: Version.parse(AppVersionService.instance.version),
  );
  if (!context.mounted) return;
  if (result.status == UpdateCheckStatus.updateAvailable &&
      result.update != null) {
    showUpdateDialog(context, result.update!);
  }
}
