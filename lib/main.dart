import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/services/settings_service.dart';
import 'core/utils/window_controls.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

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
