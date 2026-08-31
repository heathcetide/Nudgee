import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A network image with tap-to-view fullscreen, Hero animation, and gallery support.
///
/// Shows a thumbnail that, when tapped, opens [LingImageViewer] for fullscreen
/// viewing with pinch-to-zoom and swipe navigation.
class LingImageBox extends StatelessWidget {
  final String url;
  final String? heroTag;
  final int? index;
  final BoxFit fit;
  final List<String>? galleryUrls;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  const LingImageBox({
    super.key,
    required this.url,
    this.heroTag,
    this.index,
    this.fit = BoxFit.cover,
    this.galleryUrls,
    this.width,
    this.height,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    final tag = heroTag ?? url;

    return GestureDetector(
      onTap: () => _openViewer(context, tag),
      child: Hero(
        tag: tag,
        child: ClipRRect(
          borderRadius: borderRadius ?? BorderRadius.zero,
          child: SizedBox(
            width: width,
            height: height,
            child: CachedNetworkImage(
              imageUrl: url,
              fit: fit,
              placeholder: (_, __) => placeholder ?? _defaultPlaceholder(),
              errorWidget: (_, __, ___) => errorWidget ?? _defaultError(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _defaultPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
      ),
    );
  }

  Widget _defaultError() {
    return Container(
      color: Colors.grey[200],
      child: const Icon(Icons.broken_image, color: Colors.grey),
    );
  }

  void _openViewer(BuildContext context, String tag) {
    final images = galleryUrls ?? [url];
    final startIndex = index ?? 0;

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: LingImageViewer(
              images: images,
              startIndex: startIndex,
              heroTags: List.generate(images.length, (i) => 'imgviewer_${i}_${images[i]}'),
            ),
          );
        },
      ),
    );
  }
}

/// Fullscreen image viewer with pinch-to-zoom and swipe navigation.
///
/// Supports a gallery of images with page swiping, double-tap to zoom,
/// and pinch-to-zoom via [InteractiveViewer].
class LingImageViewer extends StatefulWidget {
  final List<String> images;
  final int startIndex;
  final List<String>? heroTags;
  final String? loadingImage;

  const LingImageViewer({
    super.key,
    required this.images,
    this.startIndex = 0,
    this.heroTags,
    this.loadingImage,
  });

  @override
  State<LingImageViewer> createState() => _LingImageViewerState();
}

class _LingImageViewerState extends State<LingImageViewer> {
  late int _currentIndex;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.startIndex;
    _pageController = PageController(initialPage: widget.startIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Image gallery
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.images.length,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (context, index) {
                return _ZoomableImage(
                  url: widget.images[index],
                  heroTag: widget.heroTags?[index] ?? widget.images[index],
                  loadingUrl: index == widget.startIndex ? widget.loadingImage : null,
                );
              },
            ),
          ),
          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  if (widget.images.length > 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '${_currentIndex + 1} / ${widget.images.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoomableImage extends StatefulWidget {
  final String url;
  final String heroTag;
  final String? loadingUrl;

  const _ZoomableImage({required this.url, required this.heroTag, this.loadingUrl});

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> {
  final _transformationController = TransformationController();
  bool _isZoomed = false;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
    setState(() => _isZoomed = false);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 0.5,
        maxScale: 4.0,
        onInteractionUpdate: (details) {
          final scale = _transformationController.value.getMaxScaleOnAxis();
          final zoomed = scale > 1.01;
          if (zoomed != _isZoomed) setState(() => _isZoomed = zoomed);
        },
        onInteractionEnd: (details) {
          if (!_isZoomed) _resetZoom();
        },
        child: GestureDetector(
          onDoubleTap: _isZoomed ? _resetZoom : null,
          child: Hero(
            tag: widget.heroTag,
            child: CachedNetworkImage(
              imageUrl: widget.url,
              fit: BoxFit.contain,
              placeholder: (_, __) => widget.loadingUrl != null
                  ? CachedNetworkImage(imageUrl: widget.loadingUrl!, fit: BoxFit.contain)
                  : const Center(
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      ),
                    ),
              errorWidget: (_, __, ___) => const Center(
                child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
