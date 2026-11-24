import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Botón principal: azul oscuro, brillo periódico, animación al pulsar y
/// spinner de carga. Queda deshabilitado mientras [isLoading] sea true.
class LoginButton extends StatefulWidget {
  const LoginButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  State<LoginButton> createState() => _LoginButtonState();
}

class _LoginButtonState extends State<LoginButton> with SingleTickerProviderStateMixin {
  bool _hover = false;
  bool _pressed = false;

  /// Ciclo del brillo: barrido en el primer 40 % y pausa el resto.
  late final AnimationController _sheen = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  );

  bool get _enabled => widget.onPressed != null && !widget.isLoading;

  @override
  void initState() {
    super.initState();
    _syncSheen();
  }

  @override
  void didUpdateWidget(covariant LoginButton old) {
    super.didUpdateWidget(old);
    _syncSheen();
  }

  void _syncSheen() {
    if (_enabled && !_sheen.isAnimating) {
      _sheen.repeat();
    } else if (!_enabled && _sheen.isAnimating) {
      _sheen
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _sheen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _enabled;
    final radius = BorderRadius.circular(14);
    final sinAnimar = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.isLoading ? 'Procesando' : widget.text,
      excludeSemantics: true,
      child: AnimatedScale(
        scale: (_pressed && enabled) ? 0.97 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: (enabled || widget.isLoading) ? 1 : 0.55,
          duration: const Duration(milliseconds: 200),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 54,
            decoration: BoxDecoration(
              color: (_hover && enabled) ? AppColors.primaryHover : AppColors.primary,
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: (_hover && enabled) ? 0.5 : 0.35),
                  blurRadius: (_hover && enabled) ? 22 : 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(
                children: [
                  if (enabled && !sinAnimar)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _sheen,
                          builder: (context, _) {
                            final t = (_sheen.value / 0.4).clamp(0.0, 1.0);
                            if (_sheen.value > 0.4) return const SizedBox.shrink();
                            return FractionalTranslation(
                              translation: Offset(-1 + t * 3.5, 0),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: 0.4,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withValues(alpha: 0),
                                        Colors.white.withValues(alpha: 0.18),
                                        Colors.white.withValues(alpha: 0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: radius,
                      onTap: enabled ? widget.onPressed : null,
                      onHover: (v) => setState(() => _hover = v),
                      onHighlightChanged: (v) => setState(() => _pressed = v),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: widget.isLoading
                                ? const SizedBox(
                                    key: ValueKey('cargando'),
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: AppColors.white,
                                    ),
                                  )
                                : FittedBox(
                                    key: ValueKey(widget.text),
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      widget.text,
                                      style: const TextStyle(
                                        color: AppColors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ),
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
  }
}