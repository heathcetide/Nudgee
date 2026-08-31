import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:nudgee/core/constants/app_constants.dart';

/// A link preview card.
///
/// Renders a horizontal layout: on the left the title, description, and
/// domain; on the right a thumbnail image (when [imageUrl] is provided).
/// The whole card is tappable via [onTap].
class LingLinkPreview extends StatelessWidget {
  /// Link title.
  final String? title;

  /// Link description / summary.
  final String? description;

  /// Thumbnail image URL. When null, only the text column is shown.
  final String? imageUrl;

  /// The original URL. Used to derive the domain and for display.
  final String url;

  /// Called when the card is tapped.
  final VoidCallback? onTap;

  /// Max lines for the title. Defaults to 2.
  final int titleMaxLines;

  /// Max lines for the description. Defaults to 2.
  final int descriptionMaxLines;

  const LingLinkPreview({
    super.key,
    this.title,
    this.description,
    this.imageUrl,
    required this.url,
    this.onTap,
    this.titleMaxLines = 2,
    this.descriptionMaxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasThumbnail = imageUrl != null && imageUrl!.isNotEmpty;
    final domain = _extractDomain(url);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            border: Border.all(
              color: theme.dividerColor,
              width: 0.5,
            ),
          ),
          padding: const EdgeInsets.all(AppConstants.spacingSm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Text column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (title != null && title!.isNotEmpty)
                      Text(
                        title!,
                        maxLines: titleMaxLines,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (description != null && description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description!,
                        maxLines: descriptionMaxLines,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.link,
                          size: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            domain,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Thumbnail
              if (hasThumbnail) ...[
                const SizedBox(width: AppConstants.spacingSm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: CachedNetworkImage(
                      imageUrl: imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.image_outlined,
                          size: 24,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Extracts a display domain from [url].
  String _extractDomain(String url) {
    var u = url;
    // Strip scheme.
    for (final scheme in ['https://', 'http://']) {
      if (u.startsWith(scheme)) {
        u = u.substring(scheme.length);
        break;
      }
    }
    // Strip path.
    final slashIndex = u.indexOf('/');
    if (slashIndex != -1) {
      u = u.substring(0, slashIndex);
    }
    return u.isEmpty ? url : u;
  }
}
