import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Una sesión de enfoque terminada.
class SesionEnfoque {
  final String tareaId;
  final DateTime fin;
  final int minutos;

  const SesionEnfoque({
    required this.tareaId,
    required this.fin,
    required this.minutos,
  });

  Map<String, dynamic> toJson() => {
        't': tareaId,
        'f': fin.toIso8601String(),
        'm': minutos,
      };

  factory SesionEnfoque.fromJson(Map<String, dynamic> json) => SesionEnfoque(
        tareaId: json['t'] as String,
        fin: DateTime.parse(json['f'] as String),
        minutos: json['m'] as int,
      );
}

/// Guarda las sesiones de enfoque en el dispositivo (SharedPreferences).
///
/// Los datos viven en este teléfono: no se sincronizan con Supabase.
class EnfoqueService {
  EnfoqueService._();
  static final instancia = EnfoqueService._();

  static const _clave = 'kronoflow_sesiones_enfoque';
  static const _maximo = 1000;

  Future<List<SesionEnfoque>> todas() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final crudo = prefs.getString(_clave);
      if (crudo == null) return [];

      return (jsonDecode(crudo) as List)
          .map((e) => SesionEnfoque.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error al leer sesiones de enfoque: $e');
      return [];
    }
  }

  Future<void> registrar(SesionEnfoque sesion) async {
    try {
      final lista = await todas();
      lista.add(sesion);
      final recortada =
          lista.length > _maximo ? lista.sublist(lista.length - _maximo) : lista;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _clave,
        jsonEncode(recortada.map((s) => s.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('Error al guardar la sesión de enfoque: $e');
    }
  }
}