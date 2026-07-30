import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

/// 全屏状态。值为 `true` 表示窗口处于最大化（全屏）状态。
///
/// 没有直接使用 [windowManager.setFullScreen] 的原因：
/// - 调用 `setFullScreen(true)` 进入全屏有 OS 过渡动画
/// - 但调用 `setFullScreen(false)` 退出全屏时窗口**瞬间弹回**，无过渡
/// - 且在退出过程中会闪现原生 Windows 标题栏
/// - 改用 `maximize()` / `unmaximize()` 后，进入和退出都有平滑动画
/// - 唯一代价：任务栏可见（不遮挡）
final ValueNotifier<bool> fullscreenNotifier = ValueNotifier(false);

bool _fullscreenBusy = false;

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
