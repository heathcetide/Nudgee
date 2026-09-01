import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:nudgee/core/services/shared_prefs_service.dart';

import 'package:nudgee/core/di/injector.dart';
import 'package:nudgee/core/services/file_storage_service.dart';
import 'package:nudgee/core/services/qiniu_storage_service.dart';

/// 帖子数据模型。
class PostItem {
  final String id;
  final String posterUid;
  final String posterName;
  final String posterAvatar;
  final String content;
  final List<String> images;
  final DateTime time;
  int likeCount;
  int commentCount;
  bool isLiked;
  List<Map<String, dynamic>> displayLikeUserList;
  List<Map<String, dynamic>> displayCommentList;

  PostItem({
    required this.id,
    required this.posterUid,
    required this.posterName,
    required this.posterAvatar,
    required this.content,
    required this.images,
    required this.time,
    this.likeCount = 0,
    this.commentCount = 0,
    this.isLiked = false,
    this.displayLikeUserList = const [],
    this.displayCommentList = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'posterUid': posterUid,
        'posterName': posterName,
        'posterAvatar': posterAvatar,
        'content': content,
        'images': images,
        'time': time.toIso8601String(),
        'likeCount': likeCount,
        'commentCount': commentCount,
        'isLiked': isLiked,
        'displayLikeUserList': displayLikeUserList,
        'displayCommentList': displayCommentList,
      };

  factory PostItem.fromJson(Map<String, dynamic> json) => PostItem(
        id: json['id'] as String? ?? '',
        posterUid: json['posterUid']?.toString() ?? '',
        posterName: json['posterName'] as String? ?? '',
        posterAvatar: json['posterAvatar'] as String? ?? '',
        content: json['content'] as String? ?? '',
        images: (json['images'] as List?)?.map((e) => e.toString()).toList() ?? [],
        time: DateTime.tryParse(json['time'] as String? ?? '') ?? DateTime.now(),
        likeCount: json['likeCount'] as int? ?? 0,
        commentCount: json['commentCount'] as int? ?? 0,
        isLiked: json['isLiked'] as bool? ?? false,
        displayLikeUserList:
            (json['displayLikeUserList'] as List?)?.map((e) => e as Map<String, dynamic>).toList() ?? [],
        displayCommentList:
            (json['displayCommentList'] as List?)?.map((e) => e as Map<String, dynamic>).toList() ?? [],
      );

  /// 转换为 campus_discover UI 所需的 Map 格式。
  Map<String, dynamic> toUIMap() => {
        'posterUid': posterUid,
        'posterName': posterName,
        'posterAvatar': posterAvatar,
        'content': content,
        'time': time,
        'isLiked': isLiked,
        'likeCount': likeCount,
        'commentCount': commentCount,
        'displayLikeUserList': displayLikeUserList,
        'displayCommentList': displayCommentList,
        'imageList': images,
      };
}

/// 帖子集合。
class PostData {
  final List<PostItem> posts;
  const PostData({this.posts = const []});

  Map<String, dynamic> toJson() => {
        'posts': posts.map((e) => e.toJson()).toList(),
      };

