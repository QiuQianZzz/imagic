import 'package:flutter/services.dart';

class ShortcutAction {
  final String id;
  final String label;
  final LogicalKeyboardKey defaultKey;

  const ShortcutAction({
    required this.id,
    required this.label,
    required this.defaultKey,
  });
}

const List<ShortcutAction> shortcutActions = [
  ShortcutAction(id: 'prev_image', label: '上一张图片', defaultKey: LogicalKeyboardKey.arrowLeft),
  ShortcutAction(id: 'next_image', label: '下一张图片', defaultKey: LogicalKeyboardKey.arrowRight),
  ShortcutAction(id: 'toggle_fullscreen', label: '切换全屏', defaultKey: LogicalKeyboardKey.f11),
  ShortcutAction(id: 'exit_fullscreen', label: '退出全屏', defaultKey: LogicalKeyboardKey.escape),
];

ShortcutAction? findShortcutById(String id) {
  for (final a in shortcutActions) {
    if (a.id == id) return a;
  }
  return null;
}
