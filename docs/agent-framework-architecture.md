# Nudgee Agent 框架架构设计

> 版本: 0.4 (2026-09-01)
> 状态: 设计阶段

## 1. 设计目标

在 Nudgee 应用内构建一个 **Flutter 原生 Agent 框架**，让 AI 助手不只是问答，而是能：
- **调用工具**：操作日程、发帖、查询数据等
- **自主规划**：多步推理，拆解复杂任务
- **持久记忆**：跨会话记住用户偏好和历史
- **主动推送**：定时提醒、每日报告等
- **多 Agent 协作**：不同专长的 Agent 互相委派任务
- **技能系统 (Skills)**：可复用的程序化能力模块，支持发现、组合、进化
- **MCP 协议**：连接外部 MCP Server，无限扩展工具/资源/Prompt
- **沙箱执行**：安全运行 LLM 生成的 Dart 代码，权限隔离
- **提示词模板**：参数化模板 + 变量填充，快速构建 Agent 人设
- **Harness 编排**：围绕 LLM 的结构化执行层 — 上下文治理、记忆管理、技能路由、验证治理
- **循环控制 (Loop)**：ReAct 循环 + 循环检测 + 预算控制 + 人工介入

### 移动端专属目标（v0.3 新增）

以上是 Agent 框架的通用目标。但 Nudgee 是 **移动端 App**，不是桌面/服务端，以下目标同等重要：

- **移动端约束适配**：iOS/Android 沙箱禁止 `fork/exec`，MCP stdio 传输不可用 → 必须设计替代方案
- **崩溃恢复**：多步 Agent 执行到第 N 步时 app 被系统杀掉 → 重开后能从检查点恢复，不丢半截结果
- **离线降级**：手机没网时 Agent 仍能做有限的事（本地工具/缓存回复），而不是直接报错
- **成本可见性**：用户能看到每次 Agent 运行消耗了多少 token / 花了多少钱，而不是月底才发现账单爆炸
- **多设备同步**：两台设备同时修改 Agent 记忆 → 不能 last-write-wins 丢数据，需要冲突解决
- **新事件 UX**：`humanConfirmation`/`sandboxExec`/`skillProgress`/`loopWarning` 在手机 UI 上长什么样，必须定义
- **后台执行限制**：iOS/Android 后台执行时间严格受限 → 主动推送/定时任务必须有降级方案
- **性能不退化**：Agent 框架不能拖累现有功能的启动速度、帧率、内存

### 设计原则

| 原则 | 说明 |
|------|------|
| **Flutter-first** | 纯 Dart 实现，不依赖 Python/Node 后端 |
| **Provider-neutral** | 统一接口，支持 DeepSeek / OpenAI / 本地模型 |
| **渐进式** | 从简单 ReAct 循环开始，逐步增加 Skills/MCP/Sandbox |
| **可观测** | 每一步推理、工具调用、技能触发都可追踪 |
| **持久化** | Agent 状态可保存恢复，支持后台中断后续接 |
| **安全优先** | 沙箱隔离 + 权限分级 + 人工确认 + 循环熔断 |
| **Harness 优先** | 编排层是一等公民，不是实现细节 |
| **移动端现实** | 不假设有桌面级能力（fork/exec/无限后台/大内存），每个设计都要过"手机上能跑吗"这一关 |
| **离线友好** | 网络不可用时优雅降级，而非整体不可用 |
| **成本透明** | 用户随时可查看 token 消耗与预估费用 |
| **复用现有基建** | 优先复用 Nudgee 已有的 37 个 Service，不重复造轮子 |

---

## 2. 整体架构 — Agent Harness

Harness 是围绕 LLM 的**结构化执行层**：把模型能力转化为长周期 Agent 行为的系统。
它不是"包装 LLM API"，而是治理上下文、记忆、技能路由、编排循环和验证的完整框架。

```
┌──────────────────────────────────────────────────────────────────┐
│                        AgentHarness                               │
│                    (结构化执行层 / 编排层)                          │
│                                                                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐        │
│  │ AgentCore│  │ AgentCore│  │ AgentCore│  │ AgentCore│        │
│  │ (星语)   │  │ (理财)   │  │ (面试)   │  │ (健身)   │        │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘        │
│       │             │             │             │               │
│  ┌────┴─────────────┴─────────────┴─────────────┴────┐          │
│  │              Orchestrator (编排器)                  │          │
│  │   循环控制 · 任务委派 · 多Agent协作 · 人工介入       │          │
│  └────┬────────┬──────────┬──────────┬────────┬──────┘          │
│       │        │          │          │        │                  │
│  ┌────┴───┐ ┌──┴──────┐ ┌─┴──────┐ ┌─┴────┐ ┌─┴───────┐        │
│  │ReAct   │ │ Context │ │Memory  │ │Skill │ │Verify   │        │
│  │Loop    │ │Governor │ │Manager │ │Router│ │& Guard  │        │
│  │(推理   │ │(上下文  │ │(三层   │ │(技能 │ │(验证 +  │        │
│  │ 循环)  │ │ 治理)   │ │ 记忆)  │ │ 路由)│ │ 安全)   │        │
│  └────┬───┘ └──┬──────┘ └─┬──────┘ └─┬────┘ └─┬───────┘        │
│       │        │          │          │        │                  │
│  ┌────┴────────┴──────────┴──────────┴────────┴──────┐          │
│  │              Tool Registry (工具注册表)             │          │
│  │   内置工具 · MCP工具 · 技能工具 · 沙箱工具           │          │
│  └────┬────────────────────────────────────┬──────────┘          │
│       │                                    │                     │
│  ┌────┴──────┐                      ┌──────┴──────┐             │
│  │  Sandbox   │                      │  MCP Client │             │
│  │  (沙箱)    │                      │  (外部协议)  │             │
│  │  d4rt 解释 │                      │  stdio/SSE  │             │
│  │  权限隔离  │                      │  HTTP 传输  │             │
│  └───────────┘                      └─────────────┘             │
│                                                                  │
│  ┌──────────────────────────────────────────────────┐           │
│  │              Storage Layer (存储层)                │           │
│  │  SQLite · 七牛云 · Vector · PromptTemplate        │           │
│  └──────────────────────────────────────────────────┘           │
└──────────────────────────────────────────────────────────────────┘
```

---

## 3. 核心模块

### 3.1 AgentHarness — 编排层

Harness 是整个框架的入口，管理所有 Agent 生命周期、编排策略和治理规则。

```dart
/// Agent Harness — 编排层入口。
///
/// 管理所有 Agent 实例、编排策略、治理规则。
/// 是模型能力 → 长周期 Agent 行为的转换层。
class AgentHarness extends ChangeNotifier {
  final LLMClient llm;
  final ToolRegistry tools;
  final SkillRegistry skills;
  final McpManager mcp;
  final Sandbox sandbox;
  final AgentStorage storage;
  final ContextGovernor contextGov;
  final MemoryManager memory;
  final VerifyGuard guard;

  /// 已注册的 Agent 实例
  final Map<String, AgentCore> _agents = {};

  /// 运行一次 Agent 会话，返回流式事件
  Stream<AgentEvent> run({
    required String agentId,
    required String userInput,
    String? sessionId,
  });

  /// 注册新 Agent
  AgentCore registerAgent(AgentConfig config);

  /// Agent 间任务委派
  Stream<AgentEvent> delegate({
    required String fromAgentId,
    required String toAgentId,
    required String task,
  });
}
```

### 3.2 Orchestrator — 编排器

控制 ReAct 循环的执行策略、多 Agent 协作、人工介入。

```dart
/// 编排策略。
enum OrchestrationMode {
  single,       // 单 Agent 独立运行
  sequential,   // 多 Agent 顺序协作
  parallel,     // 多 Agent 并行执行
  hierarchical, // 主 Agent 委派子 Agent
}

/// 编排器 — 控制循环执行。
class Orchestrator {
  final OrchestrationMode mode;
  final int maxSteps;           // 最大循环次数
  final int maxTokensPerStep;   // 每步 token 预算
  final Duration stepTimeout;   // 每步超时
  final bool enableHumanInLoop; // 人工介入

  /// 执行编排循环
  Stream<AgentEvent> execute({
    required AgentCore agent,
    required String input,
    required AgentHarness harness,
  });

  /// 循环检测 — 防止 Agent 陷入死循环
  bool _detectLoop(List<AgentEvent> history);

  /// 预算检查 — token/步数是否超限
  bool _checkBudget(int steps, int tokensUsed);
}
```

### 3.3 ReAct Loop — 推理循环

核心循环：**Reason → Act → Observe → Reflect → Repeat**

```
用户输入
    ↓
┌──→ Reason (LLM 推理 + 思考过程)
│       ↓
│   需要工具/技能? ──否──→ 最终回复 → 结束
│       │是
│       ↓
│   Act (调用工具/执行技能/沙箱代码)
│       ↓
│   Observe (获取结果)
│       ↓
│   Reflect (结果是否符合预期? 需要重规划?)
│       ↓
│   结果加入上下文
└─── 循环 (直到 maxSteps / 预算耗尽 / 完成)
```

```dart
/// Agent 事件类型 (流式输出, sealed class)。
sealed class AgentEvent {
  /// 思考过程 delta (DeepSeek reasoning)
  const factory AgentEvent.thinking(String delta) = ThinkingEvent;

  /// 正文回复 delta
  const factory AgentEvent.content(String delta) = ContentEvent;

  /// 工具调用请求
  const factory AgentEvent.toolCall(ToolCall call) = ToolCallEvent;

  /// 工具执行结果
  const factory AgentEvent.toolResult(String toolName, ToolResult result) = ToolResultEvent;

  /// 技能触发
  const factory AgentEvent.skillTriggered(SkillRef skill) = SkillTriggeredEvent;

  /// 技能执行进度
  const factory AgentEvent.skillProgress(String skillId, String step, double progress) = SkillProgressEvent;

  /// 沙箱代码执行
  const factory AgentEvent.sandboxExec(String code, SandboxResult result) = SandboxExecEvent;

  /// MCP 工具调用
  const factory AgentEvent.mcpCall(String server, String tool, dynamic result) = McpCallEvent;

  /// 规划步骤
  const factory AgentEvent.plan(List<PlanStep> steps) = PlanEvent;

  /// 人工确认请求
  const factory AgentEvent.humanConfirmation(ToolCall call, String reason) = HumanConfirmationEvent;

  /// 循环检测警告
  const factory AgentEvent.loopWarning(int stepCount) = LoopWarningEvent;

  /// 完成
  const factory AgentEvent.done(String finalReply, AgentRunStats stats) = DoneEvent;

  /// 错误
  const factory AgentEvent.error(String message, {ErrorSeverity severity}) = ErrorEvent;
}

/// 运行统计。
class AgentRunStats {
  final int steps;
  final int tokensUsed;
  final int toolCalls;
  final int skillUses;
  final Duration duration;
  final double estimatedCost;
}
```

### 3.4 ContextGovernor — 上下文治理

管理 LLM 上下文窗口，防止溢出，智能裁剪。

```dart
/// 上下文治理器 — 管理发送给 LLM 的上下文。
class ContextGovernor {
  final int maxContextTokens;

  /// 构建给 LLM 的完整上下文
  ///
  /// 组装顺序:
  /// 1. System Prompt (Agent 人设 + 技能描述)
  /// 2. 长期记忆摘要
  /// 3. 历史会话摘要 (中期记忆)
  /// 4. 当前会话消息 (短期记忆, 滑动窗口)
  /// 5. 工具/技能定义
  /// 6. 用户输入
  String buildContext({
    required AgentConfig agent,
    required String userInput,
    required AgentMemory memory,
    required List<ToolDefinition> tools,
    required List<SkillSummary> skills,
  });

  /// 智能裁剪 — 保留重要消息, 压缩旧消息
  List<Message> trim(List<Message> messages, int targetTokens);

  /// 语义压缩 — 用 LLM 压缩历史消息
  Future<String> compress(List<Message> messages);
}
```

### 3.5 ToolRegistry — 工具注册表

统一管理三类工具：内置工具、MCP 工具、技能工具。

```dart
/// 工具定义。
abstract class AgentTool {
  String get name;
  String get description;
  Map<String, dynamic> get parametersSchema;
  bool get requiresConfirmation => false;
  ToolCategory get category;

  Future<ToolResult> execute(Map<String, dynamic> args);
}

enum ToolCategory {
  builtin,    // 内置工具 (日程/帖子/通知等)
  mcp,        // MCP Server 提供的工具
  skill,      // 技能衍生的工具
  sandbox,    // 沙箱代码执行工具
}

/// 工具注册表。
class ToolRegistry {
  final Map<String, AgentTool> _tools = {};

  /// 注册工具
  void register(AgentTool tool);

  /// 批量注册
  void registerAll(List<AgentTool> tools);

  /// 注册 MCP Server 的所有工具
  Future<void> registerMcpServer(McpConnection server);

  /// 获取工具定义 (给 LLM 的 JSON Schema)
  List<ToolDefinition> definitions({ToolCategory? filter});

  /// 执行工具
  Future<ToolResult> execute(String name, Map<String, dynamic> args);

  /// 工具是否需要确认
  bool needsConfirmation(String name);
}
```

**预设内置工具清单：**

| 工具 | 描述 | 需确认 | 类别 |
|------|------|--------|------|
| `schedule.add` | 添加日程 | ✅ | builtin |
| `schedule.query` | 查询日程 | ❌ | builtin |
| `schedule.remove` | 删除日程 | ✅ | builtin |
| `post.create` | 发布信息圈帖子 | ✅ | builtin |
| `post.query` | 查询最新帖子 | ❌ | builtin |
| `post.like` | 点赞帖子 | ❌ | builtin |
| `chat.send` | 发送消息到指定会话 | ✅ | builtin |
| `notification.schedule` | 安排本地通知 | ❌ | builtin |
| `user.profile` | 获取用户信息 | ❌ | builtin |
| `memory.save` | 保存长期记忆 | ❌ | builtin |
| `web.search` | 网络搜索 | ❌ | builtin |
| `sandbox.exec` | 执行 Dart 代码 | ✅ | sandbox |
| `mcp.*` | MCP Server 提供的工具 | 按配置 | mcp |

### 3.6 SkillRegistry — 技能系统

**技能 (Skill)** 是可复用的程序化能力模块，比工具更高层：
- 工具是原子操作（加一个日程）
- 技能是多步骤工作流（制定一周健身计划 = 查询日程 + 规划时间 + 批量添加 + 发送通知）

```dart
/// 技能定义 — 可复用的程序化能力。
abstract class AgentSkill {
  /// 技能 ID
  String get id;

  /// 技能名称 (LLM 可见, 用于触发判断)
  String get name;

  /// 简短描述 (渐进式披露: 先只看名称+描述)
  String get summary;

  /// 详细说明 (触发后加载完整内容)
  String get fullDescription;

  /// 适用条件 (什么时候用这个技能)
  String get applicabilityCondition;

  /// 允许使用的工具
  List<String> get allowedTools;

  /// 终止条件
  String get terminationCriteria;

  /// 执行技能
  Stream<SkillEvent> execute({
    required String userInput,
    required AgentHarness harness,
    Map<String, dynamic> params = const {},
  });

  /// 技能是否适用于当前输入 (LLM 判断 or 规则匹配)
  bool isApplicable(String userInput, AgentContext context);
}

/// 技能事件。
sealed class SkillEvent {
  const factory SkillEvent.step(String description) = SkillStepEvent;
  const factory SkillEvent.toolCall(ToolCall call) = SkillToolCallEvent;
  const factory SkillEvent.output(String content) = SkillOutputEvent;
  const factory SkillEvent.done(SkillResult result) = SkillDoneEvent;
}

/// 技能注册表。
class SkillRegistry {
  final Map<String, AgentSkill> _skills = {};

  /// 注册技能
  void register(AgentSkill skill);

  /// 渐进式披露: 返回技能摘要列表 (给 LLM 判断用哪个)
  List<SkillSummary> summaries();

  /// 获取技能完整定义
  AgentSkill? getById(String id);

  /// 根据用户输入匹配技能
  List<AgentSkill> match(String userInput, AgentContext context);
}
```

