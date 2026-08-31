import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

/// A file preview / detail page.
///
/// Shows file metadata and allows opening the file with the system
/// default application via [open_filex].
class LingFileViewer extends StatelessWidget {
  final String? filePath;
  final String? fileName;
  final int? fileSize;
  final String? fileUrl;

  const LingFileViewer({
    super.key,
    this.filePath,
    this.fileName,
    this.fileSize,
    this.fileUrl,
  });

  String get _displayName => fileName ?? '未知文件';

  String get _sizeStr {
    if (fileSize == null) return '';
    if (fileSize! < 1024) return '$fileSize B';
    if (fileSize! < 1024 * 1024) return '${(fileSize! / 1024).toStringAsFixed(1)} KB';
    if (fileSize! < 1024 * 1024 * 1024) {
      return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(fileSize! / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  IconData get _fileIcon {
    final name = _displayName.toLowerCase();
    if (name.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (name.endsWith('.doc') || name.endsWith('.docx')) return Icons.description;
    if (name.endsWith('.xls') || name.endsWith('.xlsx')) return Icons.table_chart;
    if (name.endsWith('.ppt') || name.endsWith('.pptx')) return Icons.slideshow;
    if (name.endsWith('.txt') || name.endsWith('.md')) return Icons.text_snippet;
    if (name.endsWith('.zip') || name.endsWith('.rar') || name.endsWith('.7z')) {
      return Icons.folder_zip;
    }
    if (name.endsWith('.mp4') || name.endsWith('.avi') || name.endsWith('.mov')) {
      return Icons.video_file;
    }
    if (name.endsWith('.mp3') || name.endsWith('.wav') || name.endsWith('.aac')) {
      return Icons.audio_file;
    }
    if (name.endsWith('.jpg') || name.endsWith('.jpeg') || name.endsWith('.png') ||
        name.endsWith('.gif') || name.endsWith('.bmp')) {
      return Icons.image;
    }
    return Icons.insert_drive_file;
  }

  String get _fileType {
    final name = _displayName.toLowerCase();
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex >= 0 && dotIndex < name.length - 1) {
      return name.substring(dotIndex + 1).toUpperCase();
    }
    return 'FILE';
  }

  Future<void> _openFile(BuildContext context) async {
    final path = filePath;
    if (path == null || !File(path).existsSync()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('文件不存在或无法访问')),
        );
      }
      return;
    }
    final result = await OpenFilex.open(path);
    if (result.type != ResultType.done && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法打开文件: ${result.message}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_displayName),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            onPressed: () => _openFile(context),
            tooltip: '打开文件',
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // File icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  _fileIcon,
                  size: 56,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 24),
              // File name
              Text(
                _displayName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              // File type badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _fileType,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (_sizeStr.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _sizeStr,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              // Open button
              FilledButton.icon(
                onPressed: () => _openFile(context),
                icon: const Icon(Icons.open_in_browser),
                label: const Text('打开文件'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
