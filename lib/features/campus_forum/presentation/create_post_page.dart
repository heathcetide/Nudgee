import 'dart:typed_data';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:go_router/go_router.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import 'package:nudgee/core/di/injector.dart';
import 'package:nudgee/core/extensions/context_extensions.dart';
import 'package:nudgee/core/services/auth_service.dart';
import 'package:nudgee/core/services/post_service.dart';
import 'package:nudgee/core/services/qiniu_storage_service.dart';
import 'package:nudgee/features/common/utils/crop_image.dart';
import 'package:nudgee/features/common/utils/functions.dart';
import 'package:nudgee/features/common/widgets/page_scaffold.dart';

/// 发布帖子页面 — 信息圈。
///
/// 用户可以输入文字内容、选择最多 9 张图片，
/// 发布后图片上传到七牛云，帖子数据保存到本地 + 云端。
class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final _contentController = TextEditingController();
  final List<Uint8List> _selectedImages = [];
  bool _isPublishing = false;

  static const int _maxImages = 9;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_selectedImages.length >= _maxImages) return;
    final remaining = _maxImages - _selectedImages.length;

    final result = await AssetPicker.pickAssets(
      context,
      pickerConfig: AssetPickerConfig(
        maxAssets: remaining,
        requestType: RequestType.image,
      ),
    );
    if (result == null || result.isEmpty) return;

    for (final asset in result) {
      if (_selectedImages.length >= _maxImages) break;
      final bytes = await asset.originBytes;
      if (bytes != null) {
        final compressed = await getCompressedImage(
          bytes,
          minHeight: 1080,
          minWidth: 1080,
          quality: 30,
        );
        if (mounted) {
          setState(() => _selectedImages.add(compressed));
        }
      }
    }
  }

  void _removeImage(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  Future<void> _publish() async {
    final l10n = context.l10n;
    if (_contentController.text.trim().isEmpty && _selectedImages.isEmpty) {
      SmartDialog.showNotify(msg: '请输入内容或选择图片', notifyType: NotifyType.warning);
      return;
    }

    setState(() => _isPublishing = true);
    SmartDialog.showLoading(msg: '发布中...');

    try {
      final auth = sl<AuthService>();
      final user = auth.currentUser.value;
      if (user == null) {
        SmartDialog.dismiss();
        SmartDialog.showNotify(msg: '请先登录', notifyType: NotifyType.error);
        setState(() => _isPublishing = false);
        return;
      }

      final qiniu = sl<QiniuStorageService>();

      // Upload images to Qiniu.
      final imageUrls = <String>[];
      for (int i = 0; i < _selectedImages.length; i++) {
        final key = 'nudgee/posts/${user.id}/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final url = await qiniu.uploadBytes(key, _selectedImages[i]);
        if (url != null) {
          imageUrls.add(url);
        }
      }

      // Build post item and save via PostService.
      final postItem = PostItem(
        id: '${user.id}_${DateTime.now().millisecondsSinceEpoch}',
        posterUid: user.id,
        posterName: user.name,
        posterAvatar: user.avatar ?? '',
        content: _contentController.text.trim(),
        images: imageUrls,
        time: DateTime.now(),
      );

      await sl<PostService>().addPost(postItem);
      debugPrint('[CreatePost] post saved: ${postItem.id}');

      SmartDialog.dismiss();
      SmartDialog.showNotify(msg: '发布成功', notifyType: NotifyType.success);

      if (mounted) {
        GoRouter.of(context).pop();
      }
    } catch (e) {
      SmartDialog.dismiss();
      SmartDialog.showNotify(msg: '发布失败: $e', notifyType: NotifyType.failure);
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PageScaffold(
      title: Text('发布帖子'),
      leading: getPopLeading(context),
      customActions: [
        TextButton(
          onPressed: _isPublishing ? null : _publish,
          child: Text(
            '发布',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: _isPublishing
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.primary,
            ),
          ),
        ),
      ],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 内容输入
            TextField(
              controller: _contentController,
              maxLines: 6,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: '分享你的想法...',
                border: InputBorder.none,
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),

            // 图片选择网格
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (int i = 0; i < _selectedImages.length; i++)
                  _imageTile(_selectedImages[i], i),
                if (_selectedImages.length < _maxImages)
                  _addImageButton(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageTile(Uint8List bytes, int index) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ExtendedImage.memory(
            bytes,
            width: 100,
            height: 100,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          child: GestureDetector(
            onTap: () => _removeImage(index),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _addImageButton() {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: _pickImages,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.dividerColor,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.add_photo_alternate_outlined,
          size: 32,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
