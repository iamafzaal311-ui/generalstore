/// Reusable widgets for the application
///
/// This file contains commonly used widgets that are used across
/// multiple features to maintain consistency and reduce duplication.
library;

import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../theme/app_theme.dart';
import '../extensions/dart_extensions.dart';

// ============================================================================
// LOADING WIDGET
// ============================================================================

/// Loading indicator widget with optional message
class LoadingWidget extends StatelessWidget {
  final String? message;
  final double size;

  const LoadingWidget({super.key, this.message, this.size = 50});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: const CircularProgressIndicator(strokeWidth: 3),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              message!,
              style: context.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// ERROR WIDGET
// ============================================================================

/// Error display widget with retry button
class ErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final String retryButtonText;

  const ErrorWidget({
    super.key,
    required this.message,
    this.onRetry,
    this.retryButtonText = 'Retry',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: context.colorScheme.error,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Error', style: context.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              style: context.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(retryButtonText),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// EMPTY STATE WIDGET
// ============================================================================

/// Empty state display with optional action button
class EmptyStateWidget extends StatelessWidget {
  final String message;
  final String? actionText;
  final VoidCallback? onAction;
  final IconData? icon;

  const EmptyStateWidget({
    super.key,
    required this.message,
    this.actionText,
    this.onAction,
    this.icon = Icons.inbox_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey[400]),
            const SizedBox(height: AppSpacing.lg),
            Text(
              message,
              style: context.textTheme.bodyLarge?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(onPressed: onAction, child: Text(actionText!)),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// CARD WITH TITLE AND ACTION
// ============================================================================

/// Reusable card with title, content, and optional action button
class ActionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final String? actionTooltip;
  final EdgeInsetsGeometry padding;

  const ActionCard({
    super.key,
    required this.title,
    required this.child,
    this.actionIcon,
    this.onAction,
    this.actionTooltip,
    this.padding = const EdgeInsets.all(AppSpacing.md),
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: context.textTheme.titleMedium),
                if (actionIcon != null && onAction != null)
                  IconButton(
                    icon: Icon(actionIcon),
                    onPressed: onAction,
                    tooltip: actionTooltip,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// STATUS BADGE
// ============================================================================

/// Status badge widget
class StatusBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color? textColor;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    required this.backgroundColor,
    this.textColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: context.textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// INFO ROW
// ============================================================================

/// Display info row with label and value
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? valueStyle;
  final IconData? icon;

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.valueStyle,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(label, style: context.textTheme.bodyMedium),
            ],
          ),
          Text(
            value,
            style:
                valueStyle ??
                context.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// CUSTOM SEARCH BAR
// ============================================================================

/// Custom search bar widget
class SearchBar extends StatelessWidget {
  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final IconData searchIcon;
  final int maxLines;

  const SearchBar({
    super.key,
    this.controller,
    this.hintText = 'Search...',
    this.onChanged,
    this.onClear,
    this.searchIcon = Icons.search,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(searchIcon),
        suffixIcon: controller?.text.isNotEmpty ?? false
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  controller?.clear();
                  onClear?.call();
                  onChanged?.call('');
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        ),
      ),
    );
  }
}

// ============================================================================
// DATA TABLE WIDGET
// ============================================================================

/// Reusable data table widget for displaying tabular data
class DataTableWidget extends StatelessWidget {
  final List<String> columns;
  final List<List<Widget>> rows;
  final bool isLoading;
  final String? emptyMessage;
  final ScrollController? horizontalScrollController;

  const DataTableWidget({
    super.key,
    required this.columns,
    required this.rows,
    this.isLoading = false,
    this.emptyMessage = 'No data available',
    this.horizontalScrollController,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const LoadingWidget();
    }

    if (rows.isEmpty) {
      return EmptyStateWidget(message: emptyMessage ?? 'No data available');
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      controller: horizontalScrollController,
      child: DataTable(
        columns: columns.map((col) => DataColumn(label: Text(col))).toList(),
        rows: rows
            .map(
              (row) =>
                  DataRow(cells: row.map((cell) => DataCell(cell)).toList()),
            )
            .toList(),
      ),
    );
  }
}

// ============================================================================
// CONFIRMATION DIALOG
// ============================================================================

/// Show confirmation dialog
Future<bool> showConfirmationDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmButtonText = 'Confirm',
  String cancelButtonText = 'Cancel',
  Color? confirmButtonColor,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelButtonText),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmButtonColor ?? context.colorScheme.error,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmButtonText),
        ),
      ],
    ),
  );

  return result ?? false;
}

