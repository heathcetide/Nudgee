# Nudgee Agent 框架架构设计

> 版本: 0.1 (2026-09-01)
> 状态: 设计阶段

## 1. 设计目标

在 Nudgee 应用内构建一个 **Flutter 原生 Agent 框架**，让 AI 助手不只是问答，而是能：
- **调用工具**：操作日程、发帖、查询数据等
- **自主规划**：多步推理，拆解复杂任务
- **持久记忆**：跨会话记住用户偏好和历史
- **主动推送**：定时提醒、每日报告等
- **多 Agent 协作**：不同专长的 Agent 互相委派任务

### 设计原则

| 原则 | 说明 |
|------|------|
| **Flutter-first** | 纯 Dart 实现，不依赖 Python/Node 后端 |
| **Provider-neutral** | 统一接口，支持 DeepSeek / OpenAI / 本地模型 |
| **渐进式** | 从简单 ReAct 循环开始，逐步增加复杂度 |
| **可观测** | 每一步推理、工具调用都可追踪 |
| **持久化** | Agent 状态可保存恢复，支持后台中断后续接 |

---

## 2. 整体架构

```
┌──────────────────────────────────────────────────────────┐
│                     AgentRuntime                          │
│                   (Agent 运行时入口)                       │
│                                                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐      │
│  │  AgentCore  │  │  AgentCore  │  │  AgentCore  │      │
│  │  (星语)     │  │  (理财专家)  │  │  (代码面试)  │      │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘      │
│         │                │                │              │
│  ┌──────┴────────────────┴────────────────┴──────┐      │
│  │              ReAct Loop (推理循环)              │      │
│  │   Reason → Act (Tool Call) → Observe → Repeat  │      │
│  └──────┬────────────────┬────────────────┬──────┘      │
│         │                │                │              │
│  ┌──────┴──────┐  ┌──────┴──────┐  ┌──────┴──────┐      │
│  │ ToolRegistry│  │   Memory    │  │   Planner   │      │
│  │ (工具注册表) │  │  (记忆系统)  │  │  (规划器)    │      │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘      │
│         │                │                │              │
│  ┌──────┴──────┐  ┌──────┴──────┐  ┌──────┴──────┐      │
│  │   Tools     │  │  Storage    │  │  LLMClient  │      │
│  │ Schedule    │  │  SQLite     │  │  DeepSeek   │      │
│  │ Post        │  │  七牛云      │  │  OpenAI     │      │
│  │ Search      │  │  Vector     │  │  Ollama     │      │
│  │ Notify      │  │             │  │             │      │
│  └─────────────┘  └─────────────┘  └─────────────┘      │
└──────────────────────────────────────────────────────────┘
```

---

## 3. 核心模块

### 3.1 AgentCore — Agent 核心

每个 Agent 是一个独立的 `AgentCore` 实例，拥有自己的：
- **Persona**：人设 (system prompt)
- **Tools**：可用工具集
- **Memory**：记忆实例
- **Model**：使用的 LLM 模型

```dart
/// Agent 核心配置。
class AgentConfig {
  final String id;
  final String name;
  final String icon;           // emoji
  final String systemPrompt;   // 人设
  final String model;          // LLM 模型
  final List<String> toolNames; // 可用工具名
  final double temperature;
  final int maxSteps;          // ReAct 最大循环次数
  final Map<String, dynamic> metadata;
}

/// Agent 运行时核心。
class AgentCore extends ChangeNotifier {
  final AgentConfig config;
  final LLMClient llm;
  final ToolRegistry tools;
  final AgentMemory memory;
  final Planner planner;

  /// 运行一次 Agent 循环，返回流式事件。
  Stream<AgentEvent> run(String userInput);
}
```

### 3.2 ReAct Loop — 推理循环

核心循环：**Reason → Act → Observe → Repeat**

