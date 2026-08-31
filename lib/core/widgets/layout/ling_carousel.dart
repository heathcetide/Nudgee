import 'package:flutter/material.dart';

/// A simple auto-playing image/content carousel.
///
/// Supports:
/// - Auto-play with configurable interval.
/// - Page indicator dots.
/// - Loop mode.
/// - Custom item builder.
class LingCarousel extends StatefulWidget {
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final Duration autoPlayInterval;
  final bool autoPlay;
  final bool loop;
  final double height;
  final double viewportFraction;
  final Curve curve;
  final Duration duration;
  final bool showIndicator;
  final Color? activeDotColor;
  final Color? inactiveDotColor;
  final double dotSize;
  final EdgeInsets indicatorPadding;
  final ValueChanged<int>? onPageChanged;

  const LingCarousel({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.autoPlayInterval = const Duration(seconds: 4),
    this.autoPlay = true,
    this.loop = true,
    this.height = 200,
    this.viewportFraction = 1.0,
    this.curve = Curves.easeInOut,
    this.duration = const Duration(milliseconds: 400),
    this.showIndicator = true,
    this.activeDotColor,
    this.inactiveDotColor,
    this.dotSize = 8,
    this.indicatorPadding = const EdgeInsets.only(bottom: 12),
    this.onPageChanged,
  });

  @override
  State<LingCarousel> createState() => _LingCarouselState();
}

class _LingCarouselState extends State<LingCarousel> {
  late PageController _controller;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: widget.viewportFraction);
    if (widget.autoPlay) _startAutoPlay();
  }

  void _startAutoPlay() {
    Future.delayed(widget.autoPlayInterval, () {
      if (!mounted || !widget.autoPlay) return;
      _nextPage();
      _startAutoPlay();
    });
  }

  void _nextPage() {
    if (widget.itemCount == 0) return;
    int nextPage = _currentPage + 1;
    if (nextPage >= widget.itemCount) {
      if (widget.loop) {
        nextPage = 0;
      } else {
        return;
      }
    }
    _controller.animateToPage(
      nextPage,
      duration: widget.duration,
      curve: widget.curve,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount == 0) return SizedBox(height: widget.height);

    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            onPageChanged: (page) {
              setState(() => _currentPage = page);
              widget.onPageChanged?.call(page);
            },
            itemCount: widget.loop ? null : widget.itemCount,
            itemBuilder: (context, index) {
              final realIndex = widget.loop ? index % widget.itemCount : index;
              return widget.itemBuilder(context, realIndex);
            },
          ),
          if (widget.showIndicator && widget.itemCount > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: widget.indicatorPadding.bottom,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.itemCount, (i) {
                  final isActive = i == _currentPage % widget.itemCount;
                  return Container(
                    width: isActive ? widget.dotSize * 2 : widget.dotSize,
                    height: widget.dotSize,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: isActive
                          ? widget.activeDotColor ?? Theme.of(context).colorScheme.primary
                          : widget.inactiveDotColor ?? Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(widget.dotSize / 2),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}
