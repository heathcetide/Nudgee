import 'package:nudgee/core/agent/tools/agent_tool.dart';
import 'package:nudgee/core/agent/tools/tool_result.dart';
import 'package:nudgee/core/di/injector.dart';
import 'package:nudgee/core/models/schedule_model.dart';
import 'package:nudgee/core/services/notification_service.dart';

/// Tool: notification.schedule
///
/// Schedules a local notification reminder at a specific date and time.
/// This is separate from schedule.add — it only sets a notification,
/// not a calendar entry. Useful for one-off reminders.
///
/// Mutation tool — requires confirmation.
class NotificationScheduleTool extends AgentTool {
  @override
  String get name => 'notification.schedule';

  @override
  String get description =>
      'Schedule a local notification reminder at a specific date and time. '
      'The notification will show a title and body message when it fires. '
      'Use this for one-off reminders like "Remind me to call mom at 7pm".';

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'title': {
            'type': 'string',
            'description': 'Notification title, e.g. "Reminder: Call Mom"',
          },
          'body': {
            'type': 'string',
            'description': 'Notification body text with details',
          },
          'date': {
            'type': 'string',
            'description': 'Date in YYYY-MM-DD format',
          },
          'time': {
            'type': 'string',
            'description': 'Time in HH:mm 24-hour format, e.g. "19:00"',
          },
        },
        'required': ['title', 'date', 'time'],
      };

  @override
  bool get isMutation => true;

  @override
  bool get requiresConfirmation => true;

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final title = args['title'] as String?;
    final date = args['date'] as String?;
    final time = args['time'] as String?;
    final body = args['body'] as String? ?? '';

    if (title == null || date == null || time == null) {
      return const ToolResult.error(
          'Missing required fields: title, date, time');
    }

    // Validate formats
    if (!_isValidDate(date)) {
      return ToolResult.error('Invalid date format: $date (expected YYYY-MM-DD)');
    }
    if (!_isValidTime(time)) {
      return ToolResult.error('Invalid time format: $time (expected HH:mm)');
    }

    // Check if the scheduled time is in the future
    final scheduledDate = DateTime.parse('${date}T$time:00');
    if (scheduledDate.isBefore(DateTime.now())) {
      return ToolResult.error(
          'The scheduled time ($date $time) is in the past. '
          'Please provide a future date and time.');
    }

    try {
      final service = sl<NotificationService>();
      // Create a temporary ScheduleItem to use the existing API
      final item = ScheduleItem(
        id: 'notif_${date}_${time}_${title.hashCode}',
        name: title,
        location: '',
        note: body,
        date: date,
        startTime: time,
        endTime: time,
        startIndex: 0,
        length: 1,
        isExtra: true,
      );

      await service.scheduleNotification(item);

      return ToolResult.success(
          'Notification scheduled: "$title" on $date at $time'
          '${body.isNotEmpty ? ' — $body' : ''}');
    } catch (e) {
      return ToolResult.error('Failed to schedule notification: $e');
    }
  }

  bool _isValidDate(String date) {
    try {
      DateTime.parse(date);
      return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date);
    } catch (_) {
      return false;
    }
  }

  bool _isValidTime(String time) =>
      RegExp(r'^([01]?\d|2[0-3]):[0-5]\d$').hasMatch(time);
}