**预设技能清单：**

| 技能 | 描述 | 步骤 |
|------|------|------|
| `weekly_planner` | 一周日程规划 | 查询现有日程 → 分析空闲时间 → 规划任务 → 批量添加 → 通知 |
| `fitness_plan` | 健身计划制定 | 询问目标 → 查询日程 → 生成计划 → 添加日程 → 设置提醒 |
| `study_scheduler` | 学习计划排期 | 评估科目 → 分配时间块 → 添加日程 → 设置复习提醒 |
| `daily_briefing` | 每日简报 | 查询今日日程 → 查询天气 → 生成摘要 → 推送通知 |
| `post_draft` | 帖子草稿生成 | 分析意图 → 生成内容 → 用户确认 → 发布 |
| `code_review` | 代码审查 | 接收代码 → 分析 → 沙箱验证 → 给出建议 |

**技能生命周期：**

```
Discovery (发现)
    ↓
Practice (练习/执行)
    ↓
Distillation (蒸馏/优化)
    ↓
Storage (存储)
    ↓
Composition (组合)
    ↓
Evaluation (评估)
    ↓
Update (更新)
```

### 3.7 McpManager — MCP 协议管理

连接外部 MCP Server，无限扩展工具/资源/Prompt。

```dart
/// MCP 连接配置。
class McpServerConfig {
  final String id;
  final String name;
  final McpTransport transport;  // stdio / sse / streamableHttp
  final Map<String, dynamic> transportConfig;
  final bool autoConnect;
  final List<String> allowedTools;  // 白名单, null = 全部允许
  final bool requireConfirmation;
}

/// MCP 管理器。
class McpManager {
  final Map<String, McpConnection> _connections = {};

  /// 连接 MCP Server
  Future<McpConnection> connect(McpServerConfig config);

  /// 断开连接
  Future<void> disconnect(String serverId);

  /// 获取所有已连接 Server 的工具
  List<ToolDefinition> allTools();

  /// 获取所有资源
  List<McpResource> allResources();

  /// 获取所有 Prompt 模板
  List<McpPrompt> allPrompts();

  /// 调用 MCP 工具
  Future<dynamic> callTool(String serverId, String toolName, Map<String, dynamic> args);

  /// 读取 MCP 资源
  Future<String> readResource(String serverId, String uri);

  /// 应用 MCP Prompt 模板
  Future<String> applyPrompt(String serverId, String promptName, Map<String, dynamic> args);
}
```

**预设 MCP Server：**

| Server | 传输 | 用途 | 移动端可用 |
|--------|------|------|-----------|
| `filesystem` | stdio | 文件读写 (限制在 app 目录) | ❌ 需替代方案 |
| `fetch` | stdio | HTTP 请求 (网页抓取) | ❌ 需替代方案 |
| `memory` | stdio | 外部知识图谱 | ❌ 需替代方案 |
| `sqlite` | stdio | 直接查询 app SQLite | ❌ 需替代方案 |
| `web-search` | streamableHttp | 网络搜索 | ✅ |
| `nudgee-builtin` | in-process | 内置工具桥接 (不走网络) | ✅ |