  factory PostData.fromJson(Map<String, dynamic> json) => PostData(
        posts: (json['posts'] as List?)
                ?.map((e) => PostItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

/// 帖子服务 — 管理信息圈帖子的本地持久化 + 七牛云同步。
///
/// 数据存储:
/// - 本地: FileStorageService → posts/posts_<userId>.json
/// - 云端: QiniuStorageService → posts/<userId>.json
class PostService extends ChangeNotifier {
  final FileStorageService _fileStorage;
  final QiniuStorageService _qiniu;
  final SharedPrefsService _prefs;

  static const String _localDir = 'posts';
  static const String _prefsUserIdKey = 'post_user_id';
  static const String _prefsLastSyncKey = 'post_last_sync';

  PostData _data = const PostData();
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _lastError;

  PostService({
    required FileStorageService fileStorage,
    required QiniuStorageService qiniu,
    required SharedPrefsService prefs,
  })  : _fileStorage = fileStorage,
        _qiniu = qiniu,
        _prefs = prefs;

  // ── Getters ───────────────────────────────────────────────────────────

  List<PostItem> get posts => _data.posts;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get lastError => _lastError;

  /// 当前用户 ID。
  String get _userId => _prefs.getString(_prefsUserIdKey) ?? 'default';
  void setUserId(String userId) {
    _prefs.setString(_prefsUserIdKey, userId);
    init();
  }

  /// 本地文件名（按用户区分）。
  String get _localFile => 'posts_$_userId.json';

  /// 云端存储 key。
  String get _cloudKey => 'posts/$_userId.json';

  // ── 初始化 ────────────────────────────────────────────────────────────

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    try {
      final bytes = await _fileStorage.readBytes(_localDir, _localFile);
      if (bytes != null) {
        final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        _data = PostData.fromJson(json);
        debugPrint('[PostService] loaded ${_data.posts.length} posts from local');
      }
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[PostService] init error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── 云端同步 ──────────────────────────────────────────────────────────

  Future<void> syncFromCloud() async {
    if (!_qiniu.isConfigured) return;
    _isSyncing = true;
    notifyListeners();
    try {
      final bytes = await _qiniu.downloadBytes(_cloudKey);
      if (bytes != null) {
        final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        _data = PostData.fromJson(json);
        await _saveLocal();
        debugPrint('[PostService] synced from cloud: ${_data.posts.length} posts');
      }
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[PostService] syncFromCloud error: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> syncToCloud() async {
    if (!_qiniu.isConfigured) return;
    try {
      final jsonStr = jsonEncode(_data.toJson());
      final bytes = Uint8List.fromList(utf8.encode(jsonStr));
      final url = await _qiniu.uploadBytes(_cloudKey, bytes);
      if (url != null) {
        await _prefs.setString(_prefsLastSyncKey, DateTime.now().toIso8601String());
        debugPrint('[PostService] synced to cloud: $url');
      }
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[PostService] syncToCloud error: $e');
    }
  }

  // ── 本地存储 ──────────────────────────────────────────────────────────

  Future<void> _saveLocal() async {
    try {
      final jsonStr = jsonEncode(_data.toJson());
      final bytes = Uint8List.fromList(utf8.encode(jsonStr));
      await _fileStorage.saveBytes(_localDir, _localFile, bytes);
    } catch (e) {
      debugPrint('[PostService] _saveLocal error: $e');
    }
  }

  // ── CRUD ──────────────────────────────────────────────────────────────

  /// 发布帖子。自动保存本地 + 上传云端。
  Future<void> addPost(PostItem item) async {
    final posts = [item, ..._data.posts];
    _data = PostData(posts: posts);
    await _saveLocal();
    notifyListeners();
    syncToCloud();
  }

  /// 删除帖子。
  Future<void> removePost(String postId) async {
    final posts = _data.posts.where((e) => e.id != postId).toList();
    _data = PostData(posts: posts);
    await _saveLocal();
    notifyListeners();
    syncToCloud();
  }

  /// 点赞/取消点赞。
  Future<void> toggleLike(String postId, String userId, String userName) async {
    final posts = _data.posts.map((e) {
      if (e.id == postId) {
        final newLikeList = List<Map<String, dynamic>>.from(e.displayLikeUserList);
        if (e.isLiked) {
          newLikeList.removeWhere((u) => u['uid']?.toString() == userId);
          e.likeCount = (e.likeCount - 1).clamp(0, 99999);
        } else {
          newLikeList.insert(0, {'uid': userId, 'name': userName});
          e.likeCount = e.likeCount + 1;
        }
        return PostItem(
          id: e.id,
          posterUid: e.posterUid,
          posterName: e.posterName,
          posterAvatar: e.posterAvatar,
          content: e.content,
          images: e.images,
          time: e.time,
          likeCount: e.likeCount,
          commentCount: e.commentCount,
          isLiked: !e.isLiked,
          displayLikeUserList: newLikeList,
          displayCommentList: e.displayCommentList,
        );
      }
      return e;
    }).toList();
    _data = PostData(posts: posts);
    await _saveLocal();
    notifyListeners();
    syncToCloud();
  }

  /// 添加评论。
  Future<void> addComment(String postId, Map<String, dynamic> comment) async {
    final posts = _data.posts.map((e) {
      if (e.id == postId) {
        final newComments = [...e.displayCommentList, comment];
        return PostItem(
          id: e.id,
          posterUid: e.posterUid,
          posterName: e.posterName,
          posterAvatar: e.posterAvatar,
          content: e.content,
          images: e.images,
          time: e.time,
          likeCount: e.likeCount,
          commentCount: e.commentCount + 1,
          isLiked: e.isLiked,
          displayLikeUserList: e.displayLikeUserList,
          displayCommentList: newComments,
        );
      }
      return e;
    }).toList();
    _data = PostData(posts: posts);
    await _saveLocal();
    notifyListeners();
    syncToCloud();
  }

  /// 获取所有帖子的 UI Map 格式列表（按时间降序）。
  List<Map<String, dynamic>> getPostsAsUIMap() {
    final sorted = List<PostItem>.from(_data.posts)
      ..sort((a, b) => b.time.compareTo(a.time));
    return sorted.map((e) => e.toUIMap()).toList();
  }
}
