import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/image_background.dart';
import '../constants/window_style.dart';
import '../utils/windows_registry.dart';

class SettingsService {
  static const _keyThemeMode = 'theme_mode';
  static const _keyShowNavBarArrows = 'show_navbar_arrows';
  static const _keyShowNavBarOpen = 'show_navbar_open';
  static const _keyShowFloatingArrows = 'show_floating_arrows';
  static const _keySeedColor = 'seed_color';
  static const _keyCustomColors = 'custom_colors';
  static const _keyWindowStyle = 'window_style';
  static const _keyImageBackground = 'image_background';
  static const _keyShortcutBindings = 'shortcut_bindings';

  static const int defaultSeedColor = 0xFF5B8DEF;

  late final SharedPreferences _prefs;

  ThemeMode themeMode = ThemeMode.system;
  bool showNavBarArrows = true;
  bool showNavBarOpen = true;
  bool showFloatingArrows = true;
  int seedColor = defaultSeedColor;
  List<int> customSeedColors = [];
  WindowStyle windowStyle = WindowStyle.windows;
  ImageBackground imageBackground = ImageBackground.checkerboard;
  Map<String, int> shortcutBindings = {};

  /// 文件关联与自启动开关。
  ///
  /// 这两个是系统级状态，**单一数据源是 Windows 注册表**：
  /// - 读取时实时查注册表（用户可能在 Windows 设置里改过）
  /// - 写入由 SettingsState 调用 WindowsRegistry 完成
  /// - 不持久化到 SharedPreferences，避免双源不一致
  /// 非 Windows 平台保持 false。
  bool fileAssociation = false;
  bool autoStart = false;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _load();
  }

  void _load() {
    themeMode = ThemeMode.values[_prefs.getInt(_keyThemeMode) ?? 0];
    showNavBarArrows = _prefs.getBool(_keyShowNavBarArrows) ?? true;
    showNavBarOpen = _prefs.getBool(_keyShowNavBarOpen) ?? true;
    showFloatingArrows = _prefs.getBool(_keyShowFloatingArrows) ?? true;
    seedColor = _prefs.getInt(_keySeedColor) ?? defaultSeedColor;
    customSeedColors =
        _prefs
            .getStringList(_keyCustomColors)
            ?.map((s) => int.tryParse(s))
            .whereType<int>()
            .toList() ??
        [];
    windowStyle = WindowStyle.values[_prefs.getInt(_keyWindowStyle) ?? 0];
    imageBackground = _loadImageBackground();
    _loadShortcutBindings();
    _loadSystemIntegration();
  }

  ImageBackground _loadImageBackground() {
    // 优先使用新的 name 字符串存储
    final name = _prefs.getString(_keyImageBackground);
    if (name != null) return ImageBackground.fromName(name);
    // 回退：老版本用 int 索引存储（兼容迁移）
    final idx = _prefs.getInt(_keyImageBackground);
    if (idx != null && idx >= 0 && idx < ImageBackground.values.length) {
      return ImageBackground.values[idx];
    }
    return ImageBackground.checkerboard;
  }

  void _loadShortcutBindings() {
    final raw = _prefs.getString(_keyShortcutBindings);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      shortcutBindings = decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      shortcutBindings = {};
    }
  }

  /// 加载系统集成状态：以注册表为唯一数据源。
  /// 非 Windows 平台直接保持 false。
  void _loadSystemIntegration() {
    if (!Platform.isWindows) return;
    // 实时读注册表，反映用户在 Windows 设置里可能做出的改动
    fileAssociation = WindowsRegistry.isFileAssociationRegistered();
    autoStart = WindowsRegistry.isAutoStartEnabled();
  }

  Future<void> save() async {
    await _prefs.setInt(_keyThemeMode, themeMode.index);
    await _prefs.setBool(_keyShowNavBarArrows, showNavBarArrows);
    await _prefs.setBool(_keyShowNavBarOpen, showNavBarOpen);
    await _prefs.setBool(_keyShowFloatingArrows, showFloatingArrows);
    await _prefs.setInt(_keySeedColor, seedColor);
    await _prefs.setStringList(
      _keyCustomColors,
      customSeedColors.map((c) => c.toString()).toList(),
    );
    await _prefs.setInt(_keyWindowStyle, windowStyle.index);
    await _prefs.setString(_keyImageBackground, imageBackground.name);
    await _prefs.setString(_keyShortcutBindings, jsonEncode(shortcutBindings));
    // 注意：fileAssociation / autoStart 不写入 prefs，
    // 注册表是唯一数据源，下次启动会重新读取
  }

  Future<void> resetToDefaults() async {
    themeMode = ThemeMode.system;
    showNavBarArrows = true;
    showNavBarOpen = true;
    showFloatingArrows = true;
    seedColor = defaultSeedColor;
    customSeedColors = [];
    windowStyle = WindowStyle.windows;
    imageBackground = ImageBackground.checkerboard;
    shortcutBindings = {};
    // 不重置 fileAssociation / autoStart：这两个是系统级状态，
    // 不应被"重置设置为默认"操作误清除
    await save();
  }
}
