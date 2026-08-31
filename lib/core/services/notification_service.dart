import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:just_audio/just_audio.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'package:nudgee/core/models/schedule_model.dart';

/// 日程提醒服务 — 本地通知 + 铃声播放。
///
/// 使用 [flutter_local_notifications] 发送定时本地通知，
/// 使用 [just_audio] 播放提醒铃声。
class NotificationService {
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _initialized = false;

  /// Initialize the notification service.
  Future<void> init() async {
    if (_initialized) return;
    try {
      tz.initializeTimeZones();

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);
      await _notifications.initialize(settings);
      _initialized = true;
      debugPrint('[NotificationService] initialized');
    } catch (e) {
      debugPrint('[NotificationService] init error: $e');
    }
  }

  /// Request notification permissions (Android 13+).
  Future<void> requestPermissions() async {
    try {
      final android = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        await android.requestNotificationsPermission();
        await android.requestExactAlarmsPermission();
      }
    } catch (e) {
      debugPrint('[NotificationService] requestPermissions error: $e');
    }
  }

  /// Schedule a notification for a [ScheduleItem].
  ///
  /// The notification fires at [item.startTime] on [item.date],
  /// showing the task name and location.
  Future<void> scheduleNotification(ScheduleItem item) async {
    if (!_initialized) await init();

    try {
      final parts = item.startTime.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      final scheduledDate = DateTime.parse(item.date).add(Duration(hours: hour, minutes: minute));
      final now = DateTime.now();

      // Don't schedule if the time has already passed.
      if (scheduledDate.isBefore(now)) {
        debugPrint('[NotificationService] schedule skipped — time already passed: $scheduledDate');
        return;
      }

      final id = item.id.hashCode & 0x7FFFFFFF; // Ensure positive int

      const androidDetails = AndroidNotificationDetails(
        'schedule_reminders',
        '日程提醒',
        channelDescription: '日程任务开始时间提醒',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

      final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);

      await _notifications.zonedSchedule(
        id,
        '日程提醒: ${item.name}',
        '${item.startTime} - ${item.endTime}  ${item.location != '未指定' ? "📍 ${item.location}" : ""}',
        tzDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );

      debugPrint('[NotificationService] scheduled: ${item.name} at $scheduledDate (id=$id)');
    } catch (e) {
      debugPrint('[NotificationService] scheduleNotification error: $e');
    }
  }

  /// Cancel a scheduled notification for a [ScheduleItem].
  Future<void> cancelNotification(ScheduleItem item) async {
    try {
      final id = item.id.hashCode & 0x7FFFFFFF;
      await _notifications.cancel(id);
      debugPrint('[NotificationService] cancelled: ${item.name} (id=$id)');
    } catch (e) {
      debugPrint('[NotificationService] cancelNotification error: $e');
    }
  }

  /// Cancel a notification by item id.
  Future<void> cancelById(String itemId) async {
    try {
      final id = itemId.hashCode & 0x7FFFFFFF;
      await _notifications.cancel(id);
    } catch (e) {
      debugPrint('[NotificationService] cancelById error: $e');
    }
  }

  /// Play a short reminder sound using just_audio.
  Future<void> playReminderSound() async {
    try {
      await _audioPlayer.setAsset('assets/sounds/reminder.mp3');
      await _audioPlayer.play();
      debugPrint('[NotificationService] playing reminder sound');
    } catch (e) {
      debugPrint('[NotificationService] playReminderSound error (asset may not exist): $e');
    }
  }

  /// Stop any playing sound.
  Future<void> stopSound() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      debugPrint('[NotificationService] stopSound error: $e');
    }
  }

  /// Cancel all scheduled notifications.
  Future<void> cancelAll() async {
    try {
      await _notifications.cancelAll();
      debugPrint('[NotificationService] cancelled all');
    } catch (e) {
      debugPrint('[NotificationService] cancelAll error: $e');
    }
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}
