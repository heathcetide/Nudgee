import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import 'package:nudgee/app/router/app_router.dart';
import 'package:nudgee/core/di/injector.dart';
import 'package:nudgee/core/extensions/context_extensions.dart';
import 'package:nudgee/core/services/auth_service.dart';
import 'package:nudgee/features/common/utils/route_observer.dart';
import 'package:nudgee/features/common/widgets/avatar.dart';
import 'package:nudgee/features/common/widgets/page_scaffold.dart';

class MyInformation extends StatefulWidget {
  const MyInformation({super.key});

  @override
  State<MyInformation> createState() => _MyInformationState();
}

class _MyInformationState extends State<MyInformation> with RouteAware {
  AuthUser? _user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    appRouteObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPopNext() {
    _loadUser();
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  void _loadUser() {
    final auth = sl<AuthService>();
    setState(() {
      _user = auth.currentUser.value;
    });
  }

  /// 申请相册权限
  Future<bool> _requestPhotoPermission() async {
    if (!Platform.isAndroid) return true;
    if (await Permission.photos.isGranted) return true;
    final result = await [Permission.photos, Permission.videos].request();
    final granted = result.values.every((s) => s.isGranted);
    if (!granted) {
      await openAppSettings();
    }
    return granted;
  }

  /// 修改性别
  Future<void> _editGender() async {
    final current = _user?.gender;
    String? selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(context.l10n.infoSelectGender),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, '男'),
            child: Row(
              children: [
                Icon(Icons.male,
                    color: current == '男' ? Theme.of(ctx).primaryColor : null),
                const SizedBox(width: 8),
                Text(context.l10n.infoGenderMale),
                if (current == '男')
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.check, size: 18),
                  ),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, '女'),
            child: Row(
              children: [
                Icon(Icons.female,
                    color: current == '女' ? Theme.of(ctx).primaryColor : null),
                const SizedBox(width: 8),
                Text(context.l10n.infoGenderFemale),
                if (current == '女')
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.check, size: 18),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (selected == null || selected == current) return;

    SmartDialog.showLoading(msg: context.l10n.infoSaving);
    final (ok, err) = await sl<AuthService>().updateProfile({'gender': selected});
    SmartDialog.dismiss();
    if (ok) {
      _loadUser();
      SmartDialog.showNotify(msg: context.l10n.infoSaveSuccess, notifyType: NotifyType.success);
    } else {
      SmartDialog.showNotify(msg: err ?? context.l10n.infoSaveFailed, notifyType: NotifyType.failure);
    }
  }

  /// 修改手机号
  Future<void> _editPhone() async {
    final controller = TextEditingController(text: _user?.phone ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.infoEditPhone),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          autofocus: true,
          decoration: InputDecoration(
            labelText: context.l10n.infoPhone,
            hintText: context.l10n.infoPhoneHint,
            prefixIcon: const Icon(Icons.phone),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );
    if (result == null || result == _user?.phone) return;
    if (result.isEmpty) {
      SmartDialog.showNotify(msg: context.l10n.infoPhoneEmpty, notifyType: NotifyType.error);
      return;
    }

    SmartDialog.showLoading(msg: context.l10n.infoSaving);
    final (ok, err) = await sl<AuthService>().updateProfile({'phone': result});
    SmartDialog.dismiss();
    if (ok) {
      _loadUser();
      SmartDialog.showNotify(msg: context.l10n.infoSaveSuccess, notifyType: NotifyType.success);
    } else {
      SmartDialog.showNotify(msg: err ?? context.l10n.infoSaveFailed, notifyType: NotifyType.failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _user?.name ?? context.l10n.notSet;
    final id = _user?.id ?? context.l10n.notSet;
    final avatar = _user?.avatar;
    final gender = _user?.gender ?? context.l10n.notSet;
    final phone = _user?.phone ?? context.l10n.notSet;

    return PageScaffold(
      title: Text(context.l10n.profileMyInfo),
      leading: getPopLeading(context),
      child: ListView(
        children: ListTile.divideTiles(
          tiles: [
            // 昵称
            ListTile(
              onTap: () {
                GoRouter.of(context).push('/profile/changeNickName',
                    extra: {'nickName': name});
              },
              title: Text(context.l10n.infoNickname),
              trailing: ListTileTrailingTextArrow(text: name),
            ),
            // 头像
            ListTile(
              onTap: () async {
                final bool granted = await _requestPhotoPermission();
                if (!granted) {
                  SmartDialog.showNotify(
                      msg: context.l10n.infoPhotoPermission, notifyType: NotifyType.error);
                  return;
                }
                final List<AssetEntity>? assetEntityList =
                    await AssetPicker.pickAssets(context,
                        pickerConfig: AssetPickerConfig(
                            maxAssets: 1, requestType: RequestType.image));
                if (assetEntityList == null) return;
                GoRouter.of(context).push('/profile/avatarUpload',
                    extra: {'assetEntityList': assetEntityList});
              },
              title: Text('\n${context.l10n.infoAvatar}\n'),
              trailing: ListTileTrailingTextArrow(
                text: SizedBox(
                  width: 50,
                  height: 50,
                  child: Avatar(avatar, name: name),
                ),
              ),
            ),
            // 用户ID（只读）
            ListTile(
              enabled: false,
              title: Text(context.l10n.profileUserId),
              trailing: ListTileTrailingTextArrow(text: id, arrow: false),
            ),
            // 性别（可设置）
            ListTile(
              onTap: _editGender,
              title: Text(context.l10n.infoGender),
              trailing: ListTileTrailingTextArrow(text: gender),
            ),
            // 手机号（可设置）
            ListTile(
              onTap: _editPhone,
              title: Text(context.l10n.infoPhone),
              trailing: ListTileTrailingTextArrow(text: phone),
            ),
            // 注销账号
            TextButton(
              onPressed: () {},
              child: Text(
                context.l10n.profileDeleteAccount,
                style: TextStyle(
                    fontSize: 18,
                    color: Colors.red,
                    fontWeight: FontWeight.bold),
              ),
            ),
            // 退出登录
            TextButton(
              onPressed: () async {
                final router = GoRouter.of(context);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(context.l10n.logout),
                    content: Text(context.l10n.infoLogoutConfirm),
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
                try {
                  final auth = sl<AuthService>();
                  await auth.logout();
                } catch (_) {}
                router.go(AppRouter.login);
              },
              child: Text(
                context.l10n.logout,
                style: TextStyle(
                    fontSize: 18,
                    color: Colors.orange,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(),
            Center(
              child: Text(
                context.l10n.reloginHint,
                style: TextStyle(color: Theme.of(context).hintColor),
              ),
            ),
          ] as Iterable<Widget>,
          context: context,
        ).toList(),
      ),
    );
  }
}

class ListTileTrailingTextArrow extends StatelessWidget {
  final dynamic text;
  final bool arrow;
  const ListTileTrailingTextArrow(
      {super.key, required this.text, this.arrow = true});

  @override
  Widget build(BuildContext context) {
    Widget? _text;
    if (text is String) {
      _text = Text(text,
          style: const TextStyle(fontSize: 15),
          overflow: TextOverflow.ellipsis);
    } else {
      _text = text;
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _text!,
        arrow
            ? const Padding(
                padding: EdgeInsets.only(left: 8.0),
                child: Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                ),
              )
            : Container(),
      ],
    );
  }
}