> ⚠️ **移动端约束**：iOS/Android 应用沙箱禁止 `fork/exec`，stdio 传输需要 spawn 子进程（`npx -y @modelcontextprotocol/server-filesystem`），在手机上根本跑不起来。详见 [§11 移动端约束与 MCP 适配](#11-移动端约束与-mcp-适配)。

### 3.8 Sandbox — 沙箱执行环境

安全运行 LLM 生成的 Dart 代码，使用 `d4rt` 解释器 + 权限沙箱。

```dart
/// 沙箱权限配置。
class SandboxPermissions {
  final bool allowFilesystem;   // 文件读写
  final bool allowNetwork;      // 网络请求
  final bool allowProcess;      // 进程执行
  final bool allowIsolate;      // Isolate 操作
  final String? filesystemRoot; // 文件系统根目录限制
  final List<String> networkWhitelist; // 网络白名单
  final Duration timeout;       // 执行超时
  final int memoryLimitMB;      // 内存限制

  const SandboxPermissions({
    this.allowFilesystem = false,
    this.allowNetwork = false,
    this.allowProcess = false,
    this.allowIsolate = false,
    this.filesystemRoot,
    this.networkWhitelist = const [],
    this.timeout = const Duration(seconds: 10),
    this.memoryLimitMB = 50,
  });

  /// 默认安全配置 (最小权限)
  static const safe = SandboxPermissions();

  /// 代码执行配置 (允许计算, 禁止 IO)
  static const compute = SandboxPermissions(
    allowNetwork: true,
    networkWhitelist: ['api.deepseek.com'],
  );
}

/// 沙箱执行结果。
class SandboxResult {
  final bool success;
  final dynamic output;       // 返回值
  final String? stdout;       // 标准输出
  final String? stderr;       // 错误输出
  final Duration duration;
  final String? error;        // 执行错误
}

/// 沙箱 — 安全执行 Dart 代码。
class Sandbox {
  /// 执行 Dart 代码
  Future<SandboxResult> execute({
    required String code,
    SandboxPermissions permissions = SandboxPermissions.safe,
    Map<String, dynamic> bindings = const {},
  });

  /// 验证代码安全性 (静态分析)
  SandboxSafetyReport analyze(String code);

  /// 预定义的桥接 API (暴露给沙箱的安全函数)
  void registerBridge(String name, Function fn);
}
```

**沙箱使用场景：**

| 场景 | 权限 | 示例 |
|------|------|------|
| 数据计算 | 无 IO | "帮我算一下这个月的支出总和" → 生成 Dart 代码计算 |
| 数据分析 | 网络 (白名单) | "查一下这支股票的走势" → 生成代码调 API + 分析 |
| 文件处理 | 文件系统 (限制根目录) | "整理我的日程数据" → 生成代码读写 SQLite |
| 代码验证 | 无 IO | "这段代码对吗" → 沙箱运行验证 |

### 3.9 AgentMemory — 三层记忆系统

```
┌─────────────────────────────────────────┐
│           AgentMemory                    │
├─────────────────────────────────────────┤
│                                         │
│  ┌─────────────┐  短期记忆 (Working)     │
│  │ 当前会话上下文 │  ← 最近 N 轮对话       │
│  │ + 工具结果   │  ← 滑动窗口裁剪         │
│  │ + 技能状态   │  ← ContextGovernor 管理 │
│  └──────┬──────┘                        │
│         │ 摘要压缩                        │
│  ┌──────┴──────┐  中期记忆 (Episodic)    │
│  │ 会话摘要     │  ← 每次会话结束生成摘要   │
│  │ + 关键事件   │  ← SQLite 存储          │
│  │ + 技能使用   │  ← 七牛云同步           │
│  └──────┬──────┘                        │
│         │ 提取偏好                        │
│  ┌──────┴──────┐  长期记忆 (Semantic)    │
│  │ 用户偏好     │  ← "用户喜欢简洁回复"    │
│  │ + 事实知识   │  ← "用户是前端工程师"    │
│  │ + 技能 mastery│ ← "用户擅长 React"     │
│  │             │  ← SQLite + 向量检索    │
│  └─────────────┘                        │
│                                         │
└─────────────────────────────────────────┘
```

```dart
class MemoryManager {
  final MemoryStorage storage;

  /// 短期：当前会话消息历史
  final List<Message> workingMemory;

  /// 中期：历史会话摘要
  List<EpisodeSummary> get episodes;

  /// 长期：用户偏好和事实
  List<MemoryItem> get longTerm;

  /// 添加对话消息
  void addMessage(Message msg);

  /// 会话结束时生成摘要 (用 LLM)
  Future<EpisodeSummary> summarizeEpisode(List<Message> messages);

  /// 提取/更新长期记忆 (用 LLM)
  Future<void> extractLongTerm(String content);

  /// 语义检索相关记忆
  Future<List<MemoryItem>> retrieveRelevant(String query, {int limit = 5});

  /// 构建记忆上下文 (注入 system prompt)
  String buildMemoryContext(String userInput);
}
```

### 3.10 VerifyGuard — 验证与安全治理

```dart
/// 验证与安全治理层。
class VerifyGuard {
  /// 工具调用前验证
  GuardResult preCheck(ToolCall call, AgentContext context);

  /// 工具结果验证
  GuardResult postCheck(ToolCall call, ToolResult result);

  /// 输出安全检查 (PII 脱敏、有害内容过滤)
  String sanitizeOutput(String content);

  /// 循环检测
  bool detectLoop(List<AgentEvent> history);

  /// 预算检查
  BudgetStatus checkBudget(AgentRunStats stats, BudgetConfig config);

  /// 人工确认请求
  Future<bool> requestHumanConfirmation(ToolCall call, String reason);
}

enum GuardResult { allow, deny, requireConfirmation }
```

### 3.11 PromptTemplate — 提示词模板系统

```dart
/// 提示词模板 (已有基础建设, 集成到 Agent 框架)。
///
/// 模板 → AgentConfig 的映射:
/// - template.systemPrompt → agent.systemPrompt (人设)
/// - template.variables → agent 配置参数
/// - template.category → agent 分组
class PromptTemplateBridge {
  /// 从模板创建 Agent 配置
  AgentConfig templateToAgent(PromptTemplate template, Map<String, String> vars) {
    final filledPrompt = template.fillVariables(vars);
    return AgentConfig(
      id: 'agent_${template.id}',
      name: template.name,
      icon: template.icon,
      systemPrompt: filledPrompt,
      model: AppConfig.ai?.model ?? 'deepseek-chat',
      toolNames: _inferToolsFromCategory(template.category),
      temperature: 0.7,
      maxSteps: 10,
    );
  }

  /// 根据分类推断可用工具
  List<String> _inferToolsFromCategory(String category) {
    switch (category) {
      case '生活助手':
        return ['schedule.add', 'schedule.query', 'notification.schedule', 'web.search'];
      case '学习提升':
        return ['schedule.add', 'schedule.query', 'sandbox.exec', 'web.search'];
      case '效率工具':
        return ['post.create', 'post.query', 'web.search', 'sandbox.exec'];
      default:
        return ['web.search'];
    }
  }
}
```

### 3.12 LLMClient — 统一模型接口

```dart
abstract class LLMClient {
  /// 流式对话 (支持 tool calling + thinking)
  Stream<LLMChunk> streamChat({
    required String message,
    required String systemPrompt,
    List<Message> history,
    List<ToolDefinition> tools,
    double? temperature,
  });

  /// 切换模型
  void switchModel(String model);

  /// 可用模型列表
  List<String> availableModels();

  /// Token 用量统计
  TokenUsage estimateUsage(String input, String output);
}

/// LLM 流式输出块
class LLMChunk {
  final String? contentDelta;
  final String? thinkingDelta;    // DeepSeek reasoning
  final ToolCall? toolCall;       // 工具调用请求
  final bool isDone;
  final TokenUsage? usage;
}
```

---

## 4. 数据流

### 4.1 完整执行流程 (带技能 + MCP + 沙箱)

```
用户输入 "帮我制定一周健身计划，每天下午安排1小时"
    │
    ▼
AgentHarness.run(agentId, userInput)
    │
    ├──→ ContextGovernor.buildContext()  // 组装上下文 (人设+记忆+技能+工具)
    │
    ├──→ SkillRegistry.match(input)      // 匹配技能
    │       ↓
    │    匹配到 `fitness_plan` 技能
    │       ↓
    │    AgentEvent.skillTriggered(fitness_plan)
    │
    ├──→ Skill.execute()                 // 执行技能
    │       │
    │       ├──→ Step 1: 查询现有日程
    │       │    AgentEvent.toolCall(schedule.query)
    │       │    → ScheduleService.queryThisWeek()
    │       │    → AgentEvent.toolResult
    │       │
    │       ├──→ Step 2: 分析空闲时间 (沙箱)
    │       │    AgentEvent.sandboxExec(dartCode)
    │       │    → Sandbox.execute(code, permissions: compute)
    │       │    → 计算结果: 周一-周五 14:00-15:00 空闲
    │       │
    │       ├──→ Step 3: 生成计划 (LLM)
    │       │    → 生成 5 天健身计划
    │       │
    │       ├──→ Step 4: 批量添加日程 (需确认)
    │       │    AgentEvent.humanConfirmation(schedule.add x5)
    │       │    → 用户确认
    │       │    → ScheduleService.addSchedule() x5
    │       │
    │       └──→ Step 5: 设置提醒
    │            AgentEvent.toolCall(notification.schedule x5)
    │            → NotificationService.schedule() x5
    │
    ├──→ LLM 生成最终回复
    │       ↓
    │    AgentEvent.content("已为你安排了一周健身计划...")
    │
    ├──→ MemoryManager.summarizeEpisode()  // 生成会话摘要
    ├──→ MemoryManager.extractLongTerm()   // 提取: "用户想每天下午健身1小时"
    │
    ▼
AgentEvent.done(finalReply, stats)
    │
    ▼
ChatService 持久化 → UI 更新
```

### 4.2 MCP 工具调用流程

```
LLM 返回 tool_call("mcp.filesystem.read_file", {path: "data.json"})
    │
    ▼
ToolRegistry.execute("mcp.filesystem.read_file", args)
    │
    ▼
McpManager.callTool("filesystem", "read_file", args)
    │
    ├──→ McpConnection (stdio/SSE/HTTP)
    │       ↓
    │    MCP Server 执行 → 返回结果
    │
    ▼
ToolResult(success: true, output: fileContent)
```

### 4.3 沙箱执行流程

```
LLM 返回 tool_call("sandbox.exec", {code: "..."})
    │
    ▼
VerifyGuard.preCheck()  // 静态分析代码安全性
    │
    ├──→ 安全 → 继续
    ├──→ 有风险 → requireConfirmation
    └──→ 危险 → deny
    │
    ▼
Sandbox.execute(code, permissions: compute)
    │
    ├──→ d4rt 解释器执行
    │    ├──→ 权限检查 (网络/文件/进程)
    │    ├──→ 超时检查 (10s)
    │    └──→ 内存限制 (50MB)
    │
    ▼
SandboxResult(success: true, output: result)
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
  skills TEXT,          -- JSON array of skill ids
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
  skills_used TEXT,     -- JSON array of skill ids
  created_at TEXT NOT NULL,
  FOREIGN KEY (agent_id) REFERENCES agents(id)
);

-- Agent 记忆 - 长期事实 (长期记忆)
CREATE TABLE agent_memories (
  id TEXT PRIMARY KEY,
  agent_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  type TEXT NOT NULL,   -- 'preference' | 'fact' | 'skill_mastery'
  content TEXT NOT NULL,
  importance REAL DEFAULT 0.5,
  embedding TEXT,       -- 向量 (JSON array)
  access_count INTEGER DEFAULT 0,
  created_at TEXT NOT NULL,
  last_accessed TEXT,
  FOREIGN KEY (agent_id) REFERENCES agents(id)
);

-- 技能定义
CREATE TABLE agent_skills (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  summary TEXT NOT NULL,
  full_description TEXT,
  applicability_condition TEXT,
  allowed_tools TEXT,   -- JSON array
  termination_criteria TEXT,
  is_builtin INTEGER DEFAULT 0,
  mastery_level REAL DEFAULT 0.0,  -- 用户对该技能的掌握程度
  created_at TEXT NOT NULL,
  updated_at TEXT
);

-- MCP Server 配置
CREATE TABLE mcp_servers (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  transport TEXT NOT NULL,  -- 'stdio' | 'sse' | 'streamableHttp'
  config TEXT NOT NULL,     -- JSON
  auto_connect INTEGER DEFAULT 1,
  allowed_tools TEXT,       -- JSON array or null
  require_confirmation INTEGER DEFAULT 0,
  created_at TEXT NOT NULL
);

-- Agent 执行日志 (可观测)
CREATE TABLE agent_logs (
  id TEXT PRIMARY KEY,
  agent_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  session_id TEXT NOT NULL,
  event_type TEXT NOT NULL,  -- 'thinking'|'tool_call'|'tool_result'|'skill'|'sandbox'|'mcp'|'done'
  content TEXT,
  metadata TEXT,
  step INTEGER,
  tokens_used INTEGER,
  created_at TEXT NOT NULL
);

-- 沙箱执行记录
CREATE TABLE sandbox_executions (
  id TEXT PRIMARY KEY,
  agent_id TEXT NOT NULL,
  session_id TEXT NOT NULL,
  code TEXT NOT NULL,
  permissions TEXT,     -- JSON
  success INTEGER,
  output TEXT,
  error TEXT,
  duration_ms INTEGER,
  created_at TEXT NOT NULL
);
```

### 5.2 云端同步

| 数据 | 本地 | 云端 (七牛) | 同步策略 |
|------|------|------------|---------|
| Agent 配置 | SQLite `agents` | `agents/configs_<userId>.json` | last-write-wins |
| 会话摘要 | SQLite `agent_episodes` | `agents/episodes_<userId>.json` | append-only |
| 长期记忆 | SQLite `agent_memories` | `agents/memories_<userId>.json` | **版本号+字段合并** |
| 技能定义 | SQLite `agent_skills` | `agents/skills_<userId>.json` | last-write-wins |
| MCP 配置 | SQLite `mcp_servers` | `agents/mcp_<userId>.json` | last-write-wins |
| 成本记录 | SQLite `cost_records` | 不同步 (仅本地) | — |
| 执行日志 | SQLite `agent_logs` | 不同步 (仅本地) | — |
| 沙箱记录 | SQLite `sandbox_executions` | 不同步 (仅本地) | — |
| 会话状态 | Hive `agent_sessions` | 不同步 (仅本地) | — |
| 检查点 | Hive `agent_checkpoints` | 不同步 (仅本地) | — |

### 5.3 新增表 (v0.3)

```sql
-- 成本记录
CREATE TABLE cost_records (
  id TEXT PRIMARY KEY,
  session_id TEXT NOT NULL,
  model TEXT NOT NULL,
  input_tokens INTEGER NOT NULL,
  output_tokens INTEGER NOT NULL,
  thinking_tokens INTEGER DEFAULT 0,
  cost REAL NOT NULL,           -- CNY
  currency TEXT DEFAULT 'CNY',
  created_at TEXT NOT NULL
);

-- 索引: 按日期查询成本
CREATE INDEX idx_cost_created ON cost_records(created_at);
CREATE INDEX idx_cost_session ON cost_records(session_id);
```

---

## 6. 目录结构

```
lib/core/agent/
├── agent_harness.dart            # AgentHarness — 编排层入口
├── orchestrator.dart             # Orchestrator — 编排器 (循环控制/多Agent协作)
├── agent_core.dart               # AgentCore — 单个 Agent 核心
├── agent_config.dart             # AgentConfig — Agent 配置模型
├── agent_event.dart              # AgentEvent — 流式事件 (sealed class)
├── agent_stats.dart              # AgentRunStats — 运行统计
├── agent_session.dart            # AgentSession — 会话状态模型
├── agent_storage.dart            # AgentStorage — 持久化入口 (SQLite + Hive)
│
├── context/
│   ├── context_governor.dart     # ContextGovernor — 上下文治理
│   └── context_builder.dart      # 上下文组装器
│
├── memory/
│   ├── memory_manager.dart       # MemoryManager — 三层记忆管理
│   ├── episode_summary.dart      # 会话摘要模型
│   ├── memory_item.dart          # 长期记忆模型
│   ├── memory_storage.dart       # 记忆持久化 (SQLite + 七牛云)
│   └── syncable_memory.dart      # 可同步记忆 (带版本号, 用于冲突解决)
│
├── skills/
│   ├── agent_skill.dart          # AgentSkill 抽象类
│   ├── skill_registry.dart       # SkillRegistry — 技能注册表
│   ├── skill_event.dart          # SkillEvent — 技能事件
│   ├── skill_summary.dart        # 技能摘要 (渐进式披露)
│   ├── weekly_planner_skill.dart # 一周日程规划技能
│   ├── fitness_plan_skill.dart   # 健身计划技能
│   ├── study_scheduler_skill.dart# 学习计划排期技能
│   ├── daily_briefing_skill.dart # 每日简报技能
│   ├── post_draft_skill.dart     # 帖子草稿技能
│   └── code_review_skill.dart    # 代码审查技能
│
├── tools/
│   ├── agent_tool.dart           # AgentTool 抽象类
│   ├── tool_registry.dart        # ToolRegistry — 工具注册表
│   ├── tool_result.dart          # ToolResult — 工具结果
│   ├── tool_definition.dart      # ToolDefinition — 工具定义 (给 LLM)
│   ├── schedule_tools.dart       # 日程相关工具
│   ├── post_tools.dart           # 信息圈相关工具
│   ├── chat_tools.dart           # 聊天相关工具
│   ├── notification_tools.dart   # 通知相关工具
│   ├── web_tools.dart            # 网络搜索工具
│   ├── memory_tools.dart         # 记忆操作工具
│   ├── user_tools.dart           # 用户信息工具
│   └── sandbox_tool.dart         # 沙箱执行工具
│
├── mcp/
│   ├── mcp_manager.dart          # McpManager — MCP 协议管理
│   ├── mcp_connection.dart       # McpConnection — 单个连接
│   ├── mcp_server_config.dart    # McpServerConfig — 配置模型
│   ├── mcp_resource.dart         # McpResource — 资源模型
│   ├── mcp_prompt.dart           # McpPrompt — Prompt 模板模型
│   ├── mcp_server_interface.dart # McpServerInterface — 统一接口
│   └── in_process_mcp_server.dart# InProcessMcpServer — 内置工具桥接 (移动端主力)
│
├── sandbox/
│   ├── sandbox.dart              # Sandbox — 沙箱入口
│   ├── sandbox_permissions.dart  # 权限配置
│   ├── sandbox_result.dart       # 执行结果
│   ├── sandbox_safety.dart       # 安全分析
│   └── sandbox_bridges.dart      # 桥接 API (暴露给沙箱的安全函数)
│
├── guard/
│   ├── verify_guard.dart         # VerifyGuard — 验证与安全治理
│   ├── budget_config.dart        # 预算配置
│   ├── loop_detector.dart        # 循环检测器
│   └── retry_strategy.dart       # 指数退避重试策略
│
├── checkpoint/
│   ├── checkpoint_manager.dart   # CheckpointManager — 崩溃恢复
│   ├── agent_checkpoint.dart     # 检查点模型
│   └── agent_session.dart        # 会话状态模型
│
├── cost/
│   ├── cost_tracker.dart         # CostTracker — 实时成本追踪
│   ├── model_pricing.dart        # 模型定价配置
│   └── cost_record.dart          # 成本记录模型
│
├── sync/
│   ├── agent_sync_manager.dart   # AgentSyncManager — 多设备同步
│   └── conflict_resolver.dart    # 冲突解决策略
│
├── offline/
│   ├── offline_runner.dart       # OfflineAwareAgentRunner — 离线降级
│   └── offline_tool_executor.dart# 离线工具执行 (无 LLM)
│
├── observability/
│   ├── agent_logger.dart         # AgentLogger — 执行日志
│   └── perf_monitor.dart         # AgentPerformanceMonitor — 性能监控
│
├── planner/
│   ├── planner.dart              # Planner — 规划器接口
│   ├── plan_step.dart            # PlanStep — 规划步骤
│   └── planning_strategies.dart  # 直答/单步/多步/重规划策略
│
├── template/
│   └── prompt_template_bridge.dart # 提示词模板 → Agent 桥接
│
└── providers/
    ├── llm_client.dart           # LLMClient — 统一模型接口
    ├── llm_chunk.dart            # LLMChunk — 流式输出块
    ├── deepseek_client.dart      # DeepSeek 实现
    ├── openai_client.dart        # OpenAI 兼容实现
    └── ollama_client.dart        # 本地模型实现 (后续)
```

---

## 7. 实现路线图

### Phase 1: 基础框架 + ReAct 循环
- [ ] `AgentConfig` / `AgentEvent` / `AgentRunStats` / `AgentSession` 模型
- [ ] `LLMClient` 接口 + DeepSeek 实现 (复用现有 AiService)
- [ ] `AgentTool` 抽象 + `ToolRegistry`
- [ ] `AgentCore` + ReAct 循环 (Reason → Act → Observe)
- [ ] `Orchestrator` 基础循环控制 (maxSteps + 超时)
- [ ] `ContextGovernor` 基础上下文组装
- [ ] 集成到 `ChatPage` (替换当前 `_streamAiReply` → `_runAgent`)
- [ ] `AgentMemory` 短期记忆 (会话上下文)
- [ ] **新事件 UI 组件**: `ToolCallCard` / `StatsFooter` / `ErrorCard`
- [ ] **config.yaml 扩展**: `agent` 段
- [ ] **l10n 新增**: Agent 相关国际化键

### Phase 2: 工具系统 + In-Process MCP
- [ ] `schedule.add` / `schedule.query` / `schedule.remove`
- [ ] `post.create` / `post.query` / `post.like`
- [ ] `notification.schedule`
- [ ] `memory.save` / `user.profile`
- [ ] `web.search`
- [ ] 工具调用确认 UI (`HumanConfirmationDialog`)
- [ ] 工具执行结果展示 UI (`ToolCallCard` / `ToolResultCard`)
- [ ] **In-Process MCP Server** (移动端主力, 包装内置 Service)
- [ ] **McpManager 平台适配** (initForPlatform)

### Phase 3: 记忆系统 + 多设备同步
- [ ] 中期记忆 — 会话摘要生成 (LLM 调用)
- [ ] 长期记忆 — 用户偏好提取 (LLM 调用)
- [ ] 记忆注入 system prompt (ContextGovernor 集成)
- [ ] SQLite 持久化 + 七牛云同步
- [ ] **AgentSyncManager** — 版本号 + 字段级合并
- [ ] **冲突解决策略** (preference/fact/skill_mastery)
- [ ] **同步时机**: 启动/更新后/后台/网络恢复
- [ ] 语义检索 (向量, 后续可换 sqlite-vec)

### Phase 4: 技能系统 (Skills)
- [ ] `AgentSkill` 抽象 + `SkillRegistry`
- [ ] 渐进式披露 (summary → fullDescription)
- [ ] 技能匹配 (规则 + LLM 判断)
- [ ] 技能执行流程 (多步骤工作流)
- [ ] 预设技能: `weekly_planner` / `fitness_plan` / `daily_briefing`
- [ ] 技能 UI: `SkillBanner` / `SkillProgressBar`
- [ ] 技能生命周期: 发现 → 执行 → 评估 → 更新

### Phase 5: MCP 协议 (远程 + 桌面)
- [ ] `McpManager` + `McpConnection` (远程 HTTP)
- [ ] SSE / Streamable HTTP 传输 (远程 MCP Server)
- [ ] **AppLifecycleService 集成** — 前台恢复时重连
- [ ] 工具发现 + 自动注册到 ToolRegistry
- [ ] 资源读取 + Prompt 模板应用
- [ ] MCP Server 配置页面
- [ ] **stdio 传输 (仅桌面)** — macOS/Linux/Windows
- [ ] 预设远程 MCP Server: web-search

### Phase 6: 沙箱执行
- [ ] 集成 `d4rt` / `tom_d4rt` Dart 解释器
- [ ] `Sandbox` 入口 + 权限系统
- [ ] 安全分析 (静态检查代码)
- [ ] 桥接 API (暴露安全函数给沙箱)
- [ ] `sandbox.exec` 工具
- [ ] 沙箱执行 UI (`SandboxCodeCard`)
- [ ] 执行记录持久化

### Phase 7: 规划器 + Harness 治理 + 成本可见性
- [ ] `Planner` 接口 + 直答/单步/多步策略
- [ ] 动态重规划 (工具结果不符预期时)
- [ ] `VerifyGuard` 完整实现 (preCheck/postCheck/sanitize)
- [ ] 循环检测 (hash-based) + `LoopWarningBanner` UI
- [ ] **CostTracker** — 实时成本追踪 + 持久化
- [ ] **预算控制** (token/步数/费用) + `BudgetConfig`
- [ ] **成本统计 UI** (设置页 + 预算超限警告)
- [ ] 人工介入 (Human-in-the-loop)
- [ ] 执行计划 UI (`PlanTimeline`)
- [ ] **错误处理** — `RetryStrategy` + LLM 自修复 + `AgentErrorHandler`

### Phase 8: 崩溃恢复 + 离线降级 + 可观测性
- [ ] **CheckpointManager** — 每步检查点持久化
- [ ] **agent_sessions / agent_checkpoints 表**
- [ ] **崩溃恢复 UX** — "上次有未完成的任务" 弹窗
- [ ] **AppLifecycleService 集成** — pause→save, resume→check
- [ ] **OfflineAwareAgentRunner** — 离线降级
- [ ] **OfflineToolExecutor** — 无 LLM 的本地工具执行
- [ ] **离线横幅 UI** + 网络恢复自动同步
- [ ] **AgentLogger** — 执行日志持久化到 agent_logs
- [ ] **AgentPerformanceMonitor** — 帧率/内存监控
- [ ] **开发者面板** — Agent 执行回放

### Phase 9: 多 Agent 协作
- [ ] Agent 间消息传递
- [ ] 任务委派 (`transfer_to_agent`)
- [ ] 并行/顺序/层级编排
- [ ] Agent 商店 (用户可添加新 Agent)
- [ ] 提示词模板 → Agent 一键创建 (`PromptTemplateBridge`)

### Phase 10: 主动推送
- [ ] 定时调度器 (复用 `BackgroundTaskService`)
- [ ] 后台 Agent 执行 (iOS 30s 限制降级)
- [ ] 推送通知集成 (`PushNotificationService`)
- [ ] 每日简报 / 定时提醒

### Phase 11: 测试与质量保证
- [ ] `MockLLMClient` — 不依赖真实 API 的测试
- [ ] 工具单元测试 (每个 Tool 独立)
- [ ] 沙箱安全测试 (权限/超时/内存)
- [ ] Widget 测试 (所有 Agent UI 组件)
- [ ] 崩溃恢复集成测试
- [ ] 同步冲突解决测试
- [ ] 离线降级测试

### Phase 8: 多 Agent 协作
- [ ] Agent 间消息传递
- [ ] 任务委派 (`transfer_to_agent`)
- [ ] 并行/顺序/层级编排
- [ ] Agent 商店 (用户可添加新 Agent)
- [ ] 提示词模板 → Agent 一键创建

### Phase 9: 主动推送
- [ ] 定时调度器
- [ ] 后台 Agent 执行
- [ ] 推送通知集成
- [ ] 每日简报 / 定时提醒

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
    │    AgentHarness.run(agentId, text)
    │         │
    │         ▼ Stream<AgentEvent>
    │    ┌────┴──────────┐
    │    │ thinking       │ → 更新 bubble metadata (流式)
    │    │ content        │ → 更新 bubble text (流式)
    │    │ toolCall       │ → 显示工具调用卡片
    │    │ skillTriggered │ → 显示技能触发提示
    │    │ sandboxExec    │ → 显示代码 + 执行结果
    │    │ humanConfirm   │ → 弹出确认对话框
    │    │ done           │ → ChatService.addAiMessage() 持久化
    │    └───────────────┘
    │
    └──→ UI 更新
```

### 8.2 PromptTemplateService 集成

提示词模板通过 `PromptTemplateBridge` 映射为 `AgentConfig`：
- 模板的 `systemPrompt` → Agent 的人设
- 模板的 `variables` → Agent 配置参数
- 模板的 `category` → 自动推断可用工具集
- 选择模板 = 创建新 Agent 实例

### 8.3 与现有 37 个 Service 的集成映射

Nudgee 已有大量基础建设，Agent 框架**复用而非重造**：

| 现有 Service | Agent 框架复用方式 | 改动程度 |
|-------------|-------------------|---------|
| `AiService` | 包装为 `LLMClient` 实现 (`DeepSeekClient`) | 薄包装, 不改原代码 |
| `ChatService` | Agent 事件持久化到 ChatService 的 messages 表 | 加 metadata 字段 |
| `ScheduleService` | 包装为 `schedule.add/query/remove` 工具 | 薄包装 |
| `PostService` | 包装为 `post.create/query/like` 工具 | 薄包装 |
| `NotificationService` | 包装为 `notification.schedule` 工具 | 薄包装 |
| `PromptTemplateService` | 通过 `PromptTemplateBridge` 转 AgentConfig | 薄包装 |
| `QiniuStorageService` | Agent 记忆/配置云端同步 | 薄包装 |
| `FileStorageService` | Agent 本地文件存储 (检查点/日志) | 薄包装 |
| `LocalDatabaseService` (Hive) | Agent 检查点/会话状态 (K/V 存储) | 新增 box |
| `SharedPrefsService` | Agent 偏好设置 (默认模型/预算) | 新增 keys |
| `SecureStorageService` | MCP Server OAuth token 安全存储 | 薄包装 |
| `ConnectivityService` | 离线降级判断 | 直接使用 |
| `AppLifecycleService` | 崩溃恢复触发 (pause→save, resume→check) | 加监听 |
| `BackgroundTaskService` | 主动推送定时任务 | 注册新 task |
| `PushNotificationService` | Agent 主动消息推送 | 薄包装 |
| `LoggerService` | Agent 执行日志 | 直接使用 |
| `LogReporterService` | Agent 错误上报 | 直接使用 |
| `CrashHandler` | Agent 未捕获异常兜底 | 加 zone |
| `FrameTimingMonitorService` | Agent 执行期间帧率监控 | 直接使用 |
| `AnalyticsService` | Agent 使用埋点 (技能触发/工具调用) | 新增 events |
| `AppUpdateService` | Agent 框架版本兼容检查 | 薄包装 |
| `PermissionService` | 沙箱/通知权限请求 | 直接使用 |
| `UserStorageService` | 获取当前用户 ID (记忆隔离) | 直接使用 |
| `UserCacheService` | `user.profile` 工具获取用户信息 | 直接使用 |
| `ApiCacheService` | web.search 工具结果缓存 | 直接使用 |
| `UploadService` | post.create 工具上传图片 | 直接使用 |
| `DownloadService` | Agent 下载远程资源 | 直接使用 |
| `FilePickerService` | 用户给 Agent 提供文件 | 直接使用 |
| `BluetoothService` | 后续 IoT 工具扩展 | 预留 |
| `SocialLoginService` | Agent 用户身份验证 | 直接使用 |
| `AuthService` | Agent 用户上下文 (userId) | 直接使用 |
| `AppInitializer` | Agent 框架初始化入口 | 加 init 调用 |

**不需要改动的 Service**：`ApiClient`、`CircuitBreaker`、各 network interceptor — Agent 框架不直接用 HTTP，而是通过 `LLMClient` 抽象。

### 8.4 初始化顺序

Agent 框架的初始化必须排在现有 Service 之后：

```dart
// app_initializer.dart 中新增
Future<void> initAgentFramework() async {
  // 1. 依赖的 Service 必须已注册
  assert(sl.isRegistered<ScheduleService>());
  assert(sl.isRegistered<PostService>());
  assert(sl.isRegistered<ChatService>());
  assert(sl.isRegistered<AiService>());

  // 2. 注册 Agent 框架组件
  _safeRegister(() => sl.registerLazySingleton<Sandbox>(() => Sandbox()));
  _safeRegister(() => sl.registerLazySingleton<CostTracker>(() => CostTracker(storage: sl())));
  _safeRegister(() => sl.registerLazySingleton<McpManager>(() => McpManager()));
  _safeRegister(() => sl.registerLazySingleton<SkillRegistry>(() => SkillRegistry()..register(...)));
  _safeRegister(() => sl.registerLazySingleton<ToolRegistry>(() => ToolRegistry()..registerAll([...])));
  _safeRegister(() => sl.registerLazySingleton<MemoryManager>(() => MemoryManager(...)));
  _safeRegister(() => sl.registerLazySingleton<CheckpointManager>(() => CheckpointManager(...)));
  _safeRegister(() => sl.registerLazySingleton<AgentHarness>(() => AgentHarness(...)));

  // 3. 初始化 MCP (平台适配)
  await sl<McpManager>().initForPlatform();

  // 4. 恢复未完成的 Agent 会话
  await sl<CheckpointManager>().checkAndNotifyRecovery();

  // 5. 注册后台任务 (主动推送)
  sl<BackgroundTaskService>().registerTask(BackgroundTask(
    name: 'daily_briefing',
    frequency: const Duration(hours: 24),
    constraints: const Constraints(requiresNetwork: true),
    task: () => sl<AgentHarness>().runDailyBriefing(),
  ));
}
```

### 8.5 DI 注册

```dart
// injector.dart
_safeRegister(() {
  // 沙箱
  sl.registerLazySingleton<Sandbox>(() => Sandbox());

  // 成本追踪
  sl.registerLazySingleton<CostTracker>(() => CostTracker(storage: sl<AgentStorage>()));

  // MCP 管理器
  sl.registerLazySingleton<McpManager>(() => McpManager());

  // 技能注册表
  sl.registerLazySingleton<SkillRegistry>(() => SkillRegistry()
    ..register(WeeklyPlannerSkill())
    ..register(FitnessPlanSkill())
    ..register(DailyBriefingSkill()));

  // 工具注册表
  sl.registerLazySingleton<ToolRegistry>(() => ToolRegistry()
    ..registerAll([
      ScheduleAddTool(sl<ScheduleService>()),
      ScheduleQueryTool(sl<ScheduleService>()),
      PostCreateTool(sl<PostService>()),
      NotificationTool(sl<NotificationService>()),
      SandboxExecTool(sl<Sandbox>()),
      // MCP 工具在 McpManager 连接后自动注册
    ]));

  // Agent Harness
  sl.registerLazySingleton<AgentHarness>(() => AgentHarness(
    llm: sl<LLMClient>(),
    tools: sl<ToolRegistry>(),
    skills: sl<SkillRegistry>(),
    mcp: sl<McpManager>(),
    sandbox: sl<Sandbox>(),
    storage: sl<AgentStorage>(),
    contextGov: ContextGovernor(),
    memory: sl<MemoryManager>(),
    guard: VerifyGuard(costTracker: sl<CostTracker>()),
  ));
});
```

---

## 9. 安全与边界

| 风险 | 对策 | 模块 |
|------|------|------|
| Agent 无限循环 | `maxSteps` 限制 + hash 循环检测 + 熔断 | Orchestrator + LoopDetector |
| 敏感操作未授权 | `requiresConfirmation` → 人工确认对话框 | VerifyGuard |
| 上下文溢出 | 滑动窗口裁剪 + 语义压缩 | ContextGovernor |
| 工具执行异常 | try-catch + 错误结果回传 LLM 重试 | ToolRegistry |
| API 费用失控 | token 用量追踪 + 每日限额 + 预算熔断 | VerifyGuard + BudgetConfig |
| 隐私泄露 | 本地工具不传敏感数据到 LLM, 仅传结果摘要 | VerifyGuard |
| 沙箱代码恶意 | d4rt 权限沙箱 + 静态分析 + 超时/内存限制 | Sandbox |
| MCP Server 不可信 | 工具白名单 + 确认机制 + 资源访问限制 | McpManager |
| 技能供应链攻击 | 信任分级 + 签名验证 + 来源审计 | SkillRegistry |
| 输出有害内容 | PII 脱敏 + 内容过滤 | VerifyGuard |

---

## 10. 参考项目

| 项目 | 语言 | 借鉴点 |
|------|------|--------|
| [Vantura](https://pub.dev/packages/vantura) | Dart/Flutter | ReAct 循环、双层记忆、检查点、状态恢复 |
| [Akashi Agents](https://github.com/AleSZanello/akashi_agents) | Dart | 多 Agent 编排、durable 执行、HITL |
| [dart_agent_core](https://pub.dev/packages/dart_agent_core) | Dart | 工具系统、MCP 支持、Agent evals、技能系统 |
| [flutter_agentic](https://pub.dev/packages/flutter_agentic) | Dart/Flutter | 多 Provider 路由、安全层、ReAct |
| [LangGraph](https://github.com/langchain-ai/langgraph) | Python | ReAct 模式、State/Node/Edge、检查点 |
| [Omnigent](https://github.com/francescostabile/omnigent) | Python | 推理图、分层规划、错误恢复、循环检测 |
| [mcp_dart](https://pub.dev/packages/mcp_dart) | Dart | MCP 协议完整实现 (client/server/host) |
| [mcp_client](https://pub.dev/packages/mcp_client) | Dart | MCP client, 多版本协议, OAuth |
| [d4rt](https://pub.dev/packages/d4rt) | Dart | Dart 解释器, 权限沙箱, 桥接系统 |
| [tom_d4rt](https://github.com/al-the-bear/tom_d4rt) | Dart | d4rt 增强版, Flutter 集成, OTA UI |
| [SkillNet](https://arxiv.org/pdf/2603.04448) | Python | 技能创建/评估/组织, 技能本体论 |
| [Skill-Use Benchmark](https://arxiv.org/html/2608.04828) | Python | 技能触发/合规/边界 三维评估 |
| [Harness Scaling](https://arxiv.org/html/2605.26112) | Python | Harness 设计, 上下文治理, 技能路由, 验证治理 |
| [LingAgent](https://github.com/LingByte/ling-agent) | Go | 两级压缩、5 模式权限、消息消毒、Knowledge/Memory 分离、ToolSearch、SubAgent 类型、Goal 锚定迭代 |

---

## 11. 移动端约束与 MCP 适配

### 11.1 问题

MCP 标准传输有三种：`stdio`、`SSE`、`Streamable HTTP`。

| 传输 | 原理 | 桌面 | iOS | Android |
|------|------|------|-----|---------|
| stdio | spawn 子进程 + stdin/stdout | ✅ | ❌ 禁止 fork/exec | ❌ 禁止 fork/exec |
| SSE | HTTP 长连接 + Server-Sent Events | ✅ | ✅ (前台) | ✅ (前台) |
| Streamable HTTP | HTTP 请求/响应 | ✅ | ✅ | ✅ |

**结论**：MCP 官方预设的 5 个 Server 有 4 个用 stdio，在手机上全部不可用。

### 11.2 适配方案 — 三层 MCP 架构

```
┌─────────────────────────────────────────────────────┐
│              McpManager (统一入口)                    │
├─────────────┬───────────────┬───────────────────────┤
│  In-Process │  Remote HTTP  │   stdio (仅桌面)       │
│  (移动端主力) │  (移动端可用)  │   (macOS/Linux/Win)   │
├─────────────┼───────────────┼───────────────────────┤
│ Nudgee 内置  │ web-search    │ filesystem            │
│ 工具桥接     │ 远程 MCP Hub  │ fetch                 │
│ 不走网络     │ (自建/第三方)  │ memory                │
│              │               │ sqlite                │
└─────────────┴───────────────┴───────────────────────┘
```

#### 方案 A: In-Process MCP (移动端主力)

把 Nudgee 已有的 Service 包装成 MCP 兼容的工具，**不走网络，不走子进程**，直接在 app 进程内调用。对 LLM 来说它就是一个 MCP Server 提供的工具，对 app 来说它就是现有 Service 的薄包装。

```dart
/// In-Process MCP Server — 把内置 Service 暴露为 MCP 兼容工具。
///
/// 不走 stdio/SSE/HTTP，直接在进程内调用。
/// 对 McpManager 来说，它和远程 MCP Server 接口一致。
class InProcessMcpServer implements McpServerInterface {
  @override
  String get id => 'nudgee-builtin';

  @override
  List<ToolDefinition> get tools => [
    ToolDefinition(
      name: 'schedule.query',
      description: '查询用户日程',
      inputSchema: {'date': 'string', 'range': 'string?'},
    ),
    ToolDefinition(
      name: 'post.create',
      description: '发布信息圈帖子',
      inputSchema: {'content': 'string', 'images': 'array?'},
    ),
    // ... 其他内置工具
  ];

  @override
  Future<dynamic> callTool(String name, Map<String, dynamic> args) async {
    // 直接调用 Nudgee 已有的 Service
    switch (name) {
      case 'schedule.query':
        return sl<ScheduleService>().querySchedules(...);
      case 'post.create':
        return sl<PostService>().addPost(...);
    }
  }
}
```

**优点**：零网络开销、零权限问题、复用现有 37 个 Service、移动端立即可用。
**缺点**：不是"真正的" MCP（没有独立 Server 进程），但接口兼容。

#### 方案 B: Remote HTTP MCP (移动端可用)

对于需要外部能力的工具（网络搜索、第三方 API），使用 SSE / Streamable HTTP 传输连接远程 MCP Server。

```dart
// 移动端可用的远程 MCP Server
final remoteServers = [
  McpServerConfig(
    id: 'web-search',
    transport: McpTransport.streamableHttp,
    transportConfig: {'url': 'https://mcp.example.com/search'},
    autoConnect: true,
  ),
];
```

**注意**：iOS/Android 后台时 HTTP 长连接会被系统切断，需要在 `AppLifecycleService` 恢复时重连。

#### 方案 C: stdio MCP (仅桌面)

如果未来 Nudgee 发布 macOS/Linux/Windows 桌面版，可以启用 stdio 传输连接本地 MCP Server。移动端自动跳过。

```dart
// 仅桌面平台注册 stdio MCP Server
if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
  await mcp.connect(McpServerConfig(
    id: 'filesystem',
    transport: McpTransport.stdio,
    transportConfig: {
      'command': 'npx',
      'arguments': ['-y', '@modelcontextprotocol/server-filesystem', appDir],
    },
  ));
}
```

### 11.3 平台能力矩阵

| 能力 | iOS | Android | macOS | Web |
|------|-----|---------|-------|-----|
| In-Process MCP | ✅ | ✅ | ✅ | ✅ |
| Remote HTTP MCP | ✅ (前台) | ✅ (前台) | ✅ | ✅ |
| stdio MCP | ❌ | ❌ | ✅ | ❌ |
| d4rt 沙箱 | ✅ | ✅ | ✅ | ⚠️ (analyzer 太大) |
| 后台 Agent 执行 | ⚠️ (30s 限制) | ⚠️ (Doze 模式) | ✅ | ❌ |
| 本地通知 | ✅ | ✅ | ✅ | ❌ |
| 推送通知 | ✅ (APNs) | ✅ (FCM) | ✅ (APNs) | ✅ (Web Push) |

### 11.4 McpManager 平台适配实现

```dart
class McpManager {
  Future<void> initForPlatform() async {
    // 1. 始终注册 In-Process MCP (所有平台)
    register(InProcessMcpServer());

    // 2. 注册远程 HTTP MCP (所有平台, 前台可用)
    for (final config in _remoteConfigs) {
      if (config.autoConnect) await connect(config);
    }

    // 3. 仅桌面注册 stdio MCP
    if (!kIsWeb && (Platform.isMacOS || Platform.isLinux || Platform.isWindows)) {
      for (final config in _stdioConfigs) {
        if (config.autoConnect) await connect(config);
      }
    }
  }

