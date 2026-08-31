import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nudgee/app/app.dart';

/// Nudgee — 自律 · 记账 · AI 陪伴
///
/// Startup flow:
///  1. Ensure Flutter bindings initialized.
///  2. Launch the app inside a [ProviderScope].
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: NudgeeApp()));
}
