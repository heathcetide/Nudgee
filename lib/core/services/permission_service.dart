import 'package:permission_handler/permission_handler.dart';

import 'package:nudgee/core/errors/app_exception.dart';

/// Centralized permission request service.
///
/// Wraps `permission_handler` with a uniform API and error handling.
/// Each method returns `true` if the permission is granted, `false` otherwise.
class PermissionService {
  PermissionService._();

  /// Request camera permission (needed for video calls).
  static Future<bool> requestCamera() async {
    final status = await Permission.camera.request();
    _checkPermanentlyDenied(Permission.camera, status);
    return status.isGranted || status.isLimited;
  }

  /// Request microphone permission (needed for audio calls).
  static Future<bool> requestMicrophone() async {
    final status = await Permission.microphone.request();
    _checkPermanentlyDenied(Permission.microphone, status);
    return status.isGranted || status.isLimited;
  }

  /// Request camera + microphone together (typical for joining a call).
  static Future<bool> requestMedia() async {
    final results = await [Permission.camera, Permission.microphone].request();
    final cameraGranted = results[Permission.camera]?.isGranted ?? false;
    final micGranted = results[Permission.microphone]?.isGranted ?? false;
    return cameraGranted && micGranted;
  }

  /// Request storage / photos permission (needed for recording/file save).
  static Future<bool> requestStorage() async {
    final status = await Permission.storage.request();
    return status.isGranted;
  }

  /// Request photos / gallery permission (needed for image picking).
  ///
  /// On Android 13+ this maps to the granular photo permission; on older
  /// Android and iOS it falls back to storage / photos access.
  static Future<bool> requestPhotos() async {
    final status = await Permission.photos.request();
    _checkPermanentlyDenied(Permission.photos, status);
    return status.isGranted || status.isLimited;
  }

  /// Request notification permission.
  static Future<bool> requestNotifications() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Request location permission.
  static Future<bool> requestLocation() async {
    final status = await Permission.location.request();
    _checkPermanentlyDenied(Permission.location, status);
    return status.isGranted || status.isLimited;
  }

  /// Request Bluetooth permissions.
  ///
  /// On Android 12+ this requests both [Permission.bluetoothScan] and
  /// [Permission.bluetoothConnect]. On older Android / iOS these permissions
  /// are not required and the method returns `true`.
  static Future<bool> requestBluetooth() async {
    // Android 12+ requires runtime BLE permissions.
    final permissions = <Permission>[
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ];

    final results = await permissions.request();

    final scanGranted = results[Permission.bluetoothScan]?.isGranted ?? true;
    final connectGranted =
        results[Permission.bluetoothConnect]?.isGranted ?? true;

    for (final entry in results.entries) {
      if (entry.value.isPermanentlyDenied) {
        throw PermissionException(entry.key.toString());
      }
    }

    return scanGranted && connectGranted;
  }

  /// Check the current status of a permission without requesting.
  static Future<PermissionStatus> check(Permission permission) => permission.status;

  /// Whether a permission is permanently denied (user must open system settings).
  static Future<bool> isPermanentlyDenied(Permission permission) async {
    final status = await permission.status;
    return status.isPermanentlyDenied;
  }

  /// Open the app's system settings page.
  static Future<void> openSettings() => openAppSettings();

  // ── Request + Execute pattern ────────────────────────────────────────

  /// Request a permission and execute [action] if granted.
  ///
  /// Returns `true` if the action was executed, `false` if permission was denied.
  /// ```dart
  /// await PermissionService.requestAndDo(
  ///   Permission.camera,
  ///   action: () => startCamera(),
  /// );
  /// ```
  static Future<bool> requestAndDo(
    Permission permission, {
    required Future<void> Function() action,
  }) async {
    final granted = await _requestSingle(permission);
    if (granted) {
      await action();
      return true;
    }
    return false;
  }

  /// Request camera permission and execute [action] if granted.
  static Future<bool> requestCameraAndDo(Future<void> Function() action) {
    return requestAndDo(Permission.camera, action: action);
  }

  /// Request microphone permission and execute [action] if granted.
  static Future<bool> requestMicrophoneAndDo(Future<void> Function() action) {
    return requestAndDo(Permission.microphone, action: action);
  }

  /// Request camera + microphone and execute [action] if both granted.
  static Future<bool> requestMediaAndDo(Future<void> Function() action) async {
    final granted = await requestMedia();
    if (granted) {
      await action();
      return true;
    }
    return false;
  }

  /// Request storage permission and execute [action] if granted.
  static Future<bool> requestStorageAndDo(Future<void> Function() action) {
    return requestAndDo(Permission.storage, action: action);
  }

  /// Request photos permission and execute [action] if granted.
  static Future<bool> requestPhotosAndDo(Future<void> Function() action) {
    return requestAndDo(Permission.photos, action: action);
  }

  /// Request location permission and execute [action] if granted.
  static Future<bool> requestLocationAndDo(Future<void> Function() action) {
    return requestAndDo(Permission.location, action: action);
  }

  /// Request Bluetooth permissions and execute [action] if granted.
  ///
  /// On Android 12+ both `bluetoothScan` and `bluetoothConnect` are requested.
  static Future<bool> requestBluetoothAndDo(Future<void> Function() action) async {
    final granted = await requestBluetooth();
    if (granted) {
      await action();
      return true;
    }
    return false;
  }

  /// Request multiple permissions at once.
  static Future<Map<Permission, PermissionStatus>> requestMultiple(
    List<Permission> permissions,
  ) async {
    return await permissions.request();
  }

  /// Check all permissions and return their statuses.
  static Future<Map<Permission, PermissionStatus>> checkAll(
    List<Permission> permissions,
  ) async {
    final result = <Permission, PermissionStatus>{};
    for (final p in permissions) {
      result[p] = await p.status;
    }
    return result;
  }

  // ── Private ──────────────────────────────────────────────────────────

  static Future<bool> _requestSingle(Permission permission) async {
    final status = await permission.request();
    _checkPermanentlyDenied(permission, status);
    return status.isGranted || status.isLimited;
  }

  static void _checkPermanentlyDenied(Permission permission, PermissionStatus status) {
    if (status.isPermanentlyDenied) {
      throw PermissionException(permission.toString());
    }
  }
}
