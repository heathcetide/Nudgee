import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:nudgee/core/agent/agent.dart';
import 'package:nudgee/core/agent/providers/providers.dart';
import 'package:nudgee/core/agent/skills/skills.dart';
import 'package:nudgee/core/agent/memory/memory.dart';
import 'package:nudgee/core/agent/trace/agent_trace.dart';
import 'package:nudgee/core/config/app_config.dart';
import 'package:nudgee/core/di/injector.dart' as di;
import 'package:nudgee/core/services/local_database_service.dart';
import 'package:nudgee/core/services/permission_service.dart';
import 'package:nudgee/core/services/workspace_service.dart';

/// Agent service — integrates AgentHarness with tools, skills, memory, and LLM config.
///
/// This is the **full agent stack** for the AI assistant "Echo Agent":
/// - Uses [AgentHarness] (wraps [AgentCore] ReAct loop + [Orchestrator])
/// - Has access to all built-in tools (web.search, schedule, post, memory, etc.)
/// - Has access to sandbox execution (sandbox.exec, sandbox.fs)
/// - Uses [SkillRegistry] for multi-step workflow matching (weekly planner, etc.)
/// - Uses [MemoryManager] for long-term user memory injection into system prompt
/// - Uses [AgentTrace] for full execution observability
/// - Emits [AgentEvent]s (thinking, content, tool calls, tool results)
///   so the UI can visualize the full agent process
///
/// Usage:
/// ```dart
/// final agentService = sl<AgentService>();
/// await for (final event in agentService.run('What is the weather?')) {
///   if (event is ThinkingEvent) print('Thinking: ${event.delta}');
///   if (event is ContentEvent) print('Content: ${event.delta}');
///   if (event is ToolCallEvent) print('Tool: ${event.call.name}');
///   if (event is DoneEvent) print('Done: ${event.finalReply}');
/// }
/// ```
class AgentService {
  ToolRegistry? _toolRegistry;
  LLMClient? _llmClient;
  AgentConfig? _agentConfig;
  AgentHarness? _harness;
  SkillRegistry? _skillRegistry;
  MemoryManager? _memoryManager;

  /// Last run's trace (for debugging/observability).
  AgentTrace? _lastTrace;

  /// Optional confirmation handler — set by the UI layer to enable
  /// interactive permission prompts. When a tool requires confirmation,
  /// this handler is called with the tool call and reason.
  /// Return `true` to allow, `false` to deny.
  Future<bool> Function(ToolCall call, String reason)? onConfirmation;

  bool _initialized = false;
  String _currentModel = '';
  List<LlmMessage> _history = [];

  /// Whether the agent service is configured and ready.
  bool get isConfigured => _initialized;

  /// The currently selected model.
  String get currentModel => _currentModel;

  /// Returns the static list of available models from the LLM client.
  List<String> availableModels() {
    return _llmClient?.availableModels() ?? [];
  }

  /// Fetches available models from the API (/v1/models).
  /// Falls back to the static list on error.
  Future<List<String>> fetchModels() async {
    if (_llmClient == null) return [];
    return _llmClient!.fetchModels();
  }

  /// The current system prompt.
  String get currentSystemPrompt => _agentConfig?.systemPrompt ?? '';

  /// The tool registry (for registering additional tools).
  ToolRegistry get toolRegistry => _toolRegistry!;

  /// The skill registry.
  SkillRegistry? get skillRegistry => _skillRegistry;

  /// The memory manager.
  MemoryManager? get memoryManager => _memoryManager;

  /// The last execution trace.
  AgentTrace? get lastTrace => _lastTrace;

  /// The conversation history.
  List<LlmMessage> get history => List.unmodifiable(_history);

