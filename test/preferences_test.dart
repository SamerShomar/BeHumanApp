import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:be_human_app/core/languages/app_localizations.dart';
import 'package:be_human_app/core/providers/preferences_store.dart';
import 'package:be_human_app/core/providers/theme_provider.dart';

/// The theme and the language reset on every launch, because neither was ever
/// written down. Choosing dark mode and reopening the app brought back light;
/// choosing Arabic brought back English.
///
/// These use one store across two containers, which is what a restart is: the
/// app is built again, the disk is not wiped.
void main() {
  ProviderContainer containerWith(PreferencesStore store) {
    final container = ProviderContainer(
      overrides: [preferencesStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('the theme', () {
    test('survives a restart', () async {
      final store = InMemoryPreferencesStore();

      final first = containerWith(store);
      expect(first.read(themeProvider), isFalse, reason: 'starts light');
      first.read(themeProvider.notifier).setTheme(true);
      expect(first.read(themeProvider), isTrue);

      // The app opens again against the same disk.
      final second = containerWith(store);
      expect(second.read(themeProvider), isTrue,
          reason: 'reopened light — the choice was thrown away');
    });

    test('survives being switched back', () async {
      final store = InMemoryPreferencesStore();
      containerWith(store).read(themeProvider.notifier).setTheme(true);
      containerWith(store).read(themeProvider.notifier).setTheme(false);

      expect(containerWith(store).read(themeProvider), isFalse);
    });

    test('defaults to light on a device that has never chosen', () {
      expect(containerWith(InMemoryPreferencesStore()).read(themeProvider),
          isFalse);
    });
  });

  group('the language', () {
    test('survives a restart', () {
      final store = InMemoryPreferencesStore();

      final first = containerWith(store);
      first.read(localeProvider.notifier).setLocale(const Locale('ar'));

      expect(containerWith(store).read(localeProvider), const Locale('ar'));
    });

    test('ignores a stored language this build does not ship', () {
      // A code left by an older version would otherwise leave every string on
      // screen showing its own translation key.
      final store = InMemoryPreferencesStore()
        ..setString(PreferenceKeys.localeCode, 'fr');

      final locale = containerWith(store).read(localeProvider);
      expect(AppLocalizations.supportedLocales, contains(locale));
      expect(locale, const Locale('en'));
    });

    test('accepts every language the app actually ships', () {
      for (final supported in AppLocalizations.supportedLocales) {
        final store = InMemoryPreferencesStore();
        containerWith(store).read(localeProvider.notifier).setLocale(supported);
        expect(containerWith(store).read(localeProvider), supported);
      }
    });
  });

  test('a build with no store still runs, it just forgets', () {
    // The default store is in-memory, so a build that forgot to install the
    // real one degrades to the old behaviour instead of failing to launch.
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(themeProvider.notifier).setTheme(true);
    expect(container.read(themeProvider), isTrue);
  });
}
