import 'package:flutter/material.dart';

import 'package:nudgee/core/services/bluetooth_service.dart';

/// A compact Bluetooth status indicator.
///
/// Displays an icon and a short label describing the current adapter state.
/// Tapping the widget invokes [onTap] — typically used to open Bluetooth
/// settings or request permissions.
class LingBluetoothStatus extends StatelessWidget {
  /// The current Bluetooth adapter state.
  final LingBluetoothState state;

  /// Called when the widget is tapped.
  final VoidCallback? onTap;

  const LingBluetoothStatus({
    super.key,
    required this.state,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _color(theme);
    final icon = _icon;
    final label = _label;

    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: content,
      );
    }
    return content;
  }

  IconData get _icon {
    switch (state) {
      case LingBluetoothState.ready:
        return Icons.bluetooth;
      case LingBluetoothState.locating:
        return Icons.bluetooth_searching;
      case LingBluetoothState.poweredOff:
        return Icons.bluetooth_disabled;
      case LingBluetoothState.unauthorized:
        return Icons.lock_outline;
      case LingBluetoothState.unsupported:
        return Icons.bluetooth_audio_outlined;
      case LingBluetoothState.unknown:
        return Icons.help_outline;
    }
  }

  String get _label {
    switch (state) {
      case LingBluetoothState.ready:
        return '已就绪';
      case LingBluetoothState.locating:
        return '正在搜索';
      case LingBluetoothState.poweredOff:
        return '未开启';
      case LingBluetoothState.unauthorized:
        return '未授权';
      case LingBluetoothState.unsupported:
        return '不支持';
      case LingBluetoothState.unknown:
        return '未知';
    }
  }

  Color _color(ThemeData theme) {
    switch (state) {
      case LingBluetoothState.ready:
        return Colors.blue;
      case LingBluetoothState.locating:
        return Colors.orange;
      case LingBluetoothState.poweredOff:
        return theme.colorScheme.outline;
      case LingBluetoothState.unauthorized:
        return Colors.deepOrange;
      case LingBluetoothState.unsupported:
        return theme.colorScheme.error;
      case LingBluetoothState.unknown:
        return theme.colorScheme.outline;
    }
  }
}
