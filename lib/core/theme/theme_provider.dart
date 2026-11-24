import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { light, dark, system }

class ThemeProvider extends ChangeNotifier {
  ThemeProvider(this._preferences);

  static const _preferenceKey = 'moneywise.themeMode';
  final SharedPreferences _preferences;

  AppThemeMode _mode = AppThemeMode.system;

  AppThemeMode get mode => _mode;

  ThemeMode get themeMode => switch (_mode) {
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
    AppThemeMode.system => ThemeMode.system,
  };

  Future<void> load() async {
    final stored = _preferences.getString(_preferenceKey);
    _mode = AppThemeMode.values.firstWhere(
      (mode) => mode.name == stored,
      orElse: () => AppThemeMode.system,
    );
    notifyListeners();
  }

  Future<void> setMode(AppThemeMode mode) async {
    if (_mode == mode) return;
    await _preferences.setString(_preferenceKey, mode.name);
    _mode = mode;
    notifyListeners();
  }
}
