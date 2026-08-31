import 'dart:async';

import 'package:flutter/foundation.dart';

// Platform-specific backend selected via conditional imports.
// On non-Web (dart:io) platforms the real connectivity_plus backend is used;
// on Web a stub backend that reports [NetworkType.unknown] is used instead,
// avoiding the package:web incompatibility with Flutter 3.22.x DDC.
import 'package:nudgee/core/services/connectivity_service_web.dart'
    if (dart.library.io) 'package:nudgee/core/services/connectivity_service_io.dart'
    as platform;

/// The type of network connection currently available.
enum NetworkType {
  wifi,
  mobile,
  ethernet,
  bluetooth,
  vpn,
  none,
  unknown,
}

/// Monitors device network connectivity.
///
/// Exposes the current [NetworkType] and a boolean [isConnected] flag through
/// [ValueNotifier]s and broadcast streams. Call [init] once at startup and
/// [dispose] on shutdown.
class ConnectivityService {
  ConnectivityService() : _backend = platform.ConnectivityBackend();

  final platform.ConnectivityBackend _backend;

  /// Notifier for the current network type.
  final ValueNotifier<NetworkType> currentTypeNotifier =
      ValueNotifier<NetworkType>(NetworkType.unknown);

  /// Notifier for whether the device currently has any connection.
  final ValueNotifier<bool> isConnectedNotifier =
      ValueNotifier<bool>(false);

  /// Stream controller backing [networkStream].
  final StreamController<NetworkType> _controller =
      StreamController<NetworkType>.broadcast();

  /// Broadcast stream of network type changes.
  Stream<NetworkType> get networkStream => _controller.stream;

  /// The current network type.
  NetworkType get currentType => currentTypeNotifier.value;

  /// Whether the device currently has a network connection.
  bool get isConnected => currentTypeNotifier.value != NetworkType.none;

  bool _initialized = false;
  StreamSubscription<NetworkType>? _backendSub;

  /// Start listening to platform connectivity changes.
  ///
  /// This is async because the initial type is fetched from the platform.
  /// Safe to call without awaiting — the service defaults to
  /// [NetworkType.unknown] until the initial value arrives.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Seed with the current value (async on native platforms).
    final initial = await _backend.currentType;
    _update(initial);

    _backendSub = _backend.networkStream.listen(_update);
  }

  void _update(NetworkType type) {
    currentTypeNotifier.value = type;
    isConnectedNotifier.value = type != NetworkType.none;
    if (!_controller.isClosed) {
      _controller.add(type);
    }
  }

  /// Stop listening and release resources.
  void dispose() {
    _backendSub?.cancel();
    _backendSub = null;
    _initialized = false;
    _controller.close();
    currentTypeNotifier.dispose();
    isConnectedNotifier.dispose();
  }
}
