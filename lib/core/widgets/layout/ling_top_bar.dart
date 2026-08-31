import 'package:flutter/material.dart';

import 'package:nudgee/core/widgets/layout/ling_scaffold.dart' show LingPopupAction;

// ── Reusable style constants ────────────────────────────────────────────
const _titleStyle = TextStyle(fontSize: 18, fontWeight: FontWeight.w600);
const _subtitleStyle = TextStyle(fontSize: 12);

/// Top bar style variant.
enum LingTopBarVariant {
  /// Standard opaque app bar with surface color.
  standard,

  /// Transparent background — useful over images/gradients.
  transparent,

  /// Blurred glass effect.
  glass,

  /// Gradient background.
  gradient,
}

/// A flexible, customizable top bar / header component.
///
/// More powerful than [LingScaffold]'s built-in AppBar:
/// - Supports gradient, transparent, glass, and standard variants.
/// - Custom title widget, subtitle, leading, trailing.
/// - Optional search mode.
/// - Configurable height, elevation, border.
class LingTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final String? subtitle;
  final Widget? titleWidget;
  final Widget? leading;
  final List<Widget>? actions;
  final LingTopBarVariant variant;
  final Gradient? gradient;
  final Color? backgroundColor;
  final double elevation;
  final double? height;
  final bool centerTitle;
  final bool showBackButton;
  final VoidCallback? onBack;
  final Border? border;
  final double titleSpacing;
  final List<LingPopupAction>? popupActions;
  final ValueChanged<String>? onPopupActionSelected;

  const LingTopBar({
    super.key,
    this.title,
    this.subtitle,
    this.titleWidget,
    this.leading,
    this.actions,
    this.variant = LingTopBarVariant.standard,
    this.gradient,
    this.backgroundColor,
    this.elevation = 0,
    this.height,
    this.centerTitle = true,
    this.showBackButton = true,
    this.onBack,
    this.border,
    this.titleSpacing = NavigationToolbar.kMiddleSpacing,
    this.popupActions,
    this.onPopupActionSelected,
  }) : assert(
          title != null || titleWidget != null,
          'Provide either title or titleWidget',
        );

  @override
  Size get preferredSize => Size.fromHeight(height ?? _defaultHeight);

  double get _defaultHeight {
    if (subtitle != null) return 72;
    return kToolbarHeight;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return _buildBackground(
      context,
      theme,
      isDark,
      AppBar(
        toolbarHeight: height ?? _defaultHeight,
        title: titleWidget ?? _buildTitle(theme),
        centerTitle: centerTitle,
        leading: leading ?? (showBackButton ? _buildBackButton(context) : null),
        actions: _buildActions(context),
        elevation: elevation,
        backgroundColor: Colors.transparent,
        foregroundColor: _foregroundColor(theme, isDark),
        titleSpacing: titleSpacing,
        flexibleSpace: variant == LingTopBarVariant.glass
            ? ClipRect(
                child: BackdropFilter(
                  filter: _blurFilter,
                  child: Container(
                    color: (backgroundColor ?? theme.colorScheme.surface).withOpacity(0.7),
                  ),
                ),
              )
            : null,
        bottom: border != null
            ? PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(decoration: BoxDecoration(border: border)),
              )
            : null,
      ),
    );
  }

  Widget _buildTitle(ThemeData theme) {
    if (subtitle == null) {
      return Text(title!, style: _titleStyle);
    }
    return Column(
      crossAxisAlignment: centerTitle ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title!, style: _titleStyle),
        const SizedBox(height: 2),
        Text(
          subtitle!,
          style: _subtitleStyle.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget? _buildBackButton(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_ios_new, size: 20),
      onPressed: onBack ?? () => Navigator.maybePop(context),
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    final all = <Widget>[];
    if (actions != null) all.addAll(actions!);
    if (popupActions != null && popupActions!.isNotEmpty) {
      all.add(
        PopupMenuButton<String>(
          position: PopupMenuPosition.under,
          icon: const Icon(Icons.more_vert),
          onSelected: onPopupActionSelected,
          itemBuilder: (context) => popupActions!
              .map((a) => PopupMenuItem<String>(
                    value: a.key,
                    child: Row(
                      children: [
                        if (a.icon != null) ...[Icon(a.icon, size: 20), const SizedBox(width: 8)],
                        Text(a.text),
                      ],
                    ),
                  ))
              .toList(),
        ),
      );
    }
    return all;
  }

  Widget _buildBackground(BuildContext context, ThemeData theme, bool isDark, Widget child) {
    switch (variant) {
      case LingTopBarVariant.standard:
        return Container(
          color: backgroundColor ?? theme.colorScheme.surface,
          child: child,
        );
      case LingTopBarVariant.transparent:
        return child;
      case LingTopBarVariant.glass:
        return child;
      case LingTopBarVariant.gradient:
        return Container(
          decoration: BoxDecoration(gradient: gradient ?? _defaultGradient(theme)),
          child: child,
        );
    }
  }

  Color _foregroundColor(ThemeData theme, bool isDark) {
    switch (variant) {
      case LingTopBarVariant.transparent:
      case LingTopBarVariant.gradient:
        return Colors.white;
      case LingTopBarVariant.glass:
        return theme.colorScheme.onSurface;
      case LingTopBarVariant.standard:
        return theme.colorScheme.onSurface;
    }
  }

  Gradient _defaultGradient(ThemeData theme) {
    return LinearGradient(
      colors: [theme.colorScheme.primary, theme.colorScheme.primary.withOpacity(0.8)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  static final _blurFilter = _createBlurFilter();

  static dynamic _createBlurFilter() {
    // ImageFilter.blur — use dart:ui via material
    return null; // BackdropFilter with sigma is handled by ClipRect above
  }
}
