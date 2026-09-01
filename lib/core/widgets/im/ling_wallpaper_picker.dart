import 'package:flutter/material.dart';

import 'package:nudgee/app/theme/app_colors.dart';
import 'package:nudgee/core/constants/app_constants.dart';
import 'package:nudgee/core/widgets/im/ling_chat_background.dart';

/// A wallpaper preset (color or gradient).
class LingWallpaperPreset {
  final LingChatBackgroundType type;
  final Color? color;
  final LinearGradient? gradient;

  const LingWallpaperPreset({
    required this.type,
    this.color,
    this.gradient,
  });
}

/// All available wallpaper presets.
const List<LingWallpaperPreset> lingWallpaperPresets = [
  LingWallpaperPreset(type: LingChatBackgroundType.color, color: Color(0xFFFFFFFF)),
  LingWallpaperPreset(type: LingChatBackgroundType.color, color: Color(0xFFF8FAFC)),
  LingWallpaperPreset(type: LingChatBackgroundType.color, color: Color(0xFFE0F2FE)),
  LingWallpaperPreset(type: LingChatBackgroundType.color, color: Color(0xFFFCE7F3)),
  LingWallpaperPreset(type: LingChatBackgroundType.color, color: Color(0xFFDCFCE7)),
  LingWallpaperPreset(type: LingChatBackgroundType.color, color: Color(0xFFFEF3C7)),
  LingWallpaperPreset(
    type: LingChatBackgroundType.gradient,
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF4F6BED), Color(0xFF7B93F5)],
    ),
  ),
  LingWallpaperPreset(
    type: LingChatBackgroundType.gradient,
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF14B8A6), Color(0xFF22C55E)],
    ),
  ),
  LingWallpaperPreset(
    type: LingChatBackgroundType.gradient,
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
    ),
  ),
  LingWallpaperPreset(
    type: LingChatBackgroundType.gradient,
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
    ),
  ),
  LingWallpaperPreset(
    type: LingChatBackgroundType.gradient,
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
    ),
  ),
  LingWallpaperPreset(
    type: LingChatBackgroundType.gradient,
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
    ),
  ),
];

/// A wallpaper selection page for chat backgrounds.
///
/// Displays preset wallpapers in a grid. Each preset is either a solid
/// color or a linear gradient. The currently selected preset is
/// highlighted with a check mark. A "恢复默认" button is shown at the
/// bottom.
class LingWallpaperPicker extends StatelessWidget {
  /// The currently selected background type.
  final LingChatBackgroundType selectedType;

  /// The index of the currently selected preset.
  final int selectedIndex;

  /// Called when a preset is selected.
  final void Function(int index, LingChatBackgroundType type) onSelected;

  /// Called when the "恢复默认" button is tapped.
  final VoidCallback onReset;

  /// Title shown in the app bar. Defaults to "聊天壁纸".
  final String title;

  const LingWallpaperPicker({
    super.key,
    required this.selectedType,
    required this.selectedIndex,
    required this.onSelected,
    required this.onReset,
    this.title = '聊天壁纸',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: theme.colorScheme.surface,
      ),
      body: Column(
        children: [
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(AppConstants.spacingMd),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: AppConstants.spacingSm,
                crossAxisSpacing: AppConstants.spacingSm,
                childAspectRatio: 0.75,
              ),
              itemCount: lingWallpaperPresets.length,
              itemBuilder: (context, index) {
                final preset = lingWallpaperPresets[index];
                final isSelected = index == selectedIndex &&
                    preset.type == selectedType;
                return _WallpaperTile(
                  preset: preset,
                  isSelected: isSelected,
                  onTap: () => onSelected(index, preset.type),
                );
              },
            ),
          ),
          // Reset button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spacingMd),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('恢复默认'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppConstants.spacingSm + 2,
                    ),
                    side: BorderSide(color: theme.dividerColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusLg,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WallpaperTile extends StatelessWidget {
  final LingWallpaperPreset preset;
  final bool isSelected;
  final VoidCallback onTap;

  const _WallpaperTile({
    required this.preset,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: preset.type == LingChatBackgroundType.color
                  ? preset.color
                  : null,
              gradient: preset.type == LingChatBackgroundType.gradient
                  ? preset.gradient
                  : null,
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : theme.dividerColor,
                width: isSelected ? 2.5 : 1,
              ),
            ),
          ),
          if (isSelected)
            Positioned(
              top: AppConstants.spacingXs,
              right: AppConstants.spacingXs,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
