import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Skeleton loading variant types.
enum LingSkeletonVariant {
  list,
  card,
  grid,
  profile,
  custom,
}

/// A skeleton loading placeholder with shimmer animation.
///
/// Shows a shimmering placeholder while content is loading.
/// Use [LingSkeletonList], [LingSkeletonCard], [LingSkeletonGrid],
/// or [LingSkeletonProfile] for common patterns.
class LingSkeleton extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final Widget? skeleton;
  final Color? baseColor;
  final Color? highlightColor;

  const LingSkeleton({
    super.key,
    required this.isLoading,
    required this.child,
    this.skeleton,
    this.baseColor,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLoading) return child;
    return skeleton ?? LingSkeletonList(baseColor: baseColor, highlightColor: highlightColor);
  }
}

/// Base shimmer wrapper — use this to build custom skeletons.
class LingShimmer extends StatelessWidget {
  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;
  final ShimmerDirection direction;

  const LingShimmer({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
    this.direction = ShimmerDirection.ltr,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: baseColor ?? (isDark ? Colors.grey[800]! : Colors.grey[300]!),
      highlightColor: highlightColor ?? (isDark ? Colors.grey[700]! : Colors.grey[100]!),
      direction: direction,
      child: child,
    );
  }
}

/// A skeleton placeholder box with rounded corners.
class LingSkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const LingSkeletonBox({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// List item skeleton — avatar + title + subtitle layout.
class LingSkeletonList extends StatelessWidget {
  final int itemCount;
  final Color? baseColor;
  final Color? highlightColor;

  const LingSkeletonList({super.key, this.itemCount = 3, this.baseColor, this.highlightColor});

  @override
  Widget build(BuildContext context) {
    return LingShimmer(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Column(
        children: List.generate(itemCount, (index) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const LingSkeletonBox(width: 50, height: 50, borderRadius: 25),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const LingSkeletonBox(height: 16),
                      const SizedBox(height: 8),
                      const LingSkeletonBox(width: 200, height: 12),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

/// Card skeleton — image + title + description layout.
class LingSkeletonCard extends StatelessWidget {
  final int itemCount;
  final Color? baseColor;
  final Color? highlightColor;

  const LingSkeletonCard({super.key, this.itemCount = 1, this.baseColor, this.highlightColor});

  @override
  Widget build(BuildContext context) {
    return LingShimmer(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Column(
        children: List.generate(itemCount, (index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LingSkeletonBox(height: 120, borderRadius: 8),
                SizedBox(height: 16),
                LingSkeletonBox(height: 24),
                SizedBox(height: 8),
                LingSkeletonBox(width: 200, height: 16),
              ],
            ),
          );
        }),
      ),
    );
  }
}

/// Grid item skeleton — image + title + price layout.
class LingSkeletonGrid extends StatelessWidget {
  final int itemCount;
  final int crossAxisCount;
  final Color? baseColor;
  final Color? highlightColor;

  const LingSkeletonGrid({
    super.key,
    this.itemCount = 6,
    this.crossAxisCount = 2,
    this.baseColor,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    return LingShimmer(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.75,
        children: List.generate(itemCount, (index) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(child: LingSkeletonBox(height: double.infinity, borderRadius: 0)),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      LingSkeletonBox(height: 16),
                      SizedBox(height: 8),
                      LingSkeletonBox(width: 80, height: 14),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

/// Profile skeleton — avatar + name + stats layout.
class LingSkeletonProfile extends StatelessWidget {
  final Color? baseColor;
  final Color? highlightColor;

  const LingSkeletonProfile({super.key, this.baseColor, this.highlightColor});

  @override
  Widget build(BuildContext context) {
    return LingShimmer(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const LingSkeletonBox(width: 80, height: 80, borderRadius: 40),
            const SizedBox(height: 16),
            const LingSkeletonBox(width: 150, height: 20),
            const SizedBox(height: 8),
            const LingSkeletonBox(width: 100, height: 14),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: const [
                    LingSkeletonBox(width: 40, height: 20),
                    SizedBox(height: 4),
                    LingSkeletonBox(width: 60, height: 12),
                  ],
                ),
                Column(
                  children: const [
                    LingSkeletonBox(width: 40, height: 20),
                    SizedBox(height: 4),
                    LingSkeletonBox(width: 60, height: 12),
                  ],
                ),
                Column(
                  children: const [
                    LingSkeletonBox(width: 40, height: 20),
                    SizedBox(height: 4),
                    LingSkeletonBox(width: 60, height: 12),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
