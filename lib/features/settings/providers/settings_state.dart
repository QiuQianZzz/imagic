import 'package:flutter/material.dart';

import '../../../core/constants/window_style.dart';
import '../../../core/constants/image_background.dart';
import '../../../core/services/settings_service.dart';

class SettingsState extends ChangeNotifier {
  final SettingsService _service;

  SettingsState(this._service);

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
    notifyListeners();
  }
}
