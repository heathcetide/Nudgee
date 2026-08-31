import 'package:flutter/material.dart';

import 'package:nudgee/app/theme/app_colors.dart';

/// A star / favorite indicator for a message bubble.
///
/// Shows a filled gold star when [isStarred] is true, or an outlined gray
/// star when false. Tapping invokes [onTap].
class LingMessageStar extends StatelessWidget {
  /// Whether the message is currently starred.
  final bool isStarred;

  /// Called when the star is tapped.
  final VoidCallback? onTap;

  /// Icon size. Defaults to 16.
  final double size;

  const LingMessageStar({
    super.key,
    required this.isStarred,
    this.onTap,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Icon(
        isStarred ? Icons.star : Icons.star_border,
        size: size,
        color: isStarred ? AppColors.tertiary : Colors.grey,
      ),
    );
  }
}
