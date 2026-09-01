import 'package:nudgee/core/agent/tools/agent_tool.dart';
import 'package:nudgee/core/agent/tools/tool_registry.dart';
import 'package:nudgee/core/agent/tools/tool_result.dart';

/// Tool: tool.search
///
/// Searches for available tools by keyword. Used for lazy tool loading —
/// the agent starts with a minimal toolset and uses this to discover
/// additional tools when needed.
///
/// Read-only tool.
class ToolSearchTool extends AgentTool {
  final ToolRegistry _registry;

  ToolSearchTool(this._registry);

  @override
  String get name => 'tool.search';

  @override
  String get description =>
      'Search for available tools by keyword. Returns tool names and '
      'descriptions. Use this to discover tools you haven\'t been given '
      'directly — after finding a relevant tool, ask the user to enable it.';

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'keyword': {
            'type': 'string',
            'description': 'Search keyword (matches tool name or description)',
          },
        },
        'required': ['keyword'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final keyword = args['keyword'] as String?;
    if (keyword == null || keyword.isEmpty) {
      return const ToolResult.error('Missing required field: keyword');
    }

    final lowerKeyword = keyword.toLowerCase();
    final allDefs = _registry.definitionsFor();
    final matches = allDefs.where((def) {
      return def.name.toLowerCase().contains(lowerKeyword) ||
          def.description.toLowerCase().contains(lowerKeyword);
    }).toList();

    if (matches.isEmpty) {
      return ToolResult.success(
          'No tools found matching "$keyword". Available tools: '
          '${allDefs.map((d) => d.name).join(", ")}');
    }

    final lines = matches.map((def) {
      return '- ${def.name}: ${def.description}'
          '${def.requiresConfirmation ? " (requires confirmation)" : ""}'
          '${def.isMutation ? " (mutation)" : ""}';
    }).join('\n');

    return ToolResult.success(
        'Found ${matches.length} tool${matches.length > 1 ? "s" : ""} '
        'matching "$keyword":\n$lines');
  }
}
