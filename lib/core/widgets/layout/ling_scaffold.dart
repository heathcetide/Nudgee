import 'package:flutter/material.dart';

/// A popup menu action for [LingScaffold.popupActions].
class LingPopupAction {
  final String key;
  final String text;
  final IconData? icon;

  const LingPopupAction({required this.key, required this.text, this.icon});
}

/// A standardized scaffold with optional app bar, body, FAB, and popup menu.
///
/// Provides consistent padding and layout across the app.
/// Supports [popupActions] for a "more" menu in the app bar.
class LingScaffold extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final Widget? body;
  final List<Widget>? actions;
  final List<LingPopupAction>? popupActions;
  final ValueChanged<String>? onPopupActionSelected;
  final Widget? floatingActionButton;
  final Widget? drawer;
  final Widget? bottomNavigationBar;
  final Widget? bottomSheet;
  final bool showBackButton;
  final Color? backgroundColor;
  final Color? appBarBackgroundColor;
  final bool resizeToAvoidBottomInset;
  final Widget? leading;

  const LingScaffold({
    super.key,
    this.title,
    this.titleWidget,
    this.body,
    this.actions,
    this.popupActions,
    this.onPopupActionSelected,
    this.floatingActionButton,
    this.drawer,
    this.bottomNavigationBar,
    this.bottomSheet,
    this.showBackButton = true,
    this.backgroundColor,
    this.appBarBackgroundColor,
    this.resizeToAvoidBottomInset = true,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final allActions = <Widget>[
      if (actions != null) ...actions!,
      if (popupActions != null && popupActions!.isNotEmpty)
        PopupMenuButton<String>(
          position: PopupMenuPosition.under,
          icon: const Icon(Icons.more_vert),
          onSelected: onPopupActionSelected,
          itemBuilder: (context) {
            return popupActions!.map((action) {
              return PopupMenuItem<String>(
                value: action.key,
                child: Row(
                  children: [
                    if (action.icon != null) ...[
                      Icon(action.icon, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Text(action.text),
                  ],
                ),
              );
            }).toList();
          },
        ),
    ];

    return Scaffold(
      appBar: (title != null || titleWidget != null || allActions.isNotEmpty)
          ? AppBar(
              title: titleWidget ?? (title != null ? Text(title!) : null),
              actions: allActions,
              automaticallyImplyLeading: showBackButton,
              leading: leading,
              backgroundColor: appBarBackgroundColor,
            )
          : null,
      body: body,
      floatingActionButton: floatingActionButton,
      drawer: drawer,
      bottomNavigationBar: bottomNavigationBar,
      bottomSheet: bottomSheet,
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
    );
  }
}
