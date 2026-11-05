// Drop-in replacement for `Shimmer.fromColors(...)` from package:shimmer.
// Same parameters, plus: stops sweeping when the user has asked to reduce
// motion, and is hidden from screen readers (wrap the loading region in
// MangoLoadingRegion to announce "Loading" once).
import 'package:flutter/widgets.dart';
import 'package:shimmer/shimmer.dart';

import '../../accessibility/mango_motion.dart';

class MangoShimmer extends StatelessWidget {
  const MangoShimmer({
    super.key,
    required this.baseColor,
    required this.highlightColor,
    required this.child,
    this.period = const Duration(milliseconds: 1500),
    this.direction = ShimmerDirection.ltr,
    this.loop = 0,
    this.enabled = true,
  });

  final Color baseColor;
  final Color highlightColor;
  final Widget child;
  final Duration period;
  final ShimmerDirection direction;
  final int loop;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        period: period,
        direction: direction,
        loop: loop,
        enabled: enabled && !MangoMotion.reduced(context),
        child: child,
      ),
    );
  }
}
