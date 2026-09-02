import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import 'package:nudgee/app/theme/app_colors.dart';
import 'package:nudgee/core/constants/app_constants.dart';
import 'package:nudgee/core/di/injector.dart';
import 'package:nudgee/core/services/auth_service.dart';
import 'package:nudgee/core/services/file_storage_service.dart';
import 'package:nudgee/core/services/qiniu_storage_service.dart';
import 'package:nudgee/core/services/shared_prefs_service.dart';
import 'package:nudgee/core/widgets/im/ling_chat_background.dart';
import 'package:nudgee/features/common/utils/functions.dart';

/// A wallpaper entry (preset color/gradient or custom uploaded image).
class LingWallpaperEntry {
  final LingChatBackgroundType type;
  final Color? color;
  final LinearGradient? gradient;
  final String? imageUrl; // for custom image type

  /// Whether this is a built-in preset (cannot be deleted).
  final bool isPreset;

  const LingWallpaperEntry({
    required this.type,
    this.color,
    this.gradient,
    this.imageUrl,
    this.isPreset = false,
  });

  Map<String, dynamic> toJson() => {
        'type': type.index,
        'color': color?.value,
        'gradient': gradient != null
            ? {
                'begin': gradient!.begin.toString(),
                'end': gradient!.end.toString(),
                'colors': gradient!.colors.map((c) => c.value).toList(),
              }
            : null,
        'imageUrl': imageUrl,
        'isPreset': isPreset,
      };

  factory LingWallpaperEntry.fromJson(Map<String, dynamic> json) {
    return LingWallpaperEntry(
      type: LingChatBackgroundType.values[(json['type'] as int).clamp(0, 2)],
      color: json['color'] != null ? Color(json['color'] as int) : null,
      imageUrl: json['imageUrl'] as String?,
      isPreset: json['isPreset'] as bool? ?? false,
    );
  }
}

/// Built-in preset wallpapers (cannot be deleted).
/// The first entry (index 0) uses null color to follow the theme surface.
const List<LingWallpaperEntry> lingWallpaperPresets = [
  LingWallpaperEntry(type: LingChatBackgroundType.color, color: null, isPreset: true),
  LingWallpaperEntry(type: LingChatBackgroundType.color, color: Color(0xFFFFFFFF), isPreset: true),
  LingWallpaperEntry(type: LingChatBackgroundType.color, color: Color(0xFFF8FAFC), isPreset: true),
  LingWallpaperEntry(type: LingChatBackgroundType.color, color: Color(0xFFE0F2FE), isPreset: true),
  LingWallpaperEntry(type: LingChatBackgroundType.color, color: Color(0xFFFCE7F3), isPreset: true),
  LingWallpaperEntry(type: LingChatBackgroundType.color, color: Color(0xFFDCFCE7), isPreset: true),
  LingWallpaperEntry(type: LingChatBackgroundType.color, color: Color(0xFFFEF3C7), isPreset: true),
  LingWallpaperEntry(
    type: LingChatBackgroundType.gradient,
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF4F6BED), Color(0xFF7B93F5)],
    ),
    isPreset: true,
  ),
  LingWallpaperEntry(
    type: LingChatBackgroundType.gradient,
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF14B8A6), Color(0xFF22C55E)],
    ),
    isPreset: true,
  ),
  LingWallpaperEntry(
    type: LingChatBackgroundType.gradient,
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
    ),
    isPreset: true,
  ),
  LingWallpaperEntry(
    type: LingChatBackgroundType.gradient,
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
    ),
    isPreset: true,
  ),
  LingWallpaperEntry(
    type: LingChatBackgroundType.gradient,
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
    ),
    isPreset: true,
  ),
  LingWallpaperEntry(
    type: LingChatBackgroundType.gradient,
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
    ),
    isPreset: true,
  ),
];

/// SharedPreferences key for persisting custom wallpaper entries.
const String _customWallpapersKey = 'custom_chat_wallpapers';

/// Maximum total wallpapers (presets + custom).
const int maxWallpapers = 30;

