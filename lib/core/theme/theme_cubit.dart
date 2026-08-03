/// ThemeCubit — manages theme mode state with SharedPreferences persistence.
///
/// Uses Cubit (not BLoC) because theme toggle is synchronous state with
/// no async events. Persistence to SharedPreferences is async but the
/// Cubit itself emits ThemeMode directly.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages theme mode state. Persisted to SharedPreferences.
class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit() : super(ThemeMode.dark) {
    _load();
  }

  static const _key = 'theme_mode';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString(_key) ?? 'dark';
    emit(mode == 'light' ? ThemeMode.light : ThemeMode.dark);
  }

  /// Toggles between dark and light theme.
  Future<void> toggle() async {
    final next = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    emit(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, next == ThemeMode.light ? 'light' : 'dark');
  }

  /// Sets the theme mode directly.
  Future<void> setMode(ThemeMode mode) async {
    emit(mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode == ThemeMode.light ? 'light' : 'dark');
  }
}