  /// Initialize from [AppConfig]. Safe to call multiple times.
  void init() {
    if (_initialized) return;

    try {
      final cfg = AppConfig.ai;
      if (cfg == null || cfg.apiKey.isEmpty) {
        debugPrint('[AgentService] No valid AI config found, service disabled');
        return;
      }

      _currentModel = cfg.model;
      _llmClient = _createLlmClient(cfg);
      _toolRegistry = ToolRegistry();

      // Try to get WorkspaceService from DI (may not be registered yet)
      WorkspaceService? workspace;
      try {
        workspace = di.sl<WorkspaceService>();
      } catch (_) {
        // WorkspaceService not registered — workspace.fs tool will be skipped
      }

      registerBuiltinTools(_toolRegistry!, workspace: workspace);

      // ── Skill Registry ──
      _skillRegistry = SkillRegistry();
      registerBuiltinSkills(_skillRegistry!);

      // ── Memory Manager ──
      // Try to get LocalDatabaseService from DI for persistent storage.
      try {
        final db = di.sl<LocalDatabaseService>();
        final storage = MemoryStorage(db);
        _memoryManager = MemoryManager(
          storage: storage,
          llmClient: _llmClient!,
          llmModel: _currentModel,
          userId: 'default',
        );
        // Load cache asynchronously (non-blocking).
        _memoryManager!.loadCache().catchError((e) {
          debugPrint('[AgentService] MemoryManager loadCache error: $e');
        });
      } catch (e) {
        debugPrint('[AgentService] MemoryManager init skipped: $e');
      }

      _agentConfig = AgentConfig(
        id: 'nudgee-assistant',
        name: 'Echo Agent',
        systemPrompt: ChatServiceSystemPrompt.defaultPrompt,
        model: _currentModel,
        toolNames: builtinToolNames,
        maxSteps: 10,
      );

      // ── Build AgentHarness ──
      // Use PermissionService for live permission mode management.
      // Falls back to bypassPermissions if PermissionService is not registered.
      PermissionContext permContext;
      try {
        permContext = di.sl<PermissionService>().context;
      } catch (_) {
        debugPrint('[AgentService] PermissionService not available, using bypass');
        permContext =
            PermissionContext.fixed(PermissionMode.bypassPermissions);
      }

      _harness = AgentHarness(
        llmClient: _llmClient!,
        toolRegistry: _toolRegistry!,
        skillRegistry: _skillRegistry,
        memoryManager: _memoryManager,
        permissionContext: permContext,
        traceFactory: () => AgentTrace(),
        onConfirmation: onConfirmation,
        llmModel: _currentModel,
      );
      _harness!.registerAgent(_agentConfig!);

      _initialized = true;
      debugPrint('[AgentService] Initialized with model=$_currentModel, '
          'tools=${_toolRegistry!.names.length}, '
          'skills=${_skillRegistry!.length}, '
          'memory=${_memoryManager != null ? "on" : "off"}, '
          'trace=on');
    } catch (e, stack) {
      debugPrint('[AgentService] init() FAILED: $e');
      debugPrint('[AgentService] stack: $stack');
    }
  }

  /// Creates the appropriate LLM client based on config.
  LLMClient _createLlmClient(AiConfig cfg) {
    final provider = cfg.provider.toLowerCase();
    final baseUrl = cfg.baseUrl ?? '';
    final model = cfg.model;
    final apiKey = cfg.apiKey;

    // Try to match by provider name, then by baseUrl, then default to OpenAI-compatible
    switch (provider) {
      case 'anthropic' || 'claude':
        return AnthropicClient(
          apiKey: apiKey,
          baseUrl: baseUrl.isNotEmpty ? baseUrl : 'https://api.anthropic.com/v1',
          defaultModel: model,
        );
      case 'google' || 'gemini' || 'googleai':
        return GoogleAIClient(
          apiKey: apiKey,
          baseUrl: baseUrl.isNotEmpty
              ? baseUrl
              : 'https://generativelanguage.googleapis.com/v1beta',
          defaultModel: model,
        );
      case 'mistral':
        return MistralClient(
          apiKey: apiKey,
          baseUrl: baseUrl.isNotEmpty ? baseUrl : 'https://api.mistral.ai/v1',
          defaultModel: model,
        );
      case 'xai' || 'grok':
        return XAIClient(
          apiKey: apiKey,
          baseUrl: baseUrl.isNotEmpty ? baseUrl : 'https://api.x.ai/v1',
          defaultModel: model,
        );
      case 'ollama':
        return OllamaClient(
          baseUrl: baseUrl.isNotEmpty ? baseUrl : 'http://localhost:11434/v1',
          defaultModel: model,
        );
      case 'deepseek':
        return DeepSeekClientV2(
          apiKey: apiKey,
          baseUrl: baseUrl.isNotEmpty ? baseUrl : 'https://api.deepseek.com/v1',
          defaultModel: model,
        );
      case 'qiniu':
        return QiniuClient(
          apiKey: apiKey,
          baseUrl: baseUrl.isNotEmpty ? baseUrl : 'https://llmapi.qiniu.io/v1',
          defaultModel: model,
        );
      case 'openrouter':
        return OpenRouterClient(
          apiKey: apiKey,
          baseUrl: baseUrl.isNotEmpty ? baseUrl : 'https://openrouter.ai/api/v1',
          defaultModel: model,
        );
      default:
        // Default: OpenAI-compatible (works for OpenAI, Qiniu, LiteLLM, etc.)
        return OpenAICompatibleClient(
          apiKey: apiKey,
          baseUrl: baseUrl.isNotEmpty ? baseUrl : 'https://api.openai.com/v1',
          defaultModel: model,
        );
    }
  }

