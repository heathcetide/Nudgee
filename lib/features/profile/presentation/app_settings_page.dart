import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

import 'package:nudgee/app/theme/locale_controller.dart';
import 'package:nudgee/app/theme/theme_controller.dart';
import 'package:nudgee/core/di/injector.dart';
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
        title: const Text('清理缓存'),
        content: const Text('确定要清理所有缓存文件吗？\n（不会清除用户数据和登录信息）'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    SmartDialog.showLoading(msg: '清理中...');
    try {
      final fileStorage = sl<FileStorageService>();
      await fileStorage.clearCategory(FileStorageService.dirCache);
      await _loadStorageInfo();
      SmartDialog.dismiss();
      SmartDialog.showNotify(msg: '清理成功', notifyType: NotifyType.success);
    } catch (e) {
      SmartDialog.dismiss();
      SmartDialog.showNotify(msg: '清理失败: $e', notifyType: NotifyType.failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeControllerProvider);
    final locale = ref.watch(localeControllerProvider);

    return PageScaffold(
      title: const Text('软件设置'),
      leading: getPopLeading(context),
      child: ListView(
        children: [
          // ── 主题 ──────────────────────────────────────────────────────
          _SectionHeader(title: '主题'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                RadioListTile<ThemeMode>(
                  title: const Text('浅色模式'),
                  value: ThemeMode.light,
                  groupValue: themeMode,
                  onChanged: (v) =>
                      ref.read(themeControllerProvider.notifier).setMode(v!),
                ),
                RadioListTile<ThemeMode>(
                  title: const Text('深色模式'),
                  value: ThemeMode.dark,
                  groupValue: themeMode,
                  onChanged: (v) =>
                      ref.read(themeControllerProvider.notifier).setMode(v!),
                ),
                RadioListTile<ThemeMode>(
                  title: const Text('跟随系统'),
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
          _SectionHeader(title: '语言'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                RadioListTile<String>(
                  title: const Text('简体中文'),
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
                  title: const Text('English'),
                  value: 'en',
                  groupValue: locale?.languageCode ?? 'system',
                  onChanged: (v) {
                    if (v == null) return;
                    ref.read(localeControllerProvider.notifier).setLocale(Locale(v));
                  },
                ),
                RadioListTile<String>(
                  title: const Text('跟随系统'),
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
          _SectionHeader(title: '存储管理'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: ListTile.divideTiles(
                context: context,
                tiles: [
                  ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: const Text('总占用空间'),
                    trailing: Text(_formatSize(_totalSize),
                        style: theme.textTheme.bodyMedium),
                  ),
                  ListTile(
                    leading: const Icon(Icons.image_outlined),
                    title: const Text('头像缓存'),
                    trailing: Text(
                        _formatSize(_storageSizes[FileStorageService.dirAvatars] ?? 0),
                        style: theme.textTheme.bodyMedium),
                  ),
                  ListTile(
                    leading: const Icon(Icons.cached_outlined),
                    title: const Text('通用缓存'),
                    trailing: Text(
                        _formatSize(_storageSizes[FileStorageService.dirCache] ?? 0),
                        style: theme.textTheme.bodyMedium),
                  ),
                  ListTile(
                    leading: const Icon(Icons.download_outlined),
                    title: const Text('下载文件'),
                    trailing: Text(
                        _formatSize(_storageSizes[FileStorageService.dirDownloads] ?? 0),
                        style: theme.textTheme.bodyMedium),
                  ),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('日志文件'),
                    trailing: Text(
                        _formatSize(_storageSizes[FileStorageService.dirLogs] ?? 0),
                        style: theme.textTheme.bodyMedium),
                  ),
                  ListTile(
                    leading: Icon(Icons.cleaning_services_outlined,
                        color: theme.colorScheme.error),
                    title: Text('清理缓存',
                        style: TextStyle(color: theme.colorScheme.error)),
                    onTap: _clearCache,
                  ),
                ],
              ).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // ── 关于 ──────────────────────────────────────────────────────
          _SectionHeader(title: '关于'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: ListTile.divideTiles(
                context: context,
                tiles: [
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('版本号'),
                    trailing: Text('1.0.0', style: theme.textTheme.bodyMedium),
                  ),
                  ListTile(
                    leading: const Icon(Icons.phone_android_outlined),
                    title: const Text('平台'),
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
