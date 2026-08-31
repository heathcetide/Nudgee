import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:get_it/get_it.dart';

import 'package:nudgee/core/errors/app_exception.dart';
import 'package:nudgee/core/services/logger_service.dart';

/// Bluetooth adapter state mapped to a project-agnostic enum.
enum LingBluetoothState {
  /// State could not be determined yet.
  unknown,

  /// Bluetooth is not supported on this device / platform.
  unsupported,

  /// The app is not authorized to use Bluetooth.
  unauthorized,

  /// Bluetooth is powered off.
  poweredOff,

  /// Bluetooth is turning on / locating.
  locating,

  /// Bluetooth is on and ready to use.
  ready,
}

/// A platform-agnostic representation of a scanned BLE device.
class LingBluetoothDevice {
  /// MAC address (Android) or UUID (iOS).
  final String id;

  /// Advertised device name.
  final String name;

  /// Received signal strength indicator in dBm.
  final int rssi;

  /// Whether the device is currently connectable.
  final bool isConnectable;

  const LingBluetoothDevice({
    required this.id,
    required this.name,
    required this.rssi,
    required this.isConnectable,
  });

  @override
  String toString() =>
      'LingBluetoothDevice(id: $id, name: $name, rssi: $rssi, isConnectable: $isConnectable)';
}

/// A platform-agnostic representation of a BLE characteristic.
class LingBluetoothCharacteristic {
  /// Characteristic UUID.
  final String uuid;

  /// Supported operations, e.g. `['read', 'write', 'notify']`.
  final List<String> properties;

  const LingBluetoothCharacteristic({
    required this.uuid,
    required this.properties,
  });

  @override
  String toString() =>
      'LingBluetoothCharacteristic(uuid: $uuid, properties: $properties)';
}

/// A platform-agnostic representation of a BLE service.
class LingBluetoothServiceInfo {
  /// Service UUID.
  final String uuid;

  /// Characteristics discovered under this service.
  final List<LingBluetoothCharacteristic> characteristics;

  const LingBluetoothServiceInfo({
    required this.uuid,
    required this.characteristics,
  });

  @override
  String toString() =>
      'LingBluetoothServiceInfo(uuid: $uuid, characteristics: $characteristics)';
}

/// A centralized BLE service wrapping `flutter_blue_plus`.
///
/// Exposes a simplified, project-agnostic API for scanning, connecting,
/// discovering services, reading / writing characteristics and receiving
/// notifications. All operations are logged via [LoggerService] and errors
/// are wrapped in [AppException] subtypes.
class BluetoothService {
  final LoggerService _logger;

  BluetoothService() : _logger = GetIt.instance<LoggerService>();

  // ── Internal state ────────────────────────────────────────────────────
  fbp.BluetoothDevice? _connectedDevice;
  StreamSubscription<fbp.BluetoothAdapterState>? _adapterSub;
  StreamSubscription<fbp.BluetoothConnectionState>? _connectionSub;

  final StreamController<LingBluetoothState> _stateController =
      StreamController<LingBluetoothState>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  final Map<String, StreamController<List<int>>> _notificationControllers = {};

  LingBluetoothState _currentState = LingBluetoothState.unknown;

  // ── Adapter state ─────────────────────────────────────────────────────

  /// A broadcast stream of the current Bluetooth adapter state.
  Stream<LingBluetoothState> get stateStream {
    _ensureAdapterListener();
    return _stateController.stream;
  }

  /// The current (synchronous) adapter state.
  LingBluetoothState get currentState {
    _ensureAdapterListener();
    return _currentState;
  }

  void _ensureAdapterListener() {
    if (_adapterSub != null) return;
    _currentState = _mapAdapterState(fbp.FlutterBluePlus.adapterStateNow);
    _stateController.add(_currentState);
    _adapterSub = fbp.FlutterBluePlus.adapterState.listen((state) {
      _currentState = _mapAdapterState(state);
      _stateController.add(_currentState);
      _logger.d('Bluetooth adapter state: $_currentState');
    });
  }