/// Load custom wallpaper entries from SharedPreferences.
Future<List<LingWallpaperEntry>> loadCustomWallpapers() async {
  final prefs = sl<SharedPrefsService>();
  final json = prefs.getString(_customWallpapersKey);
  if (json == null) return [];
  try {
    final list = jsonDecode(json) as List;
    return list
        .map((e) => LingWallpaperEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
}

/// Save custom wallpaper entries to SharedPreferences.
Future<void> saveCustomWallpapers(List<LingWallpaperEntry> entries) async {
  final prefs = sl<SharedPrefsService>();
  final json = jsonEncode(entries.map((e) => e.toJson()).toList());
  prefs.setString(_customWallpapersKey, json);
}

/// A wallpaper management page for chat backgrounds.
///
/// Displays all wallpapers (presets + custom uploaded) in a grid.
/// - Tap to select a wallpaper.
/// - Long press a custom image to delete it.
/// - Upload button to add new custom images (stored in cloud + local).
/// - Maximum 30 total wallpapers.
class LingWallpaperPicker extends StatefulWidget {
  /// The currently selected background type.
  final LingChatBackgroundType selectedType;

  /// The currently selected entry index in the combined list.
  final int selectedIndex;

  /// The currently selected custom image URL (if any).
  final String? selectedImageUrl;

  /// Called when a wallpaper is selected.
  final void Function(LingWallpaperEntry entry) onSelected;

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
    this.selectedImageUrl,
    this.title = '聊天壁纸',
  });

  @override
  State<LingWallpaperPicker> createState() => _LingWallpaperPickerState();
}

