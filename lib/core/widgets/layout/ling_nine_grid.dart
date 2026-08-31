import 'package:flutter/material.dart';

import 'package:nudgee/core/widgets/feedback/ling_image_box.dart';

/// Grid layout configuration for [LingNineGrid].
const Map<int, _GridLayout> _nineGridLayouts = {
  1: _GridLayout(rows: 1, cols: 1, aspectRatio: 1.5),
  2: _GridLayout(rows: 1, cols: 2, aspectRatio: 1.0),
  3: _GridLayout(rows: 1, cols: 3, aspectRatio: 1.0),
  4: _GridLayout(rows: 2, cols: 2, aspectRatio: 1.0),
  5: _GridLayout(rows: 2, cols: 3, aspectRatio: 1.0),
  6: _GridLayout(rows: 2, cols: 3, aspectRatio: 1.0),
  7: _GridLayout(rows: 3, cols: 3, aspectRatio: 1.0),
  8: _GridLayout(rows: 3, cols: 3, aspectRatio: 1.0),
  9: _GridLayout(rows: 3, cols: 3, aspectRatio: 1.0),
};

class _GridLayout {
  final int rows;
  final int cols;
  final double aspectRatio;
  const _GridLayout({required this.rows, required this.cols, required this.aspectRatio});
}

/// WeChat-style nine-grid image layout.
///
/// Automatically arranges 1-9 images in a grid:
/// - 1 image: large single image
/// - 2-3 images: single row
/// - 4 images: 2×2 grid
/// - 5-9 images: 3-column grid
///
/// Each image is tappable to open [LingImageViewer] with the full gallery.
class LingNineGrid extends StatelessWidget {
  final List<String> urls;
  final double spacing;
  final double maxWidth;
  final BorderRadius? borderRadius;

  const LingNineGrid({
    super.key,
    required this.urls,
    this.spacing = 3,
    this.maxWidth = 300,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();

    final count = urls.length;
    if (count > 9) {
      // Show first 9 with a "+N" overlay on the last one
      return _buildGrid(context, urls.take(9).toList(), extraCount: count - 9);
    }
    return _buildGrid(context, urls);
  }

  Widget _buildGrid(BuildContext context, List<String> images, {int? extraCount}) {
    final layout = _nineGridLayouts[images.length] ?? _nineGridLayouts[9]!;
    final cellSize = (maxWidth - spacing * (layout.cols - 1)) / layout.cols;

    // Single image — larger display
    if (images.length == 1) {
      return SizedBox(
        width: maxWidth * 0.66,
        height: maxWidth * 0.66 * layout.aspectRatio,
        child: LingImageBox(
          url: images[0],
          heroTag: 'ninegrid_0_${images[0]}',
          fit: BoxFit.cover,
          borderRadius: borderRadius ?? BorderRadius.circular(8),
          galleryUrls: urls,
        ),
      );
    }

    return SizedBox(
      width: maxWidth,
      child: Column(
        children: List.generate(layout.rows, (row) {
          return Row(
            children: List.generate(layout.cols, (col) {
              final index = row * layout.cols + col;
              if (index >= images.length) {
                return SizedBox(width: cellSize, height: cellSize);
              }
              return Padding(
                padding: EdgeInsets.only(right: col < layout.cols - 1 ? spacing : 0, bottom: spacing),
                child: SizedBox(
                  width: cellSize,
                  height: cellSize,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      LingImageBox(
                        url: images[index],
                        heroTag: 'ninegrid_${index}_${images[index]}',
                        index: index,
                        fit: BoxFit.cover,
                        borderRadius: borderRadius ?? BorderRadius.circular(4),
                        galleryUrls: urls,
                      ),
                      if (extraCount != null && index == 8)
                        ClipRRect(
                          borderRadius: borderRadius ?? BorderRadius.circular(4),
                          child: Container(
                            color: Colors.black54,
                            child: Center(
                              child: Text(
                                '+$extraCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          );
        }),
      ),
    );
  }
}
