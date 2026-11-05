// Social action with micro-interaction: like, repost, comment, share,
// save. The icon swaps with a short spring "pop" when it becomes active,
// the count ticks to its new value, and the state is exposed to screen
// readers ("Like, 12 likes" / "Liked, 13 likes").
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../accessibility/mango_motion.dart';
import '../../theme/mango_context.dart';
import '../../theme/mango_tokens.dart';
import 'mango_pressable.dart';

class MangoReactionButton extends StatefulWidget {
  const MangoReactionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.activeIcon,
    this.activeLabel,
    this.isActive = false,
    this.count = 0,
    this.countNoun,
    this.activeColor,
    this.inactiveColor,
    this.background,
    this.activeBackground,
    this.iconSize = 16,
    this.formatCount,
    this.haptic = false,
  });

  final IconData icon;
  final IconData? activeIcon;

  /// Action name when inactive, for example "Like".
  final String label;

  /// Name when active, for example "Liked". Defaults to [label].
  final String? activeLabel;
  final VoidCallback onTap;
  final bool isActive;
  final int count;

  /// Spoken with the count, for example "likes" gives "12 likes".
  final String? countNoun;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? background;
  final Color? activeBackground;
  final double iconSize;
  final String Function(int)? formatCount;

  /// Light haptic when the action becomes active (likes and saves).
  final bool haptic;

  @override
  State<MangoReactionButton> createState() => _MangoReactionButtonState();
}

class _MangoReactionButtonState extends State<MangoReactionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25), weight: 40),
    TweenSequenceItem(tween: Tween(begin: 1.25, end: 0.95), weight: 30),
    TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0), weight: 30),
  ]).animate(CurvedAnimation(parent: _pop, curve: Curves.easeOut));

  @override
  void didUpdateWidget(covariant MangoReactionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      if (widget.haptic) HapticFeedback.lightImpact();
      if (!MangoMotion.reduced(context)) _pop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final active = widget.isActive;
    final fg = active
        ? (widget.activeColor ?? c.textBrand)
        : (widget.inactiveColor ?? c.textSecondary);
    final bg = active
        ? (widget.activeBackground ?? fg.withValues(alpha: 0.14))
        : (widget.background ?? Colors.transparent);
    final countText = widget.count > 0
        ? (widget.formatCount?.call(widget.count) ?? '${widget.count}')
        : null;
    final name = active ? (widget.activeLabel ?? widget.label) : widget.label;
    final spoken = widget.countNoun != null && widget.count > 0
        ? '$name, ${widget.count} ${widget.countNoun}'
        : name;
    final duration = MangoMotion.duration(context, MangoMotionTokens.fast);

    return MangoPressable(
      onTap: widget.onTap,
      semanticLabel: spoken,
      child: ExcludeSemantics(
        child: ConstrainedBox(
          // Visual chip stays compact; the touch area meets 44 x 44.
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Center(
            widthFactor: 1,
            child: AnimatedContainer(
              duration: duration,
              curve: MangoMotionTokens.standard,
              padding: const EdgeInsets.symmetric(
                horizontal: MangoSpace.s2,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(MangoRadius.sm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: _scale,
                    child: AnimatedSwitcher(
                      duration: duration,
                      transitionBuilder: (child, anim) =>
                          FadeTransition(opacity: anim, child: child),
                      child: Icon(
                        active ? (widget.activeIcon ?? widget.icon) : widget.icon,
                        key: ValueKey(active),
                        size: widget.iconSize,
                        color: fg,
                      ),
                    ),
                  ),
                  if (countText != null) ...[
                    const SizedBox(width: MangoSpace.s1),
                    AnimatedSwitcher(
                      duration: duration,
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SizeTransition(
                          sizeFactor: anim,
                          axis: Axis.horizontal,
                          child: child,
                        ),
                      ),
                      child: Text(
                        countText,
                        key: ValueKey(countText),
                        style: context.type.labelLarge?.copyWith(
                          color: fg,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