class _LingWallpaperPickerState extends State<LingWallpaperPicker> {
  List<LingWallpaperEntry> _customEntries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomWallpapers();
  }

  Future<void> _loadCustomWallpapers() async {
    final customs = await loadCustomWallpapers();
    if (mounted) {
      setState(() {
        _customEntries = customs;
        _loading = false;
      });
    }
  }

  List<LingWallpaperEntry> get _allEntries => [
        ...lingWallpaperPresets,
        ..._customEntries,
      ];

  int get _remainingSlots => maxWallpapers - _allEntries.length;

  Future<void> _pickAndUploadImage() async {
    if (_remainingSlots <= 0) {
      SmartDialog.showNotify(
        msg: '最多 $maxWallpapers 个背景，请先删除一些',
        notifyType: NotifyType.warning,
      );
      return;
    }

    try {
      final result = await AssetPicker.pickAssets(
        context,
        pickerConfig: const AssetPickerConfig(
          maxAssets: 1,
          requestType: RequestType.image,
        ),
      );
      if (result == null || result.isEmpty) return;
      if (!mounted) return;

      SmartDialog.showLoading(msg: '正在处理图片...');

      final asset = result[0];
      final bytes = await asset.originBytes;
      if (bytes == null) {
        SmartDialog.dismiss();
        SmartDialog.showNotify(msg: '图片读取失败', notifyType: NotifyType.error);
        return;
      }

      // Compress for chat background.
      final compressed = await getCompressedImage(
        bytes,
        minHeight: 1920,
        minWidth: 1080,
        quality: 85,
      );

      // ── 1. Upload to Qiniu (cloud object storage) ──
      SmartDialog.showLoading(msg: '正在上传到云端...');
      final auth = sl<AuthService>();
      final user = auth.currentUser.value;
      final qiniu = sl<QiniuStorageService>();
      final fileStorage = sl<FileStorageService>();

      String? cloudUrl;
      if (user != null && qiniu.isConfigured) {
        final bgKey =
            'nudgee/${user.id}/chat_bg/${DateTime.now().millisecondsSinceEpoch}.jpg';
        cloudUrl = await qiniu.uploadBytes(bgKey, compressed);
      }

      // ── 2. Save to local file system ──
      final fileName =
          'bg_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final localPath = await fileStorage.saveBytes(
        FileStorageService.dirChatBg,
        fileName,
        compressed,
      );

      SmartDialog.dismiss();

      if (localPath == null && cloudUrl == null) {
        SmartDialog.showNotify(msg: '背景保存失败', notifyType: NotifyType.error);
        return;
      }

      // Prefer local path for instant display; fall back to cloud URL.
      final imageUrl = localPath ?? cloudUrl;

      // Add to custom entries and persist.
      final newEntry = LingWallpaperEntry(
        type: LingChatBackgroundType.image,
        imageUrl: imageUrl,
        isPreset: false,
      );
      final updated = [..._customEntries, newEntry];
      await saveCustomWallpapers(updated);

      if (!mounted) return;
      setState(() {
        _customEntries = updated;
      });

      // Auto-select the newly added background.
      widget.onSelected(newEntry);
      SmartDialog.showNotify(msg: '背景添加成功', notifyType: NotifyType.success);
    } catch (e, st) {
      debugPrint('[WallpaperPicker] upload error: $e\n$st');
      SmartDialog.dismiss();
      SmartDialog.showNotify(msg: '上传失败: $e', notifyType: NotifyType.error);
    }
  }

  Future<void> _deleteCustomWallpaper(int index) async {
    final entry = _allEntries[index];
    if (entry.isPreset) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除背景'),
        content: const Text('确定要删除这个自定义背景吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // Remove from custom entries.
    final customIndex = index - lingWallpaperPresets.length;
    final updated = List<LingWallpaperEntry>.from(_customEntries);
    final removed = updated.removeAt(customIndex);
    await saveCustomWallpapers(updated);

    // Delete local file if it's a local path.
    if (removed.imageUrl != null && !removed.imageUrl!.startsWith('http')) {
      try {
        final file = File(removed.imageUrl!);
        if (file.existsSync()) await file.delete();
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _customEntries = updated;
    });
    SmartDialog.showNotify(msg: '已删除', notifyType: NotifyType.success);
  }

  bool _isSelected(int index) {
    final entry = _allEntries[index];
    if (entry.type != widget.selectedType) return false;
    if (entry.type == LingChatBackgroundType.image) {
      return entry.imageUrl == widget.selectedImageUrl;
    }
    return index == widget.selectedIndex;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allEntries = _allEntries;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: theme.colorScheme.surface,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${allEntries.length}/$maxWallpapers',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Upload button
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppConstants.spacingMd,
                    AppConstants.spacingMd,
                    AppConstants.spacingMd,
                    AppConstants.spacingSm,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed:
                          _remainingSlots > 0 ? _pickAndUploadImage : null,
                      icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                      label: Text(
                        _remainingSlots > 0
                            ? '上传自定义背景'
                            : '已达上限 $maxWallpapers 个',
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppConstants.spacingSm + 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusLg,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Wallpaper grid
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacingMd,
                      vertical: AppConstants.spacingSm,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: AppConstants.spacingSm,
                      crossAxisSpacing: AppConstants.spacingSm,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: allEntries.length,
                    itemBuilder: (context, index) {
                      final entry = allEntries[index];
                      final isSelected = _isSelected(index);
                      return _WallpaperTile(
                        entry: entry,
                        isSelected: isSelected,
                        onTap: () {
                          widget.onSelected(entry);
                          Navigator.pop(context);
                        },
                        onLongPress: entry.isPreset
                            ? null
                            : () => _deleteCustomWallpaper(index),
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
                        onPressed: () {
                          widget.onReset();
                          Navigator.pop(context);
                        },
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
  final LingWallpaperEntry entry;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _WallpaperTile({
    required this.entry,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget content;
    if (entry.type == LingChatBackgroundType.image && entry.imageUrl != null) {
      // Custom image background
      if (entry.imageUrl!.startsWith('http')) {
        content = CachedNetworkImage(
          imageUrl: entry.imageUrl!,
          fit: BoxFit.cover,
          memCacheWidth: 200,
          memCacheHeight: 200,
          errorWidget: (_, __, ___) => Container(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Icon(Icons.broken_image, color: theme.colorScheme.outline),
          ),
        );
      } else {
        content = Image.file(
          File(entry.imageUrl!),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => Container(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Icon(Icons.broken_image, color: theme.colorScheme.outline),
          ),
        );
      }
    } else if (entry.type == LingChatBackgroundType.color) {
      content = Container(
        color: entry.color ?? theme.colorScheme.surface,
      );
    } else {
      content = Container(decoration: BoxDecoration(gradient: entry.gradient));
    }

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : theme.dividerColor,
                  width: isSelected ? 2.5 : 1,
                ),
              ),
              child: content,
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
          // Delete indicator for custom (non-preset) entries
          if (onLongPress != null)
            Positioned(
              top: AppConstants.spacingXs,
              left: AppConstants.spacingXs,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_outline,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
