import 'dart:math';

import 'package:flutter/material.dart';

/// A waveform visualization widget.
///
/// Displays audio waveform bars that can animate during playback.
/// Supports:
/// - Static or animated bars.
/// - Real-time progress highlight.
/// - Customizable bar count, colors, and sizes.
/// - Random or provided amplitude data.
class LingWaveform extends StatefulWidget {
  final int barCount;
  final double progress;
  final double maxHeight;
  final double barWidth;
  final double spacing;
  final Color? activeColor;
  final Color? inactiveColor;
  final bool animate;
  final List<double>? amplitudes;
  final Duration animationDuration;

  const LingWaveform({
    super.key,
    this.barCount = 40,
    this.progress = 0,
    this.maxHeight = 60,
    this.barWidth = 3,
    this.spacing = 2,
    this.activeColor,
    this.inactiveColor,
    this.animate = false,
    this.amplitudes,
    this.animationDuration = const Duration(milliseconds: 1500),
  });

  @override
  State<LingWaveform> createState() => _LingWaveformState();
}

class _LingWaveformState extends State<LingWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late List<double> _amplitudes;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _amplitudes = widget.amplitudes ?? _generateAmplitudes();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    if (widget.animate) {
      _controller.repeat(reverse: true);
    }
  }

  List<double> _generateAmplitudes() {
    return List.generate(widget.barCount, (i) {
      // Generate a natural-looking waveform pattern
      final base = 0.3 + 0.4 * sin(i * 0.3);
      final noise = _random.nextDouble() * 0.3;
      return (base + noise).clamp(0.1, 1.0);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = widget.activeColor ?? theme.colorScheme.primary;
    final inactive = widget.inactiveColor ?? theme.colorScheme.outlineVariant;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final animOffset = widget.animate ? _controller.value * 0.3 : 0.0;
        return CustomPaint(
          size: Size(
            widget.barCount * (widget.barWidth + widget.spacing),
            widget.maxHeight,
          ),
          painter: _WaveformPainter(
            amplitudes: _amplitudes,
            progress: widget.progress,
            activeColor: active,
            inactiveColor: inactive,
            barWidth: widget.barWidth,
            spacing: widget.spacing,
            maxHeight: widget.maxHeight,
            animOffset: animOffset,
          ),
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> amplitudes;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;
  final double barWidth;
  final double spacing;
  final double maxHeight;
  final double animOffset;

  _WaveformPainter({
    required this.amplitudes,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
    required this.barWidth,
    required this.spacing,
    required this.maxHeight,
    required this.animOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final activeBarCount = (amplitudes.length * progress).round();
    final center = size.height / 2;

    for (int i = 0; i < amplitudes.length; i++) {
      final x = i * (barWidth + spacing);
      final amp = (amplitudes[i] + animOffset * (1 - amplitudes[i])).clamp(0.05, 1.0);
      final barHeight = amp * maxHeight;
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x + barWidth / 2, center), width: barWidth, height: barHeight),
        Radius.circular(barWidth / 2),
      );
      final paint = Paint()
        ..color = i < activeBarCount ? activeColor : inactiveColor
        ..style = PaintingStyle.fill;
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      progress != oldDelegate.progress || animOffset != oldDelegate.animOffset;
}
