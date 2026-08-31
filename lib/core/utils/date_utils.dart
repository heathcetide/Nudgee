/// Date / time / duration / file-size formatting utilities.
///
/// All formatting uses simple token replacement (`yyyy`, `MM`, `dd`, `HH`,
/// `mm`, `ss`) to avoid pulling in `intl` as a dependency. Relative-time
/// helpers produce Chinese strings ("刚刚", "x 分钟前", …).
class LingDateUtils {
  LingDateUtils._();

  /// Format [date] using a token-based [format] (default `yyyy-MM-dd`).
  static String formatDate(DateTime date, {String format = 'yyyy-MM-dd'}) =>
      _format(date, format);

  /// Format [date] as time (default `HH:mm:ss`).
  static String formatTime(DateTime date, {String format = 'HH:mm:ss'}) =>
      _format(date, format);

  /// Format [date] as date + time (default `yyyy-MM-dd HH:mm:ss`).
  static String formatDateTime(DateTime date,
          {String format = 'yyyy-MM-dd HH:mm:ss'}) =>
      _format(date, format);

  /// Relative time in Chinese: "刚刚" / "x 分钟前" / "x 小时前" /
  /// "昨天" / "x 天前".
  static String formatRelative(DateTime date, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final diff = reference.difference(date);

    if (diff.isNegative) return '刚刚';
    if (diff.inSeconds < 60) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) {
      if (isYesterday(date, reference)) return '昨天';
      return '${diff.inHours} 小时前';
    }
    if (diff.inDays == 1) return '昨天';
    if (diff.inDays < 30) return '${diff.inDays} 天前';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} 个月前';
    return '${(diff.inDays / 365).floor()} 年前';
  }

  /// Format a [Duration] as a compact string: "1h 23m" / "23m 45s" /
  /// "45s" / "1d 2h".
  static String formatDuration(Duration duration) {
    if (duration.isNegative) duration = -duration;
    final d = duration.inDays;
    final h = duration.inHours.remainder(60);
    final m = duration.inMinutes.remainder(60);
    final s = duration.inSeconds.remainder(60);

    final parts = <String>[];
    if (d > 0) parts.add('${d}d');
    if (h > 0) parts.add('${h}h');
    if (m > 0) parts.add('${m}m');
    if (s > 0) parts.add('${s}s');
    if (parts.isEmpty) return '0s';
    // Keep at most two components for compactness.
    return parts.take(2).join(' ');
  }

  /// Format a byte count as a human-readable file size: "1.5 MB".
  static String formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
    final digitGroups = (bytes.bitLength / 10).floor();
    final index = digitGroups < units.length ? digitGroups : units.length - 1;
    final value = bytes / (1 << (index * 10));
    return '${value.toStringAsFixed(value >= 100 || value == value.roundToDouble() ? 0 : 1)} ${units[index]}';
  }

  /// Whether [date] is on the same calendar day as today.
  static bool isToday(DateTime date, [DateTime? now]) {
    final ref = now ?? DateTime.now();
    return date.year == ref.year &&
        date.month == ref.month &&
        date.day == ref.day;
  }

  /// Whether [date] is on the calendar day before [now] (default: today).
  static bool isYesterday(DateTime date, [DateTime? now]) {
    final ref = (now ?? DateTime.now());
    final yesterday = DateTime(ref.year, ref.month, ref.day).subtract(const Duration(days: 1));
    return date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
  }

  /// Whether [date] falls within the same year as [now] (default: today).
  static bool isThisYear(DateTime date, [DateTime? now]) {
    final ref = now ?? DateTime.now();
    return date.year == ref.year;
  }

  /// Parse [dateStr] using a token-based [format] (default `yyyy-MM-dd`).
  ///
  /// Returns `DateTime.now()` if parsing fails.
  static DateTime parse(String dateStr, {String format = 'yyyy-MM-dd'}) {
    try {
      return _parse(dateStr, format);
    } catch (_) {
      return DateTime.now();
    }
  }

  /// Whole days between [start] and [end] (exclusive of [end]'s day).
  static int daysBetween(DateTime start, DateTime end) {
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    return e.difference(s).inDays;
  }

  // ── Private helpers ──────────────────────────────────────────────────

  static String _format(DateTime date, String format) {
    final yyyy = date.year.toString().padLeft(4, '0');
    final yy = yyyy.substring(2);
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final second = date.second.toString().padLeft(2, '0');
    return format
        .replaceAll('yyyy', yyyy)
        .replaceAll('yy', yy)
        .replaceAll('MM', month)
        .replaceAll('dd', day)
        .replaceAll('HH', hour)
        .replaceAll('mm', minute)
        .replaceAll('ss', second);
  }

  static DateTime _parse(String dateStr, String format) {
    // Tokenize the format string preserving literal separators.
    final tokens = <_Token>[];
    final buf = StringBuffer();
    for (var i = 0; i < format.length; i++) {
      final ch = format[i];
      if (_isTokenChar(ch)) {
        buf.write(ch);
      } else {
        if (buf.isNotEmpty) {
          tokens.add(_Token(buf.toString(), true));
          buf.clear();
        }
        tokens.add(_Token(ch, false));
      }
    }
    if (buf.isNotEmpty) tokens.add(_Token(buf.toString(), true));

    var year = 1970, month = 1, day = 1, hour = 0, minute = 0, second = 0;
    var pos = 0;
    for (final tok in tokens) {
      if (tok.isField) {
        final width = tok.value.length;
        final chunk = dateStr.substring(pos, pos + width);
        pos += width;
        final value = int.tryParse(chunk) ?? 0;
        switch (tok.value) {
          case 'yyyy':
            year = value;
            break;
          case 'yy':
            year = 2000 + value;
            break;
          case 'MM':
            month = value;
            break;
          case 'dd':
            day = value;
            break;
          case 'HH':
            hour = value;
            break;
          case 'mm':
            minute = value;
            break;
          case 'ss':
            second = value;
            break;
        }
      } else {
        // Literal separator — skip matching chars in the input.
        pos += tok.value.length;
      }
    }
    return DateTime(year, month, day, hour, minute, second);
  }

  static bool _isTokenChar(String ch) =>
      ch == 'y' || ch == 'M' || ch == 'd' || ch == 'H' || ch == 'm' || ch == 's';
}

class _Token {
  final String value;
  final bool isField;
  const _Token(this.value, this.isField);
}
