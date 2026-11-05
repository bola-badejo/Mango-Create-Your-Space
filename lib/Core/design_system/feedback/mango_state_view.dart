// One component for the non-ideal states every screen must design:
// empty, error, offline and permission denied. Each says what happened,
// why it matters, and what to do next, with one clear action.
import 'package:flutter/material.dart';

import '../../theme/mango_context.dart';
import '../../theme/mango_tokens.dart';
import '../buttons/mango_button.dart';

enum MangoStateKind { empty, error, offline, permissionDenied }

class MangoStateView extends StatelessWidget {
  const MangoStateView({
    super.key,
    required this.kind,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  /// Offline state with standard wording; screens may still override.
  factory MangoStateView.offline({Key? key, VoidCallback? onRetry}) =>
      MangoStateView(
        key: key,
        kind: MangoStateKind.offline,
        title: "You're offline",
        message: 'Saved content is still available. New posts will load '
            'when you reconnect.',
        actionLabel: onRetry == null ? null : 'Try again',
        onAction: onRetry,
      );

  final MangoStateKind kind;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  IconData get _icon => switch (kind) {
        MangoStateKind.empty => Icons.inbox_outlined,
        MangoStateKind.error => Icons.error_outline_rounded,
        MangoStateKind.offline => Icons.cloud_off_rounded,
        MangoStateKind.permissionDenied => Icons.lock_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final iconColor = kind == MangoStateKind.error ? c.error : c.textTertiary;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(MangoSpace.s6),
          child: Semantics(
            // Errors are announced when they appear; other states are not.
            liveRegion: kind == MangoStateKind.error,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: Icon(_icon, size: 40, color: iconColor),
                ),
                const SizedBox(height: MangoSpace.s4),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: context.type.titleLarge,
                ),
                const SizedBox(height: MangoSpace.s2),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: context.type.bodyMedium
                      ?.copyWith(color: c.textSecondary),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: MangoSpace.s6),
                  MangoButton(
                    label: actionLabel!,
                    onPressed: onAction,
                    size: MangoButtonSize.medium,
                    variant: MangoButtonVariant.secondary,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
