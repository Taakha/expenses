import 'package:flutter/material.dart';

class GlassTextField extends StatelessWidget {
  const GlassTextField({
    required this.label,
    super.key,
    this.controller,
    this.icon,
    this.keyboardType,
    this.validator,
    this.obscureText = false,
    this.suffix,
    this.maxLines = 1,
    this.enabled = true,
    this.onChanged,
  });

  final String label;
  final TextEditingController? controller;
  final IconData? icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool obscureText;
  final Widget? suffix;
  final int maxLines;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: obscureText ? 1 : maxLines,
      validator: validator,
      onChanged: onChanged,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon == null ? null : Icon(icon, size: 19),
        suffixIcon: suffix,
      ),
    );
  }
}
