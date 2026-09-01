import 'package:nudgee/core/agent/tools/agent_tool.dart';
import 'package:nudgee/core/agent/tools/tool_result.dart';
import 'package:nudgee/core/di/injector.dart';
import 'package:nudgee/core/models/schedule_model.dart';
import 'package:nudgee/core/services/schedule_service.dart';

/// Tool: schedule.add
///
/// Adds a new schedule item for the user. The LLM should provide the task
/// name, date, start time, and end time. Location and note are optional.
///
/// This is a mutation tool — it requires confirmation in non-bypass modes.
class ScheduleAddTool extends AgentTool {
  @override
  String get name => 'schedule.add';

  @override
  String get description =>
      'Add a new schedule item (a self-discipline task like morning run, '
      'reading, meditation, etc.) to the user\'s calendar. '
      'Provide the task name, date (YYYY-MM-DD), start time (HH:mm), '
      'and end time (HH:mm). Location and note are optional.';

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'name': {
            'type': 'string',
            'description': 'Task name, e.g. "Morning Run", "Read Book"',
          },
          'date': {
            'type': 'string',
            'description': 'Date in YYYY-MM-DD format, e.g. "2026-09-01"',
          },
          'startTime': {
            'type': 'string',
            'description': 'Start time in HH:mm 24-hour format, e.g. "07:00"',
          },
          'endTime': {
            'type': 'string',
            'description': 'End time in HH:mm 24-hour format, e.g. "08:00"',
          },
          'location': {
            'type': 'string',
            'description': 'Location of the task (optional)',
          },
          'note': {
            'type': 'string',
            'description': 'Additional notes for the task (optional)',
          },
        },
        'required': ['name', 'date', 'startTime', 'endTime'],
      };

  @override
  bool get isMutation => true;

  @override
  bool get requiresConfirmation => true;

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final name = args['name'] as String?;
    final date = args['date'] as String?;
    final startTime = args['startTime'] as String?;
    final endTime = args['endTime'] as String?;

    if (name == null || date == null || startTime == null || endTime == null) {
      return const ToolResult.error(
          'Missing required fields: name, date, startTime, endTime');
    }

    // Validate date format
    if (!_isValidDate(date)) {
      return ToolResult.error('Invalid date format: $date (expected YYYY-MM-DD)');
    }

    // Validate time format
    if (!_isValidTime(startTime) || !_isValidTime(endTime)) {
      return ToolResult.error(
          'Invalid time format (expected HH:mm 24-hour). '
          'startTime=$startTime, endTime=$endTime');
    }

    // Calculate startIndex and length for timetable grid
    final startMin = _timeToMinutes(startTime);
    final endMin = _timeToMinutes(endTime);
    if (endMin <= startMin) {
      return ToolResult.error(
          'endTime ($endTime) must be after startTime ($startTime)');
    }

    final startIndex = (startMin ~/ 60) * 2 + (startMin % 60 >= 30 ? 1 : 0);
    final length = ((endMin - startMin) / 30).ceil();

    final item = ScheduleItem(
      id: '${date}_${startTime}_${name}',
      name: name,
      location: (args['location'] as String?) ?? 'Not specified',
      note: (args['note'] as String?) ?? 'None',
      date: date,
      startTime: startTime,
      endTime: endTime,
      startIndex: startIndex,
      length: length,
      isExtra: true,
    );

    try {
      final service = sl<ScheduleService>();
      await service.addSchedule(item);
      return ToolResult.success(
          'Schedule added: "$name" on $date from $startTime to $endTime'
          '${args['location'] != null ? " at ${args['location']}" : ""}');
    } catch (e) {
      return ToolResult.error('Failed to add schedule: $e');
    }
  }

  bool _isValidDate(String date) {
    final regex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (!regex.hasMatch(date)) return false;
    try {
      DateTime.parse(date);
      return true;
    } catch (_) {
      return false;
    }
  }

  bool _isValidTime(String time) {
    final regex = RegExp(r'^([01]?\d|2[0-3]):[0-5]\d$');
    return regex.hasMatch(time);
  }

  int _timeToMinutes(String timeStr) {
    final parts = timeStr.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
}

/// Tool: schedule.query
///
/// Queries the user's schedule for a specific date or date range.
/// This is a read-only tool — no confirmation needed.
class ScheduleQueryTool extends AgentTool {
  @override
  String get name => 'schedule.query';