  LingBluetoothState _mapAdapterState(fbp.BluetoothAdapterState state) {
    switch (state) {
      case fbp.BluetoothAdapterState.unknown:
        return LingBluetoothState.unknown;
      case fbp.BluetoothAdapterState.unavailable:
        return LingBluetoothState.unsupported;
      case fbp.BluetoothAdapterState.unauthorized:
        return LingBluetoothState.unauthorized;
      case fbp.BluetoothAdapterState.turningOn:
        return LingBluetoothState.locating;
      case fbp.BluetoothAdapterState.on:
        return LingBluetoothState.ready;
      case fbp.BluetoothAdapterState.turningOff:
      case fbp.BluetoothAdapterState.off:
        return LingBluetoothState.poweredOff;
    }
  }

  // ── Scanning ──────────────────────────────────────────────────────────

  /// Start scanning for BLE devices.
  ///
  /// Returns a stream that emits the cumulative list of devices found so far.
  /// The stream completes when the scan times out or [stopScan] is called.
  Stream<List<LingBluetoothDevice>> startScan({
    Duration timeout = const Duration(seconds: 10),
    List<String>? withServices,
  }) {
    _logger.i('Starting BLE scan (timeout: $timeout, services: $withServices)');

    final controller = StreamController<List<LingBluetoothDevice>>();

    final sub = fbp.FlutterBluePlus.onScanResults.listen(
      (results) {
        final devices = results.map(_mapScanResult).toList();
        if (!controller.isClosed) controller.add(devices);
      },
      onError: (e, st) {
        _logger.e('BLE scan error', error: e, stackTrace: st);
        if (!controller.isClosed) controller.addError(e, st);
      },
    );

    controller.onCancel = () {
      sub.cancel();
    };

    fbp.FlutterBluePlus.startScan(
      withServices: withServices?.map(fbp.Guid.new).toList() ?? const [],
      timeout: timeout,
    ).then((_) {
      _logger.d('BLE scan started');
    }).catchError((e, st) {
      _logger.e('BLE scan start failed', error: e, stackTrace: st);
      if (!controller.isClosed) controller.addError(e, st);
    });

    // Close the controller when scanning stops.
    fbp.FlutterBluePlus.isScanning
        .where((scanning) => !scanning)
        .first
        .then((_) {
      if (!controller.isClosed) {
        _logger.i('BLE scan complete');
        controller.close();
      }
    });

    return controller.stream;
  }

  /// Stop an in-progress scan.
  Future<void> stopScan() async {
    _logger.d('Stopping BLE scan');
    try {
      await fbp.FlutterBluePlus.stopScan();
    } catch (e, st) {
      _logger.e('Failed to stop BLE scan', error: e, stackTrace: st);
      throw BluetoothException(
          'Failed to stop scan', originalError: e, stackTrace: st);
    }
  }

  LingBluetoothDevice _mapScanResult(fbp.ScanResult result) {
    return LingBluetoothDevice(
      id: result.device.remoteId.str,
      name: result.advertisementData.advName,
      rssi: result.rssi,
      isConnectable: result.advertisementData.connectable,
    );
  }

  // ── Connection ────────────────────────────────────────────────────────

  /// Connect to the device with the given [deviceId] (remoteId / MAC).
  Future<void> connect(String deviceId) async {
    _logger.i('Connecting to BLE device: $deviceId');
    try {
      final device = fbp.BluetoothDevice.fromId(deviceId);
      await device.connect();
      _connectedDevice = device;

      _connectionSub?.cancel();
      _connectionSub = device.connectionState.listen((state) {
        final connected = state == fbp.BluetoothConnectionState.connected;
        if (!connected) {
          _connectedDevice = null;
          _clearNotificationControllers();
        }
        _connectionController.add(connected);
        _logger.d('BLE connection state: $state');
      });

      _connectionController.add(true);
    } catch (e, st) {
      _logger.e('BLE connect failed: $deviceId', error: e, stackTrace: st);
      throw BluetoothException(
        'Failed to connect to device $deviceId',
        originalError: e,
        stackTrace: st,
      );
    }
  }

