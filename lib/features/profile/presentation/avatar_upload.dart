import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:go_router/go_router.dart';
import 'package:qiniu_flutter_sdk/qiniu_flutter_sdk.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import 'package:nudgee/features/common/utils/consts.dart';
import 'package:nudgee/features/common/utils/crop_image.dart';
import 'package:nudgee/features/common/utils/functions.dart';
import 'package:nudgee/features/common/utils/local_storage.dart';
import 'package:nudgee/features/common/widgets/page_scaffold.dart';

class AvatarUpload extends StatefulWidget {
  const AvatarUpload({super.key});

  @override
  State<AvatarUpload> createState() => _AvatarUploadState();
}

class _AvatarUploadState extends State<AvatarUpload> {
  Uint8List? imageData = null;
  final ImageEditorController _editorController = ImageEditorController();
  bool _cropping = false;
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () async {
      Map<String, dynamic> args =
          GoRouterState.of(context).extra as Map<String, dynamic>? ?? {};
      List<AssetEntity> assetEntityList = args['assetEntityList'];
      var t = await assetEntityList[0].originBytes;
      print(t);
      setState(() {
        imageData = t;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: Text('上传头像'),
      leading: getPopLeading(context),
      customActions: [
        IconButton(
            icon: Text(
              "保存",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            onPressed: () async {
              if (_cropping) {
                return;
              }
              _cropping = true;
              try {
                SmartDialog.showLoading(msg: "图片裁剪中");
                Uint8List? fileData =
                    (await cropImageDataWithNativeLibrary(_editorController)).data;
                final Uint8List originalFileData =
                    await getCompressedImage(fileData!, minHeight: 512, minWidth: 512, quality: 24);
                final Uint8List compressedFileData =
                    await getCompressedImage(fileData!, minHeight: 128, minWidth: 128, quality: 24);
                SmartDialog.showLoading(msg: "图片上传中");
                var tokenResp = (await dio.post(BaseURL + '/user/upload/credential')).data;
                String upToken = tokenResp['data']['upToken'];
                String originalUpToken = tokenResp['data']['originalUpToken'];
                String uid = await LocalStorage.user_uid.get();
                String key_md5 = md5.convert(utf8.encode(uid)).toString();
                String key = 'avatar/${key_md5}';
                await Storage()
                    .putBytes(compressedFileData, upToken, options: PutOptions(key: key));
                await Storage().putBytes(originalFileData, originalUpToken,
                    options: PutOptions(key: key + '_original'));
                var resp = (await dio.post(BaseURL + "/user/update/avatar", data: {})).data;
                print(resp);
                if (resp['code'] == 0) {
                  await syncUserInfo();
                  SmartDialog.dismiss();
                  SmartDialog.showNotify(msg: '头像修改成功', notifyType: NotifyType.success);
                  Navigator.maybePop(context);
                  return;
                }
              } catch (e) {
                print(e);
              }
              SmartDialog.dismiss();
              SmartDialog.showNotify(msg: '头像上传失败', notifyType: NotifyType.failure);
              _cropping = false;
            })
      ],
      child: imageData == null
          ? SizedBox()
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
                          ? Color.fromARGB(122, 0, 0, 0)
                          : Color.fromARGB(188, 0, 0, 0);
                    },
                  );
                },
              ),
            ),
    );
  }
}