```
用户输入
    ↓
┌──→ Reason (LLM 推理)
│       ↓
│   需要工具? ──否──→ 最终回复 → 结束
│       │是
│       ↓
│   Act (调用工具)
│       ↓
│   Observe (获取结果)
│       ↓
│   结果加入上下文
└─── 循环 (直到 maxSteps 或完成)
```

```dart
/// Agent 事件类型 (流式输出)。
sealed class AgentEvent {
  /// 思考过程 delta
  const factory AgentEvent.thinking(String delta) = ThinkingEvent;
  /// 正文回复 delta
  const factory AgentEvent.content(String delta) = ContentEvent;
  /// 工具调用请求
  const factory AgentEvent.toolCall(ToolCall call) = ToolCallEvent;
  /// 工具执行结果
  const factory AgentEvent.toolResult(String toolName, dynamic result) = ToolResultEvent;
  /// 规划步骤
  const factory AgentEvent.plan(List<String> steps) = PlanEvent;
  /// 完成
  const factory AgentEvent.done(String finalReply) = DoneEvent;
  /// 错误
  const factory AgentEvent.error(String message) = ErrorEvent;
}
```

### 3.3 ToolRegistry — 工具注册表

Agent 通过工具与 App 交互。每个工具是一个标准化的 Dart 函数：

```dart
/// 工具定义。
abstract class AgentTool {
  /// 工具名称 (LLM 可见)
  String get name;
  /// 工具描述 (LLM 据此决定是否调用)
  String get description;
  /// JSON Schema 参数定义
  Map<String, dynamic> get parametersSchema;
  /// 是否需要用户确认 (敏感操作)
  bool get requiresConfirmation => false;

  /// 执行工具
  Future<ToolResult> execute(Map<String, dynamic> args);
}

/// 工具执行结果。
class ToolResult {
  final bool success;
  final String output;        // 文本输出 (给 LLM 看)
  final Map<String, dynamic>? data;  // 结构化数据
  final bool shouldStop;      // 是否终止 Agent 循环
}
```

**预设工具清单：**

| 工具 | 描述 | 需确认 |
|------|------|--------|
| `schedule.add` | 添加日程 | ✅ |
| `schedule.query` | 查询日程 | ❌ |
| `schedule.remove` | 删除日程 | ✅ |
| `post.create` | 发布信息圈帖子 | ✅ |
| `post.query` | 查询最新帖子 | ❌ |
| `post.like` | 点赞帖子 | ❌ |
| `chat.send` | 发送消息到指定会话 | ✅ |
| `weather.query` | 查询天气 | ❌ |
| `web.search` | 网络搜索 | ❌ |
| `notification.schedule` | 安排本地通知 | ❌ |
| `user.profile` | 获取用户信息 | ❌ |
| `memory.save` | 保存长期记忆 | ❌ |

### 3.4 AgentMemory — 记忆系统

三层记忆架构：

```
┌─────────────────────────────────────────┐
│           AgentMemory                    │
├─────────────────────────────────────────┤
│                                         │
│  ┌─────────────┐  短期记忆 (Working)     │
│  │ 当前会话上下文 │  ← 最近 N 轮对话       │
│  │ + 工具结果   │  ← 滑动窗口裁剪         │
│  └──────┬──────┘                        │
│         │ 摘要压缩                        │
│  ┌──────┴──────┐  中期记忆 (Episodic)    │
│  │ 会话摘要     │  ← 每次会话结束生成摘要   │
│  │ + 关键事件   │  ← SQLite 存储          │
│  └──────┬──────┘                        │
│         │ 提取偏好                        │
│  ┌──────┴──────┐  长期记忆 (Semantic)    │
│  │ 用户偏好     │  ← "用户喜欢简洁回复"    │
│  │ + 事实知识   │  ← "用户是前端工程师"    │
│  │             │  ← SQLite + 向量检索    │
│  └─────────────┘                        │
│                                         │
└─────────────────────────────────────────┘
```

