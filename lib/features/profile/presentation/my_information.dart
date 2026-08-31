import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import 'package:nudgee/app/router/app_router.dart';
import 'package:nudgee/core/di/injector.dart';
import 'package:nudgee/core/services/auth_service.dart';
import 'package:nudgee/features/common/utils/functions.dart';
import 'package:nudgee/features/common/utils/local_storage.dart';
import 'package:nudgee/features/common/utils/route_observer.dart';
import 'package:nudgee/features/common/widgets/avatar.dart';
import 'package:nudgee/features/common/widgets/page_scaffold.dart';

class MyInformation extends StatefulWidget {
  const MyInformation({super.key});

  @override
  State<MyInformation> createState() => _MyInformationState();
}

class _MyInformationState extends State<MyInformation> with RouteAware {
  Map<String, dynamic> userInfo = {
    'avatar': '',
    'nickName': '加载中...',
    'userName': '加载中...',
    'uid': '加载中...',
    'mobile': '加载中...',
    'dormBuilding': '加载中...',
    'dormNumber': '加载中...',
    'college': '加载中...',
    'gender': '加载中...',
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    appRouteObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPopNext() {
    updateUserInfoFromLS();
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void initState() {
    updateUserInfoFromLS();
    super.initState();
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

  Future updateUserInfoFromLS() async {
    Map<String, dynamic> info = {
      'avatar': await LocalStorage.user_avatar.get() ?? '',
      'nickName': await LocalStorage.user_nickName.get() ?? '未设置',
      'userName': await LocalStorage.user_userName.get() ?? '未设置',
      'uid': await LocalStorage.user_uid.get() ?? '未设置',
      'mobile': await LocalStorage.user_mobile.get() ?? '未设置',
      'dormBuilding': await LocalStorage.user_dormBuilding.get() ?? '未设置',
      'dormNumber': await LocalStorage.user_dormNumber.get() ?? '未设置',
      'college': await LocalStorage.user_college.get() ?? '未设置',
      'gender': await LocalStorage.user_gender.get() ?? '未设置',
    };
    setState(() {
      userInfo = info;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Map<String, dynamic> args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    return PageScaffold(
        title: Text('我的信息'),
        leading: getPopLeading(context),
        child: RefreshIndicator(
          onRefresh: () async {
            await syncUserInfo();
            await updateUserInfoFromLS();
            SmartDialog.showNotify(msg: "信息同步成功", notifyType: NotifyType.success);
          },
          child: ListView(
            children: ListTile.divideTiles(
                    tiles: [
                      ListTile(
                        onTap: () {
                          GoRouter.of(context).push('/profile/changeNickName',
                              extra: {'nickName': userInfo['nickName']});
                        },
                        title: Text('昵称'),
                        trailing: ListTileTrailingTextArrow(text: userInfo['nickName']),
                      ),
                      ListTile(
                        onTap: () async {
                          // 先申请相册权限
                          final bool granted = await _requestPhotoPermission();
                          if (!granted) {
                            SmartDialog.showNotify(
                                msg: '请先授权相册权限',
                                notifyType: NotifyType.error);
                            return;
                          }
                          final List<AssetEntity>? assetEntityList = await AssetPicker.pickAssets(
                              context,
                              pickerConfig: AssetPickerConfig(maxAssets: 1, requestType: RequestType.image));
                          if (assetEntityList == null) return;
                          GoRouter.of(context).push('/profile/avatarUpload',
                              extra: {'assetEntityList': assetEntityList});
                        },
                        title: Text('\n头像\n'),
                        trailing: ListTileTrailingTextArrow(
                          text: SizedBox(
                              width: 50,
                              height: 50,
                              child: Avatar(userInfo['avatar'], name: userInfo['nickName'])),
                        ),
                      ),
                      ListTile(
                        onTap: () {},
                        title: Text('宿舍'),
                        trailing: ListTileTrailingTextArrow(
                            text: userInfo['dormBuilding'] + '栋 ' + userInfo['dormNumber']),
                      ),
                      ListTile(
                        enabled: false,
                        title: Text('学号'),
                        trailing: ListTileTrailingTextArrow(text: userInfo['uid'], arrow: false),
                      ),
                      ListTile(
                        enabled: false,
                        title: Text('姓名'),
                        trailing:
                            ListTileTrailingTextArrow(text: userInfo['userName'], arrow: false),
                      ),
                      ListTile(
                        enabled: false,
                        title: Text('性别'),
                        trailing: ListTileTrailingTextArrow(text: userInfo['gender'], arrow: false),
                      ),
                      ListTile(
                        enabled: false,
                        title: Text('号码'),
                        trailing: ListTileTrailingTextArrow(text: userInfo['mobile'], arrow: false),
                      ),
                      ListTile(
                        enabled: false,
                        title: Text('组织'),
                        trailing:
                            ListTileTrailingTextArrow(text: userInfo['college'], arrow: false),
                      ),
                      TextButton(
                          onPressed: () {},
                          child: Text(
                            '注销账号',
                            style: TextStyle(
                                fontSize: 18, color: Colors.red, fontWeight: FontWeight.bold),
                          )),
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
                          child: Text(
                            '退出登录',
                            style: TextStyle(
                                fontSize: 18, color: Colors.orange, fontWeight: FontWeight.bold),
                          )),
                      SizedBox(),
                      Center(
                        child: Text(
                          '如需修改全部信息,请前往个人中心修改,\n退出登录后重新登录即可同步您的数据',
                          style: TextStyle(color: Theme.of(context).hintColor),
                        ),
                      ),
                    ] as Iterable<Widget>,
                    context: context)
                .toList(),
          ),
        ));
  }
}

class ListTileTrailingTextArrow extends StatelessWidget {
  final text;
  final bool arrow;
  const ListTileTrailingTextArrow({super.key, required this.text, this.arrow = true});

  @override
  Widget build(BuildContext context) {
    Widget? _text;
    if (text is String) {
      _text = Text(text, style: TextStyle(fontSize: 15), overflow: TextOverflow.ellipsis);
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
              ? Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                  ),
                )
              : Container()
        ]);
  }
}
