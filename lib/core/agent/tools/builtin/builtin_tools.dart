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

// GitHub search tool
export 'package:nudgee/core/agent/tools/builtin/github_search_tool.dart';

// Workspace tools
export 'package:nudgee/core/agent/tools/builtin/js_executor_tool.dart';
export 'package:nudgee/core/agent/tools/builtin/workspace_fs_tool.dart';
export 'package:nudgee/core/agent/tools/builtin/cloud_sandbox_tool.dart';

// Meta tools
export 'package:nudgee/core/agent/tools/builtin/tool_search_tool.dart';
export 'package:nudgee/core/agent/tools/builtin/ask_user_tool.dart';
export 'package:nudgee/core/agent/tools/builtin/todo_write_tool.dart';

import 'package:nudgee/core/agent/tools/builtin/schedule_tools.dart';
import 'package:nudgee/core/agent/tools/builtin/post_tools.dart';
import 'package:nudgee/core/agent/tools/builtin/notification_tools.dart';
import 'package:nudgee/core/agent/tools/builtin/memory_tools.dart';
import 'package:nudgee/core/agent/tools/builtin/web_search_tool.dart';
import 'package:nudgee/core/agent/tools/builtin/github_search_tool.dart';
import 'package:nudgee/core/agent/tools/builtin/js_executor_tool.dart';
import 'package:nudgee/core/agent/tools/builtin/workspace_fs_tool.dart';
import 'package:nudgee/core/agent/tools/builtin/cloud_sandbox_tool.dart';
import 'package:nudgee/core/agent/tools/builtin/tool_search_tool.dart';
import 'package:nudgee/core/agent/tools/builtin/ask_user_tool.dart';
import 'package:nudgee/core/agent/tools/builtin/todo_write_tool.dart';

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

  // GitHub search
  registry.register(GitHubSearchTool());

  // Workspace (file system + JS execution + cloud sandbox)
  // WorkspaceFsTool lazily fetches WorkspaceService from DI if not provided.
  registry.register(WorkspaceFsTool(workspace));
  registry.register(JsExecutorTool());
  registry.register(CloudSandboxTool());

  // Meta tools
  registry.register(ToolSearchTool(registry));
  registry.register(AskUserTool());
  registry.register(TodoWriteTool());
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
  'github.search',
  // Workspace
  'workspace.fs',
  'workspace.js.exec',
  'cloud.exec',
  // Meta
  'tool.search',
  'ask_user',
  'todo.write',
];
