import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:nudgee/core/services/connectivity_service.dart' show NetworkType;

/// Native (dart:io) connectivity backend backed by `connectivity_plus`.
class ConnectivityBackend {
  ConnectivityBackend();

  final Connectivity _connectivity = Connectivity();

  /// Stream of connectivity changes mapped to [NetworkType].
  Stream<NetworkType> get networkStream =>
      _connectivity.onConnectivityChanged.map(_mapResult);

  /// The current network type (fetched asynchronously).
  Future<NetworkType> get currentType async =>
      _mapResult(await _connectivity.checkConnectivity());

  /// Map a list of [ConnectivityResult] to a single [NetworkType].
  ///
  /// `connectivity_plus` v6 reports a *list* of active results. We pick the
  /// most relevant one (preferring Wi-Fi / Ethernet over mobile).
  NetworkType _mapResult(List<ConnectivityResult> results) {
    if (results.isEmpty) return NetworkType.none;

    // Order of preference.
    if (results.contains(ConnectivityResult.wifi)) return NetworkType.wifi;
    if (results.contains(ConnectivityResult.ethernet)) {
      return NetworkType.ethernet;
    }
    if (results.contains(ConnectivityResult.mobile)) return NetworkType.mobile;
    if (results.contains(ConnectivityResult.bluetooth)) {
      return NetworkType.bluetooth;
    }
    if (results.contains(ConnectivityResult.vpn)) return NetworkType.vpn;
    if (results.contains(ConnectivityResult.none)) return NetworkType.none;

    return NetworkType.unknown;
  }
}
