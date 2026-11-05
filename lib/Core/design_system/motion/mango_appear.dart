// Content entrance: fades in and rises 8 px the first time it is built,
// so new content arrives with orientation instead of popping. Under
// reduced motion it simply appears. Keep [delay] small (index * 40 ms,
// capped at three items) so lists never feel slow.
import 'package:flutter/widgets.dart';

import '../../accessibility/mango_motion.dart';
import '../../theme/mango_tokens.dart';

class MangoAppear extends StatefulWidget {
  const MangoAppear({super.key, required this.child, this.delay = Duration.zero});

  /// Stagger for the item at [index]: 0, 40 and 80 ms, then no delay.
  factory MangoAppear.staggered({Key? key, required int index, required Widget child}) =>
      MangoAppear(
        key: key,
        delay: Duration(milliseconds: 40 * (index < 3 ? index : 0)),
        child: child,
      );

  final Widget child;
  final Duration delay;

  @override
  State<MangoAppear> createState() => _MangoAppearState();
}

class _MangoAppearState extends State<MangoAppear> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (MangoMotion.reduced(context)) return widget.child;
    final duration = MangoMotionTokens.base;
    return AnimatedOpacity(
      opacity: _shown ? 1 : 0,
      duration: duration,
      curve: MangoMotionTokens.enter,
      child: AnimatedSlide(
        offset: _shown ? Offset.zero : const Offset(0, 0.04),
        duration: duration,
        curve: MangoMotionTokens.enter,
        child: widget.child,
      ),
    );
  }
}

/// Cross-fades between loading, empty, error and content states so the
/// switch is visible without movement. Give each state a distinct key.
class MangoStateSwitcher extends StatelessWidget {
  const MangoStateSwitcher({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: MangoMotion.duration(context, MangoMotionTokens.base),
      switchInCurve: MangoMotionTokens.enter,
      switchOutCurve: MangoMotionTokens.exit,
      child: child,
    );
  }
}
