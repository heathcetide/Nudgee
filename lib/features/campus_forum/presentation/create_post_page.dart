import 'dart:typed_data';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:go_router/go_router.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import 'package:nudgee/core/di/injector.dart';
import 'package:nudgee/core/services/auth_service.dart';
import 'package:nudgee/core/services/post_service.dart';
import 'package:nudgee/core/services/qiniu_storage_service.dart';
import 'package:nudgee/features/common/utils/functions.dart';
import 'package:nudgee/features/common/widgets/page_scaffold.dart';

/// 发布/编辑帖子页面 — 个人圈。
///
/// 用户可以输入文字内容、选择最多 9 张图片，
/// 发布后图片上传到七牛云，帖子数据保存到本地 + 云端。
///
/// 当 [editItem] 不为 null 时进入编辑模式，可修改文本和图片。
class CreatePostPage extends StatefulWidget {
  /// 编辑模式时传入的帖子。null 表示新建。
  final PostItem? editItem;

  const CreatePostPage({super.key, this.editItem});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final _contentController = TextEditingController();
  final List<Uint8List> _selectedImages = []; // 新增的图片 (本地 bytes)
  final List<String> _existingImageUrls = []; // 编辑模式: 保留的旧图片 URL
  final List<String> _removedImageUrls = []; // 编辑模式: 被删除的旧图片 URL
  bool _isPublishing = false;
  bool get _isEditMode => widget.editItem != null;

  static const int _maxImages = 9;
  int get _totalImageCount => _selectedImages.length + _existingImageUrls.length;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _contentController.text = widget.editItem!.content;
      _existingImageUrls.addAll(widget.editItem!.images);
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_totalImageCount >= _maxImages) return;
    final remaining = _maxImages - _totalImageCount;

    final result = await AssetPicker.pickAssets(
      context,
      pickerConfig: AssetPickerConfig(
        maxAssets: remaining,
        requestType: RequestType.image,
      ),
    );
    if (result == null || result.isEmpty) return;

    for (final asset in result) {
      if (_totalImageCount >= _maxImages) break;
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

  void _removeNewImage(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  void _removeExistingImage(int index) {
    setState(() {
      final url = _existingImageUrls.removeAt(index);
      _removedImageUrls.add(url);
    });
  }

  Future<void> _publish() async {
    if (_contentController.text.trim().isEmpty &&
        _selectedImages.isEmpty &&
        _existingImageUrls.isEmpty) {
      SmartDialog.showNotify(msg: '请输入内容或选择图片', notifyType: NotifyType.warning);
      return;
    }

    setState(() => _isPublishing = true);
    SmartDialog.showLoading(msg: _isEditMode ? '保存中...' : '发布中...');

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

      // Upload new images to Qiniu.
      final newImageUrls = <String>[];
      for (int i = 0; i < _selectedImages.length; i++) {
        final key = 'nudgee/posts/${user.id}/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final url = await qiniu.uploadBytes(key, _selectedImages[i]);
        if (url != null) {
          newImageUrls.add(url);
        }
      }

      // Merge: kept existing + newly uploaded.
      final allImageUrls = [..._existingImageUrls, ...newImageUrls];

      if (_isEditMode) {
        // Update existing post.
        await sl<PostService>().updatePost(
          widget.editItem!.id,
          content: _contentController.text.trim(),
          images: allImageUrls,
        );
        debugPrint('[CreatePost] post updated: ${widget.editItem!.id}');
        SmartDialog.dismiss();
        SmartDialog.showNotify(msg: '已保存', notifyType: NotifyType.success);
      } else {
        // Build post item and save via PostService.
        final postItem = PostItem(
          id: '${user.id}_${DateTime.now().millisecondsSinceEpoch}',
          posterUid: user.id,
          posterName: user.name,
          posterAvatar: user.avatar ?? '',
          content: _contentController.text.trim(),
          images: allImageUrls,
          time: DateTime.now(),
        );

        await sl<PostService>().addPost(postItem);
        debugPrint('[CreatePost] post saved: ${postItem.id}');
        SmartDialog.dismiss();
        SmartDialog.showNotify(msg: '发布成功', notifyType: NotifyType.success);
      }

      if (mounted) {
        GoRouter.of(context).pop();
      }
    } catch (e) {
      SmartDialog.dismiss();
      SmartDialog.showNotify(msg: '操作失败: $e', notifyType: NotifyType.failure);
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PageScaffold(
      title: Text(_isEditMode ? '编辑帖子' : '发布帖子'),
      leading: getPopLeading(context),
      customActions: [
        TextButton(
          onPressed: _isPublishing ? null : _publish,
          child: Text(
            _isEditMode ? '保存' : '发布',
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
              decoration: const InputDecoration(
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
                // 保留的旧图片 (编辑模式)
                for (int i = 0; i < _existingImageUrls.length; i++)
                  _urlImageTile(_existingImageUrls[i], i, isExisting: true),
                // 新增的图片
                for (int i = 0; i < _selectedImages.length; i++)
                  _imageTile(_selectedImages[i], i),
                if (_totalImageCount < _maxImages) _addImageButton(),
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
            onTap: () => _removeNewImage(index),
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

  Widget _urlImageTile(String url, int index, {required bool isExisting}) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ExtendedImage.network(
            url,
            width: 100,
            height: 100,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          child: GestureDetector(
            onTap: () => _removeExistingImage(index),
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
