import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

import 'window_controls.dart';

final ValueNotifier<bool> fullscreenNotifier = ValueNotifier(false);

bool _fullscreenBusy = false;

/// 切换全屏状态。
///
/// 没有直接使用 [windowManager.setFullScreen] 的原因：
/// - 调用 `setFullScreen(true)` 进入全屏有 OS 过渡动画
/// - 但调用 `setFullScreen(false)` 退出全屏时窗口**瞬间弹回**，无过渡
/// - 且在退出过程中会闪现原生 Windows 标题栏
/// - 改用 `maximize()` / `unmaximize()` 后，进入和退出都有平滑动画
/// - 唯一代价：任务栏可见（不遮挡）
Future<void> toggleFullscreen() async {
  if (_fullscreenBusy) return;
  _fullscreenBusy = true;
  try {
    final fs = fullscreenNotifier.value;
    fullscreenNotifier.value = !fs;
    if (fs) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  } finally {
    _fullscreenBusy = false;
  }
}

/// 由 ViewerScreen.onWindowUnmaximize 调用：如果是全屏模式触发，则退出全屏。
void onWindowUnmaximized() {
  if (fullscreenNotifier.value) {
    fullscreenNotifier.value = false;
  }
  windowMaximizedNotifier.value = false;
}

/// 由 ViewerScreen.onWindowMaximize 调用：同步全屏与最大化状态。
/// 仅当 maximize 由 toggleFullscreen 触发时（_fullscreenBusy=true）才置 fullscreenNotifier，
/// 避免用户正常最大化窗口时误触全屏（隐藏菜单栏）。
void onWindowMaximized() {
  if (_fullscreenBusy) {
    fullscreenNotifier.value = true;
  }
  windowMaximizedNotifier.value = true;
}
