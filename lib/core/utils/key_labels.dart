import 'package:flutter/services.dart';

import '../shortcuts/shortcut_definitions.dart';

String bindingToLabel(ShortcutBinding binding) {
  final key = findKeyById(binding.keyId);
  if (key == null) return '?';
  final mods = modifiersFromBitmask(binding.modifiers);
  final parts = <String>[];
  if (mods.contains(ShortcutModifier.ctrl)) parts.add('Ctrl');
  if (mods.contains(ShortcutModifier.alt)) parts.add('Alt');
  if (mods.contains(ShortcutModifier.shift)) parts.add('Shift');
  if (mods.contains(ShortcutModifier.meta)) parts.add('Meta');
  parts.add(keyToLabel(key));
  return parts.join('+');
}

Map<int, LogicalKeyboardKey>? _keyIdCache;

LogicalKeyboardKey? findKeyById(int keyId) {
  _keyIdCache ??= {
    for (final k in LogicalKeyboardKey.knownLogicalKeys) k.keyId: k,
  };
  return _keyIdCache![keyId];
}

final Map<LogicalKeyboardKey, String> keyLabels = {
  LogicalKeyboardKey.arrowLeft: '←',
  LogicalKeyboardKey.arrowRight: '→',
  LogicalKeyboardKey.arrowUp: '↑',
  LogicalKeyboardKey.arrowDown: '↓',
  LogicalKeyboardKey.escape: 'Esc',
  LogicalKeyboardKey.space: 'Space',
  LogicalKeyboardKey.f1: 'F1',
  LogicalKeyboardKey.f2: 'F2',
  LogicalKeyboardKey.f3: 'F3',
  LogicalKeyboardKey.f4: 'F4',
  LogicalKeyboardKey.f5: 'F5',
  LogicalKeyboardKey.f6: 'F6',
  LogicalKeyboardKey.f7: 'F7',
  LogicalKeyboardKey.f8: 'F8',
  LogicalKeyboardKey.f9: 'F9',
  LogicalKeyboardKey.f10: 'F10',
  LogicalKeyboardKey.f11: 'F11',
  LogicalKeyboardKey.f12: 'F12',
  LogicalKeyboardKey.delete: 'Del',
  LogicalKeyboardKey.backspace: 'Back',
  LogicalKeyboardKey.enter: 'Enter',
  LogicalKeyboardKey.tab: 'Tab',
  LogicalKeyboardKey.home: 'Home',
  LogicalKeyboardKey.end: 'End',
  LogicalKeyboardKey.pageUp: 'PageUp',
  LogicalKeyboardKey.pageDown: 'PageDown',
  LogicalKeyboardKey.insert: 'Ins',
  LogicalKeyboardKey.equal: '=',
  LogicalKeyboardKey.minus: '-',
  LogicalKeyboardKey.digit0: '0',
  LogicalKeyboardKey.digit1: '1',
  LogicalKeyboardKey.digit2: '2',
  LogicalKeyboardKey.digit3: '3',
  LogicalKeyboardKey.digit4: '4',
  LogicalKeyboardKey.digit5: '5',
  LogicalKeyboardKey.digit6: '6',
  LogicalKeyboardKey.digit7: '7',
  LogicalKeyboardKey.digit8: '8',
  LogicalKeyboardKey.digit9: '9',
  LogicalKeyboardKey.numpad0: 'Num0',
  LogicalKeyboardKey.numpad1: 'Num1',
  LogicalKeyboardKey.numpad2: 'Num2',
  LogicalKeyboardKey.numpad3: 'Num3',
  LogicalKeyboardKey.numpad4: 'Num4',
  LogicalKeyboardKey.numpad5: 'Num5',
  LogicalKeyboardKey.numpad6: 'Num6',
  LogicalKeyboardKey.numpad7: 'Num7',
  LogicalKeyboardKey.numpad8: 'Num8',
  LogicalKeyboardKey.numpad9: 'Num9',
};

String keyToLabel(LogicalKeyboardKey key) {
  final known = keyLabels[key];
  if (known != null) return known;
  final label = key.debugName;
  if (label != null && label.startsWith('Key ')) return label.substring(4);
  if (label != null && label.startsWith('Digit ')) return label.substring(6);
  return label ?? '?';
}
