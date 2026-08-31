import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:nudgee/features/home/presentation/home_page.dart';

/// Centralized GoRouter configuration.
class AppRouter {
  AppRouter._();

  static const String home = '/';
  static const String habits = '/habits';
  static const String finance = '/finance';
  static const String chat = '/chat';
  static const String profile = '/profile';

  static GoRouter build() {
    return GoRouter(
      initialLocation: home,
      routes: [
        GoRoute(
          path: home,
          name: 'home',
          builder: (context, state) => const HomePage(),
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
              onPressed: () => context.go(AppRouter.home),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    );
  }
}
