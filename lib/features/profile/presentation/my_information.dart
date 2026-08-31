import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import 'package:nudgee/app/router/app_router.dart';
import 'package:nudgee/core/di/injector.dart';
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

  /// 申请相册权限（Android 13+ 用 READ_MEDIA_IMAGES，低版本用 READ_EXTERNAL_STORAGE）
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

  @override
  Widget build(BuildContext context) {
    final name = _user?.name ?? '未设置';
    final id = _user?.id ?? '未设置';
    final avatar = _user?.avatar;

    return PageScaffold(
      title: const Text('我的信息'),
      leading: getPopLeading(context),
      child: ListView(
        children: ListTile.divideTiles(
          tiles: [
            // 昵称（可点击修改）
            ListTile(
              onTap: () {
                GoRouter.of(context).push('/profile/changeNickName',
                    extra: {'nickName': name});
              },
              title: const Text('昵称'),
              trailing: ListTileTrailingTextArrow(text: name),
            ),
            // 头像（可点击更换）
            ListTile(
              onTap: () async {
                final bool granted = await _requestPhotoPermission();
                if (!granted) {
                  SmartDialog.showNotify(
                      msg: '请先授权相册权限', notifyType: NotifyType.error);
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
              title: const Text('\n头像\n'),
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
              title: const Text('用户ID'),
              trailing: ListTileTrailingTextArrow(text: id, arrow: false),
            ),
            // 性别（只读，后续可扩展）
            ListTile(
              enabled: false,
              title: const Text('性别'),
              trailing: ListTileTrailingTextArrow(text: '未设置', arrow: false),
            ),
            // 手机号（只读，后续可扩展）
            ListTile(
              enabled: false,
              title: const Text('手机号'),
              trailing: ListTileTrailingTextArrow(text: '未设置', arrow: false),
            ),
            // 注销账号
            TextButton(
              onPressed: () {},
              child: const Text(
                '注销账号',
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
                    title: const Text('退出登录'),
                    content: const Text('确定要退出登录吗？'),
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
                try {
                  final auth = sl<AuthService>();
                  await auth.logout();
                } catch (_) {}
                router.go(AppRouter.login);
              },
              child: const Text(
                '退出登录',
                style: TextStyle(
                    fontSize: 18,
                    color: Colors.orange,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(),
            Center(
              child: Text(
                '退出登录后重新登录即可同步您的数据',
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
