import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/constants/app_constants.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  Future<void> loadTheme() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(AppConstants.themeMode);
    _themeMode = switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(AppConstants.themeMode, mode.name);
  }
}
