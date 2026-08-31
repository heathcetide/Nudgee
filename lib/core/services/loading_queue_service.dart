import 'package:flutter/material.dart';

/// A reference-counted global loading manager.
///
/// Multiple concurrent calls to [show] will only display one loading overlay.
/// The loading is only dismissed when all callers have called [dismiss].
///
/// Usage:
/// ```dart
/// loadingQueue.show('Uploading...');
/// try {
///   await someAsyncWork();
/// } finally {
///   loadingQueue.dismiss();
/// }
/// ```
class LingLoadingQueue {
  static final LingLoadingQueue _instance = LingLoadingQueue._internal();
  factory LingLoadingQueue() => _instance;
  LingLoadingQueue._internal();

  int _count = 0;
  OverlayEntry? _overlayEntry;

  /// Show loading overlay if not already showing.
  void show([String? message, BuildContext? context]) {
    _count++;
    if (_count == 1 && context != null) {
      _overlayEntry = _createEntry(message);
      Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
    }
  }

  /// Dismiss loading overlay when all callers have dismissed.
  void dismiss() {
    if (_count > 0) {
      _count--;
      if (_count == 0) {
        _overlayEntry?.remove();
        _overlayEntry = null;
      }
    }
  }

  /// Force dismiss all loading overlays regardless of count.
  void dismissAll() {
    _count = 0;
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  /// Whether the loading overlay is currently visible.
  bool get isShowing => _count > 0;

  /// Current reference count.
  int get count => _count;

  OverlayEntry _createEntry(String? message) {
    return OverlayEntry(
      builder: (context) => _LoadingOverlay(message: message),
    );
  }
}

/// Global instance.
final loadingQueue = LingLoadingQueue();

class _LoadingOverlay extends StatelessWidget {
  final String? message;

  const _LoadingOverlay({this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.black54,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: theme.colorScheme.primary,
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: 16),
                Text(
                  message!,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
