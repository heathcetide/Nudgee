import 'dart:async';
import 'package:flutter/material.dart';

/// Countdown variant.
enum LingCountdownVariant {
  text,
  box,
  circular,
}

/// A countdown timer widget.
///
/// Displays remaining time in text, box, or circular progress format.
/// Calls [onComplete] when the countdown reaches zero.
class LingCountdown extends StatefulWidget {
  final Duration duration;
  final LingCountdownVariant variant;
  final VoidCallback? onComplete;
  final String Function(Duration remaining)? formatter;
  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? backgroundColor;
  final TextStyle? textStyle;

  const LingCountdown({
    super.key,
    required this.duration,
    this.variant = LingCountdownVariant.text,
    this.onComplete,
    this.formatter,
    this.size = 48,
    this.strokeWidth = 4,
    this.color,
    this.backgroundColor,
    this.textStyle,
  });

  @override
  State<LingCountdown> createState() => _LingCountdownState();
}

class _LingCountdownState extends State<LingCountdown> {
  late Duration _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.duration;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _remaining = _remaining - const Duration(seconds: 1);
        if (_remaining <= Duration.zero) {
          _remaining = Duration.zero;
          timer.cancel();
          widget.onComplete?.call();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _format(Duration d) {
    if (widget.formatter != null) return widget.formatter!(d);
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      final h = d.inHours.toString().padLeft(2, '0');
      return '$h:$m:$s';
    }
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = _remaining.inSeconds / widget.duration.inSeconds;

    switch (widget.variant) {
      case LingCountdownVariant.text:
        return Text(
          _format(_remaining),
          style: widget.textStyle ?? theme.textTheme.titleMedium,
        );

      case LingCountdownVariant.box:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: (widget.color ?? theme.colorScheme.primary).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _format(_remaining),
            style: widget.textStyle ??
                theme.textTheme.bodyMedium?.copyWith(
                  color: widget.color ?? theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        );

      case LingCountdownVariant.circular:
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: progress,
                strokeWidth: widget.strokeWidth,
                color: widget.color ?? theme.colorScheme.primary,
                backgroundColor: widget.backgroundColor ?? theme.colorScheme.surfaceContainerHighest,
              ),
              Text(
                '${_remaining.inSeconds}',
                style: widget.textStyle ?? theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        );
    }
  }
}
