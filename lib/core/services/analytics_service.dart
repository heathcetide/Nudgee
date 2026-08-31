import 'package:flutter/foundation.dart';

import 'package:nudgee/core/network/api_client.dart';
import 'package:nudgee/core/services/logger_service.dart';

/// Categories of analytics events.
enum AnalyticsEventType {
  pageView,
  click,
  custom,
  error,
}

/// A single analytics event captured by [AnalyticsService].
///
/// Events are queued locally and flushed to the server in batches via
/// [AnalyticsService.flush]. The structure is provider-agnostic so that
/// a concrete backend (Firebase, Sentry, custom) can be plugged in later
/// without changing call sites.
class AnalyticsEvent {
  /// Human-readable event name, e.g. `"login_button_tap"`.
  final String name;

  /// The semantic category of this event.
  final AnalyticsEventType type;

  /// Arbitrary key/value payload associated with the event.
  final Map<String, dynamic> properties;

  /// When the event was captured (local device time).
  final DateTime timestamp;

  AnalyticsEvent({
    required this.name,
    this.type = AnalyticsEventType.custom,
    Map<String, dynamic>? properties,
    DateTime? timestamp,
  })  : properties = Map<String, dynamic>.unmodifiable(properties ?? const {}),
        timestamp = timestamp ?? DateTime.now();

  /// Serialize to a JSON map suitable for network upload.
  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type.name,
        'properties': properties,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Abstract analytics layer with an in-memory event queue.
///
/// No third-party SDK is used — this keeps the public surface stable so a
/// concrete provider (Firebase Analytics, Sentry, Mixpanel, …) can be wired
/// in behind the same API. Events are batched and uploaded via [ApiClient].
class AnalyticsService {
  AnalyticsService({ApiClient? apiClient, LoggerService? logger})
      : _apiClient = apiClient,
        _logger = logger;

  final ApiClient? _apiClient;
  final LoggerService? _logger;

  /// Endpoint used when flushing queued events to the server.
  static const String flushEndpoint = '/analytics/events';

  final List<AnalyticsEvent> _queue = [];
  bool _enabled = true;

  /// Notifier that emits the current number of queued (un-flushed) events.
  final ValueNotifier<int> queueSizeNotifier = ValueNotifier<int>(0);

  // ── Configuration ─────────────────────────────────────────────────────

  /// Enable or disable event collection. When disabled, [track] and its
  /// helpers are no-ops.
  void setEnabled(bool enabled) {
    _enabled = enabled;
    _logger?.d('AnalyticsService enabled=$enabled', tag: 'analytics');
  }

  /// Whether collection is currently active.
  bool get isEnabled => _enabled;

  // ── Tracking ──────────────────────────────────────────────────────────

  /// Record a generic event.
  void track(
    String eventName, {
    AnalyticsEventType type = AnalyticsEventType.custom,
    Map<String, dynamic>? properties,
  }) {
    if (!_enabled) return;
    final event = AnalyticsEvent(
      name: eventName,
      type: type,
      properties: properties,
    );
    _enqueue(event);
  }

  /// Record a page/screen view.
  void trackPageView(
    String pageName, {
    Map<String, dynamic>? properties,
  }) =>
      track(pageName, type: AnalyticsEventType.pageView, properties: properties);

  /// Record a user tap/click on a UI element.
  void trackClick(
    String elementName, {
    Map<String, dynamic>? properties,
  }) =>
      track(elementName, type: AnalyticsEventType.click, properties: properties);

  /// Record an error event.
  void trackError(
    String errorName, {
    Map<String, dynamic>? properties,
  }) =>
      track(errorName, type: AnalyticsEventType.error, properties: properties);

  // ── Queue management ──────────────────────────────────────────────────

  void _enqueue(AnalyticsEvent event) {
    _queue.add(event);
    queueSizeNotifier.value = _queue.length;
    _logger?.d('Analytics event queued: ${event.name}', tag: 'analytics');
  }

  /// Upload all queued events to the server and clear the queue on success.
  ///
  /// If no [ApiClient] is configured this is a no-op. Failures keep the
  /// events in the queue so they can be retried later.
  Future<void> flush() async {
    if (_queue.isEmpty) return;
    if (_apiClient == null) {
      _logger?.w('Analytics flush skipped — no ApiClient configured',
          tag: 'analytics');
      return;
    }

    final batch = List<AnalyticsEvent>.from(_queue);
    try {
      await _apiClient.post(
        flushEndpoint,
        data: {
          'events': batch.map((e) => e.toJson()).toList(),
        },
      );
      // Remove the flushed batch from the queue.
      _queue.removeWhere((e) => batch.contains(e));
      queueSizeNotifier.value = _queue.length;
      _logger?.i('Analytics flushed ${batch.length} events', tag: 'analytics');
    } catch (e) {
      _logger?.e('Analytics flush failed', tag: 'analytics', error: e);
      // Keep events in queue for a later retry.
    }
  }

  /// Discard all queued events without uploading.
  void clearQueue() {
    _queue.clear();
    queueSizeNotifier.value = 0;
  }
}
