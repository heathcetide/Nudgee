import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

/// A full-screen image viewer with pinch-to-zoom and swipe navigation.
///
/// Supports both network URLs and local file paths.
class LingImageViewer extends StatefulWidget {
  /// List of image URLs or local file paths.
  final List<String> images;

  /// Index of the initial image to display.
  final int initialIndex;

  /// Optional hero tag for the initial image.
  final String? heroTag;

  const LingImageViewer({
    super.key,
    required this.images,
    this.initialIndex = 0,
    this.heroTag,
  });

  @override
  State<LingImageViewer> createState() => _LingImageViewerState();
}

class _LingImageViewerState extends State<LingImageViewer> {
  late int _currentIndex;
  late PageController _pageController;
  bool _showOverlay = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool _isLocalFile(String url) {
    return url.startsWith('/') || url.startsWith('file://');
  }

  ImageProvider _imageProvider(String url) {
    if (_isLocalFile(url)) {
      return FileImage(File(url.replaceFirst('file://', '')));
    }
    return CachedNetworkImageProvider(url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Photo gallery
          PhotoViewGallery.builder(
            pageController: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            builder: (context, index) {
              final url = widget.images[index];
              return PhotoViewGalleryPageOptions(
                imageProvider: _imageProvider(url),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 3,
                heroAttributes: index == 0 && widget.heroTag != null
                    ? PhotoViewHeroAttributes(tag: widget.heroTag!)
                    : null,
                errorBuilder: (_, error, __) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.broken_image,
                          color: Colors.white54, size: 64),
                      const SizedBox(height: 8),
                      Text(
                        '图片加载失败',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                ),
              );
            },
            scrollPhysics: const BouncingScrollPhysics(),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            enableRotation: false,
          ),
          // Top bar
          if (_showOverlay)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: AppBar(
                  backgroundColor: Colors.transparent,
                  iconTheme: const IconThemeData(color: Colors.white),
                  title: Text(
                    '${_currentIndex + 1}/${widget.images.length}',
                    style: const TextStyle(color: Colors.white),
                  ),
                  actions: [
                    if (widget.images.length > 1)
                      IconButton(
                        icon: const Icon(Icons.save_alt, color: Colors.white),
                        onPressed: () {},
                      ),
                  ],
                ),
              ),
            ),
          // Tap to toggle overlay
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _showOverlay = !_showOverlay),
              behavior: HitTestBehavior.translucent,
            ),
          ),
        ],
      ),
    );
  }
}
