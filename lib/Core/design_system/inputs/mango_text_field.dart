// Text field with a persistent label, helper text and an error message
// that Flutter links to the field for screen readers. Input is never
// cleared on validation failure.
import 'package:flutter/material.dart';

class MangoTextField extends StatelessWidget {
  const MangoTextField({
    super.key,
    required this.label,
    this.controller,
    this.helperText,
    this.errorText,
    this.hintText,
    this.required = false,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.maxLines = 1,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.enabled = true,
  });

  final String label;
  final TextEditingController? controller;
  final String? helperText;

  /// Says what to fix, for example "Use at least 8 characters".
  final String? errorText;
  final String? hintText;
  final bool required;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final int? maxLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    // "Required" is spoken and shown as text, not signalled by colour.
    final visibleLabel = required ? '$label (required)' : label;
    return TextFormField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      maxLines: obscureText ? 1 : maxLines,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      // Validate once the user has interacted, not before they start.
      autovalidateMode: AutovalidateMode.onUserInteraction,
      // Keeps the field clear of the on-screen keyboard when focused.
      scrollPadding: const EdgeInsets.only(bottom: 120),
      decoration: InputDecoration(
        labelText: visibleLabel,
        helperText: helperText,
        errorText: errorText,
        hintText: hintText,
        helperMaxLines: 3,
        errorMaxLines: 3,
      ),
    );
  }
}
