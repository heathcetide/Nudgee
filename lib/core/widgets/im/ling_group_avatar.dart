import 'package:flutter/material.dart';

import 'package:nudgee/core/widgets/feedback/ling_avatar.dart';

/// A group avatar showing up to 4 member avatars in a grid.
class LingGroupAvatar extends StatelessWidget {
  final List<String?> avatarUrls;
  final List<String> names;
  final double size;
  final double spacing;
  final BorderRadius borderRadius;

  const LingGroupAvatar({
    super.key,
    required this.avatarUrls,
    required this.names,
    this.size = 48,
    this.spacing = 2,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  @override
  Widget build(BuildContext context) {
    final count = avatarUrls.length;
    final cellSize = (size - spacing) / 2;

    // Pick the closest LingAvatarSize for the cell
    final avatarSize = _closestSize(cellSize);

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: borderRadius),
      child: count <= 1
          ? LingAvatar(
              imageUrl: avatarUrls.isNotEmpty ? avatarUrls.first : null,
              name: names.isNotEmpty ? names.first : null,
              size: _closestSize(size),
            )
          : GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              children: List.generate(count.clamp(0, 4), (i) {
                return Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: LingAvatar(
                    imageUrl: i < avatarUrls.length ? avatarUrls[i] : null,
                    name: i < names.length ? names[i] : null,
                    size: avatarSize,
                  ),
                );
              }),
            ),
    );
  }

  LingAvatarSize _closestSize(double dimension) {
    if (dimension <= 28) return LingAvatarSize.xs;
    if (dimension <= 36) return LingAvatarSize.sm;
    if (dimension <= 48) return LingAvatarSize.md;
    if (dimension <= 64) return LingAvatarSize.lg;
    if (dimension <= 84) return LingAvatarSize.xl;
    return LingAvatarSize.xxl;
  }
}
