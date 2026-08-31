import 'package:event_bus/event_bus.dart';

/// Global event bus instance.
///
/// Use [LingEventManager] for typed event publishing and subscribing,
/// or use [eventBus] directly for advanced scenarios.
final EventBus eventBus = EventBus(sync: false);

/// A typed event bus manager for publish/subscribe communication.
///
/// Define your own event classes and use [fire] / [on] to communicate
/// between decoupled components.
///
/// ```dart
/// class RoomJoinedEvent { final String roomId; RoomJoinedEvent(this.roomId); }
///
/// // Publish
/// LingEventManager.fire(RoomJoinedEvent('room-123'));
///
/// // Subscribe
/// final sub = LingEventManager.on<RoomJoinedEvent>().listen((event) {
///   print('Joined room: ${event.roomId}');
/// });
/// // Don't forget to cancel: sub.cancel();
/// ```
class LingEventManager {
  LingEventManager._();

  /// Fire an event to all subscribers.
  static void fire<T>(T event) => eventBus.fire(event);

  /// Subscribe to events of type [T].
  static Stream<T> on<T>() => eventBus.on<T>();

  /// Subscribe to all events (for debugging/logging).
  static Stream<dynamic> onAll() => eventBus.on<dynamic>();
}

/// Base class for typed events with a payload.
class LingEvent<T> {
  final T? data;
  final DateTime timestamp;

  LingEvent({this.data, DateTime? timestamp}) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => '$runtimeType(data: $data, at: $timestamp)';
}
