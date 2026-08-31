import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:go_router/go_router.dart';

import 'package:nudgee/core/di/injector.dart' as di;
import 'package:nudgee/core/services/auth_service.dart';
import 'package:nudgee/core/services/qiniu_storage_service.dart';
import 'package:nudgee/core/services/user_storage_service.dart';
import 'package:nudgee/core/extensions/context_extensions.dart';
import 'package:nudgee/features/common/widgets/page_scaffold.dart';

class ChangeNickName extends StatefulWidget {
  const ChangeNickName({super.key});

  @override
  State<ChangeNickName> createState() => _ChangeNickNameState();
}

class _ChangeNickNameState extends State<ChangeNickName> {
  final TextEditingController _nickNameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> args =
        GoRouterState.of(context).extra as Map<String, dynamic>? ?? {};
    _nickNameController.text = args['nickName'] ?? '';
    return PageScaffold(
      title: Text(context.l10n.nickNameTitle),
      leading: getPopLeading(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nickNameController,
              autofocus: true,
              decoration: InputDecoration(
                  border: const UnderlineInputBorder(),
                  labelText: context.l10n.nickNameLabel,
                  hintText: context.l10n.nickNameHint,
                  prefixIcon: const Icon(Icons.person)),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(context.l10n.nickNameRuleHint,
                  style: TextStyle(
                    color: Theme.of(context).hintColor,
                  )),
            ),
            ElevatedButton(
                onPressed: () async {
                  final nickName = _nickNameController.text.trim();
                  if (nickName.isEmpty) {
                    SmartDialog.showNotify(
                        msg: context.l10n.nickNameEmpty, notifyType: NotifyType.error);
                    return;
                  }
                  if (nickName == args['nickName']) {
                    SmartDialog.showNotify(
                        msg: context.l10n.nickNameSaveSuccess, notifyType: NotifyType.success);
                    Navigator.maybePop(context);
                    return;
                  }
                  SmartDialog.showLoading(msg: context.l10n.infoSaving);
                  try {
                    final auth = di.sl<AuthService>();
                    final user = auth.currentUser.value;
                    if (user == null) {
                      SmartDialog.dismiss();
                      SmartDialog.showNotify(
                          msg: context.l10n.avatarNotLoggedIn, notifyType: NotifyType.error);
                      return;
                    }

                    // 1. 下载当前云端 profile（保留 passwordHash 等字段）
                    final existing = await auth.fetchUserProfile(user.id);
                    if (existing == null) {
                      SmartDialog.dismiss();
                      SmartDialog.showNotify(
                          msg: context.l10n.nickNameCloudReadFailed,
                          notifyType: NotifyType.error);
                      return;
                    }

                    // 2. 更新 name 字段
                    existing['name'] = nickName;

                    // 3. 上传回七牛
                    final qiniu = di.sl<QiniuStorageService>();
                    final key = 'nudgee/${user.id}/profile.json';
                    final bytes = Uint8List.fromList(
                        utf8.encode(jsonEncode(existing)));
                    final url = await qiniu.uploadBytes(key, bytes);
                    if (url == null) {
                      SmartDialog.dismiss();
                      SmartDialog.showNotify(
                          msg: context.l10n.nickNameUploadFailed, notifyType: NotifyType.failure);
                      return;
                    }

                    // 4. 更新本地存储 + 内存状态
                    final updatedUser = AuthUser(
                      id: user.id,
                      name: nickName,
                      avatar: user.avatar,
                    );
                    final userStorage = di.sl<UserStorageService>();
                    await userStorage.saveProfile(updatedUser.toJson());
                    auth.currentUser.value = updatedUser;

                    SmartDialog.dismiss();
                    SmartDialog.showNotify(
                        msg: context.l10n.nickNameSaveSuccess, notifyType: NotifyType.success);
                    Navigator.maybePop(context);
                  } catch (e) {
                    debugPrint('[ChangeNickName] error: $e');
                    SmartDialog.dismiss();
                    SmartDialog.showNotify(
                        msg: context.l10n.nickNameSaveFailedWithError(e.toString()),
                        notifyType: NotifyType.failure);
                  }
                },
                child: Text(context.l10n.nickNameSaveChanges))
          ],
        ),
      ),
    );
  }
}
