import 'dart:async';

/// General-purpose utility functions.
class LingUtils {
  LingUtils._();

  /// Format bytes to human-readable string (e.g. "1.5 MB").
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    final digitGroups = (bytes.bitLength / 10).floor();
    return '${(bytes / (1 << (digitGroups * 10))).toStringAsFixed(1)} ${units[digitGroups]}';
  }

  /// Format duration to "MM:SS" or "HH:MM:SS".
  static String formatDuration(Duration duration) {
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  /// Format a [DateTime] to a relative time string (e.g. "3 min ago").
  static String formatRelativeTime(DateTime time, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final diff = reference.difference(time);

    if (diff.inSeconds < 60) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} 周前';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} 个月前';
    return '${(diff.inDays / 365).floor()} 年前';
  }

  /// Mask a string, showing only the first and last [keep] characters.
  /// Example: maskMiddle("1234567890", keep: 3) → "123***890"
  static String maskMiddle(String input, {int keep = 3}) {
    if (input.length <= keep * 2) return input;
    final start = input.substring(0, keep);
    final end = input.substring(input.length - keep);
    final mask = '*' * (input.length - keep * 2);
    return '$start$mask$end';
  }

  /// Validate an email address.
  static bool isValidEmail(String email) {
    return RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(email);
  }

  /// Validate a phone number (simple check: 10-15 digits).
  static bool isValidPhone(String phone) {
    return RegExp(r'^\d{10,15}$').hasMatch(phone.replaceAll(RegExp(r'[\s-]'), ''));
  }

  /// Generate a random ID using UUID v4 format (without dashes).
  static String generateId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return now.toRadixString(36).toUpperCase();
  }

  /// Debounce a function call (static helper).
  static void Function() debounce(void Function() fn, Duration delay) {
    int lastTime = 0;
    return () {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - lastTime >= delay.inMilliseconds) {
        lastTime = now;
        fn();
      }
    };
  }
}

/// Debounce extension on [VoidCallback].
///
/// Usage:
/// ```dart
/// final debounced = myFunction.debounce(500);
/// debounced(); // only fires after 500ms of inactivity
/// ```
extension LingDebounceExtension on void Function() {
  void Function() debounce([int milliseconds = 500]) {
    Timer? timer;
    return () {
      timer?.cancel();
      timer = Timer(Duration(milliseconds: milliseconds), this);
    };
  }
}

/// Throttle extension on [VoidCallback].
///
/// Usage:
/// ```dart
/// final throttled = myFunction.throttle(2000);
/// throttled(); // fires immediately
/// throttled(); // ignored (within 2s)
/// ```
extension LingThrottleExtension on void Function() {
  void Function() throttle([int milliseconds = 500]) {
    bool allowed = true;
    Timer? timer;
    return () {
      if (!allowed) return;
      allowed = false;
      this();
      timer?.cancel();
      timer = Timer(Duration(milliseconds: milliseconds), () {
        allowed = true;
      });
    };
  }
}
