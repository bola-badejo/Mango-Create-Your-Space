// Reduced-motion aware helpers. Read the platform setting
// (iOS Reduce Motion, Android Remove animations, web prefers-reduced-motion
// via the engine) through MediaQuery and shorten or remove movement.
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import '../theme/mango_tokens.dart';

abstract final class MangoMotion {
  /// True when the user has asked the system to reduce motion.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Returns [duration], or a 100 ms cross-fade length when motion is
  /// reduced, so state changes stay visible without movement.
  static Duration duration(BuildContext context, Duration duration) =>
      reduced(context) && duration > MangoMotionTokens.instant
          ? MangoMotionTokens.instant
          : duration;

  /// Returns [curve], or linear when motion is reduced.
  static Curve curve(BuildContext context, Curve curve) =>
      reduced(context) ? Curves.linear : curve;
}

/// Polite screen-reader announcements for state changes that happen away
/// from focus (upload finished, message sent, item added to cart).
/// Use sparingly: do not announce every minor visual change.
abstract final class MangoAnnounce {
  static void polite(BuildContext context, String message) {
    // ignore: deprecated_member_use
    SemanticsService.announce(message, Directionality.of(context));
  }
}
