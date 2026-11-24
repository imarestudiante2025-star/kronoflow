/// Configuración de Supabase.
///
/// La Publishable Key está pensada para ir en el cliente: la seguridad real
/// la dan las políticas RLS. NUNCA pongas aquí la "secret key" ni la
/// "service_role".
///
/// Los valores por defecto permiten ejecutar con `flutter run` sin banderas.
/// Para sobrescribirlos (otro proyecto, otro entorno):
///   flutter run -d chrome \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_KEY=sb_publishable_xxx
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://nvkyrrbjsuvpjavnhrbl.supabase.co',
  );

  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_KEY',
    defaultValue: 'sb_publishable_-WQcG7pCQHRZTCazghGS1Q_aSei5hKP',
  );

  static bool get estaConfigurado =>
      url.startsWith('https://') && publishableKey.isNotEmpty;
}