  /// AppLifecycleService 恢复时调用 — 重连远程 MCP
  Future<void> onAppResume() async {
    for (final conn in _connections.values) {
      if (conn.transport == McpTransport.streamableHttp && !conn.isConnected) {
        await conn.reconnect();
      }
    }
  }
}
```

---

## 12. 崩溃恢复与检查点 (Checkpoint)

### 12.1 问题

多步 Agent 执行到第 5 步时 app 被系统杀掉（内存压力/用户手动杀/后台超时），当前设计没有恢复机制，用户重开看到的是半截结果或直接丢失。

### 12.2 方案 — 每步检查点持久化

```
Step 1: Reason → 检查点 1 (保存: 上下文 + 思考)
Step 2: Act (schedule.query) → 检查点 2 (保存: 工具调用 + 结果)
Step 3: Reason → 检查点 3 (保存: 上下文更新)
Step 4: Act (sandbox.exec) → 检查点 4 (保存: 代码 + 结果)
  ─── 💥 app 被杀 ───
  ─── 用户重开 app ───
检测到未完成的 session (checkpoint 4)
  → 提示用户: "上次有未完成的任务，是否恢复?"
  → 恢复 → 从 Step 4 的结果继续 Step 5
  → 放弃 → 标记 session 为 aborted
```

### 12.3 数据模型

```sql
-- Agent 执行检查点
CREATE TABLE agent_checkpoints (
  id TEXT PRIMARY KEY,
  session_id TEXT NOT NULL,
  agent_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  step INTEGER NOT NULL,           -- 第几步
  step_type TEXT NOT NULL,         -- 'reason'|'act'|'observe'|'reflect'
  context_snapshot TEXT NOT NULL,  -- JSON: 当前的完整上下文
  tool_call TEXT,                  -- JSON: 如果是 act, 记录工具调用
  tool_result TEXT,                -- JSON: 如果是 observe, 记录工具结果
  thinking TEXT,                   -- 当前思考过程
  content_so_far TEXT,             -- 已生成的回复内容
  tokens_used INTEGER DEFAULT 0,
  created_at TEXT NOT NULL,
  FOREIGN KEY (session_id) REFERENCES agent_sessions(id)
);

