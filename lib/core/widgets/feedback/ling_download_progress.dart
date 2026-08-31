import 'package:flutter/material.dart';

import 'package:nudgee/core/services/download_service.dart';
import 'package:nudgee/core/widgets/feedback/ling_progress.dart';

/// A compact download progress row.
///
/// Displays the file name, a [LingLinearProgress] bar with percentage, the
/// current [DownloadStatus] as a label, and optional cancel / pause /
/// retry buttons. Mirrors [LingUploadProgress] for downloads.
///
/// ```dart
/// LingDownloadProgress(
///   task: myTask,
///   onCancel: () => downloadService.cancel(myTask.id),
///   onPause: () => downloadService.pause(myTask.id),
///   onRetry: () => downloadService.retry(myTask.id),
/// )
/// ```
class LingDownloadProgress extends StatelessWidget {
  final DownloadTask task;

  /// Called when the user taps the cancel button. Only shown while the
  /// task is downloading.
  final VoidCallback? onCancel;

  /// Called when the user taps the pause button. Only shown while the
  /// task is downloading.
  final VoidCallback? onPause;

  /// Called when the user taps the retry button. Only shown when the task
  /// has failed, been paused, or been cancelled.
  final VoidCallback? onRetry;

  /// Optional trailing widget replacing the default action buttons.
  final Widget? trailing;

  const LingDownloadProgress({
    super.key,
    required this.task,
    this.onCancel,
    this.onPause,
    this.onRetry,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(theme, task.status);
    final statusLabel = _statusLabel(task.status);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Leading status icon.
          _StatusIcon(status: task.status, color: statusColor),
          const SizedBox(width: 12),
          // Name + progress.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        task.fileName ?? task.url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      statusLabel,
                      style: theme.textTheme.labelSmall?.copyWith(color: statusColor),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LingLinearProgress(
                  value: task.progress,
                  showPercentage: true,
                  color: task.status == DownloadStatus.failed
                      ? theme.colorScheme.error
                      : task.status == DownloadStatus.completed
                          ? theme.colorScheme.primary
                          : null,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Trailing actions.
          trailing ?? _buildActions(theme, statusColor),
        ],
      ),
    );
  }

  Widget _buildActions(ThemeData theme, Color statusColor) {
    if (task.status == DownloadStatus.downloading ||
        task.status == DownloadStatus.idle) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onPause != null)
            IconButton(
              icon: const Icon(Icons.pause, size: 20),
              tooltip: 'Pause',
              color: theme.colorScheme.onSurfaceVariant,
              onPressed: onPause,
            ),
          if (onCancel != null)
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              tooltip: 'Cancel',
              color: theme.colorScheme.onSurfaceVariant,
              onPressed: onCancel,
            ),
        ],
      );
    }

    if (task.status == DownloadStatus.failed ||
        task.status == DownloadStatus.cancelled ||
        task.status == DownloadStatus.paused) {
      if (onRetry == null) return const SizedBox.shrink();
      return IconButton(
        icon: const Icon(Icons.refresh, size: 20),
        tooltip: 'Retry',
        color: statusColor,
        onPressed: onRetry,
      );
    }

    if (task.status == DownloadStatus.completed) {
      return Icon(Icons.check_circle, size: 20, color: statusColor);
    }

    return const SizedBox.shrink();
  }

  String _statusLabel(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.idle:
        return 'Waiting';
      case DownloadStatus.downloading:
        return 'Downloading';
      case DownloadStatus.paused:
        return 'Paused';
      case DownloadStatus.completed:
        return 'Done';
      case DownloadStatus.failed:
        return 'Failed';
      case DownloadStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color _statusColor(ThemeData theme, DownloadStatus status) {
    switch (status) {
      case DownloadStatus.idle:
        return theme.colorScheme.onSurfaceVariant;
      case DownloadStatus.downloading:
        return theme.colorScheme.primary;
      case DownloadStatus.paused:
        return theme.colorScheme.tertiary;
      case DownloadStatus.completed:
        return theme.colorScheme.primary;
      case DownloadStatus.failed:
        return theme.colorScheme.error;
      case DownloadStatus.cancelled:
        return theme.colorScheme.onSurfaceVariant;
    }
  }
}

class _StatusIcon extends StatelessWidget {
  final DownloadStatus status;
  final Color color;

  const _StatusIcon({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    switch (status) {
      case DownloadStatus.idle:
        icon = Icons.schedule;
        break;
      case DownloadStatus.downloading:
        icon = Icons.cloud_download;
        break;
      case DownloadStatus.paused:
        icon = Icons.pause;
        break;
      case DownloadStatus.completed:
        icon = Icons.cloud_done;
        break;
      case DownloadStatus.failed:
        icon = Icons.error_outline;
        break;
      case DownloadStatus.cancelled:
        icon = Icons.cancel;
        break;
    }
    return Icon(icon, size: 24, color: color);
  }
}
