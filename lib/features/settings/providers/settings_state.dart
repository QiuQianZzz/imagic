import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/window_style.dart';
import '../../../core/constants/image_background.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/shortcuts/shortcut_definitions.dart';

class SettingsState extends ChangeNotifier {
  final SettingsService _service;

  SettingsState(this._service);

  Map<String, LogicalKeyboardKey>? _shortcutKeyCache;

  ThemeMode get themeMode => _service.themeMode;
  bool get showNavBarArrows => _service.showNavBarArrows;
  bool get showNavBarOpen => _service.showNavBarOpen;
  bool get showFloatingArrows => _service.showFloatingArrows;
  int get seedColor => _service.seedColor;
  List<int> get customSeedColors => _service.customSeedColors;
  WindowStyle get windowStyle => _service.windowStyle;
  ImageBackground get imageBackground => _service.imageBackground;

  Future<void> setThemeMode(ThemeMode value) async {
    _service.themeMode = value;
    await _service.save();
    notifyListeners();
  }

  Future<void> setShowNavBarArrows(bool value) async {
    _service.showNavBarArrows = value;
    await _service.save();
    notifyListeners();
  }

  Future<void> setShowFloatingArrows(bool value) async {
    _service.showFloatingArrows = value;
    await _service.save();
    notifyListeners();
  }

  Future<void> setShowNavBarOpen(bool value) async {
    _service.showNavBarOpen = value;
    await _service.save();
    notifyListeners();
  }

  Future<void> setWindowStyle(WindowStyle value) async {
    _service.windowStyle = value;
    await _service.save();
    notifyListeners();
  }

  Future<void> setImageBackground(ImageBackground value) async {
    _service.imageBackground = value;
    await _service.save();
    notifyListeners();
  }

  Future<void> setSeedColor(int value) async {
    _service.seedColor = value;
    await _service.save();
    notifyListeners();
  }

  Future<void> addCustomColor(int value) async {
    _service.customSeedColors.add(value);
    _service.seedColor = value;
    await _service.save();
    notifyListeners();
  }

  Future<void> removeCustomColor(int value) async {
    _service.customSeedColors.remove(value);
    if (_service.seedColor == value) {
      _service.seedColor = _service.customSeedColors.isNotEmpty
          ? _service.customSeedColors.last
          : SettingsService.defaultSeedColor;
    }
    await _service.save();
    notifyListeners();
  }

  Future<void> resetToDefaults() async {
    await _service.resetToDefaults();
    _invalidateShortcutCache();
    notifyListeners();
  }

  LogicalKeyboardKey getShortcutKey(String actionId) {
    _shortcutKeyCache ??= _buildShortcutKeyCache();
    return _shortcutKeyCache![actionId] ?? LogicalKeyboardKey.escape;
  }

  Map<String, LogicalKeyboardKey> _buildShortcutKeyCache() {
    final cache = <String, LogicalKeyboardKey>{};
    for (final def in shortcutActions) {
      final custom = _service.shortcutBindings[def.id];
      if (custom != null) {
        LogicalKeyboardKey? match;
        for (final k in LogicalKeyboardKey.knownLogicalKeys) {
          if (k.keyId == custom) { match = k; break; }
        }
        cache[def.id] = match ?? def.defaultKey;
      } else {
        cache[def.id] = def.defaultKey;
      }
    }
    return cache;
  }

  void _invalidateShortcutCache() {
    _shortcutKeyCache = null;
  }

  Future<void> setShortcutBinding(String actionId, LogicalKeyboardKey key) async {
    final defaultAction = shortcutActions.firstWhere((a) => a.id == actionId);
    if (key == defaultAction.defaultKey) {
      // 如果绑定的是默认值，则移除自定义记录
      _service.shortcutBindings.remove(actionId);
    } else {
      _service.shortcutBindings[actionId] = key.keyId;
    }
    await _service.save();
    _invalidateShortcutCache();
    notifyListeners();
  }

  Future<void> resetShortcutBinding(String actionId) async {
    _service.shortcutBindings.remove(actionId);
    await _service.save();
    _invalidateShortcutCache();
    notifyListeners();
  }

  bool isShortcutCustom(String actionId) {
    final defaultAction = shortcutActions.firstWhere((a) => a.id == actionId);
    final currentKey = getShortcutKey(actionId);
    return currentKey != defaultAction.defaultKey;
  }

  List<String> findConflicts(String actionId, LogicalKeyboardKey key) {
    final result = <String>[];
    for (final def in shortcutActions) {
      if (def.id == actionId) continue;
      if (getShortcutKey(def.id) == key) {
        result.add(def.label);
      }
    }
    return result;
  }
}
