import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Background type for [LingChatBackground].
enum LingChatBackgroundType {
  /// Solid color background.
  color,

  /// Linear gradient background.
  gradient,

  /// Network image background with an opacity overlay.
  image,
}

/// A chat page background widget.
///
/// Supports three modes:
/// - [LingChatBackgroundType.color]: fills with [color] (defaults to
///   `theme.colorScheme.surface`).
/// - [LingChatBackgroundType.gradient]: fills with [gradient].
/// - [LingChatBackgroundType.image]: displays a network image via
///   [Image.network] with an opacity overlay.
///
/// The [child] is rendered on top of the background.
class LingChatBackground extends StatelessWidget {
  final LingChatBackgroundType type;

  /// Solid color for [LingChatBackgroundType.color].
  /// Defaults to `theme.colorScheme.surface` when null.
  final Color? color;

  /// Gradient for [LingChatBackgroundType.gradient].
  final LinearGradient? gradient;

  /// Network image URL for [LingChatBackgroundType.image].
  final String? imageUrl;

  /// The content displayed on top of the background.
  final Widget? child;

  /// Opacity applied to the background (0.0 – 1.0).
  /// For image mode this controls the overlay darkness.
  final double opacity;

  const LingChatBackground({
    super.key,
    required this.type,
    this.color,
    this.gradient,
    this.imageUrl,
    this.child,
    this.opacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clampedOpacity = opacity.clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: _baseColor(theme),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Background layer ──
          _buildBackground(context, theme, clampedOpacity),
          // ── Content layer ──
          if (child != null) child!,
        ],
      ),
    );
  }

  Color _baseColor(ThemeData theme) {
    if (type == LingChatBackgroundType.color) {
      return color ?? theme.colorScheme.surface;
    }
    return theme.colorScheme.surface;
  }

  Widget _buildBackground(
    BuildContext context,
    ThemeData theme,
    double opacity,
  ) {
    switch (type) {
      case LingChatBackgroundType.color:
        final bg = color ?? theme.colorScheme.surface;
        if (opacity >= 1.0) {
          return ColoredBox(color: bg, child: const SizedBox.expand());
        }
        return ColoredBox(
          color: bg.withOpacity(opacity),
          child: const SizedBox.expand(),
        );

      case LingChatBackgroundType.gradient:
        final grad = gradient ??
            LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                theme.colorScheme.primary.withOpacity(0.08),
                theme.colorScheme.surface,
              ],
            );
        if (opacity >= 1.0) {
          return DecoratedBox(
            decoration: BoxDecoration(gradient: grad),
            child: const SizedBox.expand(),
          );
        }
        return Opacity(
          opacity: opacity,
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: grad),
            child: const SizedBox.expand(),
          ),
        );

      case LingChatBackgroundType.image:
        if (imageUrl == null || imageUrl!.isEmpty) {
          return ColoredBox(
            color: theme.colorScheme.surface,
            child: const SizedBox.expand(),
          );
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: imageUrl!,
              fit: BoxFit.cover,
              memCacheWidth: 1080,
              memCacheHeight: 1920,
              errorWidget: (_, __, ___) => ColoredBox(
                color: theme.colorScheme.surface,
                child: const SizedBox.expand(),
              ),
            ),
            // Opacity overlay (darken) on top of the image
            if (opacity < 1.0)
              ColoredBox(
                color: theme.colorScheme.surface.withOpacity(1.0 - opacity),
                child: const SizedBox.expand(),
              ),
          ],
        );
    }
  }
}
