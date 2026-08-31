import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icons_plus/icons_plus.dart';

import 'package:nudgee/core/di/injector.dart';
import 'package:nudgee/core/services/auth_service.dart';
import 'package:nudgee/features/common/utils/route_observer.dart';
import 'package:nudgee/features/common/widgets/avatar.dart';

class ProfilePortal extends StatefulWidget {
  const ProfilePortal({super.key});

  @override
  State<ProfilePortal> createState() => _ProfilePortalState();
}

class _ProfilePortalState extends State<ProfilePortal> with RouteAware {
  AuthUser? _user;

  final List<Map<String, dynamic>> actions = [
    {'icon': Icons.person, 'text': '个人主页', 'onclick': (context) {}},
    {'icon': Icons.settings, 'text': '软件设置', 'onclick': (centext) {}},
    {'icon': AntDesign.heart_fill, 'text': '点赞列表', 'onclick': (centext) {}},
    {'icon': Icons.settings, 'text': '任务记录', 'onclick': (centext) {}},
    {'icon': Icons.help, 'text': '问题反馈', 'onclick': (centext) {}},
    {'icon': Icons.info, 'text': '关于软件', 'onclick': (centext) {}}
  ];

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

  @override
  void initState() {
    _loadUser();
    super.initState();
  }

  void _loadUser() {
    final auth = sl<AuthService>();
    setState(() {
      _user = auth.currentUser.value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = _user?.name ?? '未设置';
    final id = _user?.id ?? '';
    final avatar = _user?.avatar;

    return Container(
      color: isDark
          ? Theme.of(context).scaffoldBackgroundColor
          : Theme.of(context).colorScheme.inversePrimary.withAlpha(122),
      child: SafeArea(
          child: Column(
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 16),
            child: MaterialButton(
              onPressed: () {
                GoRouter.of(context).push('/profile/myInformation');
              },
              padding: const EdgeInsets.all(0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Container(
                        width: 66,
                        height: 66,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
                        child: Avatar(avatar, name: name),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold, height: 1.2)),
                          const SizedBox(height: 4),
                          Text(
                              id.length > 8
                                  ? 'ID: ${id.substring(0, 7)}****${id.substring(id.length - 1)}'
                                  : 'ID: $id',
                              style: const TextStyle(fontSize: 15, height: 1)),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(right: 14.0),
                      child: Icon(Icons.arrow_forward_ios, size: 20),
                    )
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
              child: ListView.builder(
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(actions[index]['text']),
                      leading: Icon(actions[index]['icon']),
                      onTap: () {
                        actions[index]['onclick'](context);
                      },
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                      ),
                    );
                  },
                  itemCount: actions.length,
                  shrinkWrap: true),
            ),
          )
        ],
      )),
    );
  }
}
