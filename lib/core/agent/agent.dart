/// Nudgee Agent Framework — core barrel exports.
///
/// Import this file to access all agent core types:
/// ```dart
/// import 'package:nudgee/core/agent/agent.dart';
/// ```

// Core models
export 'package:nudgee/core/agent/agent_config.dart';
export 'package:nudgee/core/agent/agent_config_loader.dart';
export 'package:nudgee/core/agent/agent_event.dart';
export 'package:nudgee/core/agent/agent_session.dart';
export 'package:nudgee/core/agent/agent_stats.dart';

// Harness & orchestrator
export 'package:nudgee/core/agent/agent_core.dart';
export 'package:nudgee/core/agent/agent_harness.dart';
export 'package:nudgee/core/agent/orchestrator.dart';

// Controller (Phase 7)
export 'package:nudgee/core/agent/agent_controller.dart';

// Checkpoint manager (crash recovery)
export 'package:nudgee/core/agent/checkpoint_manager.dart';

// Cost tracker (budget enforcement)
export 'package:nudgee/core/agent/cost_tracker.dart';

// Sub-agent orchestration (multi-agent collaboration)
export 'package:nudgee/core/agent/sub_agent_orchestrator.dart';

// Context & compaction
export 'package:nudgee/core/agent/context/context_governor.dart';
export 'package:nudgee/core/agent/compaction/microcompact.dart';
export 'package:nudgee/core/agent/compaction/autocompact.dart';

// Sanitize
export 'package:nudgee/core/agent/sanitize/message_sanitizer.dart';

// Permission
export 'package:nudgee/core/agent/permission/permission.dart';

// Providers
export 'package:nudgee/core/agent/providers/llm_client.dart';
export 'package:nudgee/core/agent/providers/deepseek_client.dart';

// Tools
export 'package:nudgee/core/agent/tools/agent_tool.dart';
export 'package:nudgee/core/agent/tools/tool_registry.dart';
export 'package:nudgee/core/agent/tools/tool_result.dart';
export 'package:nudgee/core/agent/tools/builtin/builtin_tools.dart';

// Trace & observability
export 'package:nudgee/core/agent/trace/agent_trace.dart';

// Memory system (Phase 3)
export 'package:nudgee/core/agent/memory/memory.dart';

// Skill system (Phase 4)
export 'package:nudgee/core/agent/skills/skills.dart';

// MCP system (Phase 5)
export 'package:nudgee/core/agent/mcp/mcp.dart';

// Guard rails
export 'package:nudgee/core/agent/guard/guard.dart';

// Sandbox execution (Phase 6)
export 'package:nudgee/core/agent/sandbox/sandbox.dart';

// UI widgets (Phase 7)
export 'package:nudgee/core/agent/ui/agent_ui.dart';
