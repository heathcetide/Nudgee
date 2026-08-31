import 'package:flutter/foundation.dart';

import 'package:nudgee/core/services/logger_service.dart';

/// A received push notification payload.
class PushNotification {
  /// Stable identifier for this notification.
  final String id;

  /// Notification title.
  final String title;

  /// Notification body text.
  final String body;

  /// Arbitrary key/value data delivered with the notification.
  final Map<String, dynamic> data;

  /// When the notification was received on the device.
  final DateTime receivedAt;

  PushNotification({
    required this.id,
    required this.title,
    required this.body,
    Map<String, dynamic>? data,
    DateTime? receivedAt,
  })  : data = Map<String, dynamic>.unmodifiable(data ?? const {}),
        receivedAt = receivedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'data': data,
        'receivedAt': receivedAt.toIso8601String(),
      };
}

/// Abstract push-notification layer.
///
/// No concrete push SDK (FCM, APNs, JPush, …) is imported here. Subclasses
/// or a strategy injected at runtime provide the platform-specific wiring;
/// the public API stays stable so the integration point can change without
/// touching call sites.
class PushNotificationService {
  PushNotificationService({LoggerService? logger}) : _logger = logger;

  final LoggerService? _logger;

  /// Emits the most recent foreground notification (`null` when cleared).
  final ValueNotifier<PushNotification?> notificationNotifier =
      ValueNotifier<PushNotification?>(null);

  /// Emits the current device push token (`null` until obtained).
  final ValueNotifier<String?> tokenNotifier = ValueNotifier<String?>(null);

  // ── Lifecycle ─────────────────────────────────────────────────────────

  /// Initialize the underlying push provider and start listening for
  /// tokens / messages. Concrete implementations override this.
  Future<void> init() async {
    _logger?.i('PushNotificationService init', tag: 'push');
  }

  /// Obtain the current device token, if available.
  Future<String?> getToken() async {
    _logger?.d('getToken requested', tag: 'push');
    return tokenNotifier.value;
  }

  // ── Incoming events ───────────────────────────────────────────────────

  /// Called when a notification is received while the app is in the
  /// foreground. Publishes it via [notificationNotifier].
  void onMessage(PushNotification notification) {
    notificationNotifier.value = notification;
    _logger?.d('Push onMessage: ${notification.title}', tag: 'push');
  }

  /// Called when the user taps a notification. Concrete implementations
  /// typically perform deep-link navigation here.
  void onNotificationTap(PushNotification notification) {
    _logger?.i('Push tap: ${notification.id}', tag: 'push');
  }

  // ── Topics ────────────────────────────────────────────────────────────

  /// Subscribe to a server-side topic.
  Future<void> subscribeTopic(String topic) async {
    _logger?.d('subscribeTopic: $topic', tag: 'push');
  }

  /// Unsubscribe from a server-side topic.
  Future<void> unsubscribeTopic(String topic) async {
    _logger?.d('unsubscribeTopic: $topic', tag: 'push');
  }

  // ── Permissions ───────────────────────────────────────────────────────

  /// Request notification permission from the OS.
  Future<void> requestPermission() async {
    _logger?.d('requestPermission', tag: 'push');
  }
}