```dart
class AgentMemory {
  /// 短期：当前会话消息历史
  final List<Message> workingMemory;

  /// 中期：历史会话摘要
  final List<EpisodeSummary> episodes;

  /// 长期：用户偏好和事实
  final List<MemoryItem> longTerm;

  /// 添加对话消息
  void addMessage(Message msg);

  /// 会话结束时生成摘要
  Future<void> summarizeEpisode();

  /// 提取/更新长期记忆
  Future<void> extractLongTerm(String content);

  /// 构建给 LLM 的上下文 (system prompt + 记忆)
  String buildContext(String userInput);
}
```

### 3.5 Planner — 规划器

对于复杂任务，Agent 先规划再执行：

```dart
abstract class Planner {
  /// 根据用户输入生成执行计划
  Future<List<PlanStep>> plan(String task, AgentCore agent);

  /// 评估是否需要重新规划
  bool shouldReplan(List<PlanStep> steps, int currentIndex);
}

class PlanStep {
  final String description;
  final String? toolName;
  final Map<String, dynamic>? toolArgs;
  bool isCompleted;
  String? result;
}
```

**规划策略：**
- **直答模式**：简单问题直接回复，不规划
- **单步工具**：需要一次工具调用（如查天气）
- **多步规划**：复杂任务拆解为多个步骤
- **动态重规划**：工具结果不符预期时调整计划

### 3.6 LLMClient — 模型客户端

统一接口，屏蔽不同 Provider 差异：

```dart
abstract class LLMClient {
  /// 流式对话 (支持 tool calling)
  Stream<LLMChunk> streamChat({
    required String message,
    required String systemPrompt,
    List<Message> history,
    List<ToolDefinition> tools,
  });

  /// 切换模型
  void switchModel(String model);

  /// 可用模型列表
  List<String> availableModels();
}

/// LLM 流式输出块
class LLMChunk {
  final String? contentDelta;
  final String? thinkingDelta;    // DeepSeek reasoning
  final ToolCall? toolCall;       // 工具调用请求
  final bool isDone;
}
```

---

## 4. 数据流

### 4.1 用户发消息 → Agent 回复

```
用户输入 "帮我安排明天下午的健身计划"
    │
    ▼
AgentRuntime.invoke(agentId, userInput)
    │
    ▼
AgentCore.run(userInput)
    │
    ├──→ Memory.buildContext(input)  // 注入记忆
    │
    ├──→ LLMClient.streamChat(       // 第一次 LLM 调用
    │      message: input,
    │      tools: [schedule.add, ...]
    │    )
    │
    ▼
LLM 返回: tool_call(schedule.add, {date: "明天", time: "14:00", ...})
    │
    ▼
ToolRegistry.execute("schedule.add", args)
    │
    ├──→ 需要确认? → 显示确认对话框 → 用户确认
    │
    ▼
ScheduleService.addSchedule(item)
    │
    ▼
ToolResult(success: true, output: "已添加日程: 健身 14:00-15:00")
    │
    ▼
工具结果加入上下文 → 再次调用 LLM
    │
    ▼
LLM 返回: content("好的！我已经帮你安排了明天下午 2 点的健身...")
    │
    ▼
AgentEvent.done(finalReply)
    │
    ▼
ChatService 持久化消息 → UI 更新
```

### 4.2 Agent 主动推送

```
┌─────────────┐
│ Scheduler    │  (定时任务)
│  每日 8:00   │
└──────┬──────┘
       │
       ▼
AgentCore.run("生成今日日程摘要")
       │
       ├──→ schedule.query(today)
       │
       ▼
LLM 生成摘要
       │
       ▼
ChatService.addAiMessage(摘要)
       │
       ▼
NotificationService.schedule(提醒)
```

---

## 5. 存储设计

### 5.1 SQLite 表结构

