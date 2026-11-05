// Mango's button. One component covers primary, secondary, tertiary,
// text and destructive variants, with loading and success states tied to
// the real outcome of the action.
//
// Accessibility: button role, label equals visible text, busy state
// announced, minimum 48 dp target. Repeated taps while an action is in
// flight are ignored, preventing duplicate submissions.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../accessibility/mango_motion.dart';
import '../../theme/mango_context.dart';
import '../../theme/mango_tokens.dart';

enum MangoButtonVariant { primary, secondary, tertiary, text, destructive }

enum MangoButtonSize { large, medium }

enum _Phase { idle, loading, success }

class MangoButton extends StatefulWidget {
  const MangoButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = MangoButtonVariant.primary,
    this.size = MangoButtonSize.large,
    this.icon,
    this.expand = false,
    this.showSuccess = false,
    this.successLabel,
    this.onError,
  });

  /// Visible text, also used as the accessible name.
  final String label;

  /// Null disables the button. If it returns a Future, the button shows a
  /// loading state until it completes, and success only if it completes
  /// without throwing. A thrown error returns the button to idle and is
  /// passed to [onError], where the caller shows what went wrong.
  final FutureOr<void> Function()? onPressed;

  /// Called when an async [onPressed] throws. Show a specific message
  /// (what happened, why it matters, what to do next) and offer a retry.
  final void Function(Object error)? onError;

  final MangoButtonVariant variant;
  final MangoButtonSize size;
  final IconData? icon;

  /// Fill the available width (forms and sheets on mobile).
  final bool expand;

  /// Briefly show a check after a successful async action.
  final bool showSuccess;

  /// Announced and shown on success, for example "Saved". Defaults to "Done".
  final String? successLabel;

  @override
  State<MangoButton> createState() => _MangoButtonState();
}

class _MangoButtonState extends State<MangoButton> {
  _Phase _phase = _Phase.idle;
  Timer? _successTimer;

  bool get _busy => _phase != _Phase.idle;

  @override
  void dispose() {
    _successTimer?.cancel();
    super.dispose();
  }

  Future<void> _handlePress() async {
    final action = widget.onPressed;
    if (action == null || _busy) return; // guards duplicate submission
    final result = action();
    if (result is! Future) return; // synchronous action: no loading state

    setState(() => _phase = _Phase.loading);
    try {
      await result;
      if (!mounted) return;
      if (widget.showSuccess) {
        setState(() => _phase = _Phase.success);
        MangoAnnounce.polite(context, widget.successLabel ?? 'Done');
        _successTimer = Timer(const Duration(milliseconds: 600), () {
          if (mounted) setState(() => _phase = _Phase.idle);
        });
      } else {
        setState(() => _phase = _Phase.idle);
      }
    } catch (error) {
      if (mounted) setState(() => _phase = _Phase.idle);
      widget.onError?.call(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final height = widget.size == MangoButtonSize.large
        ? MangoSize.buttonLarge
        : MangoSize.buttonMedium;
    final enabled = widget.onPressed != null;

    final (Color bg, Color fg, BorderSide? side) = switch (widget.variant) {
      MangoButtonVariant.primary => (c.actionPrimary, c.onActionPrimary, null),
      MangoButtonVariant.secondary => (c.surfaceSelected, c.textBrand, null),
      MangoButtonVariant.tertiary => (
          Colors.transparent,
          c.textPrimary,
          BorderSide(color: c.borderControl),
        ),
      MangoButtonVariant.text => (Colors.transparent, c.textBrand, null),
      MangoButtonVariant.destructive => (c.error, c.bgPrimary, null),
    };

    final Widget content = switch (_phase) {
      _Phase.loading => SizedBox.square(
          key: const ValueKey('loading'),
          dimension: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: fg),
        ),
      _Phase.success => Icon(
          Icons.check_rounded,
          key: const ValueKey('success'),
          size: 20,
          color: fg,
        ),
      _Phase.idle => Row(
          key: const ValueKey('idle'),
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, size: MangoSize.iconSmall),
              const SizedBox(width: MangoSpace.s2),
            ],
            Flexible(
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
    };

    final semanticsLabel = switch (_phase) {
      _Phase.loading => '${widget.label}, loading',
      _Phase.success => widget.successLabel ?? 'Done',
      _Phase.idle => widget.label,
    };

    final baseStyle = FilledButton.styleFrom(
      backgroundColor: bg,
      foregroundColor: fg,
      disabledBackgroundColor: bg == Colors.transparent
          ? Colors.transparent
          : c.textPrimary.withValues(alpha: 0.12),
      disabledForegroundColor: c.textPrimary.withValues(alpha: 0.38),
      side: side,
      minimumSize: Size(64, height),
      padding: EdgeInsets.symmetric(
        horizontal: widget.size == MangoButtonSize.large
            ? MangoSpace.s6
            : MangoSpace.s4,
      ),
    );

    final button = FilledButton(
      onPressed: enabled ? _handlePress : null,
      // While busy the button stays enabled-looking; taps are ignored in
      // _handlePress, so the colour does not flash to the disabled style.
      style: baseStyle,
      child: AnimatedSwitcher(
        duration: MangoMotion.duration(context, MangoMotionTokens.fast),
        child: content,
      ),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticsLabel,
      excludeSemantics: true,
      onTap: enabled && !_busy ? _handlePress : null,
      child: widget.expand
          ? SizedBox(width: double.infinity, child: button)
          : ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: button,
            ),
    );
  }
}

/// Icon-only button. [semanticLabel] is required, so an unlabelled icon
/// button cannot be written. The label is also shown as a tooltip.
class MangoIconButton extends StatelessWidget {
  const MangoIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.selected,
    this.selectedIcon,
  });

  final IconData icon;
  final IconData? selectedIcon;
  final String semanticLabel;
  final VoidCallback? onPressed;

  /// Non-null makes this a toggle (like, save, follow): selection is
  /// exposed to assistive technology, not only drawn.
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final isSelected = selected ?? false;
    return Semantics(
      toggled: selected,
      child: IconButton(
        tooltip: semanticLabel,
        onPressed: onPressed,
        isSelected: selected,
        icon: Icon(icon),
        selectedIcon: Icon(selectedIcon ?? icon),
        color: isSelected ? context.colors.textBrand : null,
      ),
    );
  }
}
