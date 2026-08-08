import 'package:flutter_riverpod/flutter_riverpod.dart';

class ThemeNotifier extends StateNotifier<bool> {
  ThemeNotifier() : super(false);

  void toggleTheme() => state = !state;
  void setTheme(bool isDark) => state = isDark;
}

final themeProvider = StateNotifierProvider<ThemeNotifier, bool>((ref) => ThemeNotifier());