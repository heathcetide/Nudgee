import 'dart:math';

import 'package:flutter/material.dart';

/// Voice recorder state.
enum LingVoiceRecorderState {
  /// Idle — showing the "hold to talk" button.
  idle,

  /// Recording in progress.
  recording,

  /// User swiped up to cancel.
  cancel,
}

/// A voice recording button with press-and-hold interaction.
///
/// Displays three UI states:
/// - [LingVoiceRecorderState.idle]: a microphone button with "按住说话" label.
/// - [LingVoiceRecorderState.recording]: an overlay with an animated volume
///   waveform, elapsed duration, and "松开发送" hint.
/// - [LingVoiceRecorderState.cancel]: the overlay turns red and shows
///   "松开取消" while the user swipes up.
///
/// The [duration] is provided by the parent (e.g. from a timer) so this
/// widget stays a pure view component.
class LingVoiceRecorder extends StatefulWidget {
  /// Called when the user starts pressing the button.
  final VoidCallback? onStart;

  /// Called when the user releases while recording, carrying the final
  /// [Duration] reported by the parent.
  final void Function(Duration duration)? onComplete;

  /// Called when the user releases while in the cancel state.
  final VoidCallback? onCancel;

  /// Current recording duration, updated externally.
  ///
  /// Only meaningful while [state] is [LingVoiceRecorderState.recording] or
  /// [LingVoiceRecorderState.cancel].
  final Duration duration;

  /// Optional initial state. Defaults to [LingVoiceRecorderState.idle].
  final LingVoiceRecorderState state;

  /// Optional button label shown in the idle state.
  final String idleLabel;

  /// Height of the idle button.
  final double buttonHeight;

  const LingVoiceRecorder({
    super.key,
    this.onStart,
    this.onComplete,
    this.onCancel,
    this.duration = Duration.zero,
    this.state = LingVoiceRecorderState.idle,
    this.idleLabel = '按住说话',
    this.buttonHeight = 44,
  });

  @override
  State<LingVoiceRecorder> createState() => _LingVoiceRecorderState();
}

class _LingVoiceRecorderState extends State<LingVoiceRecorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveController;

  // Internal state mirrors the widget state but is driven by gesture.
  LingVoiceRecorderState _state = LingVoiceRecorderState.idle;
  Duration _currentDuration = Duration.zero;

  // Vertical drag threshold (in px) to enter the cancel state.
  static const double _cancelThreshold = -60;

  @override
  void initState() {
    super.initState();
    _state = widget.state;
    _currentDuration = widget.duration;
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void didUpdateWidget(covariant LingVoiceRecorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state != oldWidget.state) {
      _state = widget.state;
      _syncAnimation();
    }
    if (widget.duration != oldWidget.duration) {
      _currentDuration = widget.duration;
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  void _syncAnimation() {
    if (_state == LingVoiceRecorderState.recording) {
      _waveController.repeat();
    } else {
      _waveController.stop();
    }
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _state = LingVoiceRecorderState.recording;
      _currentDuration = Duration.zero;
    });
    _waveController.repeat();
    widget.onStart?.call();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_state == LingVoiceRecorderState.idle) return;
    final dy = details.localPosition.dy;
    final shouldCancel = dy < _cancelThreshold;
    if (shouldCancel && _state != LingVoiceRecorderState.cancel) {
      setState(() => _state = LingVoiceRecorderState.cancel);
    } else if (!shouldCancel && _state == LingVoiceRecorderState.cancel) {
      setState(() => _state = LingVoiceRecorderState.recording);
    }
  }

  void _onPanEnd(DragEndDetails details) {
    _waveController.stop();
    final finalState = _state;
    final finalDuration = _currentDuration;
    setState(() => _state = LingVoiceRecorderState.idle);
    if (finalState == LingVoiceRecorderState.cancel) {
      widget.onCancel?.call();
    } else {
      widget.onComplete?.call(finalDuration);
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_state == LingVoiceRecorderState.idle) {
      return _buildIdleButton(context);
    }
    return _buildRecordingButton(context);
  }

  Widget _buildIdleButton(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Container(
        height: widget.buttonHeight,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(widget.buttonHeight / 2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mic_none,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              widget.idleLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingButton(BuildContext context) {
    final theme = Theme.of(context);
    final isCancel = _state == LingVoiceRecorderState.cancel;
    final accent = isCancel ? theme.colorScheme.error : theme.colorScheme.primary;

    return GestureDetector(
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Container(
        height: widget.buttonHeight,
        decoration: BoxDecoration(
          color: accent.withOpacity(0.12),
          borderRadius: BorderRadius.circular(widget.buttonHeight / 2),
          border: Border.all(color: accent, width: 1.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isCancel ? Icons.delete_outline : Icons.mic,
              size: 20,
              color: accent,
            ),
            const SizedBox(width: 8),
            Text(
              isCancel ? '松开取消' : '松开发送',
              style: theme.textTheme.bodyMedium?.copyWith(color: accent),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the floating overlay shown above the input bar while recording.
  ///
  /// Place this above the button in a [Stack] or [OverlayEntry]. It is not
  /// rendered automatically by [build]; the parent decides where to show it.
  Widget buildOverlay(BuildContext context) {
    final theme = Theme.of(context);
    final isCancel = _state == LingVoiceRecorderState.cancel;
    final accent = isCancel ? theme.colorScheme.error : theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Waveform animation
          SizedBox(
            height: 40,
            width: 160,
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (context, _) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: List.generate(7, (i) {
                    final t = _waveController.value * 2 * 3.1415926;
                    // Each bar uses a phase offset for a flowing effect.
                    final phase = i * 0.6;
                    final amplitude = (sin(t + phase) + 1) / 2; // 0..1
                    final height = 8.0 + amplitude * 28.0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 80),
                        width: 4,
                        height: height,
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          // Duration
          Text(
            _formatDuration(_currentDuration),
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 6),
          // Hint
          Text(
            isCancel ? '松开取消' : '松开发送',
            style: theme.textTheme.bodySmall?.copyWith(color: accent),
          ),
        ],
      ),
    );
  }
}
