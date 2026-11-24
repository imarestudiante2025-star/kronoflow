import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';

/// Decide qué pantalla mostrar según haya sesión o no.
///
/// Etapa 3: el widget existe pero todavía NO se usa en `main.dart`, para no
/// dejarte fuera de la app antes de tener pantalla de login (Etapa 4).
/// En la Etapa 5 pasará a ser el `home` del MaterialApp.
class AuthGate extends StatelessWidget {
  final WidgetBuilder autenticado;
  final WidgetBuilder noAutenticado;
  final AuthService _auth;

  AuthGate({
    super.key,
    required this.autenticado,
    required this.noAutenticado,
    AuthService? auth,
  }) : _auth = auth ?? AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _auth.cambiosDeSesion,
      builder: (context, snapshot) {
        final sesion = snapshot.data?.session ?? _auth.sesionActual;
        return sesion != null ? autenticado(context) : noAutenticado(context);
      },
    );
  }
}
