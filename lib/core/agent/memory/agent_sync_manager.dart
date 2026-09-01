import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'package:nudgee/core/agent/memory/memory_storage.dart';
import 'package:nudgee/core/services/connectivity_service.dart';
import 'package:nudgee/core/services/qiniu_storage_service.dart';

/// Manages cloud sync for agent memory.
///
/// Sync strategy:
/// - **Upload**: exports all local memory to Qiniu as JSON
/// - **Download**: fetches remote JSON, merges with local via [MemoryStorage.importAll]
/// - **Timing**: on startup, after updates, on network recovery
///
/// Cloud key convention: `agent_memory/<userId>.json`
class AgentSyncManager {
  final QiniuStorageService _qiniu;
  final MemoryStorage _storage;
  final ConnectivityService? _connectivity;

  /// Minimum interval between syncs (to avoid excessive uploads).
  final Duration minSyncInterval;

  DateTime? _lastSyncTime;
  bool _isSyncing = false;

  /// Creates an [AgentSyncManager].
  AgentSyncManager({
    required QiniuStorageService qiniu,
    required MemoryStorage storage,
    ConnectivityService? connectivity,
    this.minSyncInterval = const Duration(seconds: 30),
  })  : _qiniu = qiniu,
        _storage = storage,
        _connectivity = connectivity;

  /// Whether a sync is currently in progress.
  bool get isSyncing => _isSyncing;

  /// When the last sync happened (null if never).
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Cloud storage key for a user.
  String _cloudKey(String userId) => 'agent_memory/$userId.json';

  /// Uploads local memory to cloud.
  ///
  /// Returns true if upload succeeded.
  Future<bool> syncToCloud({String userId = 'default'}) async {
    if (!_qiniu.isConfigured) {
      debugPrint('[AgentSyncManager] syncToCloud skipped — Qiniu not configured');
      return false;
    }
    if (_isSyncing) {
      debugPrint('[AgentSyncManager] syncToCloud skipped — already syncing');
      return false;
    }

    _isSyncing = true;
    try {
      final data = await _storage.exportAll(userId: userId);
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
      final bytes = Uint8List.fromList(utf8.encode(jsonStr));
      final url = await _qiniu.uploadBytes(_cloudKey(userId), bytes);
      if (url != null) {
        _lastSyncTime = DateTime.now();
        debugPrint('[AgentSyncManager] synced to cloud: $url');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[AgentSyncManager] syncToCloud error: $e');
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  /// Downloads cloud memory and merges with local.
  ///
  /// Returns the number of items imported.
  Future<int> syncFromCloud({String userId = 'default'}) async {
    if (!_qiniu.isConfigured) {
      debugPrint('[AgentSyncManager] syncFromCloud skipped — Qiniu not configured');
      return 0;
    }
    if (_isSyncing) {
      debugPrint('[AgentSyncManager] syncFromCloud skipped — already syncing');
      return 0;
    }

    _isSyncing = true;
    try {
      final bytes = await _qiniu.downloadBytes(_cloudKey(userId));
      if (bytes == null) {
        debugPrint('[AgentSyncManager] no cloud data found');
        return 0;
      }
      final jsonStr = utf8.decode(bytes);
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final imported = await _storage.importAll(data, userId: userId);
      _lastSyncTime = DateTime.now();
      debugPrint('[AgentSyncManager] synced from cloud: $imported items imported');
      return imported;
    } catch (e) {
      debugPrint('[AgentSyncManager] syncFromCloud error: $e');
      return 0;
    } finally {
      _isSyncing = false;
    }
  }

  /// Bidirectional sync: download first, then upload merged result.
  ///
  /// This is the recommended sync flow:
  /// 1. Download remote data
  /// 2. Merge with local (importAll handles conflict resolution)
  /// 3. Upload the merged result back to cloud
  Future<SyncResult> sync({String userId = 'default'}) async {
    if (!_qiniu.isConfigured) {
      return const SyncResult(skipped: true, imported: 0, uploaded: false);
    }

    // Check rate limit
    if (_lastSyncTime != null &&
        DateTime.now().difference(_lastSyncTime!) < minSyncInterval) {
      debugPrint('[AgentSyncManager] sync skipped — too soon since last sync');
      return const SyncResult(skipped: true, imported: 0, uploaded: false);
    }

    final imported = await syncFromCloud(userId: userId);
    final uploaded = await syncToCloud(userId: userId);

    return SyncResult(skipped: false, imported: imported, uploaded: uploaded);
  }

  /// Starts listening to connectivity changes and auto-syncs on recovery.
  ///
  /// Call once during app initialization. Returns a stream subscription
  /// that the caller can cancel.
  StreamSubscription<void>? listenToConnectivity() {
    if (_connectivity == null) return null;
    // Trigger sync when network comes back
    return _connectivity.networkStream.listen((networkType) {
      if (networkType != NetworkType.none && networkType != NetworkType.unknown) {
        debugPrint('[AgentSyncManager] network recovered — triggering sync');
        sync();
      }
    });
  }
}

/// Result of a sync operation.
class SyncResult {
  /// Whether the sync was skipped (e.g. not configured, rate limited).
  final bool skipped;

  /// Number of items imported from cloud.
  final int imported;

  /// Whether the upload succeeded.
  final bool uploaded;

  /// Creates a [SyncResult].
  const SyncResult({
    required this.skipped,
    required this.imported,
    required this.uploaded,
  });

  @override
  String toString() =>
      'SyncResult(skipped=$skipped, imported=$imported, uploaded=$uploaded)';
}
