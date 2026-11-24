import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Campo reutilizable de contraseña.
///
/// La visibilidad vive en [visibility]: quien use el widget (p. ej. el login)
/// puede compartir ese mismo notifier con el personaje Rive.
class PasswordField extends StatelessWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.visibility,
    required this.validator,
    this.autofillHints = const [AutofillHints.password],
    this.enabled = true,
    this.textInputAction = TextInputAction.done,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueNotifier<bool> visibility;
  final FormFieldValidator<String> validator;
  final Iterable<String> autofillHints;
  final bool enabled;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return FocusGlow(
      focusNode: focusNode,
      child: ValueListenableBuilder<bool>(
        valueListenable: visibility,
        builder: (context, visible, _) => TextFormField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          obscureText: !visible,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          autocorrect: false,
          enableSuggestions: false,
          cursorColor: AppColors.primary,
          style: const TextStyle(color: AppColors.textDark),
          validator: validator,
          onFieldSubmitted: onFieldSubmitted,
          decoration: AppInput.decoration(
            label: 'Contraseña',
            icon: Icons.lock_outline_rounded,
            suffix: IconButton(
              tooltip: visible ? 'Ocultar contraseña' : 'Mostrar contraseña',
              onPressed: enabled ? () => visibility.value = !visible : null,
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: anim,
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: Icon(
                  visible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  key: ValueKey(visible),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}