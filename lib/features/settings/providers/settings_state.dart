import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/constants/window_style.dart';
import '../../../core/constants/image_background.dart';
import '../../../core/models/update_channel.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/shortcuts/shortcut_definitions.dart';
import '../../../core/utils/windows_registry.dart';

class SettingsState extends ChangeNotifier {
  final SettingsService _service;

  SettingsState(this._service);

  Map<String, ShortcutBinding>? _shortcutBindingCache;

  ThemeMode get themeMode => _service.themeMode;
  bool get showNavBarArrows => _service.showNavBarArrows;
  bool get showNavBarOpen => _service.showNavBarOpen;
  bool get showFloatingArrows => _service.showFloatingArrows;
  int get seedColor => _service.seedColor;
  List<int> get customSeedColors => _service.customSeedColors;
  WindowStyle get windowStyle => _service.windowStyle;
  ImageBackground get imageBackground => _service.imageBackground;
  bool get fileAssociation => _service.fileAssociation;
  bool get autoStart => _service.autoStart;
  bool get autoCheckUpdates => _service.autoCheckUpdates;
  UpdateChannel get updateChannel => _service.updateChannel;

  /// 设置文件关联开关：同步写注册表 + 持久化。
  /// 非 Windows 平台直接忽略（保持 false）。
  /// 返回 true 表示成功；失败时不更新状态，调用方可据此提示用户。
  ///
  // TODO(system-integration): UI 层目前丢弃返回值，后续应在 general_section.dart
  // 的 onChanged 回调中检查返回值，失败时用 ScaffoldMessenger.showSnackBar
  // 提示用户（如"文件关联设置失败，请检查权限"）。详见 docs/架构设计.md 4.6.3。
  Future<bool> setFileAssociation(bool value) async {
    if (!Platform.isWindows) return false;
    final ok = value
        ? WindowsRegistry.registerFileAssociation()
        : WindowsRegistry.unregisterFileAssociation();
    if (!ok) {
      // 注册表写入失败：以注册表实际状态为准回滚内存值，不持久化
      _service.fileAssociation = WindowsRegistry.isFileAssociationRegistered();
      notifyListeners();
      return false;
    }
    _service.fileAssociation = value;
    await _service.save();
    notifyListeners();
    return true;
  }

  /// 设置开机自启动开关：同步写注册表 + 持久化。
  /// 非 Windows 平台直接忽略（保持 false）。
  /// 返回 true 表示成功；失败时不更新状态，调用方可据此提示用户。
  ///
  // TODO(system-integration): 同 setFileAssociation，UI 层需基于返回值提示用户。
  // 详见 docs/架构设计.md 4.6.3。
  Future<bool> setAutoStart(bool value) async {
    if (!Platform.isWindows) return false;
    final ok = value
        ? WindowsRegistry.enableAutoStart()
        : WindowsRegistry.disableAutoStart();
    if (!ok) {
      _service.autoStart = WindowsRegistry.isAutoStartEnabled();
      notifyListeners();
      return false;
    }
    _service.autoStart = value;
    await _service.save();
    notifyListeners();
    return true;
  }

  Future<void> setThemeMode(ThemeMode value) async {
    _service.themeMode = value;
    await _service.save();
    notifyListeners();
  }

  Future<void> setAutoCheckUpdates(bool value) async {
    _service.autoCheckUpdates = value;
    await _service.save();
    notifyListeners();
  }

  Future<void> setUpdateChannel(UpdateChannel value) async {
    _service.updateChannel = value;
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

  ShortcutBinding getShortcutBinding(String actionId) {
    _shortcutBindingCache ??= _buildShortcutBindingCache();
    return _shortcutBindingCache![actionId] ?? _defaultBinding(actionId);
  }

  ShortcutBinding _defaultBinding(String actionId) {
    final def = shortcutActions.firstWhere((a) => a.id == actionId);
    return ShortcutBinding(keyId: def.defaultKey.keyId, modifiers: def.defaultModifiers);
  }

  Map<String, ShortcutBinding> _buildShortcutBindingCache() {
    final cache = <String, ShortcutBinding>{};
    for (final def in shortcutActions) {
      final custom = _service.shortcutBindings[def.id];
      cache[def.id] = custom ?? ShortcutBinding(
        keyId: def.defaultKey.keyId,
        modifiers: def.defaultModifiers,
      );
    }
    return cache;
  }

  void _invalidateShortcutCache() {
    _shortcutBindingCache = null;
  }

  Future<void> setShortcutBinding(String actionId, ShortcutBinding binding) async {
    final def = shortcutActions.firstWhere((a) => a.id == actionId);
    final isDefault = binding.keyId == def.defaultKey.keyId &&
        binding.modifiers == def.defaultModifiers;
    if (isDefault) {
      _service.shortcutBindings.remove(actionId);
    } else {
      _service.shortcutBindings[actionId] = binding;
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
    final binding = getShortcutBinding(actionId);
    final def = shortcutActions.firstWhere((a) => a.id == actionId);
    return binding.keyId != def.defaultKey.keyId || binding.modifiers != def.defaultModifiers;
  }

  List<String> findConflicts(String actionId, ShortcutBinding binding) {
    final result = <String>[];
    for (final def in shortcutActions) {
      if (def.id == actionId) continue;
      final current = getShortcutBinding(def.id);
      if (current.keyId == binding.keyId && current.modifiers == binding.modifiers) {
        result.add(def.label);
      }
    }
    return result;
  }
}
