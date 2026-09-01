import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Avatar size preset.
enum LingAvatarSize {
  xs(24),
  sm(32),
  md(40),
  lg(56),
  xl(72),
  xxl(96);

  final double value;
  const LingAvatarSize(this.value);
}

/// A versatile avatar component with image, initials, or icon fallback.
///
/// - Shows a network/local image if [imageUrl]/[image] is provided.
/// - Falls back to initials derived from [name].
/// - Falls back to [icon] if no name is given.
/// - Supports online status indicator dot.
/// - Supports ring border (e.g. for active speaker).
class LingAvatar extends StatelessWidget {
  final String? imageUrl;
  final ImageProvider? image;
  final String? name;
  final IconData? icon;
  final LingAvatarSize size;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool showOnlineStatus;
  final bool isOnline;
  final bool showRing;
  final Color? ringColor;
  final VoidCallback? onTap;

  const LingAvatar({
    super.key,
    this.imageUrl,
    this.image,
    this.name,
    this.icon,
    this.size = LingAvatarSize.md,
    this.backgroundColor,
    this.foregroundColor,
    this.showOnlineStatus = false,
    this.isOnline = false,
    this.showRing = false,
    this.ringColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final diameter = size.value;
    final bg = backgroundColor ?? _generateColor(theme);
    final fg = foregroundColor ?? Colors.white;

    Widget avatar = Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: showRing
            ? Border.all(color: ringColor ?? theme.colorScheme.primary, width: 2.5)
            : null,
      ),
      child: ClipOval(
        child: _buildContent(theme, fg),
      ),
    );

    // Online status dot
    if (showOnlineStatus) {
      final dotSize = diameter * 0.28;
      avatar = Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: isOnline ? const Color(0xFF22C55E) : const Color(0xFF94A3B8),
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.colorScheme.surface,
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: avatar);
    }
    return avatar;
  }

  Widget _buildContent(ThemeData theme, Color fg) {
    // Priority: image > imageUrl > initials > icon
    if (image != null) {
      return Image(image: image!, fit: BoxFit.cover);
    }
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      // Support asset:// prefix for local asset images.
      if (imageUrl!.startsWith('asset://')) {
        return Image.asset(
          imageUrl!.substring(8),
          fit: BoxFit.cover,
        );
      }
      return CachedNetworkImage(
        imageUrl: imageUrl!,
        fit: BoxFit.cover,
        memCacheWidth: 200,
        memCacheHeight: 200,
        errorWidget: (_, __, ___) => _buildInitials(theme, fg),
      );
    }
    return _buildInitials(theme, fg);
  }

  Widget _buildInitials(ThemeData theme, Color fg) {
    if (name != null && name!.isNotEmpty) {
      final initials = _getInitials(name!);
      return Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: size.value * 0.38,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
      );
    }
    return Icon(icon ?? Icons.person, size: size.value * 0.45, color: fg);
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, math.min(2, name.length)).toUpperCase();
  }

  Color _generateColor(ThemeData theme) {
    if (name == null || name!.isEmpty) {
      return theme.colorScheme.primaryContainer;
    }
    // Generate a stable color from the name hash.
    final colors = [
      const Color(0xFF4F6BED), // blue
      const Color(0xFF14B8A6), // teal
      const Color(0xFFF59E0B), // amber
      const Color(0xFFEC4899), // pink
      const Color(0xFF8B5CF6), // violet
      const Color(0xFF22C55E), // green
      const Color(0xFFEF4444), // red
      const Color(0xFF06B6D4), // cyan
    ];
    final hash = name.hashCode.abs();
    return colors[hash % colors.length];
  }
}
