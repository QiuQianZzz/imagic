import 'package:flutter/services.dart';

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
};

String keyToLabel(LogicalKeyboardKey key) {
  final known = keyLabels[key];
  if (known != null) return known;
  final label = key.debugName;
  if (label != null && label.startsWith('Digit ')) return label.substring(6);
  if (label != null && label.startsWith('Key ')) return label.substring(4);
  return label ?? '?';
}