  /// Disconnect from the currently connected device (no-op if none).
  Future<void> disconnect() async {
    final device = _connectedDevice;
    if (device == null) {
      _logger.d('BLE disconnect called with no connected device');
      return;
    }
    _logger.i('Disconnecting from BLE device: ${device.remoteId}');
    try {
      await device.disconnect();
    } catch (e, st) {
      _logger.e('BLE disconnect failed', error: e, stackTrace: st);
      throw BluetoothException(
        'Failed to disconnect',
        originalError: e,
        stackTrace: st,
      );
    } finally {
      _connectedDevice = null;
      _connectionSub?.cancel();
      _connectionSub = null;
      _clearNotificationControllers();
      _connectionController.add(false);
    }
  }

  /// Whether a device is currently connected.
  bool get isConnected => _connectedDevice?.isConnected ?? false;

  /// A broadcast stream of the connection state (`true` = connected).
  Stream<bool> get connectionStateStream => _connectionController.stream;

  // ── Service discovery ─────────────────────────────────────────────────

  /// Discover all services & characteristics on the connected device.
  Future<List<LingBluetoothServiceInfo>> discoverServices() async {
    final device = _requireConnectedDevice('discoverServices');
    _logger.d('Discovering BLE services for ${device.remoteId}');
    try {
      final services = await device.discoverServices();
      return services.map(_mapService).toList();
    } catch (e, st) {
      _logger.e('BLE discoverServices failed', error: e, stackTrace: st);
      throw BluetoothException(
        'Failed to discover services',
        originalError: e,
        stackTrace: st,
      );
    }
  }

  LingBluetoothServiceInfo _mapService(fbp.BluetoothService service) {
    return LingBluetoothServiceInfo(
      uuid: service.uuid.str,
      characteristics:
          service.characteristics.map(_mapCharacteristic).toList(),
    );
  }

  LingBluetoothCharacteristic _mapCharacteristic(
    fbp.BluetoothCharacteristic c,
  ) {
    final props = <String>[];
    if (c.properties.read) props.add('read');
    if (c.properties.write) props.add('write');
    if (c.properties.writeWithoutResponse) props.add('writeWithoutResponse');
    if (c.properties.notify) props.add('notify');
    if (c.properties.indicate) props.add('indicate');
    return LingBluetoothCharacteristic(uuid: c.uuid.str, properties: props);
  }

  // ── Read / Write / Notify ─────────────────────────────────────────────

  /// Read the value of a characteristic identified by its service & char UUID.
  Future<List<int>> readCharacteristic(
    String serviceUuid,
    String characteristicUuid,
  ) async {
    final c = await _findCharacteristic(serviceUuid, characteristicUuid);
    _logger.d('Reading characteristic $characteristicUuid');
    try {
      return await c.read();
    } catch (e, st) {
      _logger.e('BLE read failed: $characteristicUuid', error: e, stackTrace: st);
      throw BluetoothException(
        'Failed to read characteristic $characteristicUuid',
        originalError: e,
        stackTrace: st,
      );
    }
  }

  /// Write data to a characteristic.
  ///
  /// Set [withoutResponse] to `true` for write-without-response operations.
  Future<void> writeCharacteristic(
    String serviceUuid,
    String characteristicUuid,
    List<int> data, {
    bool withoutResponse = false,
  }) async {
    final c = await _findCharacteristic(serviceUuid, characteristicUuid);
    _logger.d('Writing ${data.length} bytes to $characteristicUuid '
        '(withoutResponse: $withoutResponse)');
    try {
      await c.write(data, withoutResponse: withoutResponse);
    } catch (e, st) {
      _logger.e('BLE write failed: $characteristicUuid', error: e, stackTrace: st);
      throw BluetoothException(
        'Failed to write characteristic $characteristicUuid',
        originalError: e,
        stackTrace: st,
      );
    }
  }

