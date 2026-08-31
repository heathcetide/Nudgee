import 'dart:io';

import 'package:flutter/material.dart';

/// A horizontal preview bar for selected images before sending.
///
/// Renders each image as an 80x80 rounded thumbnail with a small circular
/// delete button in the top-right corner. A trailing "+" add button is shown
/// until [imagePaths] reaches [maxCount].
class LingImagePickerPreview extends StatelessWidget {
  /// Local file paths (or any path decodable by [FileImage]) of selected
  /// images, in display order.
  final List<String> imagePaths;

  /// Called when the delete button on the thumbnail at [index] is tapped.
  final void Function(int index)? onRemove;

  /// Called when the trailing add button is tapped.
  final VoidCallback? onAdd;

  /// Maximum number of images allowed. The add button is hidden once this
  /// count is reached. Defaults to 9.
  final int maxCount;

  /// Thumbnail edge size.
  final double thumbSize;

  /// Thumbnail border radius.
  final double radius;

  const LingImagePickerPreview({
    super.key,
    required this.imagePaths,
    this.onRemove,
    this.onAdd,
    this.maxCount = 9,
    this.thumbSize = 80,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showAdd = imagePaths.length < maxCount;

    return SizedBox(
      height: thumbSize,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        itemCount: imagePaths.length + (showAdd ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          if (index < imagePaths.length) {
            return _buildThumb(context, index);
          }
          return _buildAddButton(context, theme);
        },
      ),
    );
  }

  Widget _buildThumb(BuildContext context, int index) {
    final theme = Theme.of(context);
    final path = imagePaths[index];

    return SizedBox(
      width: thumbSize,
      height: thumbSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: SizedBox(
              width: thumbSize,
              height: thumbSize,
              child: Image(
                image: FileImage(File(path)),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: theme.colorScheme.onSurfaceVariant,
                      size: 28,
                    ),
                  );
                },
              ),
            ),
          ),
          // Delete button
          Positioned(
            top: -6,
            right: -6,
            child: GestureDetector(
              onTap: () => onRemove?.call(index),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme.shadowColor.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.cancel,
                  size: 22,
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton(BuildContext context, ThemeData theme) {
    return GestureDetector(
      onTap: onAdd,
      child: Container(
        width: thumbSize,
        height: thumbSize,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: theme.colorScheme.outlineVariant,
            width: 1,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Icon(
          Icons.add,
          size: 32,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
