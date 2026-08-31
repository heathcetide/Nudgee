import 'dart:async';

import 'package:nudgee/core/services/connectivity_service.dart' show NetworkType;

/// Web connectivity backend stub.
///
/// `connectivity_plus` uses `package:web` which is incompatible with
/// Flutter 3.22.x DDC, so on Web we report [NetworkType.unknown] and assume
/// the device is connected (browsers don't expose network type reliably).
class ConnectivityBackend {
  ConnectivityBackend();

  final StreamController<NetworkType> _controller =
      StreamController<NetworkType>.broadcast();

  /// A stream that never emits on Web (no reliable connectivity events).
  Stream<NetworkType> get networkStream => _controller.stream;

  /// Always [NetworkType.unknown] on Web.
  Future<NetworkType> get currentType async => NetworkType.unknown;
}
