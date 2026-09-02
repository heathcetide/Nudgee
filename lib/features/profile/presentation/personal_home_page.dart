import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:nudgee/app/router/app_router.dart';
import 'package:nudgee/core/di/injector.dart';
import 'package:nudgee/core/extensions/context_extensions.dart';
import 'package:nudgee/core/services/auth_service.dart';
import 'package:nudgee/features/common/utils/route_observer.dart';
import 'package:nudgee/features/common/widgets/avatar.dart';
import 'package:nudgee/features/common/widgets/page_scaffold.dart';

/// Personal homepage — shows user's public profile card.
///
/// Displays avatar, name, ID, gender, phone in a card layout.
/// Tap "编辑资料" to go to [MyInformation].
///
/// If [userId] is provided, shows that user's profile (read-only, no edit
/// button). Otherwise shows the current logged-in user's profile.
class PersonalHomePage extends StatefulWidget {
  /// Optional user ID to view another user's profile.
  /// If null, shows the current user's own profile.
  final String? userId;

  const PersonalHomePage({super.key, this.userId});

  @override
  State<PersonalHomePage> createState() => _PersonalHomePageState();
}

class _PersonalHomePageState extends State<PersonalHomePage> with RouteAware {
  AuthUser? _user;
  bool _loading = false;

  /// Whether we're viewing another user's profile (not our own).
  bool get _isViewingOther => widget.userId != null;

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
    setState(() => _avatarRefresh++);
  }

  int _avatarRefresh = 0;

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  Future<void> _loadUser() async {
    if (_isViewingOther) {
      // Fetch other user's profile from cloud
      setState(() => _loading = true);
      try {
        final auth = sl<AuthService>();
        final profile = await auth.fetchUserProfile(widget.userId!);
        if (profile != null) {
          setState(() {
            _user = AuthUser(
              id: widget.userId!,
              name: profile['name'] as String? ?? '未知用户',
              avatar: profile['avatar'] as String?,
              gender: profile['gender'] as String?,
              phone: profile['phone'] as String?,
            );
            _loading = false;
          });
        } else {
          // Profile not found — show minimal info from uid
          setState(() {
            _user = AuthUser(id: widget.userId!, name: '未知用户');
            _loading = false;
          });
        }
      } catch (e) {
        setState(() {
          _user = AuthUser(id: widget.userId!, name: '未知用户');
          _loading = false;
        });
      }
    } else {
      // Load current user
      final auth = sl<AuthService>();
      setState(() {
        _user = auth.currentUser.value;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final name = _user?.name ?? l10n.notSet;
    final id = _user?.id ?? '';
    final avatar = _user?.avatar != null && _user!.avatar!.isNotEmpty
        ? '${_user!.avatar}${_user!.avatar!.contains('?') ? '&' : '?'}r=$_avatarRefresh'
        : null;
    final gender = _user?.gender;
    final phone = _user?.phone;

    return PageScaffold(
      title: Text(_isViewingOther ? '用户主页' : l10n.profilePersonalHome),
      leading: getPopLeading(context),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: 24),
                // ── Avatar + Name ──────────────────────────────────────────
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
                      // Name + gender icon
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            name,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (gender != null && gender.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Icon(
                              gender == '男' ? Icons.male : Icons.female,
                              size: 22,
                              color: gender == '男'
                                  ? Colors.blue
                                  : Colors.pink,
                            ),
                          ],
                        ],
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

                // ── Info Cards ─────────────────────────────────────────────
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: ListTile.divideTiles(
                      context: context,
                      tiles: [
                        ListTile(
                          leading: const Icon(Icons.person_outline),
                          title: Text(l10n.infoNickname),
                          trailing: Text(name, style: theme.textTheme.bodyMedium),
                        ),
                        ListTile(
                          leading: const Icon(Icons.wc_outlined),
                          title: Text(l10n.infoGender),
                          trailing: Text(
                            gender ?? l10n.notSet,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        // Only show phone for own profile
                        if (!_isViewingOther)
                          ListTile(
                            leading: const Icon(Icons.phone_outlined),
                            title: Text(l10n.infoPhone),
                            trailing: Text(
                              phone ?? l10n.notSet,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                      ],
                    ).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Edit Button (only for own profile) ─────────────────────
                if (!_isViewingOther)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: FilledButton.tonalIcon(
                      onPressed: () {
                        GoRouter.of(context).push(AppRouter.myInformation);
                      },
                      icon: const Icon(Icons.edit),
                      label: Text(l10n.profileEditInfo),
                    ),
                  ),
              ],
            ),
    );
  }
}
