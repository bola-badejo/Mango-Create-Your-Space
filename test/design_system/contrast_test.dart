// Guards the colour contract: every text and control pairing keeps the
// WCAG contrast ratio stated in the design system specification.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mango/Core/theme/mango_colors.dart';

double _channel(double c) =>
    c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color color) =>
    0.2126 * _channel(color.r) +
    0.7152 * _channel(color.g) +
    0.0722 * _channel(color.b);

double contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  const textAA = 4.5;
  const uiAA = 3.0;

  for (final (name, c) in [
    ('light', MangoColors.light),
    ('dark', MangoColors.dark),
  ]) {
    group('$name theme', () {
      final surfaces = [c.bgPrimary, c.bgSecondary, c.surfaceElevated, c.surfaceRaised];

      test('primary, secondary and tertiary text meet 4.5:1 on all surfaces', () {
        for (final s in surfaces) {
          expect(contrast(c.textPrimary, s), greaterThanOrEqualTo(textAA));
          expect(contrast(c.textSecondary, s), greaterThanOrEqualTo(textAA));
          expect(contrast(c.textTertiary, s), greaterThanOrEqualTo(textAA));
          expect(contrast(c.textBrand, s), greaterThanOrEqualTo(textAA));
        }
      });

      test('primary action label meets 4.5:1', () {
        expect(contrast(c.onActionPrimary, c.actionPrimary),
            greaterThanOrEqualTo(textAA));
      });

      test('control borders and focus ring meet 3:1', () {
        for (final s in [c.bgPrimary, c.bgSecondary]) {
          expect(contrast(c.borderControl, s), greaterThanOrEqualTo(uiAA));
          expect(contrast(c.focusRing, s), greaterThanOrEqualTo(uiAA));
        }
      });

      test('status colours meet 4.5:1 on their containers', () {
        expect(contrast(c.success, c.successContainer), greaterThanOrEqualTo(textAA));
        expect(contrast(c.warning, c.warningContainer), greaterThanOrEqualTo(textAA));
        expect(contrast(c.error, c.errorContainer), greaterThanOrEqualTo(textAA));
        expect(contrast(c.info, c.infoContainer), greaterThanOrEqualTo(textAA));
      });
    });
  }
}
