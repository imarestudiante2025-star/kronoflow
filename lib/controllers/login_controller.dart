import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum LoginResult { success, needsEmailConfirmation, failure }

/// Lógica del login: validación, estado de carga, autenticación y errores.
///
/// NOTA: usa Supabase igual que el login_page original. Si auth_service.dart
/// ya expone signIn / signUp / resetPassword, sustituye las llamadas marcadas
/// con "// AUTH" para no duplicar lógica.
class LoginController extends ChangeNotifier {
  /// Debe coincidir con Supabase → Authentication → Providers → Email.
  static const minPassword = 6;

  static final _regexEmail = RegExp(
    r'^[\w.+\-]+@[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)*\.[A-Za-z]{2,}$',
  );

  bool _crearCuenta = false;
  bool _cargando = false;
  bool _disposed = false;
  String? _error;
  String? _info;

  bool get crearCuenta => _crearCuenta;
  bool get cargando => _cargando;
  String? get error => _error;

  /// Devuelve el mensaje informativo pendiente (una sola vez) y lo limpia.
  String? consumirInfo() {
    final i = _info;
    _info = null;
    return i;
  }

  // ───────── Validación ─────────

  String? validarEmail(String? valor) {
    final email = (valor ?? '').trim();
    if (email.isEmpty) return 'Introduce tu correo';
    if (!_regexEmail.hasMatch(email)) return 'Introduce un correo válido';
    return null;
  }

  String? validarPassword(String? valor) {
    final password = valor ?? '';
    if (password.isEmpty) return 'Introduce tu contraseña';
    // La longitud mínima solo se exige al registrarse.
    if (_crearCuenta && password.length < minPassword) {
      return 'Mínimo $minPassword caracteres';
    }
    return null;
  }

  // ───────── Estado ─────────

  void alternarModo() {
    _crearCuenta = !_crearCuenta;
    _error = null;
    notifyListeners();
  }

  void reportarError(String mensaje) {
    _error = mensaje;
    notifyListeners();
  }

  // ───────── Autenticación ─────────

  Future<LoginResult> autenticar({
    required String email,
    required String password,
  }) async {
    if (_cargando) return LoginResult.failure; // evita doble envío
    _cargando = true;
    _error = null;
    notifyListeners();

    final correo = email.trim().toLowerCase();

    try {
      final auth = Supabase.instance.client.auth;

      if (_crearCuenta) {
        final r = await auth.signUp(email: correo, password: password); // AUTH
        // Con "confirmar correo" activo, Supabase devuelve un usuario sin
        // identidades en lugar de un error si el correo ya existe.
        final yaRegistrado = r.user != null && (r.user!.identities?.isEmpty ?? false);

        if (yaRegistrado) {
          _error = 'Ya existe una cuenta con este correo. Inicia sesión o recupera tu contraseña.';
          return LoginResult.failure;
        }
        if (r.session == null) {
          _crearCuenta = false;
          _info = 'Cuenta creada. Revisa tu correo para confirmarla.';
          return LoginResult.needsEmailConfirmation;
        }
        return LoginResult.success; // AuthGate reemplazará la pantalla
      }

      await auth.signInWithPassword(email: correo, password: password); // AUTH
      return LoginResult.success;
    } on AuthRetryableFetchException {
      // Debe ir antes que AuthException (es una subclase).
      _error = 'No hay conexión con el servidor. Revisa tu internet.';
    } on AuthException catch (e) {
      _error = _traducirError(e);
    } catch (e, st) {
      debugPrint('Error inesperado en autenticación: $e\n$st');
      _error = 'Ocurrió un error inesperado. Inténtalo de nuevo.';
    } finally {
      _cargando = false;
      notifyListeners();
    }
    return LoginResult.failure;
  }

  /// Devuelve true si la solicitud se envió. El mensaje es neutro a propósito
  /// (no confirma si el correo existe).
  Future<bool> recuperarPassword(String email) async {
    if (_cargando) return false;

    if (validarEmail(email) != null) {
      reportarError('Escribe tu correo para enviarte el enlace de recuperación.');
      return false;
    }

    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      await Supabase.instance.client.auth
          .resetPasswordForEmail(email.trim().toLowerCase()); // AUTH
      _info = 'Si el correo está registrado, recibirás un enlace para restablecer tu contraseña.';
      return true;
    } on AuthRetryableFetchException {
      _error = 'No hay conexión con el servidor. Revisa tu internet.';
    } on AuthException catch (e) {
      _error = _traducirError(e);
    } catch (e, st) {
      debugPrint('Error al recuperar contraseña: $e\n$st');
      _error = 'No se pudo enviar el correo. Inténtalo de nuevo.';
    } finally {
      _cargando = false;
      notifyListeners();
    }
    return false;
  }

  String _traducirError(AuthException e) {
    final m = e.message.toLowerCase();

    if (m.contains('invalid login credentials')) {
      return 'Correo o contraseña incorrectos.';
    }
    if (m.contains('email not confirmed')) {
      return 'Aún no has confirmado tu correo. Revisa tu bandeja de entrada.';
    }
    if (m.contains('already registered') || m.contains('already been registered')) {
      return 'Ya existe una cuenta con este correo.';
    }
    if (m.contains('password should') || m.contains('weak')) {
      return 'La contraseña es demasiado débil. Usa una más larga y variada.';
    }
    if (e.statusCode == '429' || m.contains('rate limit') || m.contains('too many')) {
      return 'Demasiados intentos. Espera unos minutos e inténtalo de nuevo.';
    }
    return e.message;
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}