import 'package:flutter/services.dart';

enum ShortcutModifier { ctrl, alt, shift, meta }

int modifiersBitmask(Iterable<ShortcutModifier> mods) {
  var mask = 0;
  for (final m in mods) {
    mask |= 1 << m.index;
  }
  return mask;
}

Set<ShortcutModifier> modifiersFromBitmask(int mask) {
  final result = <ShortcutModifier>{};
  for (final m in ShortcutModifier.values) {
    if (mask & (1 << m.index) != 0) result.add(m);
  }
  return result;
}

class ShortcutBinding {
  final int keyId;
  final int modifiers;

  const ShortcutBinding({required this.keyId, this.modifiers = 0});

  Map<String, dynamic> toJson() => {'key': keyId, 'mods': modifiers};
}

class ShortcutAction {
  final String id;
  final String label;
  final LogicalKeyboardKey defaultKey;
  final int defaultModifiers;

  const ShortcutAction({
    required this.id,
    required this.label,
    required this.defaultKey,
    this.defaultModifiers = 0,
  });
}

final List<ShortcutAction> shortcutActions = [
  ShortcutAction(id: 'open_file', label: '打开文件', defaultKey: LogicalKeyboardKey.keyO, defaultModifiers: 1),
  ShortcutAction(id: 'close_file', label: '关闭图片', defaultKey: LogicalKeyboardKey.keyW, defaultModifiers: 1),
  ShortcutAction(id: 'actual_size', label: '实际大小', defaultKey: LogicalKeyboardKey.digit1, defaultModifiers: 1),
  ShortcutAction(id: 'fit_to_window', label: '适应窗口', defaultKey: LogicalKeyboardKey.digit0, defaultModifiers: 1),
  ShortcutAction(id: 'zoom_in', label: '放大', defaultKey: LogicalKeyboardKey.equal, defaultModifiers: 1),
  ShortcutAction(id: 'zoom_out', label: '缩小', defaultKey: LogicalKeyboardKey.minus, defaultModifiers: 1),
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
