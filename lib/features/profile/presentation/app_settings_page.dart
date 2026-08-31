import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

import 'package:nudgee/app/theme/locale_controller.dart';
import 'package:nudgee/app/theme/theme_controller.dart';
import 'package:nudgee/core/di/injector.dart';
import 'package:nudgee/core/extensions/context_extensions.dart';
import 'package:nudgee/core/services/file_storage_service.dart';
import 'package:nudgee/features/common/widgets/page_scaffold.dart';


/// App settings page.
///
/// Sections:
/// - 主题: light / dark / system
/// - 语言: 中文 / English / 跟随系统
/// - 存储管理: 查看缓存大小、清理缓存
/// - 关于: 版本号
class AppSettingsPage extends ConsumerStatefulWidget {
  const AppSettingsPage({super.key});

  @override
  ConsumerState<AppSettingsPage> createState() => _AppSettingsPageState();
}

class _AppSettingsPageState extends ConsumerState<AppSettingsPage> {
  Map<String, int> _storageSizes = {};
  int _totalSize = 0;

  @override
  void initState() {
    super.initState();
    _loadStorageInfo();
  }

  Future<void> _loadStorageInfo() async {
    try {
      final fileStorage = sl<FileStorageService>();
      final sizes = await fileStorage.categorySizes();
      final total = await fileStorage.totalSize();
      if (mounted) {
        setState(() {
          _storageSizes = sizes;
          _totalSize = total;
        });
      }
    } catch (e) {
      debugPrint('[Settings] load storage info error: $e');
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.settingsClearCache),
        content: Text(context.l10n.settingsClearCacheConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    SmartDialog.showLoading(msg: context.l10n.settingsClearing);
    try {
      final fileStorage = sl<FileStorageService>();
      // Clear all cache categories (avatars + cache + logs), keep downloads.
      int freed = 0;
      freed += await fileStorage.clearCategory(FileStorageService.dirAvatars);
      freed += await fileStorage.clearCategory(FileStorageService.dirCache);
      freed += await fileStorage.clearCategory(FileStorageService.dirLogs);
      await _loadStorageInfo();
      SmartDialog.dismiss();
      SmartDialog.showNotify(
        msg: '${context.l10n.settingsClearSuccess} (${_formatSize(freed)})',
        notifyType: NotifyType.success,
      );
    } catch (e) {
      SmartDialog.dismiss();
      SmartDialog.showNotify(msg: context.l10n.settingsClearFailedWithError(e.toString()), notifyType: NotifyType.failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeControllerProvider);
    final locale = ref.watch(localeControllerProvider);

    return PageScaffold(
      title: Text(context.l10n.settingsTitle),
      leading: getPopLeading(context),
      child: ListView(
        children: [
          // ── 主题 ──────────────────────────────────────────────────────
          _SectionHeader(title: context.l10n.settingsTheme),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                RadioListTile<ThemeMode>(
                  title: Text(context.l10n.settingsThemeLight),
                  value: ThemeMode.light,
                  groupValue: themeMode,
                  onChanged: (v) =>
                      ref.read(themeControllerProvider.notifier).setMode(v!),
                ),
                RadioListTile<ThemeMode>(
                  title: Text(context.l10n.settingsThemeDark),
                  value: ThemeMode.dark,
                  groupValue: themeMode,
                  onChanged: (v) =>
                      ref.read(themeControllerProvider.notifier).setMode(v!),
                ),
                RadioListTile<ThemeMode>(
                  title: Text(context.l10n.settingsThemeSystem),
                  value: ThemeMode.system,
                  groupValue: themeMode,
                  onChanged: (v) =>
                      ref.read(themeControllerProvider.notifier).setMode(v!),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── 语言 ──────────────────────────────────────────────────────
          _SectionHeader(title: context.l10n.settingsLanguage),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                RadioListTile<String>(
                  title: Text(context.l10n.settingsLangZh),
                  value: 'zh',
                  groupValue: locale?.languageCode ?? 'system',
                  onChanged: (v) {
                    if (v == null) return;
                    if (v == 'system') {
                      ref.read(localeControllerProvider.notifier).followSystem();
                    } else {
                      ref.read(localeControllerProvider.notifier).setLocale(Locale(v));
                    }
                  },
                ),
                RadioListTile<String>(
                  title: Text(context.l10n.settingsLangEn),
                  value: 'en',
                  groupValue: locale?.languageCode ?? 'system',
                  onChanged: (v) {
                    if (v == null) return;
                    ref.read(localeControllerProvider.notifier).setLocale(Locale(v));
                  },
                ),
                RadioListTile<String>(
                  title: Text(context.l10n.settingsLangSystem),
                  value: 'system',
                  groupValue: locale?.languageCode ?? 'system',
                  onChanged: (v) {
                    ref.read(localeControllerProvider.notifier).followSystem();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── 存储管理 ──────────────────────────────────────────────────
          _SectionHeader(title: context.l10n.settingsStorage),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: ListTile.divideTiles(
                context: context,
                tiles: [
                  ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(context.l10n.settingsTotalSpace),
                    trailing: Text(_formatSize(_totalSize),
                        style: theme.textTheme.bodyMedium),
                  ),
                  ListTile(
                    leading: const Icon(Icons.image_outlined),
                    title: Text(context.l10n.settingsAvatarCache),
                    trailing: Text(
                        _formatSize(_storageSizes[FileStorageService.dirAvatars] ?? 0),
                        style: theme.textTheme.bodyMedium),
                  ),
                  ListTile(
                    leading: const Icon(Icons.cached_outlined),
                    title: Text(context.l10n.settingsGeneralCache),
                    trailing: Text(
                        _formatSize(_storageSizes[FileStorageService.dirCache] ?? 0),
                        style: theme.textTheme.bodyMedium),
                  ),
                  ListTile(
                    leading: const Icon(Icons.download_outlined),
                    title: Text(context.l10n.settingsDownloads),
                    trailing: Text(
                        _formatSize(_storageSizes[FileStorageService.dirDownloads] ?? 0),
                        style: theme.textTheme.bodyMedium),
                  ),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: Text(context.l10n.settingsLogs),
                    trailing: Text(
                        _formatSize(_storageSizes[FileStorageService.dirLogs] ?? 0),
                        style: theme.textTheme.bodyMedium),
                  ),
                  ListTile(
                    leading: Icon(Icons.cleaning_services_outlined,
                        color: theme.colorScheme.error),
                    title: Text(context.l10n.settingsClearCache,
                        style: TextStyle(color: theme.colorScheme.error)),
                    onTap: _clearCache,
                  ),
                ],
              ).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // ── 关于 ──────────────────────────────────────────────────────
          _SectionHeader(title: context.l10n.settingsAbout),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: ListTile.divideTiles(
                context: context,
                tiles: [
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: Text(context.l10n.settingsVersion),
                    trailing: Text('1.0.0', style: theme.textTheme.bodyMedium),
                  ),
                  ListTile(
                    leading: const Icon(Icons.phone_android_outlined),
                    title: Text(context.l10n.settingsPlatform),
                    trailing: Text(Platform.isAndroid ? 'Android' : 'iOS',
                        style: theme.textTheme.bodyMedium),
                  ),
                ],
              ).toList(),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

/// Section header with a small label.
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, top: 8, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).hintColor,
        ),
      ),
    );
  }
}
