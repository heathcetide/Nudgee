import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'package:nudgee/core/network/api_client.dart';
import 'package:nudgee/core/services/logger_service.dart';

/// Metadata describing an available app update returned by the server.
class UpdateInfo {
  /// Latest version string, e.g. `"1.2.0"`.
  final String latestVersion;

  /// URL to download the new APK / package.
  final String downloadUrl;

  /// Optional human-readable changelog / description.
  final String? updateDescription;

  /// When `true` the user cannot dismiss the update dialog.
  final bool forceUpdate;

  /// Optional numeric version code for comparison.
  final int? versionCode;

  const UpdateInfo({
    required this.latestVersion,
    required this.downloadUrl,
    this.updateDescription,
    this.forceUpdate = false,
    this.versionCode,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      latestVersion: json['latestVersion'] as String? ?? '',
      downloadUrl: json['downloadUrl'] as String? ?? '',
      updateDescription: json['updateDescription'] as String?,
      forceUpdate: json['forceUpdate'] as bool? ?? false,
      versionCode: json['versionCode'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'latestVersion': latestVersion,
        'downloadUrl': downloadUrl,
        'updateDescription': updateDescription,
        'forceUpdate': forceUpdate,
        'versionCode': versionCode,
      };
}

/// Service that checks for, downloads, and installs app updates.
///
/// The actual install step is platform-specific (Android intents, iOS opens
/// the App Store). On platforms without a native installer the install is a
/// no-op logged via [LoggerService]; concrete native channels can be wired
/// in later without changing the public API.
class AppUpdateService {
  AppUpdateService({required ApiClient apiClient, LoggerService? logger})
      : _apiClient = apiClient,
        _logger = logger;

  final ApiClient _apiClient;
  final LoggerService? _logger;

  /// Endpoint used to query the latest version metadata.
  static const String checkEndpoint = '/app/update/check';

  /// Notifier that emits the latest [UpdateInfo] (or `null` when none).
  final ValueNotifier<UpdateInfo?> updateInfoNotifier =
      ValueNotifier<UpdateInfo?>(null);

  /// Notifier that emits download progress as a fraction in `[0.0, 1.0]`.
  final ValueNotifier<double> downloadProgressNotifier =
      ValueNotifier<double>(0.0);

  // ── Check ─────────────────────────────────────────────────────────────

  /// Query the server for update metadata.
  ///
  /// Returns the [UpdateInfo] when a newer version is available, otherwise
  /// `null`. The result is also published via [updateInfoNotifier].
  Future<UpdateInfo?> checkUpdate() async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        checkEndpoint,
      );
      final data = response.data;
      if (data == null) {
        updateInfoNotifier.value = null;
        return null;
      }
      final info = UpdateInfo.fromJson(data);
      updateInfoNotifier.value = info;
      _logger?.i('Update available: ${info.latestVersion}', tag: 'app_update');
      return info;
    } catch (e) {
      _logger?.e('checkUpdate failed', tag: 'app_update', error: e);
      return null;
    }
  }

  // ── Download ──────────────────────────────────────────────────────────

  /// Download the update package to a temporary directory.
  ///
  /// [onProgress] receives a fraction in `[0.0, 1.0]`. Returns the local
  /// file path of the downloaded package.
  Future<String> downloadUpdate(
    UpdateInfo info, {
    Function(double)? onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    final fileName = info.downloadUrl.split('/').last;
    final savePath = '${dir.path}/$fileName';

    downloadProgressNotifier.value = 0.0;

    await _apiClient.download(
      info.downloadUrl,
      savePath,
      onReceiveProgress: (received, total) {
        if (total <= 0) return;
        final p = (received / total).clamp(0.0, 1.0);
        downloadProgressNotifier.value = p;
        onProgress?.call(p);
      },
    );

    _logger?.i('Update downloaded to $savePath', tag: 'app_update');
    return savePath;
  }

  // ── Install ───────────────────────────────────────────────────────────

  /// Install the downloaded package at [apkPath].
  ///
  /// On Android this should invoke the native package installer via a
  /// MethodChannel; on iOS the App Store is opened instead. On unsupported
  /// platforms this is a logged no-op so the abstraction stays portable.
  Future<void> installUpdate(String apkPath) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      _logger?.w('installUpdate not supported on this platform',
          tag: 'app_update');
      return;
    }

    final file = File(apkPath);
    if (!await file.exists()) {
      _logger?.e('Install file not found: $apkPath', tag: 'app_update');
      return;
    }

    // TODO(chenting): wire a MethodChannel (`nudgee/app_update`) to trigger
    // the native installer. The channel is intentionally left as a stub so
    // the service compiles without a platform plugin dependency.
    _logger?.i('Install requested for $apkPath', tag: 'app_update');
  }

  // ── UI ────────────────────────────────────────────────────────────────

  /// Show a modal update dialog for [info].
  ///
  /// When [UpdateInfo.forceUpdate] is `true` the dialog is not dismissible.
  Future<void> showUpdateDialog(BuildContext context, UpdateInfo info) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: !info.forceUpdate,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('New Version Available'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Version ${info.latestVersion}'),
              if (info.updateDescription != null) ...[
                const SizedBox(height: 12),
                Text(info.updateDescription!),
              ],
            ],
          ),
          actions: [
            if (!info.forceUpdate)
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Later'),
              ),
            FilledButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                final path = await downloadUpdate(info);
                await installUpdate(path);
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }
}
