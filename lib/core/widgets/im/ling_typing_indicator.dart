import 'package:flutter/material.dart';

/// Typing indicator — three animated bouncing dots.
class LingTypingIndicator extends StatefulWidget {
  final Color? dotColor;
  final double dotSize;
  final double spacing;
  final Color? backgroundColor;
  final EdgeInsets padding;

  const LingTypingIndicator({
    super.key,
    this.dotColor,
    this.dotSize = 8,
    this.spacing = 4,
    this.backgroundColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  });

  @override
  State<LingTypingIndicator> createState() => _LingTypingIndicatorState();
}

class _LingTypingIndicatorState extends State<LingTypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: widget.padding,
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) {
          return Padding(
            padding: EdgeInsets.only(right: index < 2 ? widget.spacing : 0),
            child: _BouncingDot(
              animation: _controller,
              delay: index * 0.2,
              size: widget.dotSize,
              color: widget.dotColor ?? theme.colorScheme.onSurfaceVariant,
            ),
          );
        }),
      ),
    );
  }
}

class _BouncingDot extends StatelessWidget {
  final Animation<double> animation;
  final double delay;
  final double size;
  final Color color;

  const _BouncingDot({
    required this.animation,
    required this.delay,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        // Offset each dot's bounce phase
        final t = (animation.value + delay) % 1.0;
        // Bounce up in first half, down in second half
        final scale = 0.5 + (1 - (2 * t - 1).abs()) * 0.5;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
