import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mango/Core/design_system/buttons/mango_button.dart';
import 'package:mango/Core/theme/mango_theme.dart';

Widget _host(Widget child) => MaterialApp(
      theme: MangoTheme.light(),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('ignores taps while an async action is running', (tester) async {
    final handle = tester.ensureSemantics();
    final completer = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(_host(MangoButton(
      label: 'Publish',
      onPressed: () {
        calls++;
        return completer.future;
      },
    )));

    await tester.tap(find.byType(MangoButton));
    await tester.pump();
    await tester.tap(find.byType(MangoButton));
    await tester.pump();
    expect(calls, 1);
    expect(find.bySemanticsLabel('Publish, loading'), findsOneWidget);

    completer.complete();
    await tester.pumpAndSettle();
    expect(find.text('Publish'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('shows success only after the action completes', (tester) async {
    final completer = Completer<void>();
    await tester.pumpWidget(_host(MangoButton(
      label: 'Save',
      showSuccess: true,
      successLabel: 'Saved',
      onPressed: () => completer.future,
    )));

    await tester.tap(find.byType(MangoButton));
    await tester.pump();
    expect(find.byIcon(Icons.check_rounded), findsNothing);

    completer.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 1));
  });

  testWidgets('reports errors and returns to idle', (tester) async {
    Object? reported;
    await tester.pumpWidget(_host(MangoButton(
      label: 'Send',
      onPressed: () async => throw StateError('offline'),
      onError: (e) => reported = e,
    )));
    await tester.tap(find.byType(MangoButton));
    await tester.pumpAndSettle();
    expect(reported, isA<StateError>());
    expect(find.text('Send'), findsOneWidget);
  });

  testWidgets('meets tap target and labelling guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(Column(mainAxisSize: MainAxisSize.min, children: [
      MangoButton(label: 'Follow', onPressed: () {}, size: MangoButtonSize.medium),
      MangoIconButton(
        icon: Icons.favorite_border,
        selectedIcon: Icons.favorite,
        semanticLabel: 'Like',
        selected: false,
        onPressed: () {},
      ),
    ])));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });
}
