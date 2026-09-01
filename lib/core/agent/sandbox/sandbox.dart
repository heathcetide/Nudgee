/// Sandbox execution system — safe Dart code execution for the AI agent.
///
/// The sandbox allows the agent to write and execute Dart code with
/// restricted permissions. Code is statically analyzed before execution
/// to detect dangerous patterns (filesystem access, network calls,
/// process execution, etc.).
///
/// Key components:
/// - [SandboxExecutor] — main entry point for executing code
/// - [SandboxStaticAnalyzer] — pre-execution safety analysis
/// - [SandboxExecTool] — AgentTool wrapper for the agent to call
/// - [SandboxBridge] — host-exposed functions for sandboxed code
/// - [SimpleSandboxInterpreter] — basic expression evaluator (no deps)
///
/// Usage:
/// ```dart
/// final executor = SandboxExecutor();
/// final result = await executor.execute('1 + 2 * 3');
/// print(result.output); // 7
///
/// // With bridge functions:
/// executor.registerBridgeFunction('greet', (args, kwargs) async {
///   return 'Hello, ${args[0]}!';
/// });
/// final result = await executor.execute('greet("World")');
/// ```
library;

export 'package:nudgee/core/agent/sandbox/sandbox_models.dart';
export 'package:nudgee/core/agent/sandbox/sandbox_analyzer.dart';
export 'package:nudgee/core/agent/sandbox/sandbox_executor.dart';
export 'package:nudgee/core/agent/sandbox/sandbox_exec_tool.dart';