-- Agent 会话状态
CREATE TABLE agent_sessions (
  id TEXT PRIMARY KEY,
  agent_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  conversation_id TEXT NOT NULL,   -- 关联 ChatService 会话
  status TEXT NOT NULL,            -- 'running'|'paused'|'completed'|'aborted'|'crashed'
  input TEXT NOT NULL,             -- 用户原始输入
  final_reply TEXT,
  total_steps INTEGER DEFAULT 0,
  total_tokens INTEGER DEFAULT 0,
  started_at TEXT NOT NULL,
  completed_at TEXT,
  last_checkpoint_id TEXT          -- 最后一个检查点
);
```

### 12.4 CheckpointManager

```dart
/// 检查点管理器 — 每步执行后保存, 崩溃后恢复。
class CheckpointManager {
  final AgentStorage storage;

  /// 保存检查点 (每步执行后调用)
  Future<void> save(AgentCheckpoint checkpoint) async {
    await storage.saveCheckpoint(checkpoint);
  }

  /// 检测未完成的会话 (app 启动时调用)
  Future<List<AgentSession>> findIncompleteSessions(String userId) async {
    return storage.sessionsWhere(status: ['running', 'paused']);
  }

  /// 恢复会话 — 从最后一个检查点继续
  Stream<AgentEvent> resume(String sessionId) async* {
    final session = await storage.getSession(sessionId);
    if (session == null) {
      yield AgentEvent.error('Session not found');
      return;
    }

    final lastCheckpoint = await storage.getLastCheckpoint(sessionId);
    if (lastCheckpoint == null) {
      yield AgentEvent.error('No checkpoint found');
      return;
    }

    // 从检查点恢复上下文, 继续执行
    yield* _orchestrator.resumeFromCheckpoint(session, lastCheckpoint);
  }

  /// 标记会话完成
  Future<void> complete(String sessionId, String finalReply, AgentRunStats stats) async {
    await storage.updateSession(sessionId, status: 'completed', finalReply: finalReply);
  }

  /// 标记会话放弃
  Future<void> abort(String sessionId) async {
    await storage.updateSession(sessionId, status: 'aborted');
  }
}
```

### 12.5 恢复 UX

```
┌─────────────────────────────────────┐
│  ⚠️ 上次有未完成的任务               │
│                                     │
│  "帮我制定一周健身计划"              │
│  已执行到第 4 步 (共约 6 步)         │
│  最后操作: 沙箱代码执行 (分析空闲时间)│
│                                     │
│  ┌─────────┐    ┌─────────┐        │
│  │  恢复   │    │  放弃   │        │
│  └─────────┘    └─────────┘        │
└─────────────────────────────────────┘
```

### 12.6 与 AppLifecycleService 集成

```dart
// app_lifecycle_service.dart 中监听
@override
void didChangeAppLifecycleState(ui.AppLifecycleState state) {
  if (state == ui.AppLifecycleState.paused) {
    // App 进入后台 → 保存当前运行中的 Agent 会话状态
    sl<CheckpointManager>().pauseAllRunning();
  }
  if (state == ui.AppLifecycleState.resumed) {
    // App 恢复前台 → 检查是否有未完成的会话
    sl<CheckpointManager>().checkAndNotifyRecovery();
  }
}
```

---

## 13. UI/UX 设计 — 新事件类型组件

### 13.1 问题

当前 `LingMessageBubble` 只处理 `thinking` + `content`。Agent 框架新增了 8 种事件类型，每种都需要明确的 UI 呈现。

### 13.2 事件 → 组件映射

| AgentEvent | UI 组件 | 位置 | 交互 |
|------------|---------|------|------|
| `thinking` | `_ThinkingBlock` (已有) | bubble 内, content 上方 | 可折叠 |
| `content` | `LingMessageBubble` (已有) | bubble 内 | 无 |
| `toolCall` | `ToolCallCard` | bubble 内, content 下方 | 可展开看参数 |
| `toolResult` | `ToolResultCard` | toolCall 下方 | 可展开看结果 |
| `skillTriggered` | `SkillBanner` | bubble 上方 | 无, 仅提示 |
| `skillProgress` | `SkillProgressBar` | skillTriggered 下方 | 无, 实时更新 |
| `sandboxExec` | `SandboxCodeCard` | bubble 内 | 可展开看代码+结果 |
| `mcpCall` | `McpCallCard` | bubble 内 | 可展开看调用详情 |
| `humanConfirmation` | `ConfirmDialog` | 全屏弹窗 | 确认/拒绝/修改 |
| `loopWarning` | `LoopWarningBanner` | bubble 上方 | 用户可强制停止 |
| `plan` | `PlanTimeline` | bubble 内 | 可展开看步骤 |
| `done` | `StatsFooter` | bubble 底部 | 可展开看统计 |
| `error` | `ErrorCard` | bubble 内 | 可重试 |

### 13.3 组件设计

#### ToolCallCard — 工具调用卡片

```
┌─────────────────────────────────────┐
│  🔧 调用工具: schedule.query          │
│  参数: {date: "2026-09-01", range: "week"} │
│  状态: ✅ 完成                        │
│  ──────────────────────────────────  │
│  ▸ 展开结果                          │
└─────────────────────────────────────┘
```

```dart
class ToolCallCard extends StatelessWidget {
  final String toolName;
  final Map<String, dynamic> args;
  final ToolResult? result;
  final bool isExecuting;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.build_outlined, size: 16),
            SizedBox(width: 8),
            Text('调用工具: $toolName', style: context.textTheme.bodySmall),
            Spacer(),
            _buildStatusIcon(),
          ]),
          if (args.isNotEmpty) ...[
            SizedBox(height: 4),
            Text('参数: ${_formatArgs(args)}',
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.theme.colorScheme.onSurfaceVariant,
                )),
          ],
          if (result != null) _buildResultExpansion(),
        ],
      ),
    );
  }
}
```

#### SkillBanner — 技能触发提示

```
┌─────────────────────────────────────┐
│  ⚡ 触发技能: 健身计划制定              │
│  ████████░░░░░░░░  Step 2/5          │
└─────────────────────────────────────┘
```

#### SandboxCodeCard — 沙箱代码卡片

```
┌─────────────────────────────────────┐
│  💻 代码执行                          │
│  ┌─────────────────────────────────┐ │
│  │ final slots = schedules.where( │ │
│  │   (s) => s.endTime.hour < 14   │ │
│  │ );                              │ │
│  │ return slots.length;            │ │
│  └─────────────────────────────────┘ │
│  状态: ✅ 成功 (120ms)                │
│  输出: 5 个空闲时段                    │
│  ▸ 展开详情                           │
└─────────────────────────────────────┘
```

#### HumanConfirmationDialog — 人工确认弹窗

```
┌─────────────────────────────────────┐
│  ⚠️ Agent 请求执行敏感操作             │
│                                     │
│  工具: schedule.add                  │
│  原因: 添加 5 个健身日程               │
│                                     │
│  参数预览:                            │
│  • 周一 14:00-15:00 健身              │
│  • 周二 14:00-15:00 健身              │
│  • ...                              │
│                                     │
│  ┌────────┐  ┌────────┐  ┌────────┐│
│  │  确认  │  │  修改  │  │  拒绝  ││
│  └────────┘  └────────┘  └────────┘│
└─────────────────────────────────────┘
```

#### PlanTimeline — 执行计划时间线

```
┌─────────────────────────────────────┐
│  📋 执行计划                          │
│                                     │
│  ✅ Step 1: 查询现有日程               │
│  ✅ Step 2: 分析空闲时间               │
│  🔄 Step 3: 生成健身计划               │
│  ⬜ Step 4: 添加日程                   │
│  ⬜ Step 5: 设置提醒                   │
└─────────────────────────────────────┘
```

#### StatsFooter — 运行统计

```
┌─────────────────────────────────────┐
│  5 步 · 3,247 tokens · ¥0.03 · 12s  │
│  ▸ 展开详情                           │
└─────────────────────────────────────┘
```

### 13.4 LingMessageBubble 扩展

```dart
class LingMessageBubble extends StatelessWidget {
  // 已有: text, thinking, metadata

  // 新增: Agent 事件列表 (按顺序展示)
  final List<AgentEvent>? agentEvents;

  Widget _buildAgentEvents() {
    if (agentEvents == null || agentEvents!.isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. 技能触发 (如果有)
        for (final e in agentEvents!)
          if (e is SkillTriggeredEvent) SkillBanner(skill: e.skill),

        // 2. 执行计划 (如果有)
        for (final e in agentEvents!)
          if (e is PlanEvent) PlanTimeline(steps: e.steps),

        // 3. 思考过程 (已有 _ThinkingBlock)
        if (metadata?['thinking'] != null)
          _ThinkingBlock(thinking: metadata!['thinking']),

        // 4. 正文 (已有)
        if (text.isNotEmpty) Text(text),

        // 5. 工具调用 + 结果
        for (final e in agentEvents!)
          if (e is ToolCallEvent) ToolCallCard(call: e.call)
          else if (e is ToolResultEvent) ToolResultCard(result: e.result),

        // 6. 沙箱执行
        for (final e in agentEvents!)
          if (e is SandboxExecEvent) SandboxCodeCard(event: e),

        // 7. 统计
        for (final e in agentEvents!)
          if (e is DoneEvent) StatsFooter(stats: e.stats),
      ],
    );
  }
}
```

### 13.5 ChatPage 集成 — 事件分发

```dart
// chat_page.dart 中 _streamAiReply 替换为 _runAgent
void _runAgent(LingConversation conv, String userText) {
  final harness = sl<AgentHarness>();
  final controller = _chatControllers[conv.id]!;

  String? aiMsgId;
  final events = <AgentEvent>[];

  harness.run(agentId: conv.id, userInput: userText).listen(
    (event) {
      switch (event) {
        case ThinkingEvent(:final delta):
          _updateThinking(controller, aiMsgId, delta);

        case ContentEvent(:final delta):
          aiMsgId = _updateContent(controller, aiMsgId, conv.id, delta);

        case ToolCallEvent():
          events.add(event);
          _updateEvents(controller, aiMsgId, events);

        case HumanConfirmationEvent():
          _showConfirmDialog(event).then((approved) {
            // 通过 Completer 把结果回传给 Agent
          });

        case SkillTriggeredEvent():
          events.add(event);
          _updateEvents(controller, aiMsgId, events);

        case DoneEvent(:final finalReply, :final stats):
          events.add(event);
          _finalizeMessage(controller, aiMsgId, finalReply, events);
          sl<ChatService>().addAiMessage(conv.id, finalReply, metadata: {
            'events': events.map(_serializeEvent).toList(),
            'stats': stats.toJson(),
          });

        case ErrorEvent():
          _showError(event);

        default:
          events.add(event);
          _updateEvents(controller, aiMsgId, events);
      }
    },
  );
}
```

---

## 14. 成本可见性与预算治理

### 14.1 问题

用户切到 `deepseek-reasoner` 跑一个 10 步 ReAct 循环，token 消耗可能是单轮问答的 20 倍。用户不知道花了多少钱，月底才发现账单爆炸。

### 14.2 CostTracker — 实时成本追踪

```dart
/// 成本追踪器 — 实时记录每次 LLM 调用的 token 消耗和费用。
class CostTracker {
  final AgentStorage storage;

  /// 各模型的单价 (每 1K tokens)
  /// 从 AppConfig 读取, 可在设置页修改
  final Map<String, ModelPricing> _pricing = {
    'deepseek-chat': ModelPricing(input: 0.001, output: 0.002, currency: 'CNY'),
    'deepseek-reasoner': ModelPricing(input: 0.004, output: 0.016, currency: 'CNY'),
  };

  /// 记录一次 LLM 调用
  Future<void> record({
    required String sessionId,
    required String model,
    required int inputTokens,
    required int outputTokens,
    required int thinkingTokens,
  }) async {
    final pricing = _pricing[model] ?? _pricing['deepseek-chat']!;
    final cost = pricing.calculate(
      input: inputTokens,
      output: outputTokens,
      thinking: thinkingTokens,
    );

    await storage.saveCostRecord(CostRecord(
      sessionId: sessionId,
      model: model,
      inputTokens: inputTokens,
      outputTokens: outputTokens,
      thinkingTokens: thinkingTokens,
      cost: cost,
      timestamp: DateTime.now(),
    ));
  }

  /// 今日总消耗
  Future<CostSummary> todaySummary() async {
    return storage.costSummary(since: DateTime.now().startOfDay);
  }

  /// 本月总消耗
  Future<CostSummary> monthSummary() async {
    return storage.costSummaries(since: DateTime.now().startOfMonth);
  }

  /// 检查是否超出预算
  bool isOverBudget(BudgetConfig config) {
    final today = todaySummary();
    return today.cost > config.dailyLimitCNY;
  }
}

class ModelPricing {
  final double input;   // 每 1K tokens 输入价格
  final double output;  // 每 1K tokens 输出价格
  final String currency;

  double calculate({required int input, required int output, required int thinking}) {
    return (input * inputPrice + output * outputPrice + thinking * inputPrice) / 1000;
  }
}

class CostSummary {
  final int totalTokens;
  final int inputTokens;
  final int outputTokens;
  final int thinkingTokens;
  final double cost;
  final String currency;
  final int callCount;
}
```

### 14.3 预算配置

```dart
class BudgetConfig {
  /// 每日费用上限 (CNY)
  final double dailyLimitCNY;

  /// 单次 Agent 运行最大 token
  final int maxTokensPerRun;

  /// 单次 Agent 运行最大步数
  final int maxStepsPerRun;

  /// 超出预算时的行为
  final BudgetExceededAction onExceeded;

  const BudgetConfig({
    this.dailyLimitCNY = 5.0,        // 默认每天 5 元
    this.maxTokensPerRun = 50000,    // 单次最多 5 万 token
    this.maxStepsPerRun = 15,        // 单次最多 15 步
    this.onExceeded = BudgetExceededAction.warnAndPause,
  });
}

