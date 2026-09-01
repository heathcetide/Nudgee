import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'package:nudgee/core/di/injector.dart';
import 'package:nudgee/core/models/prompt_template.dart';
import 'package:nudgee/core/services/file_storage_service.dart';
import 'package:nudgee/core/services/qiniu_storage_service.dart';
import 'package:nudgee/core/services/shared_prefs_service.dart';

/// 提示词模板服务 — 管理预设模板 + 用户自定义模板。
///
/// 数据存储:
/// - 本地: FileStorageService → templates/templates_<userId>.json
/// - 云端: QiniuStorageService → templates/<userId>.json
class PromptTemplateService extends ChangeNotifier {
  final FileStorageService _fileStorage;
  final QiniuStorageService _qiniu;
  final SharedPrefsService _prefs;

  static const String _localDir = 'templates';
  static const String _prefsUserIdKey = 'template_user_id';

  List<PromptTemplate> _templates = [];
  bool _isLoading = false;
  String? _lastError;

  PromptTemplateService({
    required FileStorageService fileStorage,
    required QiniuStorageService qiniu,
    required SharedPrefsService prefs,
  })  : _fileStorage = fileStorage,
        _qiniu = qiniu,
        _prefs = prefs;

  List<PromptTemplate> get templates => _templates;
  List<PromptTemplate> get builtInTemplates =>
      _templates.where((t) => t.isBuiltIn).toList();
  List<PromptTemplate> get customTemplates =>
      _templates.where((t) => !t.isBuiltIn).toList();
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;

  String get _userId => _prefs.getString(_prefsUserIdKey) ?? 'default';
  String get _localFile => 'templates_$_userId.json';
  String get _cloudKey => 'templates/$_userId.json';

  /// 所有分类。
  List<String> get categories {
    final cats = _templates.map((t) => t.category).toSet().toList();
    cats.sort();
    return cats;
  }

  /// 按分类获取模板。
  List<PromptTemplate> getByCategory(String category) =>
      _templates.where((t) => t.category == category).toList();

  void setUserId(String userId) {
    _prefs.setString(_prefsUserIdKey, userId);
    init();
  }

