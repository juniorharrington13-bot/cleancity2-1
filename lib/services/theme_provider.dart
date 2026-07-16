import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks the app's light/dark/system theme preference and persists it
/// locally, mirroring [LocaleProvider]'s pattern.
class ThemeProvider extends ChangeNotifier {
  static const String _prefsKey = 'app_theme_mode';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  ThemeMode _parse(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  String _serialize(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  /// Must be awaited before `runApp()` so the first frame already has the
  /// right theme (no flash of the wrong mode).
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _mode = _parse(prefs.getString(_prefsKey));
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, _serialize(mode));
  }
}