  /// Runs the agent with [userInput] and yields [AgentEvent]s.
  ///
  /// Uses [AgentHarness.runWithSkills] which:
  /// 1. Matches a skill (if skillRegistry is set)
  /// 2. Executes the skill if matched
  /// 3. Runs the ReAct loop with skill output + memory context
  ///
  /// Events include:
  /// - [ThinkingEvent]: reasoning deltas
  /// - [ContentEvent]: reply text deltas
  /// - [ToolCallEvent]: the agent is calling a tool
  /// - [ToolResultEvent]: a tool finished
  /// - [DoneEvent]: the run completed
  /// - [ErrorEvent]: an error occurred
  Stream<AgentEvent> run(
    String userInput, {
    String? systemPrompt,
    String? extraSystemContext,
  }) {
    if (!_initialized || _harness == null) {
      debugPrint('[AgentService] run() called but not initialized');
      return Stream.error(StateError('AgentService not configured'));
    }

    debugPrint('[AgentService] run() userInput="${userInput.substring(0, userInput.length.clamp(0, 50))}", '
        'model=$_currentModel, history=${_history.length} msgs');

    // Update system prompt if provided
    final effectivePrompt = systemPrompt ?? _agentConfig!.systemPrompt;
    if (effectivePrompt != _agentConfig!.systemPrompt) {
      _agentConfig = AgentConfig(
        id: _agentConfig!.id,
        name: _agentConfig!.name,
        systemPrompt: effectivePrompt,
        model: _currentModel,
        toolNames: _agentConfig!.toolNames,
        maxSteps: _agentConfig!.maxSteps,
      );
      // Re-register the updated config.
      _harness!.registerAgent(_agentConfig!);
    }

    // Pass history WITHOUT the current input — AgentCore adds it internally
    final historyCopy = List<LlmMessage>.from(_history);

    // Track the current input in history for future turns
    _history.add(LlmMessage.user(userInput));

    // Build memory context callback for skill personalization.
    String memoryContext() {
      return _memoryManager?.buildMemoryContext() ?? '';
    }

    // Use runWithSkills for the full flow (skill matching + memory + ReAct).
    return _harness!.runWithSkills(
      userInput: userInput,
      history: historyCopy,
      memoryContext: memoryContext,
      userId: _memoryManager?.userId ?? 'default',
    );
  }

  /// Resets the conversation history and optionally changes the system prompt.
  void reset({String? systemPrompt}) {
    _history.clear();
    if (systemPrompt != null) {
      _agentConfig = AgentConfig(
        id: _agentConfig!.id,
        name: _agentConfig!.name,
        systemPrompt: systemPrompt,
        model: _currentModel,
        toolNames: _agentConfig!.toolNames,
        maxSteps: _agentConfig!.maxSteps,
      );
      _harness?.registerAgent(_agentConfig!);
    }
  }

  /// Adds an assistant reply to the conversation history.
  ///
  /// Called by the UI after a [DoneEvent] to enable multi-turn context.
  void addAssistantHistory(String reply) {
    _history.add(LlmMessage.assistant(text: reply));
  }

  /// Clears conversation context (keeps system prompt).
  void clearContext() {
    _history.clear();
  }

  /// Switches to a different model.
  void switchModel(String model) {
    _currentModel = model;
    _agentConfig = AgentConfig(
      id: _agentConfig!.id,
      name: _agentConfig!.name,
      systemPrompt: _agentConfig!.systemPrompt,
      model: model,
      toolNames: _agentConfig!.toolNames,
      maxSteps: _agentConfig!.maxSteps,
    );
    _harness?.registerAgent(_agentConfig!);
    debugPrint('[AgentService] Switched to model: $model');
  }

