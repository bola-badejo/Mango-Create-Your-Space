import 'package:flutter/material.dart';
import 'package:mango/Core/design_system/mango_ui.dart';

class ShimmerWidget extends StatelessWidget {
  final double width;
  final double height;
  final EdgeInsetsGeometry margin;
  final ShapeBorder shapeBorder;

  const ShimmerWidget.rectangular(
      {super.key, required this.width, required this.height})
      : shapeBorder = const RoundedRectangleBorder(),
        margin = const EdgeInsets.all(0);
  const ShimmerWidget.rectangularCircular(
      {super.key, required this.width, required this.height})
      : margin = const EdgeInsets.all(0),
        shapeBorder = const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)));
  const ShimmerWidget.rectangularCircularMargin(
      {super.key,
      required this.width,
      required this.height,
      required this.margin})
      : shapeBorder = const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)));
  const ShimmerWidget.circular(
      {super.key,
      required this.width,
      required this.height,
      this.shapeBorder = const CircleBorder()})
      : margin = const EdgeInsets.all(0);

  @override
  Widget build(BuildContext context) {
    // Skeleton colours follow the theme, so dark screens get dark
    // skeletons. MangoShimmer stops the sweep under reduced motion and
    // keeps placeholders silent for screen readers.
    final c = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? c.surfaceElevated : c.borderSubtle;
    final highlight = dark ? c.surfaceRaised : c.bgSecondary;
    return MangoShimmer(
      baseColor: base,
      highlightColor: highlight,
      child: Container(
        margin: margin,
        width: width,
        height: height,
        decoration: ShapeDecoration(
          shape: shapeBorder,
          color: base,
        ),
      ),
    );
  }
}
