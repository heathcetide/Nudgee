import 'package:nudgee/core/agent/tools/agent_tool.dart';
import 'package:nudgee/core/agent/tools/tool_result.dart';

/// Tool: ask_user
///
/// Asks the user a question when the agent needs clarification or input.
/// The agent should use this when it cannot proceed without more information
/// from the user.
///
/// This is a special tool — in interactive mode, it triggers a UI dialog.
/// In headless mode, it returns a "not available" result that the agent
/// can relay to the user in its response.
class AskUserTool extends AgentTool {
  @override
  String get name => 'ask_user';

  @override
  String get description =>
      'Ask the user a question when you need clarification or input. '
      'Provide a clear question and optionally a list of choices. '
      'Use this when you cannot proceed without more information.';

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'question': {
            'type': 'string',
            'description': 'The question to ask the user',
          },
          'choices': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Optional list of choices for the user to pick from',
          },
        },
        'required': ['question'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final question = args['question'] as String?;
    if (question == null || question.isEmpty) {
      return const ToolResult.error('Missing required field: question');
    }

    final choices = (args['choices'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        <String>[];

    // In Phase 1/2 headless mode, we cannot actually ask the user.
    // The agent should relay this question in its response text.
    // Phase 3+ will add a real interactive dialog.
    final choicesStr =
        choices.isNotEmpty ? ' Options: ${choices.join(", ")}' : '';
    return ToolResult.success(
        'QUESTION_FOR_USER: $question$choicesStr. '
        'Please answer this question in your reply to the user.');
  }
}
