import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:nudgee/core/services/auth_service.dart';

/// Centralized route guard for authentication-based redirects.
///
/// Pass an [AuthService] (or `null` while auth is not yet wired up) and call
/// [redirect] from the [GoRouter] configuration. Routes listed in
/// [_protectedRoutes] require an authenticated user; unauthenticated users are
/// redirected to `/login`, while authenticated users visiting `/login` are
/// redirected to the home route.
class RouteGuard {
  RouteGuard(this.authService);

  /// The auth service — may be `null` while authentication is not yet
  /// implemented. When `null`, all routes are treated as public.
  final AuthService? authService;

  /// Routes that require an authenticated user.
  ///
  /// Note: `/settings`, `/about`, `/feedback`, `/privacyPolicy`,
  /// `/userAgreement` are intentionally public — they are local app
  /// configuration pages that should be accessible without login.
  static const Set<String> _protectedRoutes = <String>{
    '/home',
    '/addSchedule',
    '/profile/myInformation',
    '/profile/changeNickName',
    '/profile/avatarUpload',
    '/profile/personalHome',
  };

  /// GoRouter-compatible redirect callback.
  String? redirect(BuildContext context, GoRouterState state) {
    final isAuthenticated = authService?.isAuthenticated.value ?? false;
    final location = state.matchedLocation;
    final needsAuth = _needsAuth(location);

    // Redirect to login when an auth-protected route is accessed without
    // a valid session.
    if (needsAuth && !isAuthenticated) {
      return '/login';
    }

    // Avoid showing the login page to an already-authenticated user.
    if (location == '/login' && isAuthenticated) {
      return '/';
    }

    return null;
  }

  /// Whether the given [path] requires authentication.
  bool _needsAuth(String path) {
    // Exact match.
    if (_protectedRoutes.contains(path)) return true;
    // Segment match (e.g. /profile/edit matches /profile).
    for (final protected in _protectedRoutes) {
      if (path == protected || path.startsWith('$protected/')) {
        return true;
      }
    }
    return false;
  }
}
