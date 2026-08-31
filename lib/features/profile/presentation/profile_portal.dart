import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icons_plus/icons_plus.dart';

import 'package:nudgee/app/router/app_router.dart';
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
  final List<Map<String, dynamic>> _actions = [
    {
      'icon': Icons.person,
      'text': '个人主页',
      'onclick': (context) {
        GoRouter.of(context).push(AppRouter.personalHome);
      }
    },
    {
      'icon': Icons.settings,
      'text': '软件设置',
      'onclick': (context) {
        GoRouter.of(context).push(AppRouter.settings);
      }
    },
    {'icon': AntDesign.heart_fill, 'text': '点赞列表', 'onclick': (centext) {}},
    {'icon': Icons.assignment_outlined, 'text': '任务记录', 'onclick': (centext) {}},
    {'icon': Icons.help_outline, 'text': '问题反馈', 'onclick': (centext) {}},
    {'icon': Icons.info_outline, 'text': '关于软件', 'onclick': (centext) {}},
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    appRouteObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPopNext() {
    setState(() {});
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = sl<AuthService>();
    final user = auth.currentUser.value;
    final isLoggedIn = auth.isAuthenticated.value;

    return Container(
      color: isDark
          ? Theme.of(context).scaffoldBackgroundColor
          : Theme.of(context).colorScheme.inversePrimary.withAlpha(122),
      child: SafeArea(
        child: Column(
          children: [
            // ── User Card ────────────────────────────────────────────────
            Card(
              clipBehavior: Clip.antiAlias,
              margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 16),
              child: MaterialButton(
                onPressed: () {
                  if (isLoggedIn) {
                    GoRouter.of(context).push(AppRouter.myInformation);
                  } else {
                    GoRouter.of(context).go(AppRouter.login);
                  }
                },
                padding: const EdgeInsets.all(0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Container(
                          width: 66,
                          height: 66,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
                          child: isLoggedIn
                              ? Avatar(user?.avatar, name: user?.name ?? '')
                              : const Center(
                                  child: Icon(Icons.person, size: 36, color: Colors.white),
                                ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isLoggedIn ? (user?.name ?? '未设置') : '未登录',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold, height: 1.2),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isLoggedIn
                                  ? (user != null && user.id.length > 8
                                      ? 'ID: ${user.id.substring(0, 7)}****${user.id.substring(user.id.length - 1)}'
                                      : 'ID: ${user?.id ?? ""}')
                                  : '点击登录以同步您的数据',
                              style: const TextStyle(fontSize: 15, height: 1),
                            ),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(right: 14.0),
                        child: Icon(Icons.arrow_forward_ios, size: 20),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // ── Action List ───────────────────────────────────────────────
            Expanded(
              child: Card(
                clipBehavior: Clip.antiAlias,
                margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
                child: ListView.builder(
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(_actions[index]['text']),
                      leading: Icon(_actions[index]['icon']),
                      onTap: () {
                        _actions[index]['onclick'](context);
                      },
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                      ),
                    );
                  },
                  itemCount: _actions.length,
                  shrinkWrap: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
