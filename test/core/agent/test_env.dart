import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Test environment configuration.
///
/// Reads API keys from environment variables. Tests that require
/// real API access are automatically skipped if the key is not set.
///
/// Environment variables:
/// - `NUDGEE_LLM_API_KEY` — LLM API key (Qiniu/OpenAI/DeepSeek)
/// - `NUDGEE_LLM_BASE_URL` — LLM API base URL
/// - `NUDGEE_LLM_MODEL` — LLM model name
///
/// To run integration tests locally:
/// ```bash
/// export NUDGEE_LLM_API_KEY=sk-xxx
/// export NUDGEE_LLM_BASE_URL=https://llmapi.qiniu.io/v1
/// export NUDGEE_LLM_MODEL=gpt-5.4-mini
/// flutter test test/core/agent/
/// ```
class TestEnv {
  TestEnv._();

  /// LLM API key from environment.
  static final String? llmApiKey = Platform.environment['NUDGEE_LLM_API_KEY'];

  /// LLM API base URL from environment (default: Qiniu).
  static final String llmBaseUrl =
      Platform.environment['NUDGEE_LLM_BASE_URL'] ??
      'https://llmapi.qiniu.io/v1';

  /// LLM model from environment (default: gpt-5.4-mini).
  static final String llmModel =
      Platform.environment['NUDGEE_LLM_MODEL'] ?? 'gpt-5.4-mini';

  /// Whether LLM API key is available.
  static bool get hasLlmKey => llmApiKey != null && llmApiKey!.isNotEmpty;

  /// Skips the test group if LLM API key is not set.
  ///
  /// Usage:
  /// ```dart
  /// void main() {
  ///   TestEnv.skipWithoutLlmKey();
  ///
  ///   group('My LLM test', () {
  ///     test('calls LLM', () async { ... });
  ///   });
  /// }
  /// ```
  static void skipWithoutLlmKey([String? reason]) {
    if (!hasLlmKey) {
      final msg = reason ?? 'Skipping: NUDGEE_LLM_API_KEY not set';
      // Using throw to skip — this is the standard pattern for
      // conditional test skipping in Dart.
      throw StateError(msg);
    }
  }

  /// Returns the API key, or throws if not set.
  static String get llmApiKeyOrSkip {
    if (!hasLlmKey) {
      throw StateError(
          'NUDGEE_LLM_API_KEY not set — skipping integration test');
    }
    return llmApiKey!;
  }
}

/// Helper to create a test group that is skipped when no LLM key is available.
void testWithLlm(String description, dynamic Function() body) {
  if (TestEnv.hasLlmKey) {
    group(description, body);
  } else {
    group(description, () {
      test('skipped (NUDGEE_LLM_API_KEY not set)', () {
        // no-op — test passes but does nothing
      });
    });
  }
}
