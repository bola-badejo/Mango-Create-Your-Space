import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mango/Core/design_system/navigation/mango_adaptive_shell.dart';
import 'package:mango/Core/theme/mango_theme.dart';

final _destinations = [
  for (final name in ['Chats', 'Spaces', 'Home', 'Feed', 'Profile'])
    MangoDestination(
      label: name,
      icon: Icons.circle_outlined,
      selectedIcon: Icons.circle,
      builder: (_) => Center(child: Text('$name page')),
    ),
];

class _Harness extends StatefulWidget {
  const _Harness();
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  int index = 2;
  @override
  Widget build(BuildContext context) => MaterialApp(
        theme: MangoTheme.light(),
        home: MangoAdaptiveShell(
          destinations: _destinations,
          selectedIndex: index,
          onDestinationSelected: (i) => setState(() => index = i),
        ),
      );
}

Future<void> _pumpAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const _Harness());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('mobile uses a bottom bar with visible labels', (tester) async {
    await _pumpAt(tester, const Size(375, 812));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    for (final name in ['Chats', 'Spaces', 'Home', 'Feed', 'Profile']) {
      expect(find.text(name), findsOneWidget);
    }
  });

  testWidgets('smallest supported width (320) still shows all labels',
      (tester) async {
    await _pumpAt(tester, const Size(320, 640));
    expect(tester.takeException(), isNull);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('tablet uses a navigation rail', (tester) async {
    await _pumpAt(tester, const Size(820, 1180));
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isFalse);
  });

  testWidgets('desktop uses extended side navigation', (tester) async {
    await _pumpAt(tester, const Size(1440, 900));
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isTrue);
  });

  testWidgets('switching tabs builds pages lazily and keeps them',
      (tester) async {
    await _pumpAt(tester, const Size(375, 812));
    expect(find.text('Home page'), findsOneWidget);
    expect(find.text('Chats page', skipOffstage: false), findsNothing);

    await tester.tap(find.text('Chats'));
    await tester.pumpAndSettle();
    expect(find.text('Chats page'), findsOneWidget);
    // Home stays built (off stage) so its state survives.
    expect(find.text('Home page', skipOffstage: false), findsOneWidget);
  });

  testWidgets('navigation meets tap target guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpAt(tester, const Size(375, 812));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
}