  // ── 初始化 ────────────────────────────────────────────────────────────

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    try {
      // Always load built-in templates first.
      _templates = _builtInTemplates();

      // Load custom templates from local storage.
      final bytes = await _fileStorage.readBytes(_localDir, _localFile);
      if (bytes != null) {
        final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        final custom = (json['templates'] as List?)
                ?.map((e) => PromptTemplate.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        _templates.addAll(custom);
      }
      debugPrint('[PromptTemplate] loaded ${_templates.length} templates');
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[PromptTemplate] init error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── CRUD ──────────────────────────────────────────────────────────────

  /// 添加自定义模板。
  Future<void> addTemplate(PromptTemplate template) async {
    _templates.add(template);
    await _saveCustom();
    notifyListeners();
    _syncToCloud();
  }

  /// 更新自定义模板。
  Future<void> updateTemplate(PromptTemplate template) async {
    final index = _templates.indexWhere((t) => t.id == template.id);
    if (index == -1) return;
    _templates[index] = template;
    await _saveCustom();
    notifyListeners();
    _syncToCloud();
  }

  /// 删除模板（仅自定义模板可删除）。
  Future<void> removeTemplate(String id) async {
    _templates.removeWhere((t) => t.id == id && !t.isBuiltIn);
    await _saveCustom();
    notifyListeners();
    _syncToCloud();
  }

  /// 根据 ID 获取模板。
  PromptTemplate? getById(String id) =>
      _templates.where((t) => t.id == id).firstOrNull;

  // ── 本地存储 ──────────────────────────────────────────────────────────

  Future<void> _saveCustom() async {
    try {
      final custom = customTemplates;
      final json = jsonEncode({'templates': custom.map((t) => t.toJson()).toList()});
      final bytes = Uint8List.fromList(utf8.encode(json));
      await _fileStorage.saveBytes(_localDir, _localFile, bytes);
    } catch (e) {
      debugPrint('[PromptTemplate] _saveCustom error: $e');
    }
  }

  // ── 云端同步 ──────────────────────────────────────────────────────────

  Future<void> syncFromCloud() async {
    if (!_qiniu.isConfigured) return;
    try {
      final bytes = await _qiniu.downloadBytes(_cloudKey);
      if (bytes != null) {
        final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        final custom = (json['templates'] as List?)
                ?.map((e) => PromptTemplate.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        // Replace custom templates, keep built-in.
        _templates = _builtInTemplates()..addAll(custom);
        await _saveCustom();
        notifyListeners();
        debugPrint('[PromptTemplate] synced from cloud: ${custom.length} custom');
      }
    } catch (e) {
      debugPrint('[PromptTemplate] syncFromCloud error: $e');
    }
  }

  Future<void> _syncToCloud() async {
    if (!_qiniu.isConfigured) return;
    try {
      final custom = customTemplates;
      final json = jsonEncode({'templates': custom.map((t) => t.toJson()).toList()});
      final bytes = Uint8List.fromList(utf8.encode(json));
      await _qiniu.uploadBytes(_cloudKey, bytes);
    } catch (e) {
      debugPrint('[PromptTemplate] syncToCloud error: $e');
    }
  }

  // ── 预设模板 ──────────────────────────────────────────────────────────

  List<PromptTemplate> _builtInTemplates() => [
        PromptTemplate(
          id: 'builtin_finance',
          name: '理财专家',
          icon: '💰',
          description: '专业的个人理财顾问，帮你规划预算、分析投资、制定储蓄计划。',
          systemPrompt:
              '你是一位专业的理财顾问，擅长个人预算规划、投资分析和储蓄策略。'
              '请根据用户的具体情况给出务实、可操作的建议。'
              '涉及具体数字时请用表格清晰展示。使用用户的语言回复。',
          category: '生活助手',
          isBuiltIn: true,
          createdAt: DateTime(2026, 1, 1),
        ),
        PromptTemplate(
          id: 'builtin_coding_interview',
          name: '代码面试官',
          icon: '💻',
          description: '模拟技术面试，出题、追问、评价你的代码和思路。',
          systemPrompt:
              '你是一位资深的技术面试官，擅长{{语言}}方向。'
              '请模拟真实面试流程：先出一道中等难度的算法题，等用户作答后给出评价和优化建议。'
              '追问要循序渐进，关注时间/空间复杂度。使用用户的语言回复。',
          category: '学习提升',
          isBuiltIn: true,
          createdAt: DateTime(2026, 1, 1),
        ),
        PromptTemplate(
          id: 'builtin_translate',
          name: '翻译助手',
          icon: '🌐',
          description: '高质量翻译，支持多种语言，保留原文语气和风格。',
          systemPrompt:
              '你是一位专业翻译，请将用户输入的内容翻译为{{目标语言}}。'
              '保持原文的语气、风格和格式。如果原文有文化背景，请适当加注。'
              '只输出翻译结果，不需要解释。',
          category: '效率工具',
          isBuiltIn: true,
          createdAt: DateTime(2026, 1, 1),
        ),
        PromptTemplate(
          id: 'builtin_schedule',
          name: '日程规划师',
          icon: '📅',
          description: '帮你规划每日/每周日程，平衡工作与生活。',
          systemPrompt:
              '你是 Echo Agent 的日程规划模式。请帮用户梳理和规划时间安排。'
              '根据用户的目标和约束，给出具体的时间块建议，并提醒注意休息和效率。'
              '回复格式清晰，用列表或表格呈现。使用用户的语言回复。',
          category: '生活助手',
          isBuiltIn: true,
          createdAt: DateTime(2026, 1, 1),
        ),
        PromptTemplate(
          id: 'builtin_writing',
          name: '写作助手',
          icon: '✍️',
          description: '帮你润色文章、写邮件、拟报告，支持多种风格。',
          systemPrompt:
              '你是一位写作助手，擅长{{文体}}。'
              '请根据用户的需求帮助撰写、润色或改写文本。'
              '注意保持逻辑清晰、语言流畅。如果用户提供了草稿，请在保留核心意思的基础上优化表达。',
          category: '效率工具',
          isBuiltIn: true,
          createdAt: DateTime(2026, 1, 1),
        ),
        PromptTemplate(
          id: 'builtin_baigu',
          name: '八股背诵',
          icon: '📚',
          description: '计算机八股文背诵小助手，出题、检验、讲解。',
          systemPrompt:
              '你是计算机八股文背诵助手，覆盖操作系统、网络、数据库、{{方向}}等方向。'
              '请随机出一道八股文题目让用户回答，用户作答后给出评分和标准答案。'
              '追问要深入底层原理。使用用户的语言回复。',
          category: '学习提升',
          isBuiltIn: true,
          createdAt: DateTime(2026, 1, 1),
        ),
        PromptTemplate(
          id: 'builtin_emotion',
          name: '情感倾听',
          icon: '🫂',
          description: '温暖的倾听者，陪你聊天、解压、梳理情绪。',
          systemPrompt:
              '你是 Echo Agent 的情感倾听模式。请以温暖、不评判的态度倾听用户的心声。'
              '用共情的方式回应，适时给出温和的建议。不要说教，像朋友一样聊天。'
              '使用用户的语言回复。',
          category: '生活助手',
          isBuiltIn: true,
          createdAt: DateTime(2026, 1, 1),
        ),
        PromptTemplate(
          id: 'builtin_brainstorm',
          name: '头脑风暴',
          icon: '💡',
          description: '快速生成创意和方案，激发灵感。',
          systemPrompt:
              '你是一位创意顾问。请针对用户提出的{{主题}}问题，'
              '快速给出 5 个不同角度的创意方案，每个方案附简短说明。'
              '鼓励大胆想法，不急于否定。使用用户的语言回复。',
          category: '效率工具',
          isBuiltIn: true,
          createdAt: DateTime(2026, 1, 1),
        ),
      ];
}
