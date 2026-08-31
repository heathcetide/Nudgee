import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart' hide AppLifecycleState;

/// A simplified representation of the Flutter app lifecycle state.
enum AppLifecycleState {
  /// The app is visible and responding to user input.
  foreground,

  /// The app is not currently visible to the user.
  background,

  /// The app is in an inactive state and not receiving user input.
  inactive,

  /// The app is paused (e.g. behind another app / notification).
  paused,

  /// The app is detached from any host view.
  detached,
}

/// Monitors the application lifecycle and exposes state changes.
///
/// Register [init] once at startup (typically in `main()` after the binding is
/// ready) and call [dispose] on shutdown. Consumers can listen to [stateStream]
/// or read [stateNotifier] reactively, and optionally set the callback hooks
/// ([onEnterForeground], [onEnterBackground], [onPaused]).
class AppLifecycleService with WidgetsBindingObserver {
  AppLifecycleService();

  /// Notifier that publishes the current lifecycle state.
  final ValueNotifier<AppLifecycleState> stateNotifier =
      ValueNotifier<AppLifecycleState>(AppLifecycleState.foreground);

  /// Stream controller backing [stateStream].
  final StreamController<AppLifecycleState> _controller =
      StreamController<AppLifecycleState>.broadcast();

  /// Broadcast stream of lifecycle state transitions.
  Stream<AppLifecycleState> get stateStream => _controller.stream;

  /// The current lifecycle state.
  AppLifecycleState get state => stateNotifier.value;

  // ── Optional callback hooks ──────────────────────────────────────────

  /// Invoked when the app returns to the foreground.
  VoidCallback? onEnterForeground;

  /// Invoked when the app enters the background.
  VoidCallback? onEnterBackground;

  /// Invoked when the app is paused.
  VoidCallback? onPaused;

  bool _initialized = false;

  /// Register the [WidgetsBindingObserver].
  ///
  /// Safe to call multiple times — only the first call has an effect.
  void init() {
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);
  }

  /// Remove the observer and close streams.
  void dispose() {
    if (_initialized) {
      WidgetsBinding.instance.removeObserver(this);
      _initialized = false;
    }
    _controller.close();
    stateNotifier.dispose();
  }

  @override
  void didChangeAppLifecycleState(ui.AppLifecycleState state) {
    final mapped = _mapState(state);
    _notify(mapped);
  }

  void _notify(AppLifecycleState newState) {
    final previous = stateNotifier.value;
    stateNotifier.value = newState;
    if (!_controller.isClosed) {
      _controller.add(newState);
    }

    // Fire callback hooks on relevant transitions.
    if (newState == AppLifecycleState.foreground &&
        previous != AppLifecycleState.foreground) {
      onEnterForeground?.call();
    }
    if (newState == AppLifecycleState.background &&
        previous != AppLifecycleState.background) {
      onEnterBackground?.call();
    }
    if (newState == AppLifecycleState.paused &&
        previous != AppLifecycleState.paused) {
      onPaused?.call();
    }
  }

  AppLifecycleState _mapState(ui.AppLifecycleState state) {
    switch (state) {
      case ui.AppLifecycleState.resumed:
        return AppLifecycleState.foreground;
      case ui.AppLifecycleState.inactive:
        return AppLifecycleState.inactive;
      case ui.AppLifecycleState.paused:
        return AppLifecycleState.paused;
      case ui.AppLifecycleState.detached:
        return AppLifecycleState.detached;
      case ui.AppLifecycleState.hidden:
        return AppLifecycleState.background;
    }
  }
}
