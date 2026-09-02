import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:nudgee/app/router/route_guard.dart';
import 'package:nudgee/features/auth/presentation/nudgee_auth_page.dart';
import 'package:nudgee/features/auth/presentation/nudgee_auth_widgets.dart';
import 'package:nudgee/features/common/utils/route_observer.dart';
import 'package:nudgee/features/profile/presentation/app_settings_page.dart';
import 'package:nudgee/features/profile/presentation/about_page.dart';
import 'package:nudgee/features/profile/presentation/avatar_upload.dart';
import 'package:nudgee/features/profile/presentation/changelog_page.dart';
import 'package:nudgee/features/profile/presentation/change_nick_name.dart';
import 'package:nudgee/features/profile/presentation/feedback_page.dart';
import 'package:nudgee/features/profile/presentation/my_information.dart';
import 'package:nudgee/features/profile/presentation/personal_home_page.dart';
import 'package:nudgee/features/profile/presentation/privacy_policy_page.dart';
import 'package:nudgee/features/profile/presentation/user_agreement_page.dart';
import 'package:nudgee/features/home/presentation/home_page.dart';
import 'package:nudgee/features/splash/presentation/splash_page.dart';
import 'package:nudgee/features/workspace/presentation/workspace_page.dart';
import 'package:nudgee/core/models/schedule_model.dart';
import 'package:nudgee/core/services/post_service.dart';
import 'package:nudgee/features/campus_forum/presentation/create_post_page.dart';
import 'package:nudgee/features/timetable/presentation/add_schedule_page.dart';

/// Centralized route definitions.
///
/// Routes are defined as a flat list for simplicity. As the app grows,
/// feature-specific routes can be extracted into separate files and
/// merged here.
class AppRouter {
  AppRouter._();

  /// Route name constants for type-safe navigation.
  static const String splash = '/';
  static const String home = '/home';
  static const String settings = '/settings';
  static const String about = '/about';
  static const String feedback = '/feedback';
  static const String privacyPolicy = '/privacyPolicy';
  static const String userAgreement = '/userAgreement';
  static const String changelog = '/changelog';
  static const String login = '/login';
  static const String register = '/register';
  static const String myInformation = '/profile/myInformation';
  static const String changeNickName = '/profile/changeNickName';
  static const String avatarUpload = '/profile/avatarUpload';
  static const String personalHome = '/profile/personalHome';
  static const String workspace = '/workspace';
  static const String addSchedule = '/addSchedule';
  static const String createPost = '/createPost';
  static const String editPost = '/editPost';

  /// Build the [GoRouter] instance.
  ///
  /// An optional [RouteGuard] can be supplied to enforce authentication
  /// redirects. When `null` (the default) no redirect logic is applied.
  static GoRouter build({
    String initialLocation = splash,
    RouteGuard? routeGuard,
  }) {
    return GoRouter(
      initialLocation: initialLocation,
      debugLogDiagnostics: true,
      observers: [appRouteObserver],
      redirect: routeGuard == null
          ? null
          : (context, state) => routeGuard.redirect(context, state),
      routes: [
        GoRoute(
          path: splash,
          name: 'splash',
          builder: (context, state) => const SplashPage(),
        ),
        GoRoute(
          path: home,
          name: 'home',
          builder: (context, state) => const HomePage(),
        ),
        GoRoute(
          path: login,
          name: 'login',
          builder: (context, state) => NudgeeAuthPage(
            initialMode: NudgeeAuthMode.login,
          ),
        ),
        GoRoute(
          path: register,
          name: 'register',
          builder: (context, state) => NudgeeAuthPage(
            initialMode: NudgeeAuthMode.signup,
          ),
        ),
        GoRoute(
          path: myInformation,
          name: 'myInformation',
          builder: (context, state) => const MyInformation(),
        ),
        GoRoute(
          path: changeNickName,
          name: 'changeNickName',
          builder: (context, state) => const ChangeNickName(),
        ),
        GoRoute(
          path: avatarUpload,
          name: 'avatarUpload',
          builder: (context, state) => const AvatarUpload(),
        ),
        GoRoute(
          path: personalHome,
          name: 'personalHome',
          builder: (context, state) {
            // Support optional userId query param to view other users.
            final userId = state.uri.queryParameters['userId'];
            return PersonalHomePage(userId: userId);
          },
        ),
        GoRoute(
          path: workspace,
          name: 'workspace',
          builder: (context, state) => const WorkspacePage(),
        ),
        GoRoute(
          path: settings,
          name: 'settings',
          builder: (context, state) => const AppSettingsPage(),
        ),
        GoRoute(
          path: about,
          name: 'about',
          builder: (context, state) => const AboutPage(),
        ),
        GoRoute(
          path: feedback,
          name: 'feedback',
          builder: (context, state) => const FeedbackPage(),
        ),
        GoRoute(
          path: privacyPolicy,
          name: 'privacyPolicy',
          builder: (context, state) => const PrivacyPolicyPage(),
        ),
        GoRoute(
          path: userAgreement,
          name: 'userAgreement',
          builder: (context, state) => const UserAgreementPage(),
        ),
        GoRoute(
          path: changelog,
          name: 'changelog',
          builder: (context, state) => const ChangelogPage(),
        ),
        GoRoute(
          path: addSchedule,
          name: 'addSchedule',
          builder: (context, state) {
            final editItem = state.extra as ScheduleItem?;
            return AddSchedulePage(editItem: editItem);
          },
        ),
        GoRoute(
          path: createPost,
          name: 'createPost',
          builder: (context, state) => const CreatePostPage(),
        ),
        GoRoute(
          path: editPost,
          name: 'editPost',
          builder: (context, state) {
            final editItem = state.extra as PostItem?;
            return CreatePostPage(editItem: editItem);
          },
        ),
      ],
      errorBuilder: (context, state) => _ErrorPage(error: state.error),
    );
  }
}

/// Fallback error page for unknown routes.
class _ErrorPage extends StatelessWidget {
  final Exception? error;

  const _ErrorPage({this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Page Not Found')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64),
            const SizedBox(height: 16),
            Text(error?.toString() ?? 'Route not found'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go(AppRouter.splash),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    );
  }
}
