// Short confirmations and errors, for example "Link copied" or
// "Couldn't send. Check your connection and try again."
// Status is shown with an icon and words, never colour alone.
import 'package:flutter/material.dart';

import '../../theme/mango_context.dart';
import '../../theme/mango_tokens.dart';

enum MangoToastKind { info, success, error }

abstract final class MangoToast {
  static void show(
    BuildContext context, {
    required String message,
    MangoToastKind kind = MangoToastKind.info,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final c = context.colors;
    final icon = switch (kind) {
      MangoToastKind.info => Icons.info_outline_rounded,
      MangoToastKind.success => Icons.check_circle_outline_rounded,
      MangoToastKind.error => Icons.error_outline_rounded,
    };
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        // Errors stay longer so they can be read and acted on.
        duration: Duration(seconds: kind == MangoToastKind.error ? 8 : 4),
        content: Row(
          children: [
            Icon(icon, color: c.bgPrimary, size: MangoSize.icon),
            const SizedBox(width: MangoSpace.s3),
            Expanded(child: Text(message)),
          ],
        ),
        action: actionLabel != null && onAction != null
            ? SnackBarAction(label: actionLabel, onPressed: onAction)
            : null,
      ),
    );
  }
}
