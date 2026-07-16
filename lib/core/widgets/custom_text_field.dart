import 'package:flutter/material.dart';

/// A styled text field with consistent design used across the ERP.
class CustomTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String labelText;
  final String? hintText;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixIconTap;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool readOnly;
  final int maxLines;
  final String? initialValue;
  final bool enabled;
  final FocusNode? focusNode;

  const CustomTextField({
    super.key,
    this.controller,
    required this.labelText,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixIconTap,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.readOnly = false,
    this.maxLines = 1,
    this.initialValue,
    this.enabled = true,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      focusNode: focusNode,
      obscureText: obscureText,
      keyboardType: maxLines > 1 ? TextInputType.multiline : keyboardType,
      textInputAction: textInputAction,
      readOnly: readOnly,
      enabled: enabled,
      maxLines: maxLines,
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        suffixIcon: suffixIcon != null
            ? IconButton(icon: Icon(suffixIcon), onPressed: onSuffixIconTap)
            : null,
      ),
    );
  }
}
