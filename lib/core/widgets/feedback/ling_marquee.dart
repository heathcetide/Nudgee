import 'package:flutter/material.dart';

/// Direction for marquee scrolling.
enum LingMarqueeDirection {
  left,
  right,
  up,
  down,
}

/// A scrolling text/marquee widget.
///
/// Automatically scrolls content horizontally.
/// Useful for notifications, tickers, and long text in limited space.
class LingMarquee extends StatefulWidget {
  final Widget child;
  final LingMarqueeDirection direction;
  final Duration duration;
  final double gap;
  final bool autoStart;
  final EdgeInsets padding;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;

  const LingMarquee({
    super.key,
    required this.child,
    this.direction = LingMarqueeDirection.left,
    this.duration = const Duration(seconds: 10),
    this.gap = 40,
    this.autoStart = true,
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
    this.borderRadius,
  });

  @override
  State<LingMarquee> createState() => _LingMarqueeState();
}

class _LingMarqueeState extends State<LingMarquee> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final ScrollController _scrollController;
  bool _measured = false;
  double _contentWidth = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _scrollController = ScrollController();

    if (widget.autoStart) {
      _controller.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _controller.forward(from: 0);
        }
      });
      _controller.addListener(_onTick);
    }
  }

  void _onTick() {
    if (!_scrollController.hasClients) return;
    // Measure content width on first tick
    if (!_measured) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll > 0) {
        _contentWidth = maxScroll;
        _measured = true;
      }
    }
    if (_contentWidth == 0) return;
    final offset = _controller.value * _contentWidth;
    _scrollController.jumpTo(offset.clamp(0, _contentWidth));
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.zero,
      child: Container(
        color: widget.backgroundColor,
        padding: widget.padding,
        child: SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              widget.child,
              SizedBox(width: widget.gap),
              widget.child,
              SizedBox(width: widget.gap),
              widget.child,
            ],
          ),
        ),
      ),
    );
  }
}