// ============================================================================
// INPUT FIELD WIDGET
// ============================================================================

/// Reusable text input field with validation
class InputField extends StatefulWidget {
  final String label;
  final String? hint;
  final String? Function(String?)? validator;
  final TextEditingController? controller;
  final TextInputType keyboardType;
  final IconData? prefixIcon;
  final int maxLines;
  final int minLines;
  final bool obscureText;
  final ValueChanged<String>? onChanged;

  const InputField({
    super.key,
    required this.label,
    this.hint,
    this.validator,
    this.controller,
    this.keyboardType = TextInputType.text,
    this.prefixIcon,
    this.maxLines = 1,
    this.minLines = 1,
    this.obscureText = false,
    this.onChanged,
  });

  @override
  State<InputField> createState() => _InputFieldState();
}

class _InputFieldState extends State<InputField> {
  late FocusNode _focusNode;
  bool _hasError = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      _validateField();
    }
  }

  void _validateField() {
    if (widget.validator != null) {
      final error = widget.validator!(widget.controller?.text);
      setState(() {
        _hasError = error != null;
        _errorText = error;
      });
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: context.textTheme.labelMedium),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          keyboardType: widget.keyboardType,
          obscureText: widget.obscureText,
          maxLines: widget.obscureText ? 1 : widget.maxLines,
          minLines: widget.minLines,
          onChanged: (value) {
            widget.onChanged?.call(value);
            if (_hasError) {
              _validateField();
            }
          },
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixIcon: widget.prefixIcon != null
                ? Icon(widget.prefixIcon)
                : null,
            errorText: _errorText,
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.md),
              borderSide: const BorderSide(color: AppTheme.errorColor),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// BUTTON GROUP
// ============================================================================

/// Group of action buttons
class ButtonGroup extends StatelessWidget {
  final List<ButtonConfig> buttons;
  final MainAxisAlignment alignment;
  final MainAxisSize mainAxisSize;

  const ButtonGroup({
    super.key,
    required this.buttons,
    this.alignment = MainAxisAlignment.end,
    this.mainAxisSize = MainAxisSize.min,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: alignment,
      mainAxisSize: mainAxisSize,
      children: [
        for (int i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.md),
          Flexible(child: buttons[i].build()),
        ],
      ],
    );
  }
}

/// Button configuration
class ButtonConfig {
  final String label;
  final VoidCallback onPressed;
  final ButtonStyle? style;
  final IconData? icon;
  final bool isPrimary;

  ButtonConfig({
    required this.label,
    required this.onPressed,
    this.style,
    this.icon,
    this.isPrimary = false,
  });

  Widget build() {
    if (isPrimary) {
      return icon != null
          ? ElevatedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(label),
              style: style,
            )
          : ElevatedButton(
              onPressed: onPressed,
              style: style,
              child: Text(label),
            );
    } else {
      return icon != null
          ? OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(label),
              style: style,
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: style,
              child: Text(label),
            );
    }
  }
}

// ============================================================================
// SECTION HEADER
// ============================================================================

/// Section header with title and optional action
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionText;
  final VoidCallback? onAction;
  final Icon? actionIcon;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionText,
    this.onAction,
    this.actionIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: context.textTheme.headlineSmall),
          if (actionText != null && onAction != null)
            TextButton(
              onPressed: onAction,
              child: Row(
                children: [
                  Text(actionText!),
                  const SizedBox(width: AppSpacing.sm),
                  if (actionIcon != null) actionIcon!,
                ],
              ),
            ),
        ],
      ),
    );
  }
}
