import 'package:flutter/material.dart';

/// App theme definitions.
class AppTheme {
  AppTheme._();

  static const _seed = Color(0xFF6C63FF);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.light,
        ),
        fontFamily: 'SF Pro Display',
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.dark,
        ),
        fontFamily: 'SF Pro Display',
      );
}
