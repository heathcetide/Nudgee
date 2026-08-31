import 'dart:typed_data';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:go_router/go_router.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import 'package:nudgee/core/di/injector.dart' as di;
import 'package:nudgee/core/services/auth_service.dart';
import 'package:nudgee/core/services/file_storage_service.dart';
import 'package:nudgee/core/services/qiniu_storage_service.dart';
import 'package:nudgee/features/common/utils/crop_image.dart';
import 'package:nudgee/features/common/utils/functions.dart';
import 'package:nudgee/core/extensions/context_extensions.dart';
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
      title: Text(context.l10n.avatarUploadTitle),
      leading: getPopLeading(context),
      customActions: [
        IconButton(
          icon: Text(
            context.l10n.save,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          onPressed: () async {
            if (_cropping) return;
            _cropping = true;
            try {
              debugPrint('[AvatarUpload] start save...');
              SmartDialog.showLoading(msg: context.l10n.avatarCropping);
              final Uint8List? fileData =
                  (await cropImageDataWithNativeLibrary(_editorController))
                      .data;
              debugPrint('[AvatarUpload] crop done, data=${fileData?.length}B');
              if (fileData == null) {
                SmartDialog.dismiss();
                SmartDialog.showNotify(
                    msg: context.l10n.avatarCropFailed, notifyType: NotifyType.error);
                _cropping = false;
                return;
              }

              // 压缩：缩略图（128px）+ 原图（512px）
              debugPrint('[AvatarUpload] compressing...');
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
              debugPrint('[AvatarUpload] compress done: original=${originalFileData.length}B, thumb=${compressedFileData.length}B');

              SmartDialog.showLoading(msg: context.l10n.avatarUploading);

              final auth = di.sl<AuthService>();
              final user = auth.currentUser.value;
              if (user == null) {
                SmartDialog.dismiss();
                SmartDialog.showNotify(
                    msg: context.l10n.avatarNotLoggedIn, notifyType: NotifyType.error);
                _cropping = false;
                return;
              }

              final qiniu = di.sl<QiniuStorageService>();
              final fileStorage = di.sl<FileStorageService>();

              // ── 1. 上传到七牛（云端）──────────────────────────────────
              final avatarKey = 'nudgee/${user.id}/avatar.jpg';
              final avatarOriginalKey = 'nudgee/${user.id}/avatar_original.jpg';

              debugPrint('[AvatarUpload] uploading to qiniu...');
              final compressedUrl =
                  await qiniu.uploadBytes(avatarKey, compressedFileData);
              if (compressedUrl == null) {
                SmartDialog.dismiss();
                SmartDialog.showNotify(
                    msg: context.l10n.avatarUploadCloudFailed, notifyType: NotifyType.failure);
                _cropping = false;
                return;
              }
              // 原图也上传
              await qiniu.uploadBytes(avatarOriginalKey, originalFileData);
              debugPrint('[AvatarUpload] cloud upload done: $compressedUrl');

              // Cache-busting: append timestamp so ExtendedImage reloads the new image.
              final cacheBustUrl = '$compressedUrl?t=${DateTime.now().millisecondsSinceEpoch}';

              // ── 2. 保存到本地文件系统 ──────────────────────────────────
              debugPrint('[AvatarUpload] saving to local...');
              final localAvatarPath = await fileStorage.saveBytes(
                FileStorageService.dirAvatars,
                '${user.id}_avatar.jpg',
                compressedFileData,
              );
              await fileStorage.saveBytes(
                FileStorageService.dirAvatars,
                '${user.id}_avatar_original.jpg',
                originalFileData,
              );
              debugPrint('[AvatarUpload] local saved: $localAvatarPath');

              // ── 3. 更新云端 profile 的 avatar 字段 ─────────────────────
              debugPrint('[AvatarUpload] updating profile...');
              final (profileOk, profileErr) =
                  await auth.updateProfile({'avatar': compressedUrl});
              if (!profileOk) {
                debugPrint('[AvatarUpload] profile update failed: $profileErr');
              }

              debugPrint('[AvatarUpload] all done!');
              SmartDialog.dismiss();
              SmartDialog.showNotify(
                  msg: context.l10n.avatarUploadSuccess, notifyType: NotifyType.success);
              Navigator.maybePop(context);
              return;
            } catch (e, st) {
              debugPrint('[AvatarUpload] error: $e');
              debugPrint('[AvatarUpload] stacktrace: $st');
            }
            SmartDialog.dismiss();
            SmartDialog.showNotify(
                msg: context.l10n.avatarUploadFailed, notifyType: NotifyType.failure);
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
