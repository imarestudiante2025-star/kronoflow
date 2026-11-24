import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GoogleAuthService {
  // ID de cliente WEB (no el de Android)
  static const _webClientId =
      '203811288459-3dvcq9hu0s5cbid3mh6vs034pfiep1g3.apps.googleusercontent.com';

  static GoogleSignIn _crearCliente() => GoogleSignIn(
        serverClientId: _webClientId,
        scopes: const ['email'],
      );

  /// Inicia sesión con Google (Android / iOS) y crea la sesión en Supabase.
  /// Lanza una Exception con la palabra "cancelado" si el usuario cierra la ventana.
  static Future<void> signIn() async {
    final googleSignIn = _crearCliente();

    // Limpia la sesión local de Google para que siempre aparezca el selector
    // de cuentas (así se puede elegir otra cuenta sin quedar pegado a la anterior).
    try {
      await googleSignIn.signOut();
    } catch (_) {
      // Si no había sesión previa no pasa nada.
    }

    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      throw Exception('Inicio de sesión cancelado');
    }

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;

    if (idToken == null) {
      throw Exception('No se obtuvo el token de Google');
    }

    await Supabase.instance.client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  /// Cierra la sesión en Google y en Supabase.
  static Future<void> signOut() async {
    try {
      await _crearCliente().signOut();
    } catch (_) {
      // Ignorar: lo importante es cerrar la sesión de Supabase.
    }
    await Supabase.instance.client.auth.signOut();
  }
}