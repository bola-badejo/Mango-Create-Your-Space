// Shortcuts so widgets read tokens without boilerplate:
//   color: context.colors.textSecondary
//   style: context.type.bodyMedium
import 'package:flutter/material.dart';

import 'mango_colors.dart';

extension MangoContext on BuildContext {
  /// Falls back to the light palette if a screen is rendered outside a
  /// Mango theme (for example, an un-migrated test harness).
  MangoColors get colors =>
      Theme.of(this).extension<MangoColors>() ?? MangoColors.light;

  TextTheme get type => Theme.of(this).textTheme;
}
