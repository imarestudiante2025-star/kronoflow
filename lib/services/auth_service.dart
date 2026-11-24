import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Servicio de autenticación profesional para TaskFlow Pro.
/// Maneja el ciclo de vida de la sesión, registro e inicio de sesión con Supabase Auth.
class AuthService {
  GoTrueClient get _auth => SupabaseService.cliente.auth;

  Session? get sesionActual => _auth.currentSession;

  User? get usuarioActual => _auth.currentUser;

  bool get haySesion => sesionActual != null;

  /// Emite un evento cada vez que cambia la sesión (login, logout, refresco).
  Stream<AuthState> get cambiosDeSesion => _auth.onAuthStateChange;

  /// Inicia sesión con correo electrónico y contraseña.
  Future<AuthResponse> iniciarSesion({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return response;
    } catch (e) {
      throw 'Error al iniciar sesión: ${e.toString()}';
    }
  }

  /// Registra un nuevo usuario con correo electrónico y contraseña en Supabase Auth.
  Future<AuthResponse> registrar({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _auth.signUp(
        email: email.trim(),
        password: password,
      );
      return response;
    } catch (e) {
      throw 'Error en el registro: ${e.toString()}';
    }
  }

  /// Cierra la sesión activa actual.
  Future<void> cerrarSesion() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw 'Error al cerrar sesión: ${e.toString()}';
    }
  }
}