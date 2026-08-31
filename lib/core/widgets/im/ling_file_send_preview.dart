import 'dart:math';

import 'package:flutter/material.dart';

/// A confirmation dialog shown before sending a file to a conversation.
///
/// Displays a file icon (chosen by MIME type), the file name, the formatted
/// file size, and the target conversation name. The bottom row has Cancel
/// and Send buttons.
///
/// Use the static [show] helper to display it via [showDialog].
class LingFileSendPreview extends StatelessWidget {
  /// Display name of the file.
  final String fileName;

  /// File size in bytes.
  final int fileSize;

  /// MIME type of the file, used to pick an icon. May be null.
  final String? mimeType;

  /// Name of the target conversation / recipient.
  final String targetName;

  /// Called when the Send button is tapped.
  final VoidCallback? onSend;

  /// Called when the Cancel button is tapped (also fires on dialog dismiss).
  final VoidCallback? onCancel;

  const LingFileSendPreview({
    super.key,
    required this.fileName,
    required this.fileSize,
    this.mimeType,
    required this.targetName,
    this.onSend,
    this.onCancel,
  });

  /// Convenience method to show this widget as a dialog.
  ///
  /// Returns `true` when the user taps Send, `false` otherwise.
  static Future<bool?> show(
    BuildContext context, {
    required String fileName,
    required int fileSize,
    String? mimeType,
    required String targetName,
    VoidCallback? onSend,
    VoidCallback? onCancel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => LingFileSendPreview(
        fileName: fileName,
        fileSize: fileSize,
        mimeType: mimeType,
        targetName: targetName,
        onSend: onSend,
        onCancel: onCancel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      content: _buildContent(context, theme),
      actionsPadding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      actions: [
        _buildCancelButton(context, theme),
        _buildSendButton(context, theme),
      ],
    );
  }

  Widget _buildContent(BuildContext context, ThemeData theme) {
    final iconData = _iconForMimeType(mimeType);
    final iconColor = _colorForMimeType(context, mimeType);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(iconData, size: 32, color: iconColor),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '发送文件',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        _InfoRow(
          label: '文件名',
          value: fileName,
          theme: theme,
          maxLines: 2,
        ),
        const SizedBox(height: 8),
        _InfoRow(
          label: '大小',
          value: _formatFileSize(fileSize),
          theme: theme,
        ),
        const SizedBox(height: 8),
        _InfoRow(
          label: '发送至',
          value: targetName,
          theme: theme,
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildCancelButton(BuildContext context, ThemeData theme) {
    return TextButton(
      onPressed: () {
        onCancel?.call();
        Navigator.of(context).pop(false);
      },
      child: Text(
        '取消',
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildSendButton(BuildContext context, ThemeData theme) {
    return FilledButton(
      onPressed: () {
        onSend?.call();
        Navigator.of(context).pop(true);
      },
      child: const Text('发送'),
    );
  }

  /// Picks an icon based on the MIME type.
  IconData _iconForMimeType(String? mimeType) {
    if (mimeType == null) return Icons.insert_drive_file;
    final lower = mimeType.toLowerCase();
    if (lower.startsWith('image/')) return Icons.image_outlined;
    if (lower.startsWith('video/')) return Icons.movie_outlined;
    if (lower.startsWith('audio/')) return Icons.audiotrack_outlined;
    if (lower == 'application/pdf') return Icons.picture_as_pdf_outlined;
    if (lower.contains('word') || lower.contains('document')) {
      return Icons.description_outlined;
    }
    if (lower.contains('excel') || lower.contains('sheet')) {
      return Icons.table_chart_outlined;
    }
    if (lower.contains('powerpoint') || lower.contains('presentation')) {
      return Icons.slideshow_outlined;
    }
    if (lower == 'application/zip' ||
        lower == 'application/x-zip-compressed' ||
        lower == 'application/x-rar-compressed' ||
        lower.endsWith('-archive')) {
      return Icons.folder_zip_outlined;
    }
    if (lower.startsWith('text/')) return Icons.article_outlined;
    return Icons.insert_drive_file;
  }

  /// Picks a color based on the MIME type.
  Color _colorForMimeType(BuildContext context, String? mimeType) {
    final theme = Theme.of(context);
    if (mimeType == null) return theme.colorScheme.primary;
    final lower = mimeType.toLowerCase();
    if (lower.startsWith('image/')) return theme.colorScheme.primary;
    if (lower.startsWith('video/')) return theme.colorScheme.secondary;
    if (lower.startsWith('audio/')) return theme.colorScheme.tertiary;
    if (lower == 'application/pdf') return theme.colorScheme.error;
    if (lower.contains('word') || lower.contains('document')) {
      return const Color(0xFF2B579A);
    }
    if (lower.contains('excel') || lower.contains('sheet')) {
      return const Color(0xFF217346);
    }
    if (lower.contains('powerpoint') || lower.contains('presentation')) {
      return const Color(0xFFB7472A);
    }
    if (lower.startsWith('text/')) return theme.colorScheme.primary;
    return theme.colorScheme.primary;
  }

  /// Formats a byte count into a human-readable string.
  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    final i = (log(bytes) / log(1024)).floor().clamp(0, units.length - 1);
    final size = bytes / pow(1024, i);
    final sizeStr = size >= 100
        ? size.toStringAsFixed(0)
        : size.toStringAsFixed(1);
    return '$sizeStr ${units[i]}';
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final ThemeData theme;
  final int maxLines;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.theme,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
