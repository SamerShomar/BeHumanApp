/// Build-time configuration.
///
/// Values come from `--dart-define` so no keys live in the repository. See the
/// "File storage" section of the README for how to pass them.
///
/// The Supabase *anon* key is designed to ship inside client apps — it only
/// grants what the bucket's access policies allow. The `service_role` key is a
/// full admin credential and must never appear here or anywhere in the app.
class AppConfig {
  const AppConfig._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Bucket holding proposal PDFs. Keep it **private**; the app reads through
  /// short-lived signed URLs rather than public links.
  static const String proposalsBucket = String.fromEnvironment(
    'SUPABASE_PROPOSALS_BUCKET',
    defaultValue: 'proposals',
  );

  /// Whether file storage was configured for this build. When false the app
  /// still runs, but uploading is refused with an explanatory message instead
  /// of throwing somewhere deeper.
  static bool get isStorageConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
