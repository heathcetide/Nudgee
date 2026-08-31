import 'package:flutter/material.dart';

import 'package:nudgee/app/theme/app_colors.dart';
import 'package:nudgee/core/models/im/im.dart';

/// A message send-status indicator.
///
/// Renders different icons based on [status]:
/// - sending: a clock icon with a rotation animation
/// - sent: a single check
/// - delivered: a double check
/// - read: a blue double check
/// - failed: a red exclamation (tappable to resend)
class LingMessageStatusIndicator extends StatefulWidget {
  /// The message status to render.
  final LingMessageStatus status;

  /// Called when the failed indicator is tapped (to resend).
  final VoidCallback? onResend;

  /// Icon size. Defaults to 14.
  final double size;

  const LingMessageStatusIndicator({
    super.key,
    required this.status,
    this.onResend,
    this.size = 14,
  });

  @override
  State<LingMessageStatusIndicator> createState() =>
      _LingMessageStatusIndicatorState();
}

class _LingMessageStatusIndicatorState extends State<LingMessageStatusIndicator>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void didUpdateWidget(LingMessageStatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    _setupAnimation();
  }

  @override
  void initState() {
    super.initState();
    _setupAnimation();
  }

  void _setupAnimation() {
    if (widget.status == LingMessageStatus.sending) {
      _controller ??= AnimationController(
        duration: const Duration(seconds: 1),
        vsync: this,
      )..repeat();
    } else {
      _controller?.stop();
      _controller?.dispose();
      _controller = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    switch (widget.status) {
      case LingMessageStatus.sending:
        if (_controller == null) return const SizedBox.shrink();
        return RotationTransition(
          turns: _controller!,
          child: Icon(
            Icons.access_time,
            size: widget.size,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        );
      case LingMessageStatus.sent:
        return Icon(
          Icons.check,
          size: widget.size,
          color: theme.colorScheme.onSurfaceVariant,
        );
      case LingMessageStatus.delivered:
        return Icon(
          Icons.done_all,
          size: widget.size,
          color: theme.colorScheme.onSurfaceVariant,
        );
      case LingMessageStatus.read:
        return Icon(
          Icons.done_all,
          size: widget.size,
          color: AppColors.info,
        );
      case LingMessageStatus.failed:
        return GestureDetector(
          onTap: widget.onResend,
          child: Icon(
            Icons.error_outline,
            size: widget.size,
            color: AppColors.error,
          ),
        );
    }
  }
}