```sql
-- Agent 配置
CREATE TABLE agents (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  icon TEXT,
  system_prompt TEXT NOT NULL,
  model TEXT,
  tools TEXT,           -- JSON array of tool names
  temperature REAL DEFAULT 0.7,
  max_steps INTEGER DEFAULT 10,
  is_builtin INTEGER DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT
);

-- Agent 记忆 - 会话摘要 (中期记忆)
CREATE TABLE agent_episodes (
  id TEXT PRIMARY KEY,
  agent_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  summary TEXT NOT NULL,
  key_events TEXT,      -- JSON array
  created_at TEXT NOT NULL,
  FOREIGN KEY (agent_id) REFERENCES agents(id)
);

-- Agent 记忆 - 长期事实 (长期记忆)
CREATE TABLE agent_memories (
  id TEXT PRIMARY KEY,
  agent_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  type TEXT NOT NULL,   -- 'preference' | 'fact' | 'skill'
  content TEXT NOT NULL,
  importance REAL DEFAULT 0.5,
  embedding TEXT,       -- 向量 (JSON array, 后续可换 sqlite-vec)
  created_at TEXT NOT NULL,
  last_accessed TEXT,
  FOREIGN KEY (agent_id) REFERENCES agents(id)
);

-- Agent 执行日志 (可观测)
CREATE TABLE agent_logs (
  id TEXT PRIMARY KEY,
  agent_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  session_id TEXT NOT NULL,
  event_type TEXT NOT NULL,  -- 'thinking' | 'tool_call' | 'tool_result' | 'done'
  content TEXT,
  metadata TEXT,
  step INTEGER,
  created_at TEXT NOT NULL
);
```

### 5.2 云端同步

| 数据 | 本地 | 云端 (七牛) |
|------|------|------------|
| Agent 配置 | SQLite `agents` 表 | `agents/<userId>.json` |
| 会话摘要 | SQLite `agent_episodes` | `agents/episodes_<userId>.json` |
| 长期记忆 | SQLite `agent_memories` | `agents/memories_<userId>.json` |
| 执行日志 | SQLite `agent_logs` | 不同步 (仅本地) |

---

## 6. 目录结构

```
lib/core/agent/
├── agent_runtime.dart          # AgentRuntime — 运行时入口
├── agent_core.dart             # AgentCore — 单个 Agent 核心
├── agent_config.dart           # AgentConfig — Agent 配置模型
├── agent_event.dart            # AgentEvent — 流式事件 (sealed class)
├── agent_memory.dart           # AgentMemory — 三层记忆系统
├── agent_planner.dart          # Planner — 规划器
├── llm_client.dart             # LLMClient — 统一模型接口
├── llm_chunk.dart              # LLMChunk — 流式输出块
│
├── tools/
│   ├── agent_tool.dart         # AgentTool 抽象类
│   ├── tool_registry.dart      # ToolRegistry — 工具注册表
│   ├── tool_result.dart        # ToolResult — 工具结果
│   ├── schedule_tools.dart     # 日程相关工具
│   ├── post_tools.dart         # 信息圈相关工具
│   ├── chat_tools.dart         # 聊天相关工具
│   ├── notification_tools.dart # 通知相关工具
│   └── web_tools.dart          # 网络搜索工具
│
├── memory/
│   ├── episode_summary.dart    # 会话摘要模型
│   ├── memory_item.dart        # 长期记忆模型
│   └── memory_storage.dart     # 记忆持久化 (SQLite)
│
└── providers/
    ├── deepseek_client.dart    # DeepSeek 实现
    ├── openai_client.dart      # OpenAI 兼容实现
    └── ollama_client.dart      # 本地模型实现 (后续)
```

---

## 7. 实现路线图

### Phase 1: 基础框架 (当前)
- [x] `AgentConfig` / `AgentEvent` 模型定义
- [x] `LLMClient` 接口 + DeepSeek 实现
- [x] `AgentTool` 抽象 + `ToolRegistry`
- [x] `AgentCore` + ReAct 循环
- [ ] `AgentMemory` 短期记忆 (会话上下文)
- [ ] 集成到 `ChatPage` (替换当前 `_streamAiReply`)

