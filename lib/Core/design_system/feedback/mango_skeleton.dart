// Skeleton placeholder that matches the shape of the content it stands
// for. The shimmer sweeps once per 1.2 s; with reduced motion it is a
// static fill. Skeletons are hidden from screen readers; wrap a loading
// region in MangoLoadingRegion to announce "Loading" once instead.
import 'package:flutter/material.dart';

import '../../accessibility/mango_motion.dart';
import '../../theme/mango_context.dart';
import '../../theme/mango_tokens.dart';

class MangoSkeleton extends StatefulWidget {
  const MangoSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.radius = MangoRadius.sm,
    this.circle = false,
  });

  final double? width;
  final double height;
  final double radius;
  final bool circle;

  @override
  State<MangoSkeleton> createState() => _MangoSkeletonState();
}

class _MangoSkeletonState extends State<MangoSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MangoMotion.reduced(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final base = c.bgSecondary;
    final highlight = c.surfaceRaised;
    final shape = BoxDecoration(
      color: base,
      shape: widget.circle ? BoxShape.circle : BoxShape.rectangle,
      borderRadius:
          widget.circle ? null : BorderRadius.circular(widget.radius),
    );

    final box = Container(
      width: widget.width,
      height: widget.height,
      decoration: shape,
    );

    if (MangoMotion.reduced(context)) return ExcludeSemantics(child: box);

    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        child: box,
        builder: (context, child) {
          final t = _controller.value;
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (rect) => LinearGradient(
              begin: Alignment(-1.5 + 3 * t, 0),
              end: Alignment(-0.5 + 3 * t, 0),
              colors: [base, highlight, base],
            ).createShader(rect),
            child: child,
          );
        },
      ),
    );
  }
}

/// Announces a loading region once ("Loading posts") and exposes busy
/// state, while its skeleton children stay silent.
class MangoLoadingRegion extends StatelessWidget {
  const MangoLoadingRegion({
    super.key,
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      liveRegion: true,
      child: child,
    );
  }
}
