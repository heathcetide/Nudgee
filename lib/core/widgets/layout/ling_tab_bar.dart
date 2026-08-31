import 'package:flutter/material.dart';

/// A platform-adaptive bottom navigation bar.
///
/// Uses [NavigationBar] on Material 3. Provides typed tab management
/// with an index callback. Pair with [LingTabScaffold] for a complete
/// scaffold with tab switching and state preservation.
class LingTabBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<LingTabItem> items;

  const LingTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      destinations: items.map((item) {
        return NavigationDestination(
          icon: item.icon,
          selectedIcon: item.activeIcon ?? item.icon,
          label: item.label,
          tooltip: item.tooltip ?? item.label,
        );
      }).toList(),
    );
  }
}

/// A tab item configuration.
class LingTabItem {
  final Widget icon;
  final Widget? activeIcon;
  final String label;
  final String? tooltip;

  const LingTabItem({
    required this.icon,
    required this.label,
    this.activeIcon,
    this.tooltip,
  });
}

/// A scaffold with a bottom tab bar and indexed page content.
///
/// Preserves the state of each tab page using [IndexedStack].
/// This is the most common tab pattern — pages stay alive when
/// switching tabs.
///
/// ```dart
/// LingTabScaffold(
///   tabs: [
///     LingTabItem(icon: Icon(Icons.home), label: 'Home'),
///     LingTabItem(icon: Icon(Icons.settings), label: 'Settings'),
///   ],
///   pages: [HomePage(), SettingsPage()],
/// )
/// ```
class LingTabScaffold extends StatefulWidget {
  final List<LingTabItem> tabs;
  final List<Widget> pages;
  final int initialIndex;
  final ValueChanged<int>? onTabChanged;
  final Widget? floatingActionButton;
  final bool showTabBar;

  const LingTabScaffold({
    super.key,
    required this.tabs,
    required this.pages,
    this.initialIndex = 0,
    this.onTabChanged,
    this.floatingActionButton,
    this.showTabBar = true,
  }) : assert(tabs.length == pages.length, 'tabs and pages must have the same length');

  @override
  State<LingTabScaffold> createState() => _LingTabScaffoldState();
}

class _LingTabScaffoldState extends State<LingTabScaffold> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onTabChanged(int index) {
    setState(() => _currentIndex = index);
    widget.onTabChanged?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: widget.pages,
      ),
      bottomNavigationBar: widget.showTabBar
          ? LingTabBar(
              currentIndex: _currentIndex,
              onTap: _onTabChanged,
              items: widget.tabs,
            )
          : null,
      floatingActionButton: widget.floatingActionButton,
    );
  }
}
