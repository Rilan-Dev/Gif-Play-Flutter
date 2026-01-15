import 'package:flutter/material.dart';
import '../utils/shared_preferences_util.dart';

/// Provider for managing theme state.
///
/// This class provides methods for getting and setting the current theme mode,
/// with support for persistence using SharedPreferences.
class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  /// Get the current theme mode.
  ThemeMode get themeMode => _themeMode;

  /// Check if dark mode is enabled.
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  /// Load the theme mode from SharedPreferences.
  Future<void> loadThemeMode() async {
    final themeModeIndex = SharedPreferencesUtil.getInt('theme_mode', defaultValue: 0);
    _themeMode = ThemeMode.values[themeModeIndex];
    notifyListeners();
  }

  /// Set the theme mode and save it to SharedPreferences.
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await SharedPreferencesUtil.setInt('theme_mode', mode.index);
    notifyListeners();
  }

  /// Toggle between light and dark theme.
  Future<void> toggleTheme() async {
    if (_themeMode == ThemeMode.light) {
      await setThemeMode(ThemeMode.dark);
    } else {
      await setThemeMode(ThemeMode.light);
    }
  }
}

