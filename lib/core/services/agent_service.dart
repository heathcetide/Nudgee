import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:nudgee/core/agent/agent.dart';
import 'package:nudgee/core/agent/providers/providers.dart';
import 'package:nudgee/core/config/app_config.dart';
import 'package:nudgee/core/di/injector.dart' as di;
import 'package:nudgee/core/services/workspace_service.dart';

/// Agent service — integrates AgentCore with tools, memory, and LLM config.
///
/// This is the **full agent stack** for the AI assistant "星语":
/// - Uses [AgentCore] (ReAct loop) instead of raw LLM streaming
/// - Has access to all built-in tools (web.search, schedule, post, memory, etc.)
/// - Has access to sandbox execution (sandbox.exec, sandbox.fs)
/// - Emits [AgentEvent]s (thinking, content, tool calls, tool results)
///   so the UI can visualize the full agent process
///
/// Compared to [AiService] (which is a thin wrapper around FlutterAI SDK),
/// AgentService provides:
/// - Tool calling (web.search, schedule.add, memory.save, etc.)
/// - Multi-step reasoning (ReAct loop)
/// - Memory integration
/// - Full trace/observability
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
  ContextGovernor? _contextGovernor;

  bool _initialized = false;
  String _currentModel = '';
  List<LlmMessage> _history = [];

  /// Whether the agent service is configured and ready.
  bool get isConfigured => _initialized;

  /// The currently selected model.
  String get currentModel => _currentModel;

  /// The current system prompt.
  String get currentSystemPrompt => _agentConfig?.systemPrompt ?? '';

  /// The tool registry (for registering additional tools).
  ToolRegistry get toolRegistry => _toolRegistry!;

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

      _agentConfig = AgentConfig(
        id: 'nudgee-assistant',
        name: '星语',
        systemPrompt: ChatServiceSystemPrompt.defaultPrompt,
        model: _currentModel,
        toolNames: builtinToolNames,
        maxSteps: 10,
      );

      _contextGovernor = ContextGovernor(
        systemPrompt: _agentConfig!.systemPrompt,
      );

      _initialized = true;
      debugPrint('[AgentService] Initialized with model=$_currentModel, '
          'tools=${_toolRegistry!.names.length}');
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
    if (!_initialized) {
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
      _contextGovernor = ContextGovernor(systemPrompt: effectivePrompt);
    }

    final core = AgentCore(
      config: _agentConfig!,
      llmClient: _llmClient!,
      toolRegistry: _toolRegistry!,
      contextGovernor: _contextGovernor!,
      permissionContext:
          PermissionContext.fixed(PermissionMode.bypassPermissions),
    );

    // Pass history WITHOUT the current input — AgentCore adds it internally
    // (core.run builds: [...history, LlmMessage.user(userInput)])
    final historyCopy = List<LlmMessage>.from(_history);

    // Track the current input in history for future turns
    _history.add(LlmMessage.user(userInput));

    return core.run(
      userInput: userInput,
      history: historyCopy,
      extraSystemContext: extraSystemContext,
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
      _contextGovernor = ContextGovernor(systemPrompt: systemPrompt);
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
    debugPrint('[AgentService] Switched to model: $model');
  }

  /// Releases resources.
  void dispose() {
    _llmClient?.dispose();
  }
}

/// System prompt constants for the AI assistant.
class ChatServiceSystemPrompt {
  static const String defaultPrompt =
      '你是星语，Nudgee 应用的 AI 助手。你温暖、聪明、有同理心，'
      '擅长帮助用户规划日程、解答问题、提供生活建议。'
      '回复简洁自然，像朋友间的对话。使用用户的语言回复。\n\n'
      '你拥有以下工具，可以在需要时使用：\n'
      '- web.search: 搜索网络获取最新信息 (Wikipedia + DuckDuckGo)\n'
      '- github.search: 搜索 GitHub 仓库/代码/Issues/用户\n'
      '- workspace.fs: 在用户本地工作区读写文件 (write/read/list/delete/mkdir)\n'
      '- workspace.js.exec: 在本地执行 JavaScript 代码 (计算/数据处理/算法)\n'
      '- cloud.exec: 在云端沙箱执行代码 (Node.js/Python/Go, 支持 npm install)\n'
      '- schedule.add/query/remove: 管理用户日程\n'
      '- post.create/query/like: 管理动态\n'
      '- memory.save/query: 保存和查询用户记忆\n'
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