enum BudgetExceededAction {
  warnAndPause,    // 警告并暂停, 等用户确认
  warnAndContinue, // 警告但继续
  hardStop,        // 直接停止
}
```

### 14.4 成本可见性 UI

#### 每条消息底部 — StatsFooter

已在 §13 定义，每条 Agent 回复底部显示 `5 步 · 3,247 tokens · ¥0.03 · 12s`。

#### 设置页 — 成本统计

```
┌─────────────────────────────────────┐
│  💰 AI 使用统计                       │
│                                     │
│  今日: ¥0.32 (12 次对话)              │
│  本月: ¥8.45 (318 次对话)             │
│                                     │
│  模型分布:                            │
│  deepseek-chat      ¥5.20 (61%)     │
│  deepseek-reasoner  ¥3.25 (39%)     │
│                                     │
│  预算设置:                            │
│  每日上限: ¥5.00          [滑块]      │
│  当前: ¥0.32 / ¥5.00    ██████░░░░   │
│                                     │
│  [查看详细记录]                       │
└─────────────────────────────────────┘
```

#### 预算超限警告

```
┌─────────────────────────────────────┐
│  ⚠️ 今日 AI 使用已接近上限             │
│                                     │
│  已用: ¥4.82 / ¥5.00 (96%)           │
│                                     │
│  你可以:                             │
│  • 继续使用 (可能产生额外费用)         │
│  • 调整每日上限                       │
│  • 切换到更便宜的模型                  │
│                                     │
│  ┌────────┐  ┌────────┐  ┌────────┐│
│  │ 继续  │  │ 调整  │  │ 切模型 ││
│  └────────┘  └────────┘  └────────┘│
└─────────────────────────────────────┘
```

### 14.5 与 VerifyGuard 集成

```dart
class VerifyGuard {
  final CostTracker costTracker;
  final BudgetConfig budgetConfig;

  GuardResult preCheck(ToolCall call, AgentContext context) {
    // 检查预算
    if (costTracker.isOverBudget(budgetConfig)) {
      return GuardResult.deny;
    }
    // ... 其他检查
  }

  BudgetStatus checkBudget(AgentRunStats stats, BudgetConfig config) {
    final todayCost = costTracker.todaySummary().cost;
    if (todayCost >= config.dailyLimitCNY) {
      return BudgetStatus.exceeded;
    }
    if (todayCost >= config.dailyLimitCNY * 0.8) {
      return BudgetStatus.warning;
    }
    return BudgetStatus.ok;
  }
}
```

---

## 15. 多设备同步与冲突解决

### 15.1 问题

七牛云存储是 last-write-wins，两台设备同时修改 Agent 记忆会丢数据。ScheduleService/PostService 已有这个问题，Agent 记忆会放大它。

### 15.2 方案 — 版本号 + 字段级合并

```dart
/// 同步元数据 — 每条记录附带版本信息。
class SyncMeta {
  final String deviceId;       // 设备标识
  final int version;           // 递增版本号
  final DateTime updatedAt;    // 更新时间
  final DateTime? deletedAt;   // 软删除时间 (null = 未删除)
}

/// 可同步的 Agent 记忆条目。
class SyncableMemory {
  final String id;
  final String userId;
  final String agentId;
  final String type;
  final String content;
  final double importance;
  final SyncMeta sync;
}
```

### 15.3 同步策略

```
设备 A 修改记忆 M (version=2, device=A)
设备 B 同时修改记忆 M (version=2, device=B)
    │
    ▼
同步时检测到冲突 (同 id, 同 version, 不同 device)
    │
    ├──→ 类型为 'preference' (偏好) → 字段级合并
    │    A 改了 content, B 改了 importance → 取两者
    │
    ├──→ 类型为 'fact' (事实) → 时间戳优先
    │    取 updatedAt 更新的那条
    │
    ├──→ 类型为 'skill_mastery' → 取最大值
    │    mastery 是递增的, 取 max(A, B)
    │
    └──→ 无法自动解决 → 标记为冲突, 等用户处理
```

### 15.4 SyncManager

```dart
class AgentSyncManager {
  final QiniuStorageService qiniu;
  final AgentStorage storage;
  final String deviceId;

  /// 上传本地变更到云端
  Future<void> push() async {
    final localChanges = await storage.getUnsyncedMemories();
    if (localChanges.isEmpty) return;

    // 下载云端版本
    final cloudSnapshot = await qiniu.fetchJson('agents/memories_${userId}.json');
    final cloudMemories = _parseMemories(cloudSnapshot);

    // 合并
    final merged = _merge(localChanges, cloudMemories);

    // 上传合并结果
    await qiniu.uploadJson('agents/memories_${userId}.json', _serialize(merged));

    // 标记本地为已同步
    await storage.markSynced(localChanges.map((m) => m.id));
  }

  /// 下载云端变更到本地
  Future<void> pull() async {
    final cloudSnapshot = await qiniu.fetchJson('agents/memories_${userId}.json');
    final cloudMemories = _parseMemories(cloudSnapshot);

    for (final cloud in cloudMemories) {
      final local = await storage.getMemory(cloud.id);
      if (local == null) {
        // 云端有, 本地没有 → 下载
        await storage.saveMemory(cloud);
      } else if (cloud.sync.version > local.sync.version) {
        // 云端版本更高 → 更新本地
        await storage.saveMemory(cloud);
      } else if (cloud.sync.version == local.sync.version &&
                 cloud.sync.deviceId != local.sync.deviceId) {
        // 冲突 → 合并
        final resolved = _resolveConflict(local, cloud);
        await storage.saveMemory(resolved);
      }
    }
  }

  /// 字段级合并
  SyncableMemory _resolveConflict(SyncableMemory local, SyncableMemory cloud) {
    switch (local.type) {
      case 'preference':
        // 取两者各自改的字段
        return local.copyWith(
          content: local.sync.updatedAt.isAfter(cloud.sync.updatedAt)
              ? local.content : cloud.content,
          importance: max(local.importance, cloud.importance),
          sync: SyncMeta(
            deviceId: 'merged',
            version: max(local.sync.version, cloud.sync.version) + 1,
            updatedAt: DateTime.now(),
          ),
        );
      case 'fact':
        // 时间戳优先
        return local.sync.updatedAt.isAfter(cloud.sync.updatedAt) ? local : cloud;
      case 'skill_mastery':
        // 取最大值
        return (local.importance >= cloud.importance) ? local : cloud;
      default:
        return local; // 保守: 保留本地
    }
  }
}
```

### 15.5 同步时机

| 时机 | 操作 | 触发方式 |
|------|------|---------|
| App 启动 | pull | `AppInitializer` |
| 记忆更新后 | push (防抖 30s) | `MemoryManager` notify |
| App 进入后台 | push | `AppLifecycleService` |
| 网络恢复 | push + pull | `ConnectivityService` |
| 手动同步 | push + pull | 设置页按钮 |

---

## 16. 离线降级策略

### 16.1 问题

手机没网时 Agent 还能做什么？当前设计假设 LLM 永远可达，直接报错。

### 16.2 降级矩阵

| 能力 | 在线 | 离线 | 降级行为 |
|------|------|------|---------|
| LLM 推理 | ✅ | ❌ | 提示用户"需要网络" |
| 内置工具 (日程/帖子) | ✅ | ✅ | 正常执行 (本地 SQLite) |
| MCP 远程工具 | ✅ | ❌ | 跳过, 提示不可用 |
| MCP In-Process | ✅ | ✅ | 正常执行 |
| 沙箱执行 | ✅ | ✅ | 正常执行 (无网络权限) |
| 记忆检索 | ✅ | ✅ | 本地 SQLite + 本地向量 |
| 记忆同步 | ✅ | ❌ | 队列, 网络恢复后同步 |
| 模型切换 | ✅ | ❌ | 提示"切换模型需要网络" |
| 主动推送 | ✅ | ⚠️ | 本地通知可用, 远程推送不可用 |

### 16.3 OfflineAwareAgentRunner

```dart
/// 离线感知的 Agent 运行器 — 根据网络状态降级。
class OfflineAwareAgentRunner {
  final ConnectivityService connectivity;
  final AgentHarness harness;

  Stream<AgentEvent> run({
    required String agentId,
    required String userInput,
  }) async* {
    final isOnline = connectivity.isConnected;

    if (!isOnline) {
      // 检查是否有可用的离线工具
      final availableTools = harness.tools.definitions()
          .where((t) => t.category != ToolCategory.mcp || t.isInProcess)
          .toList();

      if (availableTools.isEmpty) {
        yield AgentEvent.error(
          '当前无网络连接，且没有可用的离线工具',
          severity: ErrorSeverity.warning,
        );
        return;
      }

      // 降级模式: 只用本地工具, 不调用 LLM
      yield AgentEvent.content('⚠️ 当前处于离线模式，我只能帮你执行本地操作（如查询日程、管理帖子），无法进行 AI 对话。\n\n');
      yield AgentEvent.content('你可以问我：\n');
      yield AgentEvent.content('• "我今天有什么日程？"\n');
      yield AgentEvent.content('• "帮我查一下最近的帖子"\n');
      yield AgentEvent.content('• "整理一下我的日程数据"\n');
      yield AgentEvent.done('', AgentRunStats.empty());
      return;
    }

    // 在线 → 正常运行
    yield* harness.run(agentId: agentId, userInput: userInput);
  }
}
```

### 16.4 离线工具执行 (无 LLM)

用户离线时说"我今天有什么日程"，不需要 LLM 也能回答：

```dart
class OfflineToolExecutor {
  /// 离线模式: 直接匹配意图 → 执行工具 → 格式化输出
  Future<String> tryOfflineExecute(String userInput) async {
    // 简单意图匹配 (不需要 LLM)
    if (_matches(userInput, ['今天', '日程', '安排'])) {
      final schedules = await sl<ScheduleService>().getTodaySchedules();
      if (schedules.isEmpty) return '今天没有日程安排';
      return '今天的日程:\n${schedules.map(_formatSchedule).join('\n')}';
    }

    if (_matches(userInput, ['帖子', '信息圈', '最新'])) {
      final posts = await sl<PostService>().getRecentPosts(limit: 5);
      if (posts.isEmpty) return '暂时没有帖子';
      return '最新帖子:\n${posts.map(_formatPost).join('\n')}';
    }

    // 无法离线处理
    return '抱歉，这个请求需要网络连接才能处理';
  }

  bool _matches(String input, List<String> keywords) {
    return keywords.any((k) => input.contains(k));
  }
}
```

### 16.5 与 ConnectivityService 集成

```dart
// 监听网络变化, 自动切换模式
connectivity.networkStream.listen((type) {
  if (type == NetworkType.none) {
    _showOfflineBanner();  // 顶部显示"离线模式"横幅
  } else {
    _hideOfflineBanner();
    _flushPendingSyncs();  // 网络恢复 → 同步待处理的数据
  }
});
```

---

## 17. 错误处理与重试策略

### 17.1 错误分类

| 类别 | 示例 | 处理方式 |
|------|------|---------|
| **LLM 网络错误** | 超时、429 限流、5xx | 指数退避重试 3 次 |
| **LLM 内容错误** | 返回非 JSON、格式错误 | 回传 LLM 让它修正 |
| **工具执行错误** | ScheduleService 抛异常 | 捕获 → 结果回传 LLM → LLM 决定重试或换方案 |
| **沙箱错误** | 代码编译失败、运行时异常 | 错误信息回传 LLM → LLM 修正代码 |
| **MCP 错误** | Server 断连、工具不存在 | 跳过该工具 → 告知 LLM 工具不可用 |
| **预算超限** | token/费用超上限 | 熔断 → 停止执行 → 通知用户 |
| **循环检测** | Agent 反复调用同一工具 | 熔断 → 停止执行 → 通知用户 |
| **持久化错误** | SQLite 写入失败 | 日志记录 → 内存继续 → 下次重试写入 |

### 17.2 错误严重级别

```dart
enum ErrorSeverity {
  info,       // 可忽略, 不影响流程
  warning,    // 警告, 流程继续但降级
  error,      // 错误, 当前步骤失败, 可重试
  critical,   // 严重, 整个 Agent 运行终止
}
```

### 17.3 重试策略

```dart
/// 指数退避重试器。
class RetryStrategy {
  final int maxRetries;
  final Duration initialDelay;
  final double backoffMultiplier;

  const RetryStrategy({
    this.maxRetries = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.backoffMultiplier = 2.0,
  });

  /// 执行带重试的操作
  Future<T> execute<T>(Future<T> Function() operation) async {
    int attempts = 0;
    Duration delay = initialDelay;

    while (true) {
      try {
        return await operation();
      } catch (e) {
        attempts++;
        if (attempts >= maxRetries) rethrow;

        // 429 限流 → 等更久
        if (e is RateLimitException) {
          delay = Duration(seconds: e.retryAfter ?? delay.inSeconds);
        }

        await Future.delayed(delay);
        delay = Duration(milliseconds: (delay.inMilliseconds * backoffMultiplier).round());
      }
    }
  }
}
```

### 17.4 LLM 错误自修复

当 LLM 返回的 tool_call 格式错误时，不直接报错，而是把错误信息回传给 LLM 让它修正：

```dart
// ReAct Loop 中的错误处理
try {
  final result = await tools.execute(call.name, call.args);
  context.addToolResult(call.name, result);
} catch (e) {
  // 错误信息回传 LLM, 让它知道发生了什么并自行修正
  context.addToolResult(call.name, ToolResult(
    success: false,
    error: e.toString(),
    suggestion: '工具执行失败，请检查参数或换一个方法',
  ));
  // 继续循环, LLM 会看到错误并尝试修正
}
```

### 17.5 与现有 ErrorHandler 集成

```dart
// 复用 core/errors/error_handler.dart
class AgentErrorHandler {
  final ErrorHandler baseHandler;  // 已有的 Nudgee 错误处理器

  void handleAgentError(AgentEvent error, {String? sessionId}) {
    switch (error.severity) {
      case ErrorSeverity.info:
        logger.d(error.message, tag: 'agent');
        break;
      case ErrorSeverity.warning:
        logger.w(error.message, tag: 'agent');
        break;
      case ErrorSeverity.error:
        logger.e(error.message, tag: 'agent');
        baseHandler.handleError(error.message, tag: 'agent');
        break;
      case ErrorSeverity.critical:
        logger.e('CRITICAL: ${error.message}', tag: 'agent');
        baseHandler.handleError(error.message, tag: 'agent', fatal: true);
        _notifyUser(error.message);
        break;
    }
  }
}
```

---

## 18. 日志、可观测性与性能监控

### 18.1 可观测性三层

| 层 | 内容 | 工具 |
|----|------|------|
| **用户可见** | StatsFooter (步数/token/费用/耗时) | UI 组件 |
| **开发调试** | 每步的完整事件流 | LoggerService + agent_logs 表 |
| **性能监控** | 帧率、内存、工具耗时 | FrameTimingMonitorService (已有) |

### 18.2 Agent 执行日志

每次 Agent 运行的完整事件流都记录到 `agent_logs` 表，用于调试和评估：

```dart
class AgentLogger {
  final LoggerService logger;      // 已有的日志服务
  final AgentStorage storage;

  /// 记录 Agent 事件
  Future<void> logEvent(String sessionId, AgentEvent event, {int? step}) async {
    // 1. 实时日志 (开发模式打印到控制台)
    logger.d('[Agent] ${event.runtimeType}: ${_summarize(event)}', tag: 'agent');

    // 2. 持久化到 agent_logs 表 (用于事后分析)
    await storage.insertLog(AgentLog(
      id: uuid(),
      sessionId: sessionId,
      eventType: event.runtimeType.toString(),
      content: _serialize(event),
      step: step,
      timestamp: DateTime.now(),
    ));
  }
}
```

### 18.3 开发者面板 — Agent 执行回放

```
┌─────────────────────────────────────┐
│  🔍 Agent 执行回放                    │
│                                     │
│  Session: abc123                    │
│  Agent: 星语                         │
│  输入: "帮我制定一周健身计划"           │
│                                     │
│  Step 1: thinking (234 tokens)      │
│  Step 2: tool_call schedule.query   │
│  Step 3: tool_result (5 schedules)  │
│  Step 4: sandbox_exec (120ms)       │
│  Step 5: thinking (456 tokens)      │
│  Step 6: human_confirmation ✅       │
│  Step 7: tool_call schedule.add x5  │
│  Step 8: content (streaming...)     │
│                                     │
│  总计: 8 步 · 3,247 tokens · 12s    │
│  [导出日志]  [重新执行]               │
└─────────────────────────────────────┘
```

### 18.4 性能监控集成

```dart
// 复用 FrameTimingMonitorService (已有)
class AgentPerformanceMonitor {
  final FrameTimingMonitorService frameMonitor;

