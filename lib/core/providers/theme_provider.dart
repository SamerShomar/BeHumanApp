import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:be_human_app/core/providers/preferences_store.dart';

/// Whether the app is in dark mode.
///
/// The chosen mode is written to disk as it changes and read back on the next
/// launch. It used to live only in memory, so every restart threw the choice
/// away and came back light.
class ThemeNotifier extends StateNotifier<bool> {
  ThemeNotifier(this._store)
      : super(_store.getBool(PreferenceKeys.darkTheme) ?? false);

  final PreferencesStore _store;

  void toggleTheme() => setTheme(!state);

  void setTheme(bool isDark) {
    if (state == isDark) return;
    state = isDark;
    // Not awaited: the switch should move now, not after a disk write. A
    // failed write costs the preference, never the interaction.
    _store.setBool(PreferenceKeys.darkTheme, isDark);
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, bool>(
  (ref) => ThemeNotifier(ref.watch(preferencesStoreProvider)),
);
