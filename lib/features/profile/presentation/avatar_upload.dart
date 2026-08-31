import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:go_router/go_router.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import 'package:nudgee/core/di/injector.dart' as di;
import 'package:nudgee/core/services/auth_service.dart';
import 'package:nudgee/core/services/qiniu_storage_service.dart';
import 'package:nudgee/core/services/user_storage_service.dart';
import 'package:nudgee/features/common/utils/crop_image.dart';
import 'package:nudgee/features/common/utils/functions.dart';
import 'package:nudgee/features/common/widgets/page_scaffold.dart';

class AvatarUpload extends StatefulWidget {
  const AvatarUpload({super.key});

  @override
  State<AvatarUpload> createState() => _AvatarUploadState();
}

class _AvatarUploadState extends State<AvatarUpload> {
  Uint8List? imageData;
  final ImageEditorController _editorController = ImageEditorController();
  bool _cropping = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () async {
      final Map<String, dynamic> args =
          GoRouterState.of(context).extra as Map<String, dynamic>? ?? {};
      final List<AssetEntity> assetEntityList = args['assetEntityList'];
      final t = await assetEntityList[0].originBytes;
      if (mounted) {
        setState(() {
          imageData = t;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: const Text('上传头像'),
      leading: getPopLeading(context),
      customActions: [
        IconButton(
          icon: const Text(
            '保存',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          onPressed: () async {
            if (_cropping) return;
            _cropping = true;
            try {
              SmartDialog.showLoading(msg: '图片裁剪中');
              final Uint8List? fileData =
                  (await cropImageDataWithNativeLibrary(_editorController))
                      .data;
              if (fileData == null) {
                SmartDialog.dismiss();
                SmartDialog.showNotify(
                    msg: '裁剪失败', notifyType: NotifyType.error);
                _cropping = false;
                return;
              }

              final Uint8List originalFileData = await getCompressedImage(
                  fileData,
                  minHeight: 512,
                  minWidth: 512,
                  quality: 24);
              final Uint8List compressedFileData = await getCompressedImage(
                  fileData,
                  minHeight: 128,
                  minWidth: 128,
                  quality: 24);

              SmartDialog.showLoading(msg: '图片上传中');

              final auth = di.sl<AuthService>();
              final user = auth.currentUser.value;
              if (user == null) {
                SmartDialog.dismiss();
                SmartDialog.showNotify(
                    msg: '未登录', notifyType: NotifyType.error);
                _cropping = false;
                return;
              }

              final qiniu = di.sl<QiniuStorageService>();

              // 上传头像到七牛: nudgee/{userId}/avatar.jpg + avatar_original.jpg
              final avatarKey = 'nudgee/${user.id}/avatar.jpg';
              final avatarOriginalKey = 'nudgee/${user.id}/avatar_original.jpg';

              final compressedUrl =
                  await qiniu.uploadBytes(avatarKey, compressedFileData);
              if (compressedUrl == null) {
                SmartDialog.dismiss();
                SmartDialog.showNotify(
                    msg: '头像上传失败', notifyType: NotifyType.failure);
                _cropping = false;
                return;
              }

              await qiniu.uploadBytes(avatarOriginalKey, originalFileData);

              // 更新云端 profile 的 avatar 字段
              final existing = await auth.fetchUserProfile(user.id);
              if (existing != null) {
                existing['avatar'] = compressedUrl;
                final profileBytes = Uint8List.fromList(
                    utf8.encode(jsonEncode(existing)));
                await qiniu.uploadBytes(
                    'nudgee/${user.id}/profile.json', profileBytes);
              }

              // 更新本地存储 + 内存状态
              final updatedUser = AuthUser(
                id: user.id,
                name: user.name,
                avatar: compressedUrl,
              );
              final userStorage = di.sl<UserStorageService>();
              await userStorage.saveProfile(updatedUser.toJson());
              auth.currentUser.value = updatedUser;

              SmartDialog.dismiss();
              SmartDialog.showNotify(
                  msg: '头像修改成功', notifyType: NotifyType.success);
              Navigator.maybePop(context);
              return;
            } catch (e) {
              debugPrint('[AvatarUpload] error: $e');
            }
            SmartDialog.dismiss();
            SmartDialog.showNotify(
                msg: '头像上传失败', notifyType: NotifyType.failure);
            _cropping = false;
          },
        )
      ],
      child: imageData == null
          ? const SizedBox()
          : Container(
              color: Theme.of(context).hintColor,
              child: ExtendedImage.memory(
                imageData!,
                fit: BoxFit.contain,
                mode: ExtendedImageMode.editor,
                enableLoadState: true,
                cacheRawData: true,
                initEditorConfigHandler: (ExtendedImageState? state) {
                  return EditorConfig(
                    maxScale: 20.0,
                    cropRectPadding: const EdgeInsets.all(16.0),
                    initCropRectType: InitCropRectType.imageRect,
                    cropAspectRatio: CropAspectRatios.ratio1_1,
                    controller: _editorController,
                    editorMaskColorHandler: (context, pointerDown) {
                      return pointerDown
                          ? const Color.fromARGB(122, 0, 0, 0)
                          : const Color.fromARGB(188, 0, 0, 0);
                    },
                  );
                },
              ),
            ),
    );
  }
}
