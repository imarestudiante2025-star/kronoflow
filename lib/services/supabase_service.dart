import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

class ResultadoConexion {
  final bool alcanzable;
  final String detalle;

  const ResultadoConexion({required this.alcanzable, required this.detalle});
}

class SupabaseService {
  // Inicializar Supabase
  static Future<void> inicializar() async {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );

    debugPrint('Supabase inicializado correctamente');
  }

  // Obtener cliente
  static SupabaseClient get cliente {
    return Supabase.instance.client;
  }

  // Probar conexión
  static Future<ResultadoConexion> probarConexion() async {
    try {
      await cliente.from('tareas').select().limit(1);

      return const ResultadoConexion(
        alcanzable: true,
        detalle: 'Conexión exitosa con Supabase. La tabla tareas responde correctamente.',
      );
    } catch (e) {
      return ResultadoConexion(
        alcanzable: false,
        detalle: 'No se pudo consultar la tabla tareas.\nError: $e',
      );
    }
  }
}
