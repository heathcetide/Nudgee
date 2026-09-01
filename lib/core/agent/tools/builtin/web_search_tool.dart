import 'dart:convert';

import 'package:nudgee/core/agent/tools/agent_tool.dart';
import 'package:nudgee/core/agent/tools/tool_result.dart';
import 'package:http/http.dart' as http;

/// Tool: web.search
///
/// Searches the web for information using a search API.
/// Returns summarized results that the agent can use to answer questions
/// about current events, facts, or anything not in its training data.
///
/// Read-only tool — no mutation, no confirmation needed.
///
/// Uses DuckDuckGo's Instant Answer API (no API key required).
/// For more comprehensive results, a paid search API can be plugged in.
class WebSearchTool extends AgentTool {
  @override
  String get name => 'web.search';

  @override
  String get description =>
      'Search the web for current information. Use this when the user asks '
      'about recent events, facts you\'re unsure about, or anything that '
      'requires up-to-date information. Returns search results with titles '
      'and snippets.';

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description': 'The search query',
          },
          'limit': {
            'type': 'integer',
            'description': 'Maximum number of results (default 5, max 10)',
          },
        },
        'required': ['query'],
      };

  final http.Client _httpClient;

  WebSearchTool({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final query = args['query'] as String?;
    if (query == null || query.isEmpty) {
      return const ToolResult.error('Missing required field: query');
    }

    final limit = (args['limit'] as int?)?.clamp(1, 10) ?? 5;

    try {
      // Use DuckDuckGo Instant Answer API (free, no key required)
      final uri = Uri.parse(
        'https://api.duckduckgo.com/?q=${Uri.encodeComponent(query)}'
        '&format=json&no_html=1&skip_disambig=1',
      );

      final response = await _httpClient.get(uri, headers: {
        'User-Agent': 'NudgeeAgent/1.0',
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return ToolResult.error(
            'Search failed: HTTP ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = <String>[];

      // Abstract (main answer)
      final abstract = data['Abstract'] as String?;
      if (abstract != null && abstract.isNotEmpty) {
        final source = data['AbstractSource'] as String? ?? '';
        results.add('Answer: $abstract'
            '${source.isNotEmpty ? " (source: $source)" : ""}');
      }

      // Related topics
      final relatedTopics = data['RelatedTopics'] as List?;
      if (relatedTopics != null) {
        for (final topic in relatedTopics.take(limit)) {
          if (topic is Map<String, dynamic>) {
            final text = topic['Text'] as String?;
            if (text != null && text.isNotEmpty) {
              results.add('- $text');
            }
          }
        }
      }

      // Definition
      final definition = data['Definition'] as String?;
      if (definition != null && definition.isNotEmpty) {
        results.add('Definition: $definition');
      }

      if (results.isEmpty) {
        return ToolResult.success(
            'No results found for "$query". '
            'Try rephrasing the search query.');
      }

      return ToolResult.success(
          'Search results for "$query":\n${results.take(limit).join('\n')}');
    } catch (e) {
      return ToolResult.error('Web search failed: $e');
    }
  }

  void dispose() {
    _httpClient.close();
  }
}
