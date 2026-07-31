import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/services/app_version_service.dart';
import 'core/services/settings_service.dart';
import 'core/services/single_instance_handler.dart';
import 'core/utils/window_controls.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // 单实例：初始化 MethodChannel 监听 C++ 端转发来的外部文件路径
  // 当用户在已有 Imagic 运行时双击图片文件，第二实例会把路径通过
  // 命名管道发给主实例，再通过 channel 推到 Dart 端
  SingleInstanceHandler.instance.init();

  // 预加载应用版本信息（来自 pubspec，构建时注入 exe 版本资源）
  await AppVersionService.instance.init();

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

  runApp(ImagicApp(initialFile: initialFile, settings: settings));
}
