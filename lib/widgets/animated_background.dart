import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Fondo animado de KronoFlow: aurora azul que se desplaza lentamente,
/// nieve en tres capas de profundidad y un efecto parallax con el puntero.
///
/// [pointer] va de -1 a 1 en cada eje (centro = 0,0). Se suaviza internamente.
/// Con "reducir animaciones" activado queda un fondo estático.
class AnimatedBackground extends StatefulWidget {
  const AnimatedBackground({super.key, this.pointer});

  final ValueListenable<Offset>? pointer;

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  /// Un ciclo completo dura 60 s; todos los movimientos son múltiplos enteros
  /// del ciclo, así el bucle no tiene saltos.
  late final AnimationController _t = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  );
  final _smooth = ValueNotifier<Offset>(Offset.zero);
  late final List<_Flake> _flakes = _generarCopos();

  @override
  void initState() {
    super.initState();
    _t.addListener(_suavizar);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _t.stop();
    } else if (!_t.isAnimating) {
      _t.repeat();
    }
  }

  @override
  void dispose() {
    _t.removeListener(_suavizar);
    _t.dispose();
    _smooth.dispose();
    super.dispose();
  }

  void _suavizar() {
    final objetivo = widget.pointer?.value ?? Offset.zero;
    _smooth.value = Offset.lerp(_smooth.value, objetivo, 0.05)!;
  }

  static List<_Flake> _generarCopos() {
    final rnd = math.Random(7);
    return List.generate(80, (_) {
      final depth = 0.25 + rnd.nextDouble() * 0.75;
      return _Flake(
        x: rnd.nextDouble(),
        y: rnd.nextDouble(),
        r: 0.8 + depth * 2.6,
        depth: depth,
        amp: 0.01 + rnd.nextDouble() * 0.03,
        k: 2 + (depth * 6).round(), // cruces de pantalla por ciclo (los cercanos caen más rápido)
        m: 3 + rnd.nextInt(6),
        phase: rnd.nextDouble(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _BackgroundPainter(_t, _smooth, _flakes),
        size: Size.infinite,
      ),
    );
  }
}

class _Flake {
  const _Flake({
    required this.x,
    required this.y,
    required this.r,
    required this.depth,
    required this.amp,
    required this.k,
    required this.m,
    required this.phase,
  });

  final double x, y, r, depth, amp, phase;
  final int k, m;
}

class _BackgroundPainter extends CustomPainter {
  _BackgroundPainter(this.t, this.pointer, this.flakes) : super(repaint: t);

  final Animation<double> t;
  final ValueNotifier<Offset> pointer;
  final List<_Flake> flakes;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    final rect = Offset.zero & size;
    final v = t.value;
    final a = 2 * math.pi * v;
    final p = pointer.value;

    // 1) Degradado base.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.primary, AppColors.primaryDeep],
        ).createShader(rect),
    );

    // 2) Aurora: tres resplandores que flotan con parallax.
    void blob(Offset c, double radius, Color color, double alpha) {
      final r = Rect.fromCircle(center: c, radius: radius);
      canvas.drawCircle(
        c,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [color.withValues(alpha: alpha), color.withValues(alpha: 0)],
          ).createShader(r),
      );
    }

    final radio = math.max(w, h) * 0.6;
    blob(
      Offset(w * (0.18 + 0.08 * math.sin(a)) - p.dx * w * 0.03,
          h * (0.14 + 0.06 * math.cos(a)) - p.dy * h * 0.03),
      radio,
      AppColors.auroraCyan,
      0.26,
    );
    blob(
      Offset(w * (0.86 + 0.07 * math.cos(a * 2)) + p.dx * w * 0.04,
          h * (0.36 + 0.08 * math.sin(a)) + p.dy * h * 0.03),
      radio * 0.9,
      AppColors.auroraIndigo,
      0.24,
    );
    blob(
      Offset(w * (0.5 + 0.12 * math.sin(a)) - p.dx * w * 0.02,
          h * (0.98 + 0.05 * math.cos(a * 2)) + p.dy * h * 0.02),
      radio,
      AppColors.accent,
      0.34,
    );

    // 3) Viñeta suave para dar profundidad.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 1.1,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.28)],
        ).createShader(rect),
    );

    // 4) Nieve en capas.
    final pincel = Paint();
    for (final f in flakes) {
      final fy = (f.y + v * f.k) % 1.0;
      final fx = f.x + math.sin(2 * math.pi * (v * f.m + f.phase)) * f.amp + p.dx * 0.012 * f.depth;
      final dx = (((fx % 1.0) + 1.0) % 1.0) * w;
      pincel.color = AppColors.white.withValues(alpha: 0.18 + 0.5 * f.depth);
      canvas.drawCircle(Offset(dx, fy * h), f.r, pincel);
    }
  }

  @override
  bool shouldRepaint(_BackgroundPainter old) => old.flakes != flakes || old.pointer != pointer;
}