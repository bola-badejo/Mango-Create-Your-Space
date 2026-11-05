// Layout helpers that respond to the space a widget actually gets
// (LayoutBuilder), not only to the screen width, so the same component
// works in a full-width mobile screen and in a desktop side column.
import 'package:flutter/widgets.dart';

import '../theme/mango_tokens.dart';
import 'breakpoints.dart';

/// Builds a different child per device class, based on the parent's
/// constraints. Missing builders fall back to the next smaller class.
class MangoResponsiveBuilder extends StatelessWidget {
  const MangoResponsiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  final WidgetBuilder mobile;
  final WidgetBuilder? tablet;
  final WidgetBuilder? desktop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final window = MangoBreakpoints.fromWidth(constraints.maxWidth);
      if (window.isAtLeastDesktop && desktop != null) return desktop!(context);
      if (window.isAtLeastTablet && tablet != null) return tablet!(context);
      return mobile(context);
    });
  }
}

/// Centres content and caps its width, with device-appropriate margins.
/// Use for feeds (640), reading (720) and grids (1200).
class MangoContentWidth extends StatelessWidget {
  const MangoContentWidth({
    super.key,
    required this.child,
    this.maxWidth = MangoSize.maxFeedWidth,
    this.applyMargin = true,
  });

  final Widget child;
  final double maxWidth;
  final bool applyMargin;

  @override
  Widget build(BuildContext context) {
    final margin =
        applyMargin ? MangoBreakpoints.marginFor(MangoBreakpoints.of(context)) : 0.0;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsetsDirectional.symmetric(horizontal: margin),
          child: child,
        ),
      ),
    );
  }
}
