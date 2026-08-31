import 'package:flutter/material.dart';

import 'package:nudgee/core/services/bluetooth_service.dart';

/// A scrollable list of scanned BLE devices.
///
/// Each row shows the device name, MAC / UUID, RSSI signal strength and a
/// connect button. The currently connected device is highlighted. Pull-to-
/// refresh triggers [onRefresh], and a scan-start button is shown while not
/// scanning.
class LingBluetoothDeviceList extends StatelessWidget {
  /// The list of scanned devices to display.
  final List<LingBluetoothDevice> devices;

  /// The remote id of the currently connected device, if any.
  final String? connectedDeviceId;

  /// Whether a scan is currently in progress.
  final bool isScanning;

  /// The id of the device currently being connected to (shows a spinner).
  final String? connectingDeviceId;

  /// Called when a device row is tapped.
  final ValueChanged<LingBluetoothDevice>? onDeviceTap;

  /// Called when the user pulls to refresh.
  final Future<void> Function()? onRefresh;

  /// Called when the user taps the "start scan" button.
  final VoidCallback? onScanStart;

  const LingBluetoothDeviceList({
    super.key,
    required this.devices,
    this.connectedDeviceId,
    this.isScanning = false,
    this.connectingDeviceId,
    this.onDeviceTap,
    this.onRefresh,
    this.onScanStart,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: onRefresh ?? () async {},
      child: Column(
        children: [
          _buildHeader(theme),
          Expanded(
            child: devices.isEmpty
                ? _buildEmptyState(theme)
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: devices.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final device = devices[index];
                      final isConnected = connectedDeviceId == device.id;
                      final isConnecting = connectingDeviceId == device.id;
                      return _DeviceTile(
                        device: device,
                        isConnected: isConnected,
                        isConnecting: isConnecting,
                        onTap: onDeviceTap != null
                            ? () => onDeviceTap!(device)
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            '发现设备 (${devices.length})',
            style: theme.textTheme.titleSmall,
          ),
          const Spacer(),
          if (isScanning)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            TextButton.icon(
              onPressed: onScanStart,
              icon: const Icon(Icons.search, size: 18),
              label: const Text('扫描'),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Icon(Icons.bluetooth_searching,
            size: 64, color: theme.colorScheme.outline),
        const SizedBox(height: 16),
        Center(
          child: Text(
            isScanning ? '正在搜索设备…' : '未发现设备，下拉刷新或点击扫描',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _DeviceTile extends StatelessWidget {
  final LingBluetoothDevice device;
  final bool isConnected;
  final bool isConnecting;
  final VoidCallback? onTap;

  const _DeviceTile({
    required this.device,
    required this.isConnected,
    required this.isConnecting,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = isConnected
        ? theme.colorScheme.primaryContainer.withOpacity(0.3)
        : Colors.transparent;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: bgColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.bluetooth,
              color: isConnected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name.isEmpty ? '未知设备' : device.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight:
                          isConnected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    device.id,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            _rssiBadge(theme),
            const SizedBox(width: 8),
            _connectButton(theme),
          ],
        ),
      ),
    );
  }

  Widget _rssiBadge(ThemeData theme) {
    final color = _rssiColor;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.signal_cellular_alt, size: 14, color: color),
        const SizedBox(width: 2),
        Text(
          '${device.rssi} dBm',
          style: theme.textTheme.labelSmall?.copyWith(color: color),
        ),
      ],
    );
  }

  Color get _rssiColor {
    if (device.rssi >= -50) return Colors.green;
    if (device.rssi >= -70) return Colors.lightGreen;
    if (device.rssi >= -90) return Colors.orange;
    return Colors.red;
  }

  Widget _connectButton(ThemeData theme) {
    if (isConnecting) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (isConnected) {
      return Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 24);
    }
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: const Text('连接'),
    );
  }
}
