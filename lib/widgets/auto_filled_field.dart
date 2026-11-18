import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

InputDecoration autoFilledDecoration({required String label, String? helper}) =>
    InputDecoration(
      labelText: label,
      helperText: helper,
      helperMaxLines: 3,
      filled: true,
      fillColor: AppColors.autoFilledBackground,
      suffixIcon: const Icon(
        Icons.lock_outline,
        size: 18,
        color: AppColors.autoFilledInk,
      ),
      labelStyle: const TextStyle(color: AppColors.autoFilledInk),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.autoFilledBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.autoFilledBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.autoFilledBorder),
      ),
    );

/// Profile values and calculated facts are visually separate from editable inputs.
class AutoFilledValue extends StatelessWidget {
  const AutoFilledValue({
    super.key,
    required this.label,
    required this.value,
    this.helper,
  });
  final String label;
  final String value;
  final String? helper;
  @override
  Widget build(BuildContext context) => Semantics(
    readOnly: true,
    child: InputDecorator(
      decoration: autoFilledDecoration(label: label, helper: helper),
      child: Text(
        value.trim().isEmpty ? 'Not set' : value,
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.autoFilledInk,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}
