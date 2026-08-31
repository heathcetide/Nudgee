import 'package:flutter/material.dart';

import 'package:nudgee/core/constants/app_constants.dart';

/// A "X 正在输入..." text status with animated ellipsis.
///
/// Display logic:
/// - 1 person → "X 正在输入..."
/// - 2 people → "X、Y 正在输入..."
/// - 3+ people → "X、Y 等 N 人正在输入..."
class LingTypingStatus extends StatefulWidget {
  /// Names of the users who are typing.
  final List<String> userNames;

  /// Maximum number of names to display before switching to the
  /// "等 N 人" summary. Defaults to 3.
  final int maxDisplay;

  const LingTypingStatus({
    super.key,
    required this.userNames,
    this.maxDisplay = 3,
  });

  @override
  State<LingTypingStatus> createState() => _LingTypingStatusState();
}

class _LingTypingStatusState extends State<LingTypingStatus>
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

  String _buildText() {
    final names = widget.userNames;
    if (names.isEmpty) return '';

    if (names.length == 1) {
      return '${names[0]} 正在输入';
    }
    if (names.length == 2) {
      return '${names[0]}、${names[1]} 正在输入';
    }
    final shown = names.take(widget.maxDisplay).join('、');
    return '$shown 等 ${names.length} 人正在输入';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userNames.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final text = _buildText();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: AppConstants.spacingXs),
        _AnimatedDots(controller: _controller),
      ],
    );
  }
}

class _AnimatedDots extends StatelessWidget {
  final AnimationController controller;

  const _AnimatedDots({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (t + i * 0.2) % 1.0;
            final opacity = 0.3 + (1 - (2 * phase - 1).abs()) * 0.7;
            return Opacity(
              opacity: opacity,
              child: Padding(
                padding: EdgeInsets.only(right: i < 2 ? 2 : 0),
                child: Text(
                  '.',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
