import 'package:flutter/material.dart';

/// A volume control slider with mute toggle and icon.
///
/// Shows a speaker icon that reflects the current volume level,
/// with a horizontal slider for adjustment.
class LingVolumeSlider extends StatefulWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final double maxWidth;
  final bool showIcon;
  final double iconSize;
  final Color? activeColor;
  final Color? iconColor;
  final bool vertical;

  const LingVolumeSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.maxWidth = 200,
    this.showIcon = true,
    this.iconSize = 24,
    this.activeColor,
    this.iconColor,
    this.vertical = false,
  });

  @override
  State<LingVolumeSlider> createState() => _LingVolumeSliderState();
}

class _LingVolumeSliderState extends State<LingVolumeSlider> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
  }

  @override
  void didUpdateWidget(LingVolumeSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _value = widget.value;
    }
  }

  IconData _volumeIcon(double value) {
    if (value <= 0) return Icons.volume_off;
    if (value < 0.33) return Icons.volume_mute;
    if (value < 0.66) return Icons.volume_down;
    return Icons.volume_up;
  }

  void _toggleMute() {
    final newValue = _value > 0 ? 0.0 : 1.0;
    setState(() => _value = newValue);
    widget.onChanged(newValue);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.activeColor ?? theme.colorScheme.primary;
    final iconColor = widget.iconColor ?? theme.colorScheme.onSurfaceVariant;

    if (widget.vertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(_volumeIcon(_value), size: widget.iconSize, color: iconColor),
            onPressed: _toggleMute,
          ),
          SizedBox(
            height: 120,
            child: RotatedBox(
              quarterTurns: 3,
              child: Slider(
                value: _value,
                activeColor: color,
                onChanged: (v) {
                  setState(() => _value = v);
                  widget.onChanged(v);
                },
              ),
            ),
          ),
        ],
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: widget.maxWidth),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showIcon)
            IconButton(
              icon: Icon(_volumeIcon(_value), size: widget.iconSize, color: iconColor),
              onPressed: _toggleMute,
              visualDensity: VisualDensity.compact,
            ),
          Expanded(
            child: Slider(
              value: _value,
              activeColor: color,
              onChanged: (v) {
                setState(() => _value = v);
                widget.onChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}
