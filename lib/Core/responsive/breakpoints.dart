// Device classes from the responsive brief. Width-based, never model-based.
// Flutter receives logical pixels, which match CSS pixels on web.
import 'package:flutter/widgets.dart';

import '../theme/mango_tokens.dart';

enum MangoWindow {
  /// 320-374: essential content, compact navigation.
  smallMobile,

  /// 375-767: the primary mobile experience.
  mobile,

  /// 768-1023: expanded layout and navigation rail.
  tablet,

  /// 1024-1399: multi-column composition, persistent navigation.
  desktop,

  /// 1400+: controlled expansion; content keeps its maximum widths.
  largeDesktop;

  bool get isMobile => this == smallMobile || this == mobile;
  bool get isAtLeastTablet => index >= tablet.index;
  bool get isAtLeastDesktop => index >= desktop.index;
}

abstract final class MangoBreakpoints {
  static const double mobile = 375;
  static const double tablet = 768;
  static const double desktop = 1024;
  static const double largeDesktop = 1400;

  static MangoWindow fromWidth(double width) {
    if (width >= largeDesktop) return MangoWindow.largeDesktop;
    if (width >= desktop) return MangoWindow.desktop;
    if (width >= tablet) return MangoWindow.tablet;
    if (width >= mobile) return MangoWindow.mobile;
    return MangoWindow.smallMobile;
  }

  /// Uses MediaQuery.sizeOf so the caller rebuilds only on size changes,
  /// not on keyboard insets or other MediaQuery updates.
  static MangoWindow of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);

  /// Horizontal screen margin per device class.
  static double marginFor(MangoWindow window) => switch (window) {
        MangoWindow.smallMobile => MangoSpace.s3,
        MangoWindow.mobile => MangoSpace.s4,
        MangoWindow.tablet => MangoSpace.s6,
        MangoWindow.desktop => MangoSpace.s8,
        MangoWindow.largeDesktop => MangoSpace.s10,
      };
}
