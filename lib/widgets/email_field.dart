import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Campo reutilizable de correo electrónico.
class EmailField extends StatelessWidget {
  const EmailField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.validator,
    this.enabled = true,
    this.textInputAction = TextInputAction.next,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final FormFieldValidator<String> validator;
  final bool enabled;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return FocusGlow(
      focusNode: focusNode,
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        keyboardType: TextInputType.emailAddress,
        textInputAction: textInputAction,
        autofillHints: const [AutofillHints.email],
        autocorrect: false,
        enableSuggestions: false,
        cursorColor: AppColors.primary,
        style: const TextStyle(color: AppColors.textDark),
        validator: validator,
        onFieldSubmitted: onFieldSubmitted,
        decoration: AppInput.decoration(
          label: 'Email',
          hint: 'nombre@correo.com',
          icon: Icons.mail_outline_rounded,
        ),
      ),
    );
  }
}