import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where a user's own settings are kept between launches.
///
/// The theme and the language were held in memory only, so both reset on every
/// launch — the app came back light and in English however it had been left.
/// For a team working in Arabic that is not a small annoyance; it is the app
/// forgetting who is using it.
///
/// An interface rather than SharedPreferences directly, so tests and the
/// offscreen statement render get a working store without a platform channel.
abstract interface class PreferencesStore {
  bool? getBool(String key);
  String? getString(String key);
  Future<void> setBool(String key, bool value);
  Future<void> setString(String key, String value);
}

/// Keys, in one place so a typo cannot silently stop something persisting.
abstract final class PreferenceKeys {
  static const String darkTheme = 'settings.darkTheme';
  static const String localeCode = 'settings.localeCode';
}

/// The real store, backed by the platform.
class SharedPreferencesStore implements PreferencesStore {
  const SharedPreferencesStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  bool? getBool(String key) => _prefs.getBool(key);

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);

  @override
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);
}

/// Remembers nothing beyond the current run.
///
/// The default, so a widget test or the detached statement render works
/// without a platform channel. `main` overrides it with the real one — which
/// means a build that forgot to do that degrades to the old behaviour rather
/// than crashing on launch.
class InMemoryPreferencesStore implements PreferencesStore {
  final Map<String, Object> _values = {};

  @override
  bool? getBool(String key) => _values[key] as bool?;

  @override
  String? getString(String key) => _values[key] as String?;

  @override
  Future<void> setBool(String key, bool value) async => _values[key] = value;

  @override
  Future<void> setString(String key, String value) async =>
      _values[key] = value;
}

final preferencesStoreProvider = Provider<PreferencesStore>(
  (ref) => InMemoryPreferencesStore(),
);
