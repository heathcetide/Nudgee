import 'package:flutter/material.dart';

import 'package:nudgee/core/models/upload_task.dart';
import 'package:nudgee/core/widgets/feedback/ling_progress.dart';

/// A compact upload progress row.
///
/// Displays the file name, a [LingLinearProgress] bar with percentage, the
/// current [UploadStatus] as a label, and optional cancel / retry buttons.
///
/// ```dart
/// LingUploadProgress(
///   task: myTask,
///   onCancel: () => uploadService.cancelUpload(myTask.id),
///   onRetry: () => uploadService.retryUpload(myTask.id),
/// )
/// ```
class LingUploadProgress extends StatelessWidget {
  final UploadTask task;

  /// Called when the user taps the cancel button. Only shown while the
  /// task is queued or uploading.
  final VoidCallback? onCancel;

  /// Called when the user taps the retry button. Only shown when the task
  /// has failed or been cancelled.
  final VoidCallback? onRetry;

  /// Optional trailing widget replacing the default action buttons.
  final Widget? trailing;

  const LingUploadProgress({
    super.key,
    required this.task,
    this.onCancel,
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
                        task.fileName,
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
                  color: task.status == UploadStatus.failed
                      ? theme.colorScheme.error
                      : task.status == UploadStatus.completed
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
    if (task.status == UploadStatus.queued || task.status == UploadStatus.uploading) {
      if (onCancel == null) return const SizedBox.shrink();
      return IconButton(
        icon: const Icon(Icons.close, size: 20),
        tooltip: 'Cancel',
        color: theme.colorScheme.onSurfaceVariant,
        onPressed: onCancel,
      );
    }

    if (task.status == UploadStatus.failed || task.status == UploadStatus.cancelled) {
      if (onRetry == null) return const SizedBox.shrink();
      return IconButton(
        icon: const Icon(Icons.refresh, size: 20),
        tooltip: 'Retry',
        color: statusColor,
        onPressed: onRetry,
      );
    }

    if (task.status == UploadStatus.completed) {
      return Icon(Icons.check_circle, size: 20, color: statusColor);
    }

    // Paused.
    return Icon(Icons.pause_circle, size: 20, color: statusColor);
  }

  String _statusLabel(UploadStatus status) {
    switch (status) {
      case UploadStatus.queued:
        return 'Queued';
      case UploadStatus.uploading:
        return 'Uploading';
      case UploadStatus.paused:
        return 'Paused';
      case UploadStatus.completed:
        return 'Done';
      case UploadStatus.failed:
        return 'Failed';
      case UploadStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color _statusColor(ThemeData theme, UploadStatus status) {
    switch (status) {
      case UploadStatus.queued:
        return theme.colorScheme.onSurfaceVariant;
      case UploadStatus.uploading:
        return theme.colorScheme.primary;
      case UploadStatus.paused:
        return theme.colorScheme.tertiary;
      case UploadStatus.completed:
        return theme.colorScheme.primary;
      case UploadStatus.failed:
        return theme.colorScheme.error;
      case UploadStatus.cancelled:
        return theme.colorScheme.onSurfaceVariant;
    }
  }
}

class _StatusIcon extends StatelessWidget {
  final UploadStatus status;
  final Color color;

  const _StatusIcon({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    switch (status) {
      case UploadStatus.queued:
        icon = Icons.schedule;
        break;
      case UploadStatus.uploading:
        icon = Icons.cloud_upload;
        break;
      case UploadStatus.paused:
        icon = Icons.pause;
        break;
      case UploadStatus.completed:
        icon = Icons.cloud_done;
        break;
      case UploadStatus.failed:
        icon = Icons.error_outline;
        break;
      case UploadStatus.cancelled:
        icon = Icons.cancel;
        break;
    }
    return Icon(icon, size: 24, color: color);
  }
}
