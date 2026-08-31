import 'package:auto_size_text/auto_size_text.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icons_plus/icons_plus.dart';

import 'package:nudgee/app/router/app_router.dart';
import 'package:nudgee/core/di/injector.dart';
import 'package:nudgee/core/extensions/context_extensions.dart';
import 'package:nudgee/core/services/auth_service.dart';
import 'package:nudgee/features/common/utils/route_observer.dart';
import 'package:nudgee/features/common/widgets/avatar.dart';

class ProfilePortal extends StatefulWidget {
  const ProfilePortal({super.key});

  @override
  State<ProfilePortal> createState() => _ProfilePortalState();
}

class _ProfilePortalState extends State<ProfilePortal> with RouteAware {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    appRouteObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPopNext() {
    // Bump refresh counter to force avatar URL change → reload image.
    setState(() => _avatarRefresh++);
  }

  int _avatarRefresh = 0;

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = sl<AuthService>();
    final user = auth.currentUser.value;
    final isLoggedIn = auth.isAuthenticated.value;
    // Append refresh counter to avatar URL to bust image cache.
    final avatarUrl = user?.avatar != null && user!.avatar!.isNotEmpty
        ? '${user.avatar}${user.avatar!.contains('?') ? '&' : '?'}r=$_avatarRefresh'
        : null;

    final List<Map<String, dynamic>> actions = [
      {
        'icon': Icons.person,
        'text': l10n.profilePersonalHome,
        'onclick': (context) {
          GoRouter.of(context).push(AppRouter.personalHome);
        }
      },
      {'icon': AntDesign.heart_fill, 'text': l10n.profileLikes, 'onclick': (centext) {}},
      {
        'icon': Icons.help_outline,
        'text': l10n.profileFeedback,
        'onclick': (context) {
          GoRouter.of(context).push(AppRouter.feedback);
        }
      },
      {
        'icon': Icons.settings,
        'text': l10n.profileAppSettings,
        'onclick': (context) {
          GoRouter.of(context).push(AppRouter.settings);
        }
      },
      {
        'icon': Icons.info_outline,
        'text': l10n.profileAbout,
        'onclick': (context) {
          GoRouter.of(context).push(AppRouter.about);
        }
      },
    ];

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
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: isLoggedIn
                                ? null
                                : Theme.of(context).colorScheme.primaryContainer,
                          ),
                          child: isLoggedIn
                              ? Avatar(avatarUrl, name: user?.name ?? '')
                              : Center(
                                  child: Icon(
                                    Icons.person,
                                    size: 36,
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  ),
                                ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isLoggedIn ? (user?.name ?? l10n.notSet) : l10n.notLoggedIn,
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
                                  : l10n.tapToLogin,
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
