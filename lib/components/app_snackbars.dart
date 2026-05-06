import 'package:flutter/material.dart';

/// Small helper for consistent in-app notifications.
///
/// Uses a floating [SnackBar] with theme-driven colors (no hard-coded palette).
class AppSnackbars {
  static void success(BuildContext context, String message) => _show(context, message, _SnackKind.success);

  static void error(BuildContext context, String message) => _show(context, message, _SnackKind.error);

  static void info(BuildContext context, String message) => _show(context, message, _SnackKind.info);

  static void warning(BuildContext context, String message) => _show(context, message, _SnackKind.warning);

  static void _show(BuildContext context, String message, _SnackKind kind) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    final scheme = Theme.of(context).colorScheme;
    final (bg, fg, icon) = switch (kind) {
      _SnackKind.success => (scheme.primary, scheme.onPrimary, Icons.check_circle),
      _SnackKind.error => (scheme.error, scheme.onError, Icons.error_outline),
      _SnackKind.info => (scheme.secondary, scheme.onSecondary, Icons.info_outline),
      _SnackKind.warning => (scheme.tertiary, scheme.onTertiary, Icons.warning_amber_rounded),
    };

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          backgroundColor: bg,
          content: Row(
            children: [
              Icon(icon, color: fg),
              const SizedBox(width: 12),
              Expanded(child: Text(message, style: TextStyle(color: fg, fontWeight: FontWeight.w600))),
            ],
          ),
        ),
      );
  }
}

enum _SnackKind { success, error, info, warning }
