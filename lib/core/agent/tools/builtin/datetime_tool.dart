import 'package:nudgee/core/agent/tools/agent_tool.dart';
import 'package:nudgee/core/agent/tools/tool_result.dart';

/// Tool: datetime
///
/// Returns the current date, time, and timezone.
/// Also supports formatting and date arithmetic.
class DateTimeTool extends AgentTool {
  @override
  String get name => 'datetime';

  @override
  String get description =>
      'Get current date/time info, format dates, or do date arithmetic. '
      'Use this when the user asks "what time is it", "what day is today", '
      'or when you need the current time for scheduling. '
      'Actions: "now" (current time), "format" (format a date), '
      '"add" (add days/hours to a date), "diff" (difference between dates).';

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'action': {
            'type': 'string',
            'description': 'Operation: "now" (default), "format", "add", "diff"',
            'enum': ['now', 'format', 'add', 'diff'],
          },
          'date': {
            'type': 'string',
            'description': 'Date string (for format/add/diff). '
                'Accepts ISO 8601 (2024-01-15T14:30:00) or "2024-01-15" or "now".',
          },
          'format': {
            'type': 'string',
            'description': 'Output format pattern. '
                'yyyy=year, MM=month, dd=day, HH=hour(24), mm=minute, ss=second, '
                'EEEE=weekday name. Default: "yyyy-MM-dd HH:mm:ss".',
          },
          'days': {
            'type': 'integer',
            'description': 'Days to add (for "add" action, can be negative)',
          },
          'hours': {
            'type': 'integer',
            'description': 'Hours to add (for "add" action, can be negative)',
          },
          'date2': {
            'type': 'string',
            'description': 'Second date (for "diff" action)',
          },
        },
        'required': [],
      };

  @override
  bool get isMutation => false;

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final action = args['action'] as String? ?? 'now';

    return switch (action) {
      'now' => _now(args),
      'format' => _format(args),
      'add' => _add(args),
      'diff' => _diff(args),
      _ => ToolResult.error('Unknown action: $action. Use now/format/add/diff.'),
    };
  }

  ToolResult _now(Map<String, dynamic> args) {
    final now = DateTime.now();
    final fmt = args['format'] as String? ?? 'yyyy-MM-dd HH:mm:ss';
    final timezone = now.timeZoneName;
    final offset = now.timeZoneOffset;
    final offsetStr = offset.isNegative
        ? '-${offset.abs().toString().padLeft(8, '0')}'
        : '+${offset.toString().padLeft(8, '0')}';

    return ToolResult.success(
        'Current time: ${_formatDateTime(now, fmt)}\n'
        'Timezone: $timezone (UTC$offsetStr)\n'
        'Weekday: ${_weekdayName(now.weekday)}\n'
        'ISO 8601: ${now.toIso8601String()}\n'
        'Timestamp (ms): ${now.millisecondsSinceEpoch}');
  }

  ToolResult _format(Map<String, dynamic> args) {
    final dateStr = args['date'] as String?;
    if (dateStr == null) return const ToolResult.error('Missing: date');
    final fmt = args['format'] as String? ?? 'yyyy-MM-dd HH:mm:ss';

    final date = _parseDate(dateStr);
    if (date == null) {
      return ToolResult.error('Invalid date: $dateStr');
    }
    return ToolResult.success(_formatDateTime(date, fmt));
  }

  ToolResult _add(Map<String, dynamic> args) {
    final dateStr = args['date'] as String? ?? 'now';
    final days = (args['days'] as num?)?.toInt() ?? 0;
    final hours = (args['hours'] as num?)?.toInt() ?? 0;
    final fmt = args['format'] as String? ?? 'yyyy-MM-dd HH:mm:ss';

    final date = _parseDate(dateStr);
    if (date == null) {
      return ToolResult.error('Invalid date: $dateStr');
    }
    final result = date.add(Duration(days: days, hours: hours));
    return ToolResult.success(
        '${_formatDateTime(date, fmt)} + $days days $hours hours\n'
        '= ${_formatDateTime(result, fmt)} (${_weekdayName(result.weekday)})');
  }

  ToolResult _diff(Map<String, dynamic> args) {
    final date1Str = args['date'] as String?;
    final date2Str = args['date2'] as String?;
    if (date1Str == null || date2Str == null) {
      return const ToolResult.error('Missing: date and date2');
    }

    final d1 = _parseDate(date1Str);
    final d2 = _parseDate(date2Str);
    if (d1 == null) return ToolResult.error('Invalid date: $date1Str');
    if (d2 == null) return ToolResult.error('Invalid date: $date2Str');

    final diff = d2.difference(d1);
    final days = diff.inDays;
    final hours = diff.inHours;
    final minutes = diff.inMinutes;

    return ToolResult.success(
        'Date 1: ${_formatDateTime(d1, 'yyyy-MM-dd HH:mm')}\n'
        'Date 2: ${_formatDateTime(d2, 'yyyy-MM-dd HH:mm')}\n'
        'Difference: $days days ($hours hours / $minutes minutes)');
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  DateTime? _parseDate(String s) {
    if (s == 'now') return DateTime.now();
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  String _formatDateTime(DateTime dt, String pattern) {
    var result = pattern;
    result = result.replaceAll('yyyy', dt.year.toString());
    result = result.replaceAll('MM', dt.month.toString().padLeft(2, '0'));
    result = result.replaceAll('dd', dt.day.toString().padLeft(2, '0'));
    result = result.replaceAll('HH', dt.hour.toString().padLeft(2, '0'));
    result = result.replaceAll('mm', dt.minute.toString().padLeft(2, '0'));
    result = result.replaceAll('ss', dt.second.toString().padLeft(2, '0'));
    result = result.replaceAll('EEEE', _weekdayName(dt.weekday));
    return result;
  }

  String _weekdayName(int weekday) {
    const names = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    if (weekday < 1 || weekday > 7) return 'Unknown';
    return names[weekday - 1];
  }
}
