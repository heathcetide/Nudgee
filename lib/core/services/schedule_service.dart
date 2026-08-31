import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'package:nudgee/core/di/injector.dart';
import 'package:nudgee/core/errors/app_exception.dart';
import 'package:nudgee/core/models/schedule_model.dart';
import 'package:nudgee/core/services/file_storage_service.dart';
import 'package:nudgee/core/services/notification_service.dart';
import 'package:nudgee/core/services/qiniu_storage_service.dart';
import 'package:nudgee/core/services/shared_prefs_service.dart';

/// 日程服务 — 本地存储 + 七牛云对象存储同步。
///
/// 数据流：
///   1. 本地优先：读写 `FileStorageService` 的 `schedules/schedules.json`
///   2. 云端同步：上传/下载 `schedules/<userId>.json` 到七牛云
///   3. 启动时拉取云端，合并本地（云端覆盖本地）
///
/// 使用方式：
///   final service = sl<ScheduleService>();
///   await service.init();           // 加载本地数据
///   await service.syncFromCloud();  // 从云端同步
///   service.addSchedule(item);      // 添加日程（自动保存本地 + 上传云端）
///   final data = service.scheduleData;
class ScheduleService extends ChangeNotifier {
  final FileStorageService _fileStorage;
  final QiniuStorageService _qiniu;
  final SharedPrefsService _prefs;

  static const String _localDir = 'schedules';
  static const String _prefsLastSyncKey = 'schedule_last_sync';
  static const String _prefsUserIdKey = 'schedule_user_id';

  ScheduleData _data = const ScheduleData();
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _lastError;

  ScheduleService({
    required FileStorageService fileStorage,
    required QiniuStorageService qiniu,
    required SharedPrefsService prefs,
  })  : _fileStorage = fileStorage,
        _qiniu = qiniu,
        _prefs = prefs;

  /// 当前日程数据。
  ScheduleData get scheduleData => _data;

  /// 是否正在加载。
  bool get isLoading => _isLoading;

  /// 是否正在同步。
  bool get isSyncing => _isSyncing;

  /// 最后的错误信息。
  String? get lastError => _lastError;

  /// 当前用户 ID（用于云端 key）。
  String get _userId => _prefs.getString(_prefsUserIdKey) ?? 'default';
  void setUserId(String userId) {
    _prefs.setString(_prefsUserIdKey, userId);
    // Reload data for the new user.
    init();
  }

  /// 云端存储 key。
  String get _cloudKey => 'schedules/$_userId.json';

  /// 本地文件名（按用户区分）。
  String get _localFile => 'schedules_$_userId.json';

  // ── 初始化 ────────────────────────────────────────────────────────────

  /// 加载本地数据。在 app 启动时调用。
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    try {
      final bytes = await _fileStorage.readBytes(_localDir, _localFile);
      if (bytes != null) {
        final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        _data = ScheduleData.fromJson(json);
        debugPrint('[ScheduleService] loaded ${_data.byDate.length} days from local');
      }
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[ScheduleService] init error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── 云端同步 ──────────────────────────────────────────────────────────

  /// 从云端拉取数据，覆盖本地。
  ///
  /// 如果七牛未配置或下载失败，保持本地数据不变。
  Future<void> syncFromCloud() async {
    if (!_qiniu.isConfigured) {
      debugPrint('[ScheduleService] syncFromCloud skipped — Qiniu not configured');
      return;
    }
    _isSyncing = true;
    notifyListeners();
    try {
      final bytes = await _qiniu.downloadBytes(_cloudKey);
      if (bytes != null) {
        final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        _data = ScheduleData.fromJson(json);
        await _saveLocal();
        await _prefs.setString(_prefsLastSyncKey, DateTime.now().toIso8601String());
        debugPrint('[ScheduleService] synced from cloud: ${_data.byDate.length} days');
      }
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[ScheduleService] syncFromCloud error: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// 上传本地数据到云端。
  Future<void> syncToCloud() async {
    if (!_qiniu.isConfigured) {
      debugPrint('[ScheduleService] syncToCloud skipped — Qiniu not configured');
      return;
    }
    try {
      final jsonStr = jsonEncode(_data.toJson());
      final bytes = Uint8List.fromList(utf8.encode(jsonStr));
      final url = await _qiniu.uploadBytes(_cloudKey, bytes);
      if (url != null) {
        await _prefs.setString(_prefsLastSyncKey, DateTime.now().toIso8601String());
        debugPrint('[ScheduleService] synced to cloud: $url');
      }
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[ScheduleService] syncToCloud error: $e');
    }
  }

  // ── CRUD ──────────────────────────────────────────────────────────────

  /// 添加日程。自动保存本地 + 上传云端。
  Future<void> addSchedule(ScheduleItem item) async {
    final byDate = Map<String, List<ScheduleItem>>.from(_data.byDate);
    final dateItems = List<ScheduleItem>.from(byDate[item.date] ?? []);
    dateItems.add(item);
    byDate[item.date] = dateItems;
    _data = ScheduleData(byDate: byDate);

    await _saveLocal();
    // Schedule local notification + reminder sound.
    try {
      await sl<NotificationService>().scheduleNotification(item);
    } catch (e) {
      debugPrint('[ScheduleService] scheduleNotification error: $e');
    }
    notifyListeners();
    // Cloud sync is best-effort, don't block UI.
    syncToCloud();
  }

  /// 删除指定日程。
  Future<void> removeSchedule(String date, String itemId) async {
    final byDate = Map<String, List<ScheduleItem>>.from(_data.byDate);
    final dateItems = byDate[date];
    if (dateItems == null) return;
    // Cancel notification before removing.
    try {
      await sl<NotificationService>().cancelById(itemId);
    } catch (e) {
      debugPrint('[ScheduleService] cancelNotification error: $e');
    }
    dateItems.removeWhere((e) => e.id == itemId);
    if (dateItems.isEmpty) {
      byDate.remove(date);
    } else {
      byDate[date] = dateItems;
    }
    _data = ScheduleData(byDate: byDate);

    await _saveLocal();
    notifyListeners();
    syncToCloud();
  }

  /// 更新指定日程。
  Future<void> updateSchedule(ScheduleItem item) async {
    final byDate = Map<String, List<ScheduleItem>>.from(_data.byDate);
    final dateItems = byDate[item.date];
    if (dateItems == null) return;
    final index = dateItems.indexWhere((e) => e.id == item.id);
    if (index == -1) return;
    dateItems[index] = item;
    byDate[item.date] = dateItems;
    _data = ScheduleData(byDate: byDate);

    await _saveLocal();
    notifyListeners();
    syncToCloud();
  }

  /// 获取某天的日程列表（fixed + extra 合并，按时间排序）。
  List<ScheduleItem> getForDate(String date) => _data.getForDate(date);

  /// 获取某天的日程，按 timetable UI 的 Map 格式返回。
  Map<String, dynamic> getForDateAsMap(String date) => _data.getForDateAsMap(date);

  /// 清空所有日程。
  Future<void> clearAll() async {
    _data = const ScheduleData();
    await _saveLocal();
    notifyListeners();
    syncToCloud();
  }

  // ── 内部方法 ──────────────────────────────────────────────────────────

  Future<void> _saveLocal() async {
    try {
      final jsonStr = jsonEncode(_data.toJson());
      final bytes = Uint8List.fromList(utf8.encode(jsonStr));
      await _fileStorage.saveBytes(_localDir, _localFile, bytes);
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[ScheduleService] _saveLocal error: $e');
      throw StorageException('Failed to save schedule data', originalError: e);
    }
  }
}
