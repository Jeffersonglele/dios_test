import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';
import '../providers/theme_provider.dart' as legacy_providers;

// Provider pour le mode du thème
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.light) {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('dark_mode') ?? false;
    state = isDark ? ThemeMode.dark : ThemeMode.light;
    legacy_providers.darkModeNotifier.value = isDark;
  }

  void setDarkMode(bool isDark) {
    state = isDark ? ThemeMode.dark : ThemeMode.light;
    legacy_providers.darkModeNotifier.value = isDark;
    _saveThemeMode(isDark);
  }

  void toggleTheme() {
    final isDark = state == ThemeMode.dark;
    setDarkMode(!isDark);
  }

  Future<void> _saveThemeMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', isDark);
  }
}

// Provider pour le thème actuel
final themeProvider = Provider<ThemeData>((ref) {
  final themeMode = ref.watch(themeModeProvider);
  return themeMode == ThemeMode.dark ? AppTheme.darkTheme : AppTheme.lightTheme;
});

final localeProvider = StateProvider<Locale>((ref) {
  return const Locale('fr');
});
