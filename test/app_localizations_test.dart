import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:be_human_app/core/languages/app_localizations.dart';

void main() {
  group('AppLocalizations.translate', () {
    test('returns the translation for the requested locale', () {
      expect(
        AppLocalizations.translate(const Locale('en'), 'app_title'),
        'Be Human Foundation',
      );
      expect(
        AppLocalizations.translate(const Locale('ar'), 'app_title'),
        isNot('Be Human Foundation'),
      );
    });

    test('falls back to English for an unsupported locale', () {
      expect(
        AppLocalizations.translate(const Locale('fr'), 'app_title'),
        AppLocalizations.translate(const Locale('en'), 'app_title'),
      );
    });

    test('returns the key itself when it is unknown', () {
      expect(
        AppLocalizations.translate(const Locale('en'), 'does_not_exist'),
        'does_not_exist',
      );
    });

    test('substitutes named parameters', () {
      expect(
        AppLocalizations.translate(const Locale('en'), 'welcome', {'name': 'Samer'}),
        contains('Samer'),
      );
      expect(
        AppLocalizations.translate(const Locale('en'), 'welcome', {'name': 'Samer'}),
        isNot(contains('{name}')),
      );
    });
  });

  group('translation tables', () {
    // The bottom navigation and the settings screen look these up directly,
    // so a missing key in one language would silently show English.
    const navigationKeys = [
      'home_title',
      'proposals',
      'financial',
      'archive',
      'settings',
      'admin_dashboard',
      'change_password',
      'old_password',
      'new_password',
      'password_updated',
      'password_invalid',
      'save',
      'cancel',
      'logout',
    ];

    for (final locale in AppLocalizations.supportedLocales) {
      test('${locale.languageCode} defines every navigation and settings key', () {
        for (final key in navigationKeys) {
          expect(
            AppLocalizations.translate(locale, key),
            isNot(key),
            reason: 'Missing "$key" for locale "${locale.languageCode}"',
          );
        }
      });
    }
  });
}
