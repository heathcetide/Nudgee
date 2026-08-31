import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:nudgee/app/router/app_router.dart';
import 'package:nudgee/core/di/injector.dart';
import 'package:nudgee/core/services/auth_service.dart';
import 'package:nudgee/features/common/utils/route_observer.dart';
import 'package:nudgee/features/common/widgets/avatar.dart';
import 'package:nudgee/features/common/widgets/page_scaffold.dart';

/// Personal homepage — shows user's public profile card.
///
/// Displays avatar, name, ID, gender, phone in a card layout.
/// Tap "编辑资料" to go to [MyInformation].
class PersonalHomePage extends StatefulWidget {
  const PersonalHomePage({super.key});

  @override
  State<PersonalHomePage> createState() => _PersonalHomePageState();
}

class _PersonalHomePageState extends State<PersonalHomePage> with RouteAware {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = _user?.name ?? '未设置';
    final id = _user?.id ?? '';
    final avatar = _user?.avatar;
    final gender = _user?.gender;
    final phone = _user?.phone;

    return PageScaffold(
      title: const Text('个人主页'),
      leading: getPopLeading(context),
      child: ListView(
        children: [
          const SizedBox(height: 24),
          // ── Avatar + Name ──────────────────────────────────────────────
          Center(
            child: Column(
              children: [
                Container(
                  width: 96,
                  height: 96,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Avatar(avatar, name: name),
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ID: ${id.length > 12 ? '${id.substring(0, 8)}...${id.substring(id.length - 4)}' : id}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Info Cards ─────────────────────────────────────────────────
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: ListTile.divideTiles(
                context: context,
                tiles: [
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('昵称'),
                    trailing: Text(name, style: theme.textTheme.bodyMedium),
                  ),
                  ListTile(
                    leading: const Icon(Icons.wc_outlined),
                    title: const Text('性别'),
                    trailing: Text(
                      gender ?? '未设置',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.phone_outlined),
                    title: const Text('手机号'),
                    trailing: Text(
                      phone ?? '未设置',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // ── Edit Button ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton.tonalIcon(
              onPressed: () {
                GoRouter.of(context).push(AppRouter.myInformation);
              },
              icon: const Icon(Icons.edit),
              label: const Text('编辑资料'),
            ),
          ),
        ],
      ),
    );
  }
}
