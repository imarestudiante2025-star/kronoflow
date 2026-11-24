import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/marca.dart';

/// Esfera de cronómetro: 60 marcas que se iluminan según el progreso (0 a 1).
///
/// Se usa en la cabecera de inicio, en el temporizador de enfoque y en la
/// pantalla de estadísticas. El contenido del centro lo pone quien la usa.
class EsferaCronometro extends StatelessWidget {
  final double progreso;
  final Widget centro;
  final double tamano;

  /// Duración de la animación entre un progreso y otro. Usa `Duration.zero`
  /// cuando el valor cambia continuamente (por ejemplo, cada segundo).
  final Duration duracion;
  final Color colorActivo;

  const EsferaCronometro({
    super.key,
    required this.progreso,
    required this.centro,
    this.tamano = 112,
    this.duracion = const Duration(milliseconds: 1100),
    this.colorActivo = Marca.cian,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progreso.clamp(0.0, 1.0).toDouble()),
      duration: duracion,
      curve: Curves.easeOutCubic,
      builder: (context, valor, _) {
        return SizedBox(
          width: tamano,
          height: tamano,
          child: CustomPaint(
            painter: _EsferaPainter(valor, colorActivo),
            child: Center(child: centro),
          ),
        );
      },
    );
  }
}

class _EsferaPainter extends CustomPainter {
  final double progreso;
  final Color color;

  const _EsferaPainter(this.progreso, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final centro = size.center(Offset.zero);
    final radio = size.width / 2;
    // Todo se escala a partir del diseño original de 112 px.
    final k = radio / 56;
    const marcas = 60;
    final activas = (progreso * marcas).round();

    // Al completarse, la esfera se enciende.
    if (progreso > 0.995) {
      canvas.drawCircle(
        centro,
        radio - 8 * k,
        Paint()
          ..color = color.withValues(alpha: 0.16)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 16 * k),
      );
    }

    final pincel = Paint()..strokeCap = StrokeCap.round;

    for (var i = 0; i < marcas; i++) {
      final angulo = -math.pi / 2 + 2 * math.pi * i / marcas;
      final mayor = i % 5 == 0;
      final largo = (mayor ? 12.0 : 7.0) * k;
      final dir = Offset(math.cos(angulo), math.sin(angulo));

      pincel
        ..strokeWidth = (mayor ? 3.0 : 2.0) * k
        ..color = i < activas ? color : Colors.white.withValues(alpha: 0.2);

      canvas.drawLine(centro + dir * (radio - largo), centro + dir * radio, pincel);
    }

    // Punta luminosa donde va el progreso.
    if (activas > 0 && activas < marcas) {
      final angulo = -math.pi / 2 + 2 * math.pi * activas / marcas;
      final punto = centro + Offset(math.cos(angulo), math.sin(angulo)) * (radio - 20 * k);
      canvas.drawCircle(
        punto,
        5 * k,
        Paint()
          ..color = color.withValues(alpha: 0.35)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 * k),
      );
      canvas.drawCircle(punto, 2.5 * k, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_EsferaPainter old) =>
      old.progreso != progreso || old.color != color;
}