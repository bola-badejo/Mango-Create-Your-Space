// Adaptive navigation shell.
//
//   < 768 px     bottom NavigationBar, labels always visible
//   768–1023 px  NavigationRail with labels
//   >= 1024 px   extended NavigationRail (side navigation)
//
// Destinations are switched by tap or keyboard only. There is no swipe
// between destinations, so horizontal carousels inside pages own their
// own gestures. Each destination is built the first time it is visited
// and then kept alive, so scroll position and state survive tab switches
// without building every tab at startup.
import 'package:flutter/material.dart';

import '../../accessibility/mango_motion.dart';
import '../../responsive/breakpoints.dart';
import '../../theme/mango_context.dart';
import '../../theme/mango_tokens.dart';

class MangoDestination {
  const MangoDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.builder,
  });

  /// Short visible label; also the accessible name.
  final String label;
  final IconData icon;

  /// Filled variant, so selection is shown by shape as well as colour.
  final IconData selectedIcon;
  final WidgetBuilder builder;
}

class MangoAdaptiveShell extends StatefulWidget {
  const MangoAdaptiveShell({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.onReselect,
    this.accessory,
  });

  final List<MangoDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  /// Tapping the active destination again; screens can scroll to top.
  final ValueChanged<int>? onReselect;

  /// Persistent element above the bottom bar on mobile, or at the bottom
  /// of the content area on wider screens (for example the mini player).
  final Widget? accessory;

  @override
  State<MangoAdaptiveShell> createState() => _MangoAdaptiveShellState();
}

class _MangoAdaptiveShellState extends State<MangoAdaptiveShell> {
  // Destinations that have been opened at least once.
  late final Set<int> _visited = {widget.selectedIndex};

  @override
  void didUpdateWidget(covariant MangoAdaptiveShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    _visited.add(widget.selectedIndex);
  }

  void _select(int index) {
    if (index == widget.selectedIndex) {
      widget.onReselect?.call(index);
    } else {
      widget.onDestinationSelected(index);
    }
  }

  Widget _body(BuildContext context) {
    final duration = MangoMotion.duration(context, MangoMotionTokens.base);
    return IndexedStack(
      index: widget.selectedIndex,
      children: [
        for (var i = 0; i < widget.destinations.length; i++)
          // Off-stage pages are removed from focus traversal and the
          // semantics tree so keyboard and screen readers stay in the
          // visible tab.
          ExcludeFocus(
            excluding: i != widget.selectedIndex,
            child: ExcludeSemantics(
              excluding: i != widget.selectedIndex,
              child: TickerMode(
                enabled: i == widget.selectedIndex,
                child: _visited.contains(i)
                    ? AnimatedOpacity(
                        opacity: i == widget.selectedIndex ? 1 : 0,
                        duration: duration,
                        curve: MangoMotionTokens.standard,
                        child: widget.destinations[i].builder(context),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final window = MangoBreakpoints.of(context);
    final c = context.colors;

    if (window.isMobile) {
      return Scaffold(
        body: _body(context),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.accessory != null) widget.accessory!,
            NavigationBar(
              selectedIndex: widget.selectedIndex,
              onDestinationSelected: _select,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              animationDuration:
                  MangoMotion.duration(context, MangoMotionTokens.base),
              destinations: [
                for (final d in widget.destinations)
                  NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: d.label,
                    // Labels are always visible, so no duplicate tooltip.
                    tooltip: '',
                  ),
              ],
            ),
          ],
        ),
      );
    }

    final extended = window.isAtLeastDesktop;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Row(
          children: [
            FocusTraversalGroup(
              child: Semantics(
                container: true,
                explicitChildNodes: true,
                label: 'Main navigation',
                child: NavigationRail(
                  selectedIndex: widget.selectedIndex,
                  onDestinationSelected: _select,
                  extended: extended,
                  minExtendedWidth: 240,
                  labelType: extended
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
                  groupAlignment: -1,
                  destinations: [
                    for (final d in widget.destinations)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selectedIcon),
                        label: Text(d.label),
                        padding: const EdgeInsets.symmetric(
                          vertical: MangoSpace.s1,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            VerticalDivider(width: 1, thickness: 1, color: c.borderSubtle),
            Expanded(
              child: Column(
                children: [
                  Expanded(child: _body(context)),
                  if (widget.accessory != null) widget.accessory!,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