  /// Enable or disable notifications / indications on a characteristic.
  Future<void> setNotification(
    String serviceUuid,
    String characteristicUuid,
    bool enable,
  ) async {
    final c = await _findCharacteristic(serviceUuid, characteristicUuid);
    _logger.d('Setting notification on $characteristicUuid to $enable');
    try {
      await c.setNotifyValue(enable);
    } catch (e, st) {
      _logger.e('BLE setNotification failed: $characteristicUuid', error: e, stackTrace: st);
      throw BluetoothException(
        'Failed to set notification on $characteristicUuid',
        originalError: e,
        stackTrace: st,
      );
    }
  }

  /// A stream of notification values for the given characteristic UUID.
  ///
  /// The stream is lazily created and cached. It remains open until the
  /// device disconnects or [dispose] is called.
  Stream<List<int>> notificationStream(String characteristicUuid) {
    return _notificationControllers.putIfAbsent(
      characteristicUuid,
      () {
        final controller = StreamController<List<int>>.broadcast();
        // Attach a listener to the connected device's characteristic.
        _attachNotificationListener(characteristicUuid, controller);
        return controller;
      },
    ).stream;
  }

  Future<void> _attachNotificationListener(
    String characteristicUuid,
    StreamController<List<int>> controller,
  ) async {
    final device = _connectedDevice;
    if (device == null) {
      _logger.w('Cannot attach notification listener: no connected device');
      return;
    }
    try {
      final services = await device.discoverServices();
      for (final service in services) {
        for (final c in service.characteristics) {
          if (c.uuid.str.toLowerCase() ==
              characteristicUuid.toLowerCase()) {
            c.onValueReceived.listen((value) {
              if (!controller.isClosed) controller.add(value);
            });
            return;
          }
        }
      }
      _logger.w('Characteristic $characteristicUuid not found for notifications');
    } catch (e, st) {
      _logger.e('Failed to attach notification listener', error: e, stackTrace: st);
    }
  }

  // ── MTU ───────────────────────────────────────────────────────────────

  /// Request a larger MTU (Android only, no-op on iOS).
  Future<int> requestMtu(int mtu) async {
    final device = _requireConnectedDevice('requestMtu');
    _logger.d('Requesting MTU: $mtu');
    try {
      return await device.requestMtu(mtu);
    } catch (e, st) {
      _logger.e('BLE requestMtu failed: $mtu', error: e, stackTrace: st);
      throw BluetoothException(
        'Failed to request MTU $mtu',
        originalError: e,
        stackTrace: st,
      );
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  fbp.BluetoothDevice _requireConnectedDevice(String operation) {
    final device = _connectedDevice;
    if (device == null || !device.isConnected) {
      _logger.e('BLE $operation called with no connected device');
      throw const BluetoothException('No device connected');
    }
    return device;
  }

  Future<fbp.BluetoothCharacteristic> _findCharacteristic(
    String serviceUuid,
    String characteristicUuid,
  ) async {
    final device = _requireConnectedDevice('characteristic access');
    try {
      final services = await device.discoverServices();
      for (final service in services) {
        if (service.uuid.str.toLowerCase() != serviceUuid.toLowerCase()) {
          continue;
        }
        for (final c in service.characteristics) {
          if (c.uuid.str.toLowerCase() == characteristicUuid.toLowerCase()) {
            return c;
          }
        }
      }
      throw BluetoothException(
        'Characteristic $characteristicUuid not found in service $serviceUuid',
      );
    } catch (e, st) {
      if (e is BluetoothException) rethrow;
      _logger.e('BLE findCharacteristic failed', error: e, stackTrace: st);
      throw BluetoothException(
        'Failed to find characteristic $characteristicUuid',
        originalError: e,
        stackTrace: st,
      );
    }
  }

  void _clearNotificationControllers() {
    for (final c in _notificationControllers.values) {
      c.close();
    }
    _notificationControllers.clear();
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────

  /// Release all resources. Call when the service is no longer needed.
  Future<void> dispose() async {
    _logger.d('Disposing BluetoothService');
    await stopScan();
    await disconnect();
    await _adapterSub?.cancel();
    _adapterSub = null;
    await _connectionSub?.cancel();
    _connectionSub = null;
    _clearNotificationControllers();
    await _stateController.close();
    await _connectionController.close();
  }
}
