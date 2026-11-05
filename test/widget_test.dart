// App-level smoke tests that run without Firebase: the Mango theme builds
// in both modes and core components render inside it.
//
// The previous file was Flutter's default counter template, which did not
// match this app and could never pass.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mango/Core/design_system/feedback/mango_state_view.dart';
import 'package:mango/Core/theme/mango_colors.dart';
import 'package:mango/Core/theme/mango_theme.dart';

void main() {
  test('light and dark themes build with Mango tokens', () {
    final light = MangoTheme.light();
    final dark = MangoTheme.dark();
    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(light.extension<MangoColors>(), same(MangoColors.light));
    expect(dark.extension<MangoColors>(), same(MangoColors.dark));
    expect(light.textTheme.bodyMedium?.fontFamily, 'Poppins');
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('state view renders in $mode', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: MangoTheme.light(),
        darkTheme: MangoTheme.dark(),
        themeMode: mode,
        home: Scaffold(
          body: MangoStateView.offline(onRetry: () {}),
        ),
      ));
      expect(find.text("You're offline"), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
