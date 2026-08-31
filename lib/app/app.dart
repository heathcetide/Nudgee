import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nudgee/app/router/app_router.dart';
import 'package:nudgee/app/theme/app_theme.dart';

/// Root application widget.
///
/// Wires up theming and routing.
class NudgeeApp extends ConsumerWidget {
  const NudgeeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = AppRouter.build();

    return MaterialApp.router(
      title: 'Nudgee',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