### Phase 2: 工具系统
- [ ] `schedule.add` / `schedule.query` / `schedule.remove`
- [ ] `post.create` / `post.query`
- [ ] `notification.schedule`
- [ ] 工具调用确认 UI (敏感操作)
- [ ] 工具执行结果展示 UI

### Phase 3: 记忆系统
- [ ] 中期记忆 — 会话摘要生成
- [ ] 长期记忆 — 用户偏好提取
- [ ] 记忆注入 system prompt
- [ ] SQLite 持久化 + 七牛云同步

### Phase 4: 规划器
- [ ] `Planner` 接口 + 直答/单步/多步策略
- [ ] 动态重规划
- [ ] 执行计划 UI 展示

### Phase 5: 多 Agent 协作
- [ ] Agent 间消息传递
- [ ] 任务委派 (`transfer_to_agent`)
- [ ] Agent 商店 (用户可添加新 Agent)

### Phase 6: 主动推送
- [ ] 定时调度器
- [ ] 后台 Agent 执行
- [ ] 推送通知集成

---

## 8. 与现有架构的集成

### 8.1 ChatService 集成

```
ChatPage._onSend(conv, text)
    │
    ├──→ ChatService.sendMessage()     // 持久化用户消息
    │
    ├──→ 判断是否 AI 会话
    │         │
    │         ▼ 是
    │    AgentRuntime.run(agentId, text)
    │         │
    │         ▼ Stream<AgentEvent>
    │    ┌────┴────┐
    │    │ thinking │ → 更新 bubble metadata (流式)
    │    │ content  │ → 更新 bubble text (流式)
    │    │ toolCall │ → 显示工具调用卡片
    │    │ done     │ → ChatService.addAiMessage() 持久化
    │    └─────────┘
    │
    └──→ UI 更新
```

### 8.2 PromptTemplateService 集成

提示词模板直接映射为 `AgentConfig`：
- 模板的 `systemPrompt` → Agent 的人设
- 模板的 `variables` → Agent 配置参数
- 选择模板 = 创建新 Agent 会话

### 8.3 DI 注册

```dart
// injector.dart
_safeRegister(() => sl.registerLazySingleton<AgentRuntime>(
  () => AgentRuntime(
    llm: sl<LLMClient>(),
    tools: sl<ToolRegistry>(),
    chatService: sl<ChatService>(),
    scheduleService: sl<ScheduleService>(),
  ),
));
```

---

## 9. 安全与边界

| 风险 | 对策 |
|------|------|
| Agent 无限循环 | `maxSteps` 限制 (默认 10) + 循环检测 |
| 敏感操作未授权 | `requiresConfirmation` → 用户确认对话框 |
| 上下文溢出 | 滑动窗口裁剪 + 会话摘要压缩 |
| 工具执行异常 | try-catch + 错误结果回传 LLM 重试 |
| API 费用失控 | token 用量追踪 + 每日限额 |
| 隐私泄露 | 本地工具不传敏感数据到 LLM, 仅传结果摘要 |

---

## 10. 参考项目

| 项目 | 语言 | 借鉴点 |
|------|------|--------|
| [Vantura](https://pub.dev/packages/vantura) | Dart/Flutter | ReAct 循环、双层记忆、检查点 |
| [Akashi Agents](https://github.com/AleSZanello/akashi_agents) | Dart | 多 Agent 编排、durable 执行 |
| [dart_agent_core](https://pub.dev/packages/dart_agent_core) | Dart | 工具系统、MCP 支持、Agent evals |
| [flutter_agentic](https://pub.dev/packages/flutter_agentic) | Dart/Flutter | 多 Provider 路由、安全层 |
| [LangGraph](https://github.com/langchain-ai/langgraph) | Python | ReAct 模式、State/Node/Edge |
| [Omnigent](https://github.com/francescostabile/omnigent) | Python | 推理图、分层规划、错误恢复 |
