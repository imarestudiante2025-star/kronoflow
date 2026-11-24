import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/login_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/animated_background.dart';
import '../widgets/email_field.dart';
import '../widgets/login_button.dart';
import '../widgets/password_field.dart';
import '../widgets/polar_bear_animation.dart';

const _eslogan = 'Tu tiempo, tus tareas, tus logros.';

class _Beneficio {
  const _Beneficio(this.icono, this.titulo, this.detalle);
  final IconData icono;
  final String titulo;
  final String detalle;
}

const _beneficios = [
  _Beneficio(Icons.checklist_rounded, 'Organiza tus tareas', 'Sin fricción, a tu ritmo'),
  _Beneficio(Icons.cloud_done_outlined, 'Todo en la nube', 'Sincronizado en todos tus dispositivos'),
  _Beneficio(Icons.trending_up_rounded, 'Mide tu progreso', 'Celebra cada logro'),
];

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _c = LoginController();
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _passwordVisible = ValueNotifier<bool>(false);
  final _bearKey = GlobalKey<PolarBearAnimationState>();

  /// Posición del puntero (-1..1) para el parallax del fondo.
  final _pointer = ValueNotifier<Offset>(Offset.zero);

  /// Sacudida breve de la tarjeta cuando hay un error.
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  /// Entrada escalonada de todos los elementos.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  bool _introIniciada = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_introIniciada) return;
    _introIniciada = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _intro.value = 1;
    } else {
      _intro.forward();
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    _intro.dispose();
    _pointer.dispose();
    _c.dispose();
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _passwordVisible.dispose();
    super.dispose();
  }

  // ───────── Acciones ─────────

  void _sacudir() {
    if (!mounted || MediaQuery.disableAnimationsOf(context)) return;
    _shake.forward(from: 0);
  }

  void _mostrarInfo(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.snackbar,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22),
              const SizedBox(width: 12),
              Expanded(child: Text(texto, style: const TextStyle(color: AppColors.white))),
            ],
          ),
        ),
      );
  }

  void _onHover(PointerEvent e) {
    final s = MediaQuery.sizeOf(context);
    if (s.width <= 0 || s.height <= 0) return;
    _pointer.value = Offset(
      (e.position.dx / s.width * 2 - 1).clamp(-1.0, 1.0),
      (e.position.dy / s.height * 2 - 1).clamp(-1.0, 1.0),
    );
  }

  Future<void> _enviar() async {
    if (_c.cargando) return; // evita doble envío (Enter + clic)
    if (!(_formKey.currentState?.validate() ?? false)) {
      _bearKey.currentState?.fireLoginFail();
      _sacudir();
      return;
    }

    FocusScope.of(context).unfocus();

    final resultado = await _c.autenticar(email: _email.text, password: _password.text);
    if (!mounted) return;

    if (resultado == LoginResult.failure) {
      _bearKey.currentState?.fireLoginFail();
      _sacudir();
    } else {
      // success: AuthGate reemplazará esta pantalla.
      _bearKey.currentState?.fireLoginSuccess();
      TextInput.finishAutofillContext();
    }
    final info = _c.consumirInfo();
    if (info != null) _mostrarInfo(info);
  }

  Future<void> _recuperar() async {
    if (_c.cargando) return;
    if (_c.validarEmail(_email.text) != null) {
      _c.reportarError('Escribe tu correo para enviarte el enlace de recuperación.');
      _sacudir();
      _emailFocus.requestFocus();
      return;
    }
    await _c.recuperarPassword(_email.text);
    if (!mounted) return;
    final info = _c.consumirInfo();
    if (info != null) {
      _mostrarInfo(info);
    } else if (_c.error != null) {
      _sacudir();
    }
  }

  // ───────── Interfaz ─────────

  @override
  Widget build(BuildContext context) {
    final tecladoAbierto = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: MouseRegion(
        onHover: _onHover,
        child: Stack(
          children: [
            Positioned.fill(child: AnimatedBackground(pointer: _pointer)),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, box) {
                  // Móvil < 600 · Tablet 600–899 · Escritorio ≥ 900
                  final amplio = box.maxWidth >= 900;
                  final tablet = !amplio && box.maxWidth >= 600;
                  final compacto = box.maxWidth < 380 || box.maxHeight < 700 || tecladoAbierto;
                  final osoEscritorio = math.min(340.0, math.max(180.0, box.maxHeight * 0.42));

                  final contenido = amplio
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: _marca(osoAlto: osoEscritorio, amplio: true, titulo: 40),
                            ),
                            const SizedBox(width: 56),
                            SizedBox(
                              width: 440,
                              child: _columnaForm(compacto: false, holgado: true),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _marca(
                              osoAlto: compacto ? 120 : (tablet ? 230 : 190),
                              amplio: false,
                              titulo: tablet ? 38 : (compacto ? 28 : 32),
                              rotativo: !compacto,
                            ),
                            SizedBox(height: compacto ? 14 : (tablet ? 28 : 22)),
                            _columnaForm(compacto: compacto, holgado: tablet),
                          ],
                        );

                  return SingleChildScrollView(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: box.maxHeight),
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: compacto ? 14 : 24,
                            vertical: compacto ? 14 : 28,
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: amplio ? 1040 : (tablet ? 520 : 440)),
                            child: contenido,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Oso (con halo) + título centrado + eslogan.
  /// Escritorio: tarjetas de beneficios. Móvil/tablet: un beneficio rotativo.
  Widget _marca({
    required double osoAlto,
    required bool amplio,
    required double titulo,
    bool rotativo = false,
  }) {
    return _Reveal(
      animation: _intro,
      start: 0,
      end: 0.55,
      dy: 30,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              IgnorePointer(
                child: Container(
                  width: osoAlto * 1.15,
                  height: osoAlto * 1.15,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.auroraCyan.withValues(alpha: 0.30),
                        AppColors.auroraCyan.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              PolarBearAnimation(
                key: _bearKey,
                emailFocusNode: _emailFocus,
                passwordFocusNode: _passwordFocus,
                emailController: _email,
                passwordVisible: _passwordVisible,
                height: osoAlto,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'KronoFlow',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: titulo,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              color: AppColors.textOnDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _eslogan,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: amplio ? 16 : 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textOnDarkSoft,
            ),
          ),
          if (amplio) ...[
            const SizedBox(height: 30),
            _beneficio(_beneficios[0], 0.35),
            _beneficio(_beneficios[1], 0.43),
            _beneficio(_beneficios[2], 0.51),
          ] else if (rotativo) ...[
            const SizedBox(height: 14),
            const _BeneficioRotativo(),
          ],
        ],
      ),
    );
  }

  /// Tarjeta de vidrio (desenfoque real: los copos no se ven a través).
  Widget _beneficio(_Beneficio b, double inicio) {
    return _Reveal(
      animation: _intro,
      start: inicio,
      end: inicio + 0.3,
      dy: 16,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.auroraCyan.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(b.icono, size: 22, color: AppColors.auroraCyan),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            b.titulo,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textOnDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            b.detalle,
                            style: TextStyle(fontSize: 12.5, color: AppColors.textOnDarkSoft),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _columnaForm({required bool compacto, bool holgado = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _tarjeta(compacto: compacto, holgado: holgado),
        const SizedBox(height: 18),
        _Reveal(
          animation: _intro,
          start: 0.7,
          end: 1,
          dy: 10,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified_user_outlined, size: 15, color: AppColors.textOnDarkSoft),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Sincronización cifrada y segura en la nube',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.textOnDarkSoft),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tarjeta({required bool compacto, bool holgado = false}) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final registro = _c.crearCuenta;

        Widget item(double inicio, Widget hijo) => _Reveal(
              animation: _intro,
              start: inicio,
              end: math.min(inicio + 0.3, 1.0),
              dy: 16,
              child: hijo,
            );

        return AnimatedBuilder(
          animation: _shake,
          builder: (context, child) {
            final t = _shake.value;
            final dx = math.sin(t * math.pi * 6) * 8 * (1 - t);
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: _Reveal(
            animation: _intro,
            start: 0.15,
            end: 0.65,
            dy: 36,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: compacto ? 20 : (holgado ? 40 : 32),
                vertical: compacto ? 24 : 32,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: AppColors.shadowSoft, blurRadius: 40, offset: const Offset(0, 16)),
                  BoxShadow(
                    color: AppColors.glow,
                    blurRadius: 70,
                    spreadRadius: -10,
                    offset: const Offset(0, 28),
                  ),
                ],
              ),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      item(
                        0.3,
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: Text(
                                registro ? 'Crea tu cuenta' : 'Bienvenido de nuevo',
                                key: ValueKey(registro),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              registro
                                  ? 'Crea tu espacio de trabajo en segundos'
                                  : 'Inicia sesión para continuar',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 14, color: AppColors.textSoft),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: compacto ? 18 : 24),

                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        alignment: Alignment.topCenter,
                        child: _c.error == null
                            ? const SizedBox(width: double.infinity)
                            : Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _BannerError(texto: _c.error!),
                              ),
                      ),

                      item(
                        0.4,
                        EmailField(
                          controller: _email,
                          focusNode: _emailFocus,
                          enabled: !_c.cargando,
                          validator: _c.validarEmail,
                          onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      item(
                        0.47,
                        PasswordField(
                          controller: _password,
                          focusNode: _passwordFocus,
                          visibility: _passwordVisible,
                          enabled: !_c.cargando,
                          validator: _c.validarPassword,
                          autofillHints: [
                            registro ? AutofillHints.newPassword : AutofillHints.password,
                          ],
                          onFieldSubmitted: (_) => _enviar(),
                        ),
                      ),

                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        alignment: Alignment.topCenter,
                        child: registro
                            ? Padding(
                                padding: const EdgeInsets.only(top: 12, bottom: 14),
                                child: _MedidorFortaleza(controller: _password),
                              )
                            : item(
                                0.52,
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    child: TextButton(
                                      onPressed: _c.cargando ? null : _recuperar,
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.primary,
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 6,
                                        ),
                                      ),
                                      child: const Text(
                                        '¿Olvidaste tu contraseña?',
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(height: 6),

                      item(
                        0.58,
                        LoginButton(
                          text: registro ? 'Comenzar gratis' : 'Entrar al espacio de trabajo',
                          isLoading: _c.cargando,
                          onPressed: _c.cargando ? null : _enviar,
                        ),
                      ),
                      const SizedBox(height: 14),

                      item(
                        0.66,
                        Center(
                          child: TextButton(
                            onPressed: _c.cargando ? null : _c.alternarModo,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            child: Text.rich(
                              textAlign: TextAlign.center,
                              TextSpan(
                                style: const TextStyle(fontSize: 14),
                                children: [
                                  TextSpan(
                                    text: registro ? '¿Ya tienes cuenta? ' : '¿Nuevo por aquí? ',
                                    style: const TextStyle(color: AppColors.textSoft),
                                  ),
                                  TextSpan(
                                    text: registro ? 'Inicia sesión' : 'Crea tu cuenta gratis',
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────── Piezas privadas ───────────────────────────

/// Píldora compacta que rota los beneficios (móvil y tablet).
class _BeneficioRotativo extends StatefulWidget {
  const _BeneficioRotativo();

  @override
  State<_BeneficioRotativo> createState() => _BeneficioRotativoState();
}

class _BeneficioRotativoState extends State<_BeneficioRotativo> {
  Timer? _timer;
  int _i = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timer?.cancel();
    if (!MediaQuery.disableAnimationsOf(context)) {
      _timer = Timer.periodic(const Duration(seconds: 3), (_) {
        if (mounted) setState(() => _i = (_i + 1) % _beneficios.length);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = _beneficios[_i];
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(anim),
                  child: child,
                ),
              ),
              child: Row(
                key: ValueKey(_i),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(b.icono, size: 16, color: AppColors.auroraCyan),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '${b.titulo} · ${b.detalle}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: AppColors.textOnDarkSoft),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Aparición (fade + desplazamiento) dentro de un tramo [start, end] de la
/// animación de entrada. Permite escalonar los elementos.
class _Reveal extends StatelessWidget {
  const _Reveal({
    required this.animation,
    required this.start,
    required this.end,
    required this.child,
    this.dy = 22,
  });

  final Animation<double> animation;
  final double start;
  final double end;
  final double dy;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curva = Interval(start, end, curve: Curves.easeOutCubic);
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, hijo) {
        final t = curva.transform(animation.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, (1 - t) * dy), child: hijo),
        );
      },
    );
  }
}

/// Medidor visual de fortaleza (solo informativo, al crear cuenta).
/// No cambia las reglas de validación.
class _MedidorFortaleza extends StatelessWidget {
  const _MedidorFortaleza({required this.controller});

  final TextEditingController controller;

  static int _puntaje(String p) {
    if (p.isEmpty) return 0;
    var s = 0;
    if (p.length >= 6) s++;
    if (p.length >= 10) s++;
    if (RegExp(r'[a-z]').hasMatch(p) && RegExp(r'[A-Z]').hasMatch(p)) s++;
    if (RegExp(r'\d').hasMatch(p) && RegExp(r'[^\w\s]').hasMatch(p)) s++;
    return s; // 0..4
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final texto = controller.text;
        if (texto.isEmpty) {
          return const Text(
            'Usa 10+ caracteres, mayúsculas, números y símbolos.',
            style: TextStyle(fontSize: 12, color: AppColors.textSoft),
          );
        }

        final s = _puntaje(texto);
        const etiquetas = ['Muy débil', 'Débil', 'Media', 'Fuerte', 'Excelente'];
        const colores = [
          AppColors.error,
          AppColors.error,
          AppColors.warning,
          AppColors.success,
          AppColors.success,
        ];
        final llenos = s == 0 ? 1 : s;
        final color = colores[s];

        return Row(
          children: [
            for (var i = 0; i < 4; i++) ...[
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 5,
                  decoration: BoxDecoration(
                    color: i < llenos ? color : AppColors.fieldBorder,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              if (i < 3) const SizedBox(width: 6),
            ],
            const SizedBox(width: 12),
            SizedBox(
              width: 70,
              child: Text(
                etiquetas[s],
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BannerError extends StatelessWidget {
  const _BannerError({required this.texto});
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded, size: 20, color: AppColors.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                texto,
                style: const TextStyle(color: AppColors.onErrorContainer, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}