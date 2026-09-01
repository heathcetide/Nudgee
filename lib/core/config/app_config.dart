import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:yaml/yaml.dart';

/// Application environment configuration.
///
/// Compile-time values are injected via `--dart-define`.
/// Runtime secrets (Qiniu keys, etc.) are loaded from `config.yaml`
/// (git-ignored, bundled as an asset).
///
/// Example:
/// ```sh
/// flutter run --dart-define=ENV=dev --dart-define=API_BASE_URL=http://...
/// ```
class AppConfig {
  AppConfig._();

  // ── Compile-time config (--dart-define) ──────────────────────────────

  /// Current environment: `dev` | `staging` | `prod`
  static const String env = String.fromEnvironment('ENV', defaultValue: 'dev');

  /// API base URL for the Go control/signaling plane.
  static const String apiBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8080');

  /// WebSocket signaling URL.
  static const String wsUrl =
      String.fromEnvironment('WS_URL', defaultValue: 'ws://localhost:8080/ws');

  /// WebRTC ICE servers (comma-separated STUN/TURN URLs).
  static const String iceServers = String.fromEnvironment(
    'ICE_SERVERS',
    defaultValue: 'stun:stun.l.google.com:19302',
  );

  /// App name shown in UI.
  static const String appName = String.fromEnvironment('APP_NAME', defaultValue: 'Nudgee');

  /// App version.
  static const String appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');

  // ── Environment helpers ──────────────────────────────────────────────

  static bool get isDev => env == 'dev';
  static bool get isStaging => env == 'staging';
  static bool get isProd => env == 'prod';

  /// Whether verbose logging should be enabled.
  static bool get enableVerboseLogging => !isProd;

  /// Parsed list of ICE server URLs.
  static List<String> get iceServerList =>
      iceServers.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  // ── Runtime config (config.yaml) ─────────────────────────────────────

  static StorageConfig? _storage;
  static AiConfig? _ai;
  static String? _sandboxApiBaseUrl;
  static GitConfig? _git;
  static bool _configLoaded = false;

  /// Load runtime config from `assets/config.yaml`.
  /// Call once at app startup before using [storage].
  static Future<void> load() async {
    if (_configLoaded) return;
    try {
      final yamlStr = await rootBundle.loadString('assets/config/config.yaml');
      final doc = loadYaml(yamlStr) as YamlMap;
      final storage = doc['storage'] as YamlMap?;
      if (storage != null) {
        _storage = StorageConfig.fromYaml(storage);
      }
      final ai = doc['ai'] as YamlMap?;
      if (ai != null) {
        _ai = AiConfig.fromYaml(ai);
      }
      final sandbox = doc['sandbox'] as YamlMap?;
      if (sandbox != null) {
        _sandboxApiBaseUrl = sandbox['apiBaseUrl'] as String?;
      }
      final git = doc['git'] as YamlMap?;
      if (git != null) {
        _git = GitConfig.fromYaml(git);
      }
    } catch (e) {
      debugPrint('[AppConfig] Failed to load config.yaml: $e');
    }
    _configLoaded = true;
  }

  /// Storage configuration, or `null` if not loaded / missing.
  static StorageConfig? get storage => _storage;

  /// Whether storage config is available.
  static bool get hasStorage => _storage != null;

  /// AI configuration, or `null` if not loaded / missing.
  static AiConfig? get ai => _ai;

  /// Whether AI config is available.
  static bool get hasAi => _ai != null;

  /// Cloud sandbox API base URL, or `null` if not configured.
  static String? get sandboxApiBaseUrl => _sandboxApiBaseUrl;

  /// Whether cloud sandbox is configured.
  static bool get hasSandbox =>
      _sandboxApiBaseUrl != null && _sandboxApiBaseUrl!.isNotEmpty;

  /// Git configuration, or `null` if not loaded / missing.
  static GitConfig? get git => _git;

  /// Whether git config is available.
  static bool get hasGit => _git != null && _git!.token.isNotEmpty;
}

/// Storage configuration loaded from `config.yaml`.
class StorageConfig {
  final String kind;
  final String qiniuAccessKey;
  final String qiniuSecretKey;
  final String qiniuBucket;
  final String qiniuDomain;
  final bool qiniuPrivate;
  final String qiniuRegion;

  const StorageConfig({
    required this.kind,
    required this.qiniuAccessKey,
    required this.qiniuSecretKey,
    required this.qiniuBucket,
    required this.qiniuDomain,
    required this.qiniuPrivate,
    required this.qiniuRegion,
  });

  factory StorageConfig.fromYaml(YamlMap map) {
    return StorageConfig(
      kind: map['kind'] as String? ?? 'qiniu',
      qiniuAccessKey: map['qiniuAccessKey'] as String? ?? '',
      qiniuSecretKey: map['qiniuSecretKey'] as String? ?? '',
      qiniuBucket: map['qiniuBucket'] as String? ?? '',
      qiniuDomain: map['qiniuDomain'] as String? ?? '',
      qiniuPrivate: map['qiniuPrivate'] as bool? ?? false,
      qiniuRegion: map['qiniuRegion'] as String? ?? 'huanan',
    );
  }
}

/// AI configuration loaded from `config.yaml`.
class AiConfig {
  final String provider;
  final String apiKey;
  final String model;
  final String? baseUrl;
  final String? systemPrompt;

  const AiConfig({
    required this.provider,
    required this.apiKey,
    required this.model,
    this.baseUrl,
    this.systemPrompt,
  });

  factory AiConfig.fromYaml(YamlMap map) {
    return AiConfig(
      provider: map['provider'] as String? ?? 'deepseek',
      apiKey: map['apiKey'] as String? ?? '',
      model: map['model'] as String? ?? 'deepseek-chat',
      baseUrl: map['baseUrl'] as String?,
      systemPrompt: map['systemPrompt'] as String?,
    );
  }
}

/// Git configuration loaded from `config.yaml`.
///
/// Supports GitHub and Gitea/GitLab (any REST API compatible provider).
/// ```yaml
/// git:
///   provider: github   # github | gitea | gitlab
///   token: ghp_xxxxx
///   apiUrl: https://api.github.com   # optional, default per provider
///   defaultOwner: myusername         # optional default owner for ops
/// ```
class GitConfig {
  final String provider;
  final String token;
  final String apiUrl;
  final String? defaultOwner;

  const GitConfig({
    required this.provider,
    required this.token,
    required this.apiUrl,
    this.defaultOwner,
  });

  factory GitConfig.fromYaml(YamlMap map) {
    final provider = map['provider'] as String? ?? 'github';
    return GitConfig(
      provider: provider,
      token: map['token'] as String? ?? '',
      apiUrl: map['apiUrl'] as String? ??
          switch (provider) {
            'gitea' => 'https://gitea.com/api/v1',
            'gitlab' => 'https://gitlab.com/api/v4',
            _ => 'https://api.github.com',
          },
      defaultOwner: map['defaultOwner'] as String?,
    );
  }
}