  /// Sets the current user ID for memory personalization.
  /// Reloads the memory cache for the new user.
  void setUserId(String userId) {
    if (_memoryManager != null) {
      _memoryManager!.userId = userId;
      _memoryManager!.loadCache().catchError((e) {
        debugPrint('[AgentService] setUserId memory reload error: $e');
      });
    }
  }

  /// Summarizes the current session and extracts long-term memory.
  ///
  /// Call this after a conversation session ends (e.g. on DoneEvent
  /// or when the user leaves the chat) to persist episodic + semantic memory.
  Future<void> persistSessionMemory({
    required DateTime sessionStart,
    required int stepCount,
    List<String> toolsUsed = const [],
  }) async {
    if (_memoryManager == null || _history.isEmpty) return;

    try {
      // 1. Summarize the episode
      final episode = await _memoryManager!.summarizeEpisode(
        messages: _history,
        sessionStart: sessionStart,
        stepCount: stepCount,
        toolsUsed: toolsUsed,
      );
      await _memoryManager!.saveEpisode(episode);

      // 2. Extract long-term memory
      await _memoryManager!.extractLongTerm(
        messages: _history,
        episode: episode,
      );

      debugPrint('[AgentService] Session memory persisted: '
          '${episode.summary.substring(0, 50)}...');
    } catch (e) {
      debugPrint('[AgentService] persistSessionMemory error: $e');
    }
  }

  /// Releases resources.
  void dispose() {
    _llmClient?.dispose();
  }
}

/// System prompt constants for the AI assistant.
class ChatServiceSystemPrompt {
  static const String defaultPrompt =
      '你是 Echo Agent，Nudgee 应用的 AI 助手。你温暖、聪明、有同理心，'
      '擅长帮助用户规划日程、解答问题、提供生活建议。'
      '回复简洁自然，像朋友间的对话。使用用户的语言回复。\n\n'
      '你拥有以下工具，可以在需要时使用：\n'
      '- web.search: 搜索网络获取最新信息 (Wikipedia + DuckDuckGo)\n'
      '- github.search: 搜索 GitHub 仓库/代码/Issues/用户\n'
      '- git: Git 仓库操作 (GitHub/Gitea/GitLab REST API)\n'
      '    读取文件(read)、列目录/分支/提交(list)、写入文件(write)、\n'
      '    删除文件(delete)、多文件原子提交(commit_multi)、\n'
      '    创建分支(create_branch)、创建/合并 PR(create_pr/merge_pr)、\n'
      '    列出 PR/Issue(list_prs/list_issues)、创建 Issue(create_issue)、\n'
      '    仓库信息(repo_info)、创建仓库(create_repo)\n'
      '    需要 config.yaml 配置 git.token\n'
      '- workspace.fs: 在用户本地工作区读写文件 (write/read/list/delete/mkdir)\n'
      '- workspace.js.exec: 在本地执行 JavaScript 代码 (计算/数据处理/算法)\n'
      '- cloud.exec: 在云端沙箱执行代码 (Node.js/Python/Go, 支持 npm install)\n'
      '- schedule.add/query/remove: 管理用户日程\n'
      '- post.create/query/like: 管理动态\n'
      '- memory.save/query: 保存和查询用户记忆\n'
      '- datetime: 获取当前时间/日期、格式化日期、日期加减、计算日期差\n'
      '- tool.search: 搜索可用工具\n\n'
      '当用户问到你不确定的事实、最新事件、或需要计算时，主动使用工具。'
      '当用户问关于开源项目、GitHub 仓库、代码搜索时，使用 github.search。'
      '当用户需要写代码、运行代码、处理数据时，用 workspace.js.exec 执行 JavaScript，'
      '用 workspace.fs 保存代码文件到用户工作区。\n\n'
      '## 工具使用规则（重要）\n'
      '1. 调用工具前可以用一句话简短说明意图，但不要每次都说，更不要重复相同的话。'
      '2. 禁止反复输出"让我写入"/"让我构造完整文件"/"我现在写入"等重复性语句。'
      '3. 如果要写大文件，直接调用 workspace.fs write，不要在文本里预告。'
      '4. 多步骤任务中，只在第一步和最后一步说话，中间步骤直接调用工具。'
      '5. 工具调用之间的文本不超过一句话，且不能和前一步说一样的话。';
}