  /// 监控 Agent 执行期间的帧率
  void startMonitoring(String sessionId) {
    frameMonitor.startSession('agent_$sessionId');
  }

  /// Agent 执行结束, 检查是否导致卡顿
  void stopMonitoring(String sessionId, AgentRunStats stats) {
    final report = frameMonitor.stopSession('agent_$sessionId');
    if (report.droppedFrames > 10) {
      logger.w('Agent 执行导致掉帧: ${report.droppedFrames}', tag: 'agent_perf');
      // 如果沙箱执行或工具调用在主 isolate 导致卡顿
      // → 后续版本考虑移到 worker isolate
    }
  }
}
```

### 18.5 关键指标

| 指标 | 目标 | 监控方式 |
|------|------|---------|
| Agent 首字延迟 | < 2s | LLM 流式首 token 时间 |
| 工具执行耗时 | < 500ms | ToolRegistry 计时 |
| 沙箱执行耗时 | < 5s | Sandbox 计时 |
| 帧率影响 | 掉帧 < 5 | FrameTimingMonitorService |
| 内存增量 | < 20MB | DevTools / debugPrint |
| 冷启动影响 | < 100ms | AppInitializer 计时 |

---

## 19. 测试策略

### 19.1 测试分层

| 层 | 范围 | 工具 | 目标 |
|----|------|------|------|
| **单元测试** | 单个工具/技能/记忆操作 | `flutter test` | 每个工具独立可测 |
| **集成测试** | Agent + 工具 + 记忆 | `flutter test` | ReAct 循环端到端 |
| **Mock LLM 测试** | Agent 全流程 (LLM 用 Mock) | 自定义 MockLLMClient | 不依赖真实 API |
| **Widget 测试** | UI 组件 (ToolCallCard 等) | `flutter test` | 组件渲染正确 |
| **黄金测试** | Agent 回复格式 | `flutter test --update-goldens` | 防止 UI 回归 |

### 19.2 MockLLMClient — 不依赖真实 API 的测试

```dart
/// Mock LLM Client — 按预设脚本返回, 用于测试 Agent 循环。
class MockLLMClient implements LLMClient {
  /// 预设的回复脚本 (按顺序消费)
  final List<LLMChunk> _script;
  int _index = 0;

  MockLLMClient(this._script);

  @override
  Stream<LLMChunk> streamChat({
    required String message,
    required String systemPrompt,
    List<Message>? history,
    List<ToolDefinition>? tools,
    double? temperature,
  }) async* {
    while (_index < _script.length) {
      yield _script[_index++];
    }
  }

  @override
  void switchModel(String model) {}

  @override
  List<String> availableModels() => ['mock-model'];

  @override
  TokenUsage estimateUsage(String input, String output) =>
      TokenUsage(input: input.length ~/ 4, output: output.length ~/ 4);
}

/// 测试示例: Agent 调用 schedule.query 工具
test('Agent calls schedule.query tool when asked about today schedule', () async {
  final mockLlm = MockLLMClient([
    LLMChunk(toolCall: ToolCall(name: 'schedule.query', args: {'date': 'today'})),
    LLMChunk(contentDelta: '你今天有 3 个日程安排...'),
    LLMChunk(isDone: true),
  ]);

  final harness = AgentHarness(llm: mockLlm, tools: mockTools, ...);
  final events = await harness.run(agentId: 'test', userInput: '我今天有什么日程?').toList();

  expect(events, contains(predicate((e) => e is ToolCallEvent && e.call.name == 'schedule.query')));
  expect(events.last, isA<DoneEvent>());
});
```

### 19.3 工具测试 — 每个 Tool 独立可测

```dart
test('ScheduleAddTool adds schedule via ScheduleService', () async {
  final mockScheduleService = MockScheduleService();
  final tool = ScheduleAddTool(mockScheduleService);

  final result = await tool.execute({
    'title': '健身',
    'startTime': '2026-09-01T14:00:00',
    'endTime': '2026-09-01T15:00:00',
  });

  expect(result.success, isTrue);
  verify(mockScheduleService.addSchedule(any)).called(1);
});
```

### 19.4 沙箱安全测试

```dart
test('Sandbox blocks filesystem access by default', () async {
  final sandbox = Sandbox();
  final result = await sandbox.execute(
    code: "import 'dart:io'; void main() { File('test.txt').writeAsStringSync('hack'); }",
    permissions: SandboxPermissions.safe,
  );

  expect(result.success, isFalse);
  expect(result.error, contains('FilesystemPermission'));
});

test('Sandbox blocks network to non-whitelisted domains', () async {
  final sandbox = Sandbox();
  final result = await sandbox.execute(
    code: "import 'dart:io'; void main() { HttpClient().getUrl(Uri.parse('https://evil.com')); }",
    permissions: SandboxPermissions.compute,
  );

  expect(result.success, isFalse);
});
```

### 19.5 测试目录结构

```
test/
├── core/
│   └── agent/
│       ├── tools/
│       │   ├── schedule_tools_test.dart
│       │   ├── post_tools_test.dart
│       │   └── sandbox_tool_test.dart
│       ├── skills/
│       │   ├── weekly_planner_skill_test.dart
│       │   └── fitness_plan_skill_test.dart
│       ├── memory/
│       │   └── memory_manager_test.dart
│       ├── guard/
│       │   ├── verify_guard_test.dart
│       │   └── loop_detector_test.dart
│       ├── sandbox/
│       │   ├── sandbox_permissions_test.dart
│       │   └── sandbox_safety_test.dart
│       ├── mcp/
│       │   └── in_process_mcp_test.dart
│       ├── harness_test.dart           # 端到端 (Mock LLM)
│       └── checkpoint_test.dart        # 崩溃恢复测试
└── widgets/
    └── agent/
        ├── tool_call_card_test.dart
        ├── skill_banner_test.dart
        └── sandbox_code_card_test.dart
```

---

## 20. 配置管理、国际化与主题适配

### 20.1 配置管理 — config.yaml 扩展

在现有 `config.yaml` 中新增 `agent` 段：

```yaml
# config.yaml
ai:
  provider: deepseek
  apiKey: ${DEEPSEEK_API_KEY}
  model: deepseek-chat
  baseUrl: https://api.deepseek.com/v1
  systemPrompt: "你是星语..."

# 新增: Agent 框架配置
agent:
  # 默认预算
  budget:
    dailyLimitCNY: 5.0
    maxTokensPerRun: 50000
    maxStepsPerRun: 15
    onExceeded: warnAndPause    # warnAndPause | warnAndContinue | hardStop

  # 模型定价 (用于成本计算)
  pricing:
    deepseek-chat:
      input: 0.001              # CNY per 1K tokens
      output: 0.002
    deepseek-reasoner:
      input: 0.004
      output: 0.016

  # 默认 Agent
  defaultAgent:
    id: ai_assistant
    name: 星语
    model: deepseek-chat
    temperature: 0.7
    maxSteps: 10

  # MCP 配置
  mcp:
    autoConnectInProcess: true   # 始终连接内置 MCP
    remoteServers:
      - id: web-search
        url: https://mcp.example.com/search
        autoConnect: true
    # stdio servers 仅桌面生效, 移动端自动跳过
    stdioServers:
      - id: filesystem
        command: npx
        args: ['-y', '@modelcontextprotocol/server-filesystem']

  # 沙箱配置
  sandbox:
    defaultTimeout: 10s
    memoryLimitMB: 50
    allowNetwork: false          # 默认禁止网络
    networkWhitelist: []

  # 记忆配置
  memory:
    workingWindowSize: 20        # 短期记忆保留最近 N 轮
    episodeSummaryInterval: 10   # 每 N 轮生成一次会话摘要
    longTermExtractionEnabled: true
    vectorSearchEnabled: false   # 后续启用

  # 同步配置
  sync:
    debounceSeconds: 30          # 记忆更新后防抖 N 秒再上传
    conflictResolution: merge    # merge | lastWriteWins | manual
```

### 20.2 AppConfig 扩展

```dart
// core/config/app_config.dart 新增
class AgentConfig {
  final BudgetConfig budget;
  final Map<String, ModelPricing> pricing;
  final DefaultAgentConfig defaultAgent;
  final McpConfig mcp;
  final SandboxConfig sandbox;
  final MemoryConfig memory;
  final SyncConfig sync;

  static AgentConfig? fromYaml(YamlMap map) { ... }
}
```

### 20.3 国际化 — l10n 新增键

```json
// lib/l10n/app_zh.arb
{
  "agentToolCall": "调用工具: {name}",
  "@agentToolCall": {"placeholders": {"name": {"type": "String"}}},
  "agentSkillTriggered": "触发技能: {name}",
  "@agentSkillTriggered": {"placeholders": {"name": {"type": "String"}}},
  "agentSandboxExec": "代码执行",
  "agentHumanConfirm": "Agent 请求执行敏感操作",
  "agentHumanConfirmReason": "原因: {reason}",
  "@agentHumanConfirmReason": {"placeholders": {"reason": {"type": "String"}}},
  "agentConfirm": "确认",
  "agentReject": "拒绝",
  "agentModify": "修改",
  "agentLoopWarning": "检测到循环，Agent 可能陷入死循环",
  "agentForceStop": "强制停止",
  "agentStatsSteps": "{count} 步",
  "@agentStatsSteps": {"placeholders": {"count": {"type": "int"}}},
  "agentStatsTokens": "{count} tokens",
  "@agentStatsTokens": {"placeholders": {"count": {"type": "int"}}},
  "agentStatsCost": "¥{cost}",
  "@agentStatsCost": {"placeholders": {"cost": {"type": "String"}}},
  "agentStatsDuration": "{seconds}s",
  "@agentStatsDuration": {"placeholders": {"seconds": {"type": "int"}}},
  "agentBudgetWarning": "今日 AI 使用已接近上限",
  "agentBudgetExceeded": "今日 AI 使用已超出上限",
  "agentOfflineMode": "当前处于离线模式",
  "agentOfflineHint": "只能执行本地操作，无法进行 AI 对话",
  "agentRecoveryTitle": "上次有未完成的任务",
  "agentRecoveryResume": "恢复",
  "agentRecoveryAbort": "放弃",
  "agentCostToday": "今日: ¥{cost} ({count} 次对话)",
  "@agentCostToday": {"placeholders": {"cost": {"type": "String"}, "count": {"type": "int"}}},
  "agentCostMonth": "本月: ¥{cost} ({count} 次对话)",
  "@agentCostMonth": {"placeholders": {"cost": {"type": "String"}, "count": {"type": "int"}}},
  "agentBudgetSettings": "预算设置",
  "agentDailyLimit": "每日上限"
}
```

```json
// lib/l10n/app_en.arb (对应英文)
{
  "agentToolCall": "Tool call: {name}",
  "agentSkillTriggered": "Skill triggered: {name}",
  "agentSandboxExec": "Code execution",
  "agentHumanConfirm": "Agent requests sensitive operation",
  "agentHumanConfirmReason": "Reason: {reason}",
  "agentConfirm": "Confirm",
  "agentReject": "Reject",
  "agentModify": "Modify",
  "agentLoopWarning": "Loop detected, agent may be stuck",
  "agentForceStop": "Force stop",
  "agentStatsSteps": "{count} steps",
  "agentStatsTokens": "{count} tokens",
  "agentStatsCost": "¥{cost}",
  "agentStatsDuration": "{seconds}s",
  "agentBudgetWarning": "AI usage approaching daily limit",
  "agentBudgetExceeded": "AI usage exceeded daily limit",
  "agentOfflineMode": "Offline mode",
  "agentOfflineHint": "Only local operations available, no AI chat",
  "agentRecoveryTitle": "You have an unfinished task",
  "agentRecoveryResume": "Resume",
  "agentRecoveryAbort": "Discard",
  "agentCostToday": "Today: ¥{cost} ({count} chats)",
  "agentCostMonth": "This month: ¥{cost} ({count} chats)",
  "agentBudgetSettings": "Budget settings",
  "agentDailyLimit": "Daily limit"
}
```

### 20.4 主题适配

所有 Agent UI 组件使用 `context.theme` 而非硬编码颜色，确保深色/浅色主题都正确：

```dart
class ToolCallCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        // 使用 theme 提供的颜色, 自动适配深色/浅色
        color: context.theme.colorScheme.surfaceContainerHighest,
        border: Border.all(color: context.theme.dividerColor),
      ),
      child: ...
    );
  }
}
```

### 20.5 无障碍 (Accessibility)

- 所有交互元素提供 `Semantics` 标注
- 工具调用卡片支持屏幕阅读器朗读
- 确认弹窗支持键盘导航
- 文字大小跟随系统设置

---

## 21. 从 LingAgent 吸纳的设计 (v0.4)

调研了桌面上的 `ling-agent` 项目（Go 实现的生产级 coding agent harness），以下设计值得吸纳到 Nudgee Agent 框架。

### 21.1 值得吸纳的 7 个设计

| # | LingAgent 设计 | Nudgee 当前状态 | 吸纳方式 |
|---|---------------|----------------|---------|
| 1 | **两级上下文压缩** (Microcompact + Autocompact) | 只有滑动窗口裁剪 | 新增 Microcompact |
| 2 | **5 模式权限系统** (default/acceptEdits/bypass/plan/dontAsk) | 只有 requiresConfirmation 布尔值 | 新增 PermissionMode |
| 3 | **消息消毒 (Sanitize)** — 修复破损的对话历史 | 无 | 新增 MessageSanitizer |
| 4 | **Knowledge vs Memory 分离** — 知识是策展的、近规范的；记忆是追加的、会过期的 | 只有三层记忆 | 新增 Knowledge 层 |
| 5 | **ToolSearch 延迟工具加载** — 工具按需发现，减少初始 token | 全部工具一次性塞给 LLM | 新增 ToolSearch |
| 6 | **SubAgent 类型系统** (general-purpose/Explore/Plan) — 每种类型有独立 system prompt + 工具白名单 | 多 Agent 协作未定义类型 | 新增 SubAgentType |
| 7 | **Goal/PRD 锚定自主迭代** — Agent 围绕 PRD.md 反复迭代直到 `<goal-complete/>` | 无 | 新增 GoalRunner |

### 21.2 两级上下文压缩 (Microcompact + Autocompact)

LingAgent 的压缩分两级，Nudgee 当前只有 Autocompact（语义压缩），缺了 Microcompact。

```
上下文增长
    │
    ▼
┌─────────────────────────────────────────┐
│  Level 1: Microcompact (本地, 无 LLM)    │
│  触发: tool_result 总量 > 40K tokens     │
│  动作: 保留最近 3 个 tool_result,         │
│        旧的替换为 "[elided to save context]"│
│  成本: 0 token, < 1ms                    │
└─────────────────┬───────────────────────┘
                  │ 继续增长
                  ▼
┌─────────────────────────────────────────┐
│  Level 2: Autocompact (LLM 调用)         │
│  触发: 总 token > contextWindow - 33K    │
│  动作: LLM 生成对话摘要, 替换全部历史      │
│  成本: 一次 LLM 调用                     │
└─────────────────────────────────────────┘
```

```dart
class CompactionManager {
  /// Level 1: 微压缩 — 本地, 无 LLM 调用
  ///
  /// 当 tool_result 总量超过阈值时, 保留最近 N 个,
  /// 旧的替换为占位符。极快, 零成本。
  List<Message> microcompact(List<Message> messages) {
    final toolResults = messages.where((m) => m.isToolResult).toList();
    if (_estimateTokens(toolResults) < ToolResultTokenThreshold) {
      return messages;  // 不需要压缩
    }

    // 保留最近 KeepLastNResults 个, 旧的 elide
    final toKeep = toolResults.takeLast(KeepLastNResults).toSet();
    return messages.map((m) {
      if (m.isToolResult && !toKeep.contains(m)) {
        return m.copyWith(content: '[Old tool result elided to save context]');
      }
      return m;
    }).toList();
  }

