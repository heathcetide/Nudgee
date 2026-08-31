import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nudgee/app/app.dart';
import 'package:nudgee/core/di/injector.dart';
import 'package:nudgee/core/services/app_initializer.dart';
import 'package:nudgee/core/services/crash_handler.dart';
import 'package:nudgee/core/services/frame_timing_monitor_service.dart';

/// Nudgee entry point.
///
/// Startup flow:
///  1. Ensure Flutter bindings are initialized.
///  2. Install the global [CrashHandler] (FlutterError + PlatformDispatcher).
///  3. Run the [AppInitializer] orchestration (registers & runs init tasks).
///  4. Start frame jank monitoring.
///  5. Launch the app.
///
/// Note: [runZonedGuarded] is intentionally NOT used to wrap [runApp] because
/// it causes a "Zone mismatch" warning — the bindings are initialized in the
/// root zone but runApp would run in the guarded zone. Instead, async errors
/// are caught by [CrashHandler] via [PlatformDispatcher.onError].
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  CrashHandler.instance.init();

  final initializer = AppInitializer()
    ..addTask(const InitTask(
      name: 'dependencies',
      type: InitTaskType.async,
      required: false,
      timeout: Duration(seconds: 10),
      task: initDependencies,
    ));

  final result = await initializer.runAll();
  initializer.dispose();

  if (!result.success) {
    debugPrint('Init failed tasks: ${result.failedTasks}');
  }

  // Start frame jank monitoring (safe to skip if not registered).
  try {
    sl<FrameTimingMonitorService>().start();
  } catch (_) {}

  runApp(const ProviderScope(child: NudgeeApp()));
}
