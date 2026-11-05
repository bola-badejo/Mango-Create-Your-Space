// Drop-in replacement for a tap-only GestureDetector.
//
// Adds, without changing what the tap does:
//   - press feedback: a slight scale on small targets, an opacity dip on
//     large ones; opacity only when the user has asked to reduce motion
//   - button semantics, so screen readers announce "button" and the
//     child's text becomes its name (or [semanticLabel] for icon-only)
//   - keyboard access: focusable, Enter and Space activate, visible focus
//   - a pointer cursor on web and desktop
//   - Material's standard tap and long-press feedback (sound, haptic)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../accessibility/mango_motion.dart';
import '../../theme/mango_context.dart';
import '../../theme/mango_tokens.dart';

class MangoPressable extends StatefulWidget {
  const MangoPressable({
    super.key,
    this.onTap,
    this.onLongPress,
    this.onDoubleTap,
    this.child,
    this.semanticLabel,
    this.behavior,
    this.focusRadius = MangoRadius.sm,
  });

  final GestureTapCallback? onTap;
  final GestureLongPressCallback? onLongPress;
  final GestureTapCallback? onDoubleTap;
  final Widget? child;

  /// Required for icon-only targets; text children name themselves.
  final String? semanticLabel;
  final HitTestBehavior? behavior;
  final double focusRadius;

  @override
  State<MangoPressable> createState() => _MangoPressableState();
}

class _MangoPressableState extends State<MangoPressable> {
  bool _pressed = false;
  bool _focused = false;
  double _pressScale = 0.97;

  bool get _enabled =>
      widget.onTap != null ||
      widget.onLongPress != null ||
      widget.onDoubleTap != null;

  void _setPressed(bool value) {
    if (_pressed != value && mounted) setState(() => _pressed = value);
  }

  void _onTapDown(TapDownDetails _) {
    // Scale only small targets; a whole card or panel shrinking reads as
    // a glitch, so large targets get an opacity dip instead.
    final size = context.size;
    _pressScale = size == null
        ? 0.97
        : size.longestSide <= 160
            ? 0.94
            : size.longestSide <= 400
                ? 0.98
                : 1.0;
    _setPressed(true);
  }

  void _handleTap() {
    if (widget.onTap == null) return;
    Feedback.forTap(context);
    widget.onTap!();
  }

  void _handleLongPress() {
    if (widget.onLongPress == null) return;
    Feedback.forLongPress(context);
    widget.onLongPress!();
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child ?? const SizedBox.shrink();
    if (!_enabled) return child;

    final reduced = MangoMotion.reduced(context);
    final scale = _pressed && !reduced ? _pressScale : 1.0;
    final opacity = _pressed && (reduced || _pressScale == 1.0) ? 0.72 : 1.0;

    Widget content = AnimatedScale(
      scale: scale,
      duration: MangoMotionTokens.instant,
      curve: MangoMotionTokens.standard,
      child: AnimatedOpacity(
        opacity: opacity,
        duration: MangoMotionTokens.instant,
        child: child,
      ),
    );

    if (_focused) {
      content = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.focusRadius),
          border: Border.all(
            color: context.colors.focusRing,
            width: MangoSize.focusRingWidth,
          ),
        ),
        child: content,
      );
    }

    return FocusableActionDetector(
      enabled: widget.onTap != null,
      mouseCursor: widget.onTap != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _handleTap();
            return null;
          },
        ),
      },
      child: Semantics(
        container: true,
        button: widget.onTap != null,
        label: widget.semanticLabel,
        child: GestureDetector(
          behavior: widget.behavior,
          onTap: widget.onTap == null ? null : _handleTap,
          onLongPress: widget.onLongPress == null ? null : _handleLongPress,
          onDoubleTap: widget.onDoubleTap,
          onTapDown: widget.onTap == null ? null : _onTapDown,
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          child: content,
        ),
      ),
    );
  }
}
