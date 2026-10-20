/// Backend configuration.
///
/// The URL and publishable key are designed to ship inside client apps; access is
/// enforced by Row Level Security in the database. NEVER put a service_role / secret
/// key here.
///
/// Override per build with:
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...
class Env {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://xwdaygcezdbneoubimgv.supabase.co',
  );
  static const supabaseKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_WuaXdMyoYL23EcSjOgGdNQ_Q8v_J4cq',
  );
}
