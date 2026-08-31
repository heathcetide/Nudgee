import 'package:flutter/material.dart';

import 'package:nudgee/core/errors/app_exception.dart';

/// A centered error display with icon, message, and retry action.
class LingErrorView extends StatelessWidget {
  final AppException error;
  final VoidCallback? onRetry;

  const LingErrorView({
    super.key,
    required this.error,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              _titleFor(error),
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error.message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _titleFor(AppException error) {
    if (error is NetworkException) return 'Network Error';
    if (error is AuthException) return 'Authentication Error';
    if (error is ServerException) return 'Server Error';
    if (error is ValidationException) return 'Validation Error';
    if (error is PermissionException) return 'Permission Denied';
    if (error is StorageException) return 'Storage Error';
    return 'Something Went Wrong';
  }
}
