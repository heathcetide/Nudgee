import 'package:flutter/material.dart';

import 'package:nudgee/app/theme/app_colors.dart';
import 'package:nudgee/core/core.dart';
import 'package:nudgee/core/widgets/widgets.dart';

// ═══════════════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════════════

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacingSm),
      child: Text(text, style: theme.textTheme.headlineSmall),
    );
  }
}

class StatefulSwitch extends StatefulWidget {
  final String label;
  final String? description;

  const StatefulSwitch({super.key, required this.label, this.description});

  @override
  State<StatefulSwitch> createState() => _StatefulSwitchState();
}

class _StatefulSwitchState extends State<StatefulSwitch> {
  bool _value = false;

  @override
  Widget build(BuildContext context) {
    return LingSwitch(
      value: _value,
      onChanged: (v) => setState(() => _value = v),
      label: widget.label,
      description: widget.description,
    );
  }
}

class StatefulSlider extends StatefulWidget {
  final String label;
  final double min;
  final double max;
  final String Function(double)? valueFormatter;

  const StatefulSlider({super.key, required this.label, required this.min, required this.max, this.valueFormatter});

  @override
  State<StatefulSlider> createState() => _StatefulSliderState();
}

class _StatefulSliderState extends State<StatefulSlider> {
  double _value = 50;

  @override
  Widget build(BuildContext context) {
    return LingSlider(
      value: _value,
      min: widget.min,
      max: widget.max,
      label: widget.label,
      valueFormatter: widget.valueFormatter,
      onChanged: (v) => setState(() => _value = v),
    );
  }
}

class StatefulSegmented extends StatefulWidget {
  @override
  State<StatefulSegmented> createState() => _StatefulSegmentedState();
}

class _StatefulSegmentedState extends State<StatefulSegmented> {
  String _selected = 'audio';

  @override
  Widget build(BuildContext context) {
    return LingSegmentedControl<String>(
      selectedValue: _selected,
      onSelectionChanged: (v) => setState(() => _selected = v),
      segments: const [
        LingSegment(value: 'audio', label: 'Audio', icon: Icons.graphic_eq),
        LingSegment(value: 'video', label: 'Video', icon: Icons.videocam_outlined),
        LingSegment(value: 'screen', label: 'Screen', icon: Icons.screen_share),
      ],
    );
  }
}

class StatefulSkeleton extends StatefulWidget {
  @override
  State<StatefulSkeleton> createState() => _StatefulSkeletonState();
}

class _StatefulSkeletonState extends State<StatefulSkeleton> {
  bool _isLoading = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            LingButton(
              label: _isLoading ? 'Show Content' : 'Show Skeleton',
              icon: _isLoading ? Icons.visibility : Icons.visibility_off,
              onPressed: () => setState(() => _isLoading = !_isLoading),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LingSkeleton(
          isLoading: _isLoading,
          skeleton: const LingSkeletonCard(itemCount: 1),
          child: LingCard(
            title: 'Loaded Card',
            subtitle: 'This content appeared after loading',
            child: const Text('Real content here — the skeleton was shown while this was "loading".'),
          ),
        ),
        const SizedBox(height: 12),
        LingSkeleton(
          isLoading: _isLoading,
          skeleton: const LingSkeletonList(itemCount: 2),
          child: LingListSection(
            title: 'Loaded List',
            children: [
              LingListItem(leadingIcon: Icons.person, title: 'User One', subtitle: 'user1@example.com'),
              LingListItem(leadingIcon: Icons.person, title: 'User Two', subtitle: 'user2@example.com'),
            ],
          ),
        ),
      ],
    );
  }
}

class StatefulDropdown extends StatefulWidget {
  @override
  State<StatefulDropdown> createState() => _StatefulDropdownState();
}

class _StatefulDropdownState extends State<StatefulDropdown> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    return LingDropdown<String>(
      value: _selected,
      label: '音频编码',
      hint: '选择编码格式',
      prefixIcon: Icons.graphic_eq,
      onChanged: (v) => setState(() => _selected = v),
      items: const [
        LingDropdownItem(value: 'opus', label: 'Opus', icon: Icons.graphic_eq),
        LingDropdownItem(value: 'aac', label: 'AAC', icon: Icons.graphic_eq),
        LingDropdownItem(value: 'pcmu', label: 'PCMU', icon: Icons.phone_in_talk),
        LingDropdownItem(value: 'pcma', label: 'PCMA', icon: Icons.phone_in_talk),
      ],
    );
  }
}

class StatefulRating extends StatefulWidget {
  @override
  State<StatefulRating> createState() => _StatefulRatingState();
}

class _StatefulRatingState extends State<StatefulRating> {
  double _rating = 3;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LingRating(
          value: _rating,
          allowHalfRating: true,
          onRatingChanged: (v) => setState(() => _rating = v),
          iconSize: 32,
        ),
        const SizedBox(height: 8),
        LingRating(
          value: 4.5,
          readOnly: true,
          allowHalfRating: true,
          iconSize: 20,
          activeColor: AppColors.secondary,
        ),
      ],
    );
  }
}

class StatefulStepper extends StatefulWidget {
  @override
  State<StatefulStepper> createState() => _StatefulStepperState();
}

class _StatefulStepperState extends State<StatefulStepper> {
  int _value = 1;

  @override
  Widget build(BuildContext context) {
    return LingStepper(
      value: _value,
      min: 1,
      max: 20,
      label: '参与者数量',
      onChanged: (v) => setState(() => _value = v),
    );
  }
}

class StatefulWaveform extends StatefulWidget {
  @override
  State<StatefulWaveform> createState() => _StatefulWaveformState();
}

class _StatefulWaveformState extends State<StatefulWaveform> {
  double _progress = 0.3;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LingWaveform(
          progress: _progress,
          barCount: 50,
          maxHeight: 50,
          animate: true,
        ),
        const SizedBox(height: 12),
        Slider(
          value: _progress,
          onChanged: (v) => setState(() => _progress = v),
        ),
        Text('进度: ${(_progress * 100).round()}%', style: context.theme.textTheme.labelSmall),
      ],
    );
  }
}

class StatefulVolume extends StatefulWidget {
  @override
  State<StatefulVolume> createState() => _StatefulVolumeState();
}

class _StatefulVolumeState extends State<StatefulVolume> {
  double _volume = 0.5;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LingVolumeSlider(
          value: _volume,
          onChanged: (v) => setState(() => _volume = v),
        ),
        const SizedBox(height: 8),
        Text('音量: ${(_volume * 100).round()}%', style: context.theme.textTheme.labelSmall),
      ],
    );
  }
}
