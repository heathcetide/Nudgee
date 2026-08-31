import 'package:flutter/material.dart';

/// Bottom sheet variant.
enum LingBottomSheetVariant {
  standard,
  modal,
  dragable,
}

/// A customizable bottom sheet with optional drag handle, title, and actions.
///
/// Use [LingBottomSheet.show] to display a modal bottom sheet, or
/// [LingBottomSheet.showPersistent] for a non-modal persistent sheet.
class LingBottomSheet extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget? child;
  final List<Widget>? actions;
  final bool showDragHandle;
  final bool showCloseButton;
  final EdgeInsetsGeometry padding;
  final double? maxHeight;

  const LingBottomSheet({
    super.key,
    this.title,
    this.subtitle,
    this.child,
    this.actions,
    this.showDragHandle = true,
    this.showCloseButton = true,
    this.padding = const EdgeInsets.all(20),
    this.maxHeight,
  });

  /// Show a modal bottom sheet.
  static Future<T?> show<T>({
    required BuildContext context,
    String? title,
    String? subtitle,
    Widget? child,
    List<Widget>? actions,
    bool showDragHandle = true,
    bool showCloseButton = true,
    EdgeInsetsGeometry padding = const EdgeInsets.all(20),
    double? maxHeight,
    bool isScrollControlled = true,
    Color? backgroundColor,
    double borderRadius = 20,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: backgroundColor ?? Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(borderRadius)),
      ),
      builder: (context) => LingBottomSheet(
        title: title,
        subtitle: subtitle,
        actions: actions,
        showDragHandle: showDragHandle,
        showCloseButton: showCloseButton,
        padding: padding,
        maxHeight: maxHeight,
        child: child,
      ),
    );
  }

  /// Show a persistent (non-modal) bottom sheet.
  static PersistentBottomSheetController showPersistent({
    required BuildContext context,
    String? title,
    Widget? child,
    List<Widget>? actions,
    bool showDragHandle = true,
  }) {
    return showBottomSheet(
      context: context,
      builder: (context) => LingBottomSheet(
        title: title,
        actions: actions,
        showDragHandle: showDragHandle,
        showCloseButton: false,
        child: child,
      ),
    );
  }

  /// Show a simple action sheet (list of choices).
  static Future<T?> showActions<T>({
    required BuildContext context,
    required List<LingSheetAction<T>> actions,
    String? title,
    bool showCancel = true,
    String cancelText = '取消',
  }) {
    return show<T>(
      context: context,
      title: title,
      showDragHandle: true,
      showCloseButton: false,
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final action in actions)
            ListTile(
              leading: action.icon != null ? Icon(action.icon) : null,
              title: Text(action.label),
              subtitle: action.description != null ? Text(action.description!) : null,
              onTap: () => Navigator.pop(context, action.value),
            ),
          if (showCancel) ...[
            const Divider(height: 1),
            ListTile(
              title: Center(
                child: Text(cancelText, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget content = Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null || showCloseButton)
            Row(
              children: [
                if (title != null)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title!, style: theme.textTheme.titleMedium),
                        if (subtitle != null)
                          Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          )),
                      ],
                    ),
                  ),
                if (showCloseButton)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          if (child != null) ...[
            if (title != null) const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: maxHeight ?? MediaQuery.of(context).size.height * 0.6,
              ),
              child: SingleChildScrollView(child: child!),
            ),
          ],
          if (actions != null && actions!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: actions!,
            ),
          ],
        ],
      ),
    );

    if (showDragHandle) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Flexible(child: content),
        ],
      );
    }

    return SafeArea(child: content);
  }
}

/// An action item for [LingBottomSheet.showActions].
class LingSheetAction<T> {
  final T value;
  final String label;
  final String? description;
  final IconData? icon;
  final bool isDestructive;

  const LingSheetAction({
    required this.value,
    required this.label,
    this.description,
    this.icon,
    this.isDestructive = false,
  });
}