  @override
  String get description =>
      'Query the user\'s schedule (calendar) for a specific date or list all '
      'dates that have scheduled tasks. Use this to check what the user has '
      'planned on a given day.';

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'date': {
            'type': 'string',
            'description':
                'Specific date to query in YYYY-MM-DD format. '
                'If omitted, lists all dates that have scheduled tasks.',
          },
        },
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    try {
      final service = sl<ScheduleService>();
      final date = args['date'] as String?;

      if (date != null) {
        // Query specific date
        final items = service.getForDate(date);
        if (items.isEmpty) {
          return ToolResult.success('No scheduled tasks on $date.');
        }
        final lines = items.map((item) {
          return '- ${item.startTime}-${item.endTime}: ${item.name}'
              '${item.location != 'Not specified' && item.location.isNotEmpty ? ' @ ${item.location}' : ''}'
              '${item.note != 'None' && item.note.isNotEmpty ? ' (${item.note})' : ''}';
        }).join('\n');
        return ToolResult.success('Tasks on $date:\n$lines');
      } else {
        // List all dates with tasks
        final dates = service.scheduleData.dates;
        if (dates.isEmpty) {
          return ToolResult.success('No scheduled tasks found.');
        }
        final dateList = dates.map((d) {
          final count = service.scheduleData.byDate[d]?.length ?? 0;
          return '- $d ($count task${count > 1 ? "s" : ""})';
        }).join('\n');
        return ToolResult.success('Dates with scheduled tasks:\n$dateList');
      }
    } catch (e) {
      return ToolResult.error('Failed to query schedule: $e');
    }
  }
}

/// Tool: schedule.remove
///
/// Removes a schedule item by date and item ID or name.
/// This is a mutation tool — requires confirmation.
class ScheduleRemoveTool extends AgentTool {
  @override
  String get name => 'schedule.remove';

  @override
  String get description =>
      'Remove a scheduled task from the user\'s calendar. '
      'Provide the date and either the item ID or the task name '
      '(with start time for disambiguation).';

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'date': {
            'type': 'string',
            'description': 'Date in YYYY-MM-DD format',
          },
          'itemId': {
            'type': 'string',
            'description': 'The exact item ID to remove (if known)',
          },
          'name': {
            'type': 'string',
            'description':
                'Task name to remove. If multiple tasks have the same name, '
                'also provide startTime to disambiguate.',
          },
          'startTime': {
            'type': 'string',
            'description':
                'Start time in HH:mm format, used with name to disambiguate',
          },
        },
        'required': ['date'],
      };

  @override
  bool get isMutation => true;

  @override
  bool get requiresConfirmation => true;

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final date = args['date'] as String?;
    if (date == null) {
      return const ToolResult.error('Missing required field: date');
    }

    try {
      final service = sl<ScheduleService>();
      final items = service.getForDate(date);
      if (items.isEmpty) {
        return ToolResult.error('No tasks found on $date');
      }

      final itemId = args['itemId'] as String?;
      final name = args['name'] as String?;
      final startTime = args['startTime'] as String?;

      ScheduleItem? target;

      if (itemId != null) {
        target = items.where((i) => i.id == itemId).firstOrNull;
      } else if (name != null) {
        var matches = items.where((i) => i.name == name).toList();
        if (startTime != null) {
          matches = matches.where((i) => i.startTime == startTime).toList();
        }
        if (matches.length == 1) {
          target = matches[0];
        } else if (matches.length > 1) {
          final matchList = matches
              .map((m) => '- ${m.startTime}-${m.endTime}: ${m.name}')
              .join('\n');
          return ToolResult.error(
              'Multiple tasks match "$name" on $date. '
              'Please also provide startTime to disambiguate:\n$matchList');
        }
      }

      if (target == null) {
        return ToolResult.error(
            'Task not found on $date'
            '${name != null ? ' with name "$name"' : ''}'
            '${startTime != null ? ' at $startTime' : ''}');
      }

      await service.removeSchedule(date, target.id);
      return ToolResult.success(
          'Removed: "${target.name}" (${target.startTime}-${target.endTime}) on $date');
    } catch (e) {
      return ToolResult.error('Failed to remove schedule: $e');
    }
  }
}
