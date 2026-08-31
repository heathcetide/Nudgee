import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

import 'package:nudgee/app/router/app_router.dart';
import 'package:nudgee/app/router/route_guard.dart';
import 'package:nudgee/app/theme/app_theme.dart';
import 'package:nudgee/app/theme/locale_controller.dart';
import 'package:nudgee/app/theme/theme_controller.dart';
import 'package:nudgee/core/di/injector.dart';
import 'package:nudgee/core/services/auth_service.dart';

/// Root application widget.
///
/// Wires up theming, routing, localization, and route guards.
class NudgeeApp extends ConsumerWidget {
  const NudgeeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeControllerProvider);
    final locale = ref.watch(localeControllerProvider);

    // Build the route guard with the AuthService from the service locator.
    // When AuthService is not yet registered the guard is omitted so the app
    // remains fully usable during development.
    final routeGuard = _buildRouteGuard();

    final router = AppRouter.build(routeGuard: routeGuard);

    return MaterialApp.router(
      onGenerateTitle: (context) =>
          AppLocalizations.of(context)!.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      locale: locale,
      builder: FlutterSmartDialog.init(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }

  /// Attempt to resolve [AuthService] from the service locator.
  ///
  /// Returns `null` when the service is unavailable so the [RouteGuard] is
  /// skipped entirely (all routes treated as public).
  RouteGuard? _buildRouteGuard() {
    try {
      final auth = sl<AuthService>();
      return RouteGuard(auth);
    } catch (_) {
      return null;
    }
  }
}
