import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

final ValueNotifier<bool> windowMaximizedNotifier = ValueNotifier(false);

Future<void> windowMinimize() => windowManager.minimize();

Future<void> windowToggleMaximize() async {
  if (windowMaximizedNotifier.value) {
    await windowManager.unmaximize();
  } else {
    await windowManager.maximize();
  }
}

Future<void> windowClose() => windowManager.close();

void windowStartDragging() => windowManager.startDragging();
