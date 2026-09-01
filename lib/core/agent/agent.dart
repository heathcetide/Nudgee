/// Nudgee Agent Framework — core barrel exports.
///
/// Import this file to access all agent core types:
/// ```dart
/// import 'package:nudgee/core/agent/agent.dart';
/// ```

// Core models
export 'package:nudgee/core/agent/agent_config.dart';
export 'package:nudgee/core/agent/agent_event.dart';
export 'package:nudgee/core/agent/agent_session.dart';
export 'package:nudgee/core/agent/agent_stats.dart';

// Harness & orchestrator
export 'package:nudgee/core/agent/agent_core.dart';
export 'package:nudgee/core/agent/agent_harness.dart';
export 'package:nudgee/core/agent/orchestrator.dart';

// Context & compaction
export 'package:nudgee/core/agent/context/context_governor.dart';
export 'package:nudgee/core/agent/compaction/microcompact.dart';

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

// Trace & observability
export 'package:nudgee/core/agent/trace/agent_trace.dart';
