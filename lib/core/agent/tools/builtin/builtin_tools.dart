import 'package:nudgee/core/agent/tools/tool_registry.dart';
import 'package:nudgee/core/services/workspace_service.dart';

// Schedule tools
export 'package:nudgee/core/agent/tools/builtin/schedule_tools.dart';

// Post tools
export 'package:nudgee/core/agent/tools/builtin/post_tools.dart';

// Notification tools
export 'package:nudgee/core/agent/tools/builtin/notification_tools.dart';

// Memory tools
export 'package:nudgee/core/agent/tools/builtin/memory_tools.dart';

// Web search tool
export 'package:nudgee/core/agent/tools/builtin/web_search_tool.dart';

// Real-time data tools (news, weather, stock)
export 'package:nudgee/core/agent/tools/builtin/realtime_tools.dart';

// GitHub search tool
export 'package:nudgee/core/agent/tools/builtin/github_search_tool.dart';

// GitHub repo detail tool
export 'package:nudgee/core/agent/tools/builtin/github_repo_tool.dart';

// Git operations tool
export 'package:nudgee/core/agent/tools/builtin/git_tool.dart';

// Workspace tools
export 'package:nudgee/core/agent/tools/builtin/js_executor_tool.dart';
export 'package:nudgee/core/agent/tools/builtin/workspace_fs_tool.dart';
export 'package:nudgee/core/agent/tools/builtin/cloud_sandbox_tool.dart';

// DateTime tool
export 'package:nudgee/core/agent/tools/builtin/datetime_tool.dart';

// Meta tools
export 'package:nudgee/core/agent/tools/builtin/tool_search_tool.dart';
export 'package:nudgee/core/agent/tools/builtin/ask_user_tool.dart';
export 'package:nudgee/core/agent/tools/builtin/todo_write_tool.dart';

import 'package:nudgee/core/agent/tools/builtin/schedule_tools.dart';
import 'package:nudgee/core/agent/tools/builtin/post_tools.dart';
import 'package:nudgee/core/agent/tools/builtin/notification_tools.dart';
import 'package:nudgee/core/agent/tools/builtin/memory_tools.dart';
import 'package:nudgee/core/agent/tools/builtin/web_search_tool.dart';
import 'package:nudgee/core/agent/tools/builtin/realtime_tools.dart';
import 'package:nudgee/core/agent/tools/builtin/github_search_tool.dart';
import 'package:nudgee/core/agent/tools/builtin/github_repo_tool.dart';
import 'package:nudgee/core/agent/tools/builtin/git_tool.dart';
import 'package:nudgee/core/agent/tools/builtin/js_executor_tool.dart';
import 'package:nudgee/core/agent/tools/builtin/workspace_fs_tool.dart';
import 'package:nudgee/core/agent/tools/builtin/cloud_sandbox_tool.dart';
import 'package:nudgee/core/agent/tools/builtin/datetime_tool.dart';
import 'package:nudgee/core/agent/tools/builtin/tool_search_tool.dart';
import 'package:nudgee/core/agent/tools/builtin/ask_user_tool.dart';
import 'package:nudgee/core/agent/tools/builtin/todo_write_tool.dart';
import 'package:nudgee/core/config/app_config.dart';

/// Registers all built-in business tools into the given [registry].
///
/// This is the standard toolset for the Nudgee agent:
/// - schedule.add / schedule.query / schedule.remove
/// - post.create / post.query / post.like
/// - notification.schedule
/// - memory.save / memory.query
/// - user.profile
/// - web.search
/// - github.search
/// - github.repo
/// - workspace.fs / workspace.js.exec
/// - tool.search
/// - ask_user
/// - todo.write
///
/// Call this during app initialization after DI is set up:
/// ```dart
/// final registry = ToolRegistry();
/// registerBuiltinTools(registry);
/// ```
void registerBuiltinTools(ToolRegistry registry, {WorkspaceService? workspace}) {
  // Schedule
  registry.registerAll([
    ScheduleAddTool(),
    ScheduleQueryTool(),
    ScheduleRemoveTool(),
  ]);

  // Post
  registry.registerAll([
    PostCreateTool(),
    PostQueryTool(),
    PostLikeTool(),
  ]);

  // Notification
  registry.register(NotificationScheduleTool());

  // Memory
  registry.registerAll([
    MemorySaveTool(),
    MemoryQueryTool(),
    UserProfileTool(),
  ]);

  // Web search
  registry.register(WebSearchTool());

  // Real-time data (news, weather, stock)
  registry.register(WebNewsTool());
  registry.register(WebWeatherTool());
  registry.register(WebStockTool());

  // GitHub search (pass git token for authenticated API access)
  final githubToken = AppConfig.hasGit ? AppConfig.git!.token : null;
  registry.register(GitHubSearchTool(token: githubToken));

  // GitHub repo details
  registry.register(GitHubRepoTool(token: githubToken));

  // Git operations (read/write/branch/PR/issue via REST API)
  registry.register(GitTool());

  // Workspace (file system + JS execution + cloud sandbox)
  // WorkspaceFsTool lazily fetches WorkspaceService from DI if not provided.
  registry.register(WorkspaceFsTool(workspace));
  registry.register(JsExecutorTool());
  registry.register(CloudSandboxTool());

  // Meta tools
  registry.register(ToolSearchTool(registry));
  registry.register(AskUserTool());
  registry.register(TodoWriteTool());

  // DateTime
  registry.register(DateTimeTool());
}

/// Returns the list of all built-in tool names.
const List<String> builtinToolNames = [
  // Schedule
  'schedule.add',
  'schedule.query',
  'schedule.remove',
  // Post
  'post.create',
  'post.query',
  'post.like',
  // Notification
  'notification.schedule',
  // Memory
  'memory.save',
  'memory.query',
  'user.profile',
  // Web
  'web.search',
  'web.news',
  'web.weather',
  'web.stock',
  'github.search',
  'git',
  // Workspace
  'workspace.fs',
  'workspace.js.exec',
  'cloud.exec',
  // Meta
  'tool.search',
  'ask_user',
  'todo.write',
  // DateTime
  'datetime',
];
