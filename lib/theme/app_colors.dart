import 'package:flutter/material.dart';

/// Colores centralizados de KronoFlow. No repitas códigos hex en los widgets.
class AppColors {
  AppColors._();

  // Marca
  static const primary = Color(0xFF1D385B);
  static const primaryHover = Color(0xFF2A4C7A);
  static const accent = Color(0xFF3A6EA5);
  static const primaryDeep = Color(0xFF0F2038);
  static const auroraCyan = Color(0xFF4FC3F7);
  static const auroraIndigo = Color(0xFF5B6CFF);
  static const white = Color(0xFFFFFFFF);

  // Personaje polar (referencia para el diseño del .riv)
  static const bearLight = Color(0xFFF4F7FA);
  static const bearGrey = Color(0xFFD9E0E8);
  static const scarfRed = Color(0xFFD62F3A);

  // Textos
  static const textDark = Color(0xFF1B2A41);
  static const textSoft = Color(0xFF5F6F85);
  static const textOnDark = Color(0xFFFFFFFF);
  static final textOnDarkSoft = Colors.white.withValues(alpha: 0.75);

  // Campos
  static const fieldFill = Color(0xFFF3F6FA);
  static const fieldBorder = Color(0xFFD5DEEA);

  // Estados
  static const error = Color(0xFFB3261E);
  static const errorContainer = Color(0xFFFDECEA);
  static const onErrorContainer = Color(0xFF5C1410);
  static const success = Color(0xFF2E9E6B);
  static const warning = Color(0xFFE08A00);
  static const snackbar = Color(0xFF14284A);

  // Superficies y sombras
  static const surface = Color(0xFFFFFFFF);
  static final shadowSoft = Colors.black.withValues(alpha: 0.18);
  static final glow = accent.withValues(alpha: 0.30);
}

/// Decoración común de los campos del formulario.
class AppInput {
  AppInput._();

  static InputDecoration decoration({
    required String label,
    required IconData icon,
    String? hint,
    Widget? suffix,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: AppColors.textSoft),
      floatingLabelStyle: const TextStyle(
        color: AppColors.primary,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: TextStyle(color: AppColors.textSoft.withValues(alpha: 0.6)),
      filled: true,
      fillColor: AppColors.fieldFill,
      prefixIcon: Icon(icon),
      prefixIconColor: WidgetStateColor.resolveWith(
        (s) => s.contains(WidgetState.focused) ? AppColors.primary : AppColors.textSoft,
      ),
      suffixIcon: suffix,
      suffixIconColor: AppColors.textSoft,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: border(AppColors.fieldBorder),
      enabledBorder: border(AppColors.fieldBorder),
      focusedBorder: border(AppColors.primary, 1.8),
      errorBorder: border(AppColors.error),
      focusedErrorBorder: border(AppColors.error, 1.8),
    );
  }
}

/// Resplandor suave alrededor de un campo cuando tiene el foco.
class FocusGlow extends StatelessWidget {
  const FocusGlow({super.key, required this.focusNode, required this.child});

  final FocusNode focusNode;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: focusNode,
      child: child,
      builder: (context, hijo) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: focusNode.hasFocus
              ? [BoxShadow(color: AppColors.glow, blurRadius: 14)]
              : const [],
        ),
        child: hijo,
      ),
    );
  }
}