  /// Level 2: 自动压缩 — LLM 生成摘要
  ///
  /// 当总 token 接近上下文窗口时, 用 LLM 生成摘要,
  /// 替换全部历史为一条携带摘要的用户消息。
  Future<List<Message>> autocompact(
    List<Message> messages, {
    required LLMClient llm,
    required int contextWindow,
  }) async {
    final threshold = contextWindow - MaxReservedTokens - CompactBufferTokens;
    if (_estimateTokens(messages) < threshold) return messages;

    // 让 LLM 生成摘要
    final summary = await llm.chat(
      _buildSummaryRequest(messages),
      systemPrompt: CompactionPrompts.summaryInstruction,
    );

    // 替换为摘要消息
    return [
      Message.user(
        '[Conversation compacted to save context. Summary follows.]\n\n$summary'
      ),
    ];
  }

  static const keepLastNResults = 3;
  static const toolResultTokenThreshold = 40000;
  static const maxReservedTokens = 20000;
  static const compactBufferTokens = 13000;
}
```

### 21.3 5 模式权限系统

LingAgent 的权限不是布尔值，而是 5 种模式，用户可以中途切换：

```dart
/// 权限模式 — 控制 Agent 执行工具时的授权行为。
///
/// 用户可在运行中切换模式, 后续工具调用立即生效。
enum PermissionMode {
  /// 默认 — 危险操作询问用户
  normal,

  /// 自动接受文件编辑, 其他危险操作仍询问
  acceptEdits,

  /// 跳过所有权限检查 (危险)
  bypassPermissions,

  /// 计划模式 — 只读, 禁止任何修改
  plan,

  /// 非交互 — 未预批准的全部拒绝
  dontAsk,
}

class PermissionContext {
  final ValueNotifier<PermissionMode> modeNotifier;

  PermissionMode get mode => modeNotifier.value;

  /// 检查工具调用权限
  PermissionDecision check(ToolCall call) {
    // 1. 先查 deny 规则
    if (_denyRules.any((r) => r.matches(call))) {
      return PermissionDecision.deny('Blocked by deny rule');
    }

    // 2. 再查 allow 规则
    if (_allowRules.any((r) => r.matches(call))) {
      return PermissionDecision.allow();
    }

    // 3. 按模式决定
    switch (mode) {
      case PermissionMode.bypassPermissions:
        return PermissionDecision.allow();
      case PermissionMode.acceptEdits:
        if (call.isEditOperation) return PermissionDecision.allow();
        return PermissionDecision.ask('Requires confirmation');
      case PermissionMode.plan:
        if (call.isMutation) return PermissionDecision.deny('Plan mode: read-only');
        return PermissionDecision.allow();
      case PermissionMode.dontAsk:
        return PermissionDecision.deny('Not pre-approved');
      case PermissionMode.normal:
        if (call.requiresConfirmation) return PermissionDecision.ask('Requires confirmation');
        return PermissionDecision.allow();
    }
  }
}
```

**Nudgee 适配**：移动端 UI 可以在聊天页面顶部放一个权限模式切换器：

```
┌─────────────────────────────────────┐
│  🔒 权限: 正常 (询问)          [▼]   │
│  ┌─────────────────────────────┐    │
│  │ ○ 正常 (危险操作询问)        │    │
│  │ ○ 自动接受编辑              │    │
│  │ ○ 计划模式 (只读)            │    │
│  │ ○ 非交互 (未预批准全拒绝)     │    │
│  │ ○ 跳过所有检查 (危险)        │    │
│  └─────────────────────────────┘    │
└─────────────────────────────────────┘
```

### 21.4 消息消毒 (MessageSanitizer)

LingAgent 在恢复会话时修复 3 类破损的对话历史。Nudgee 的崩溃恢复也需要这个。

```dart
/// 消毒器 — 修复破损的对话历史。
///
/// 三类修复:
/// 1. 空内容: 补占位符 (API 会拒绝空 content)
/// 2. 孤立 tool_use: 补合成的 tool_result (is_error=true)
/// 3. 连续同角色消息: 合并 (API 要求 user/assistant 交替)
class MessageSanitizer {
  List<Message> sanitize(List<Message> messages) {
    if (!needsSanitize(messages)) return messages;

    var out = [...messages];

    // (1) 填充空内容
    for (var i = 0; i < out.length; i++) {
      if (out[i].content.isEmpty) {
        out[i] = out[i].copyWith(
          content: '[Empty assistant turn — content was not recorded]',
        );
      }
    }

    // (2) 为每个孤立的 tool_use 补 tool_result
    for (var i = 0; i < out.length; i++) {
      if (!out[i].isAssistant) continue;
      final orphanIds = _findOrphanToolUseIds(out, i);
      if (orphanIds.isEmpty) continue;

      final synthetic = orphanIds.map((id) => Message.toolResult(
        id: id,
        content: '[Tool call abandoned — no result was recorded]',
        isError: true,
      )).toList();

      if (i + 1 < out.length && out[i + 1].isUser) {
        out[i + 1] = out[i + 1].prependContent(synthetic);
      } else {
        out.insert(i + 1, Message.userWithBlocks(synthetic));
      }
    }

    // (3) 合并连续同角色消息
    out = _mergeConsecutiveSameRole(out);

    return out;
  }
}
```

### 21.5 Knowledge vs Memory 分离

LingAgent 把"知识"和"记忆"分开，这是对的设计：

| | Knowledge (知识) | Memory (记忆) |
|--|-----------------|--------------|
| **性质** | 策展的、近规范的 | 追加的、会过期的 |
| **生命周期** | 持久, 手动维护 | 自动生成, 定期淘汰 |
| **注入方式** | 每次 session 全量注入 system prompt | 按相关性检索注入 |
| **示例** | "用户是大学生, 专业是计算机" | "昨天聊了健身计划" |

```dart
/// 知识库 — 策展的、持久的用户知识。
///
/// 与 Memory 的区别:
/// - Knowledge 是用户确认过的、规范的事实
/// - Memory 是 Agent 自动提取的、可能过时的偏好
/// - Knowledge 每次 session 全量注入 system prompt
/// - Memory 按相关性检索注入
class KnowledgeBase {
  final AgentStorage storage;

  /// 读取全部知识 (注入 system prompt)
  Future<String> readAll(String userId) async {
    final items = await storage.getAllKnowledge(userId);
    if (items.isEmpty) return '';
    return items.map((k) => '- ${k.content}').join('\n');
  }

  /// 添加知识 (需用户确认)
  Future<void> add(String userId, String content, {String? category}) async {
    await storage.saveKnowledge(KnowledgeItem(
      id: uuid(),
      userId: userId,
      content: content,
      category: category,
      createdAt: DateTime.now(),
    ));
  }

  /// 删除知识
  Future<void> remove(String id) async {
    await storage.deleteKnowledge(id);
  }
}
```

### 21.6 ToolSearch — 延迟工具加载

LingAgent 不把所有工具一次性塞给 LLM，而是用 ToolSearch 按需发现。这对 Nudgee 很重要——MCP 工具可能有几十个。

```dart
/// 工具搜索 — 让 LLM 按需发现和加载延迟工具。
///
/// 初始只给 LLM 内置工具 + ToolSearch。
/// LLM 用 ToolSearch 查 "我需要 X 能力",
/// 匹配的工具在下一步变为可用。
class ToolSearchTool extends AgentTool {
  final List<ToolInfo> _catalog;  // 延迟工具的目录 (name + description)

  @override
  String get name => 'tool_search';

  @override
  String get description =>
    'Many tools are not loaded by default. Call this with keywords '
    'describing the capability you need to find and load relevant tools; '
    'matching tools become available on the next step.';

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final query = args['query'] as String;
    final matches = _fuzzyMatch(query, _catalog);

    // 标记匹配的工具为"下一步可用"
    _registry.activateDeferred(matches.map((m) => m.name).toSet());

    return ToolResult(
      success: true,
      output: matches.isEmpty
        ? 'No tools found for "$query"'
        : 'Found ${matches.length} tools:\n${matches.map((m) => '- ${m.name}: ${m.description}').join('\n')}\n\nThese tools are now available.',
    );
  }
}
```

**效果**：初始只给 LLM 5 个内置工具 + ToolSearch，而不是 50 个工具。token 消耗减少 60-80%。

### 21.7 SubAgent 类型系统

LingAgent 的 SubAgent 不是随意创建的，而是预定义类型，每种有独立 system prompt + 工具白名单：

```dart
/// SubAgent 类型 — 预定义的子 Agent 角色。
class SubAgentType {
  final String name;
  final String description;
  final String systemPrompt;
  final List<String> allowedTools;  // ["*"] = 全部

  const SubAgentType({
    required this.name,
    required this.description,
    required this.systemPrompt,
    required this.allowedTools,
  });

  /// 从全量工具中过滤出此类型可用的工具
  ToolRegistry filterTools(ToolRegistry base) {
    if (allowedTools == ['*']) return base;
    return base.subset(allowedTools.toSet());
  }
}

/// 预设 SubAgent 类型
class SubAgentTypes {
  static const generalPurpose = SubAgentType(
    name: 'general-purpose',
    description: '通用 Agent, 用于研究复杂问题、搜索、多步任务',
    systemPrompt: '你是一个通用 Agent。使用可用工具完成任务。'
        '完成后, 返回详细的发现或操作总结。',
    allowedTools: ['*'],
  );

  static const explore = SubAgentType(
    name: 'explore',
    description: '只读探索 Agent, 用于广泛搜索, 不修改任何东西',
    systemPrompt: '你是只读探索 Agent。只能读取和搜索, 不能修改。'
        '返回简洁、有组织的发现总结, 附带文件路径和行号。',
    allowedTools: ['schedule.query', 'post.query', 'web.search', 'user.profile'],
  );

  static const plan = SubAgentType(
    name: 'plan',
    description: '架构师 Agent, 设计实现方案, 只读',
    systemPrompt: '你是架构师 Agent。探索后产出具体的、分步骤的实现方案。'
        '识别关键文件和权衡。返回方案作为最终回复, 不修改任何东西。',
    allowedTools: ['schedule.query', 'post.query', 'web.search'],
  );

  static List<SubAgentType> all = [generalPurpose, explore, plan];
}
```

### 21.8 Goal/PRD 锚定自主迭代

LingAgent 最独特的设计——Agent 围绕一个目标文档（PRD.md）反复迭代，直到发出 `<goal-complete/>` 标记：

```
用户定义目标 (GOAL.md)
    │
    ▼
┌──→ Agent 读取目标, 执行一轮迭代
│       │
│       ├──→ 使用工具完成任务
│       ├──→ 自我验证 (运行测试/检查结果)
│       └──→ 判断目标是否完成?
│            │
│            ├──→ 否 → 更新进度, 继续下一轮 ──┐
│            │                                │
│            └──→ 是 → 发出 <goal-complete/>   │
│                                            │
└────────────────────────────────────────────┘
    最多 MaxIterations 轮 (防止无限循环)
```

```dart
/// Goal Runner — 围绕目标文档的自主迭代。
class GoalRunner {
  final AgentHarness harness;
  final int maxIterations;  // 默认 10, 上限 50

  /// 运行目标迭代
  Stream<AgentEvent> run({
    required String goalSpec,   // 目标文档内容
    required String userId,
  }) async* {
    for (var i = 0; i < maxIterations; i++) {
      yield AgentEvent.content('\n--- 迭代 ${i + 1}/$maxIterations ---\n');

      final prompt = '''
当前目标:
$goalSpec

请执行下一轮迭代。完成后如果目标已达成并验证, 在回复末尾加上 <goal-complete/>。
''';

      final events = await harness.run(
        agentId: 'goal_runner',
        userInput: prompt,
      ).toList();

      // 检查是否完成
      final finalReply = events.whereType<DoneEvent>().firstOrNull?.finalReply ?? '';
      if (finalReply.contains('<goal-complete/>')) {
        yield AgentEvent.content('\n✅ 目标已完成!');
        yield AgentEvent.done(finalReply, AgentRunStats.empty());
        return;
      }

      // 继续下一轮
      yield* Stream.fromIterable(events);
    }

    yield AgentEvent.error('达到最大迭代次数 ($maxIterations), 目标未完成');
  }
}
```

### 21.9 吸纳后的目录结构更新

```
lib/core/agent/
├── ... (已有目录)
│
├── compaction/                    # 新增: 两级压缩
│   ├── compaction_manager.dart    # CompactionManager
│   ├── microcompact.dart          # 微压缩 (本地, 无 LLM)
│   └── autocompact.dart           # 自动压缩 (LLM 摘要)
│
├── permission/                    # 新增: 5 模式权限
│   ├── permission_mode.dart       # PermissionMode 枚举
│   ├── permission_context.dart    # PermissionContext
│   └── permission_rule.dart       # allow/deny 规则
│
├── sanitize/                      # 新增: 消息消毒
│   └── message_sanitizer.dart     # 修复破损对话历史
│
├── knowledge/                     # 新增: 知识库 (vs 记忆)
│   ├── knowledge_base.dart        # KnowledgeBase
│   └── knowledge_item.dart        # 知识条目模型
│
├── subagent/                      # 新增: SubAgent 类型
│   ├── subagent_type.dart         # SubAgentType
│   └── subagent_types.dart        # 预设类型 (general/explore/plan)
│
├── goal/                          # 新增: Goal 锚定迭代
│   ├── goal_runner.dart           # GoalRunner
│   └── goal_spec.dart             # 目标文档模型
│
└── tools/
    ├── ... (已有工具)
    ├── tool_search.dart           # 新增: 延迟工具搜索
    ├── ask_user.dart              # 新增: Agent 向用户提问
    └── todo_write.dart            # 新增: Agent 任务清单
```

### 21.10 吸纳后的路线图更新

在现有 Phase 基础上插入：

| Phase | 新增任务 | 来源 |
|-------|---------|------|
| Phase 1 | `MessageSanitizer` (崩溃恢复前提) | LingAgent sanitize |
| Phase 2 | `PermissionMode` 5 模式 + UI 切换器 | LingAgent permission |
| Phase 2 | `ToolSearch` 延迟工具加载 | LingAgent toolsearch |
| Phase 2 | `AskUserQuestion` 工具 | LingAgent askuser |
| Phase 2 | `TodoWrite` 工具 (Agent 自我跟踪) | LingAgent todowrite |
| Phase 3 | `KnowledgeBase` (知识 vs 记忆分离) | LingAgent knowledge |
| Phase 3 | `Microcompact` (本地快速压缩) | LingAgent compaction |
| Phase 7 | `SubAgentType` (general/explore/plan) | LingAgent subagent |
| Phase 9 | `GoalRunner` (PRD 锚定迭代) | LingAgent goal |

### 21.11 不吸纳的部分

| LingAgent 设计 | 不吸纳原因 |
|---------------|-----------|
| Swarm (多进程子 Agent) | 移动端不能 spawn 子进程, 用 Isolate 或 in-process 替代 |
| Extensions (子进程扩展协议) | 移动端不能 spawn, 用 In-Process MCP 替代 |
| LSP 集成 | Nudgee 不是 coding agent, 不需要语言服务器 |
| Browser (CDP) | 移动端不能控制 Chrome, 用 web_search/web_fetch 替代 |
| Bash 工具 | 移动端无 shell, 用 Sandbox 替代 |
| TUI (Bubble Tea) | Nudgee 是 Flutter GUI, 不需要 TUI |
| CLI (cobra) | Nudgee 是 App, 不需要 CLI |
| Transcript 文件持久化 | Nudgee 用 SQLite, 不用文件 |
