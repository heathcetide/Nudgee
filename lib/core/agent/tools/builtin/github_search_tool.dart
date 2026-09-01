import 'dart:convert';

import 'package:nudgee/core/agent/tools/agent_tool.dart';
import 'package:nudgee/core/agent/tools/tool_result.dart';
import 'package:http/http.dart' as http;

/// Tool: github.search
///
/// Searches GitHub using the **free, no-API-key** GitHub Search API.
///
/// Supports 4 search types:
/// 1. **repositories** — search repos by name/topic/language (stars, forks, etc.)
/// 2. **code** — search code across public repos (file path, content)
/// 3. **issues** — search issues/PRs across repos
/// 4. **users** — search GitHub users/orgs
///
/// Rate limit: 10 requests/minute (unauthenticated), 30 req/min (authenticated).
/// No API key required — uses the public Search API.
///
/// Read-only tool — no mutation, no confirmation needed.
class GitHubSearchTool extends AgentTool {
  @override
  String get name => 'github.search';

  @override
  String get description =>
      'Search GitHub for repositories, code, issues, or users. '
      'Use this when the user asks about open-source projects, '
      'wants to find a library, search code on GitHub, '
      'or look up a GitHub user/organization. '
      'No API key required — uses GitHub\'s free Search API '
      '(rate limited to 10 requests/minute).';

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description': 'The search query (GitHub search syntax supported, '
                'e.g. "flutter state management stars:>1000")',
          },
          'type': {
            'type': 'string',
            'description': 'Type of search: "repositories" (default), '
                '"code", "issues", or "users"',
            'enum': ['repositories', 'code', 'issues', 'users'],
          },
          'language': {
            'type': 'string',
            'description': 'Filter by programming language (e.g. "dart", "python"). '
                'Only for repositories and code search.',
          },
          'limit': {
            'type': 'integer',
            'description': 'Maximum number of results (default 5, max 10)',
          },
        },
        'required': ['query'],
      };

  final http.Client _httpClient;

  /// Optional GitHub token for higher rate limits (30 req/min vs 10 req/min).
  /// If null, uses unauthenticated access (10 req/min).
  final String? _token;

  GitHubSearchTool({http.Client? httpClient, String? token})
      : _httpClient = httpClient ?? http.Client(),
        _token = token;

  @override
  bool get isMutation => false;

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final query = args['query'] as String?;
    if (query == null || query.isEmpty) {
      return const ToolResult.error('Missing required field: query');
    }

    final type = args['type'] as String? ?? 'repositories';
    final language = args['language'] as String?;
    final limit = (args['limit'] as int?)?.clamp(1, 10) ?? 5;

    // Build the full query string with language filter
    var fullQuery = query;
    if (language != null &&
        language.isNotEmpty &&
        (type == 'repositories' || type == 'code')) {
      fullQuery += ' language:$language';
    }

    final encodedQuery = Uri.encodeQueryComponent(fullQuery);
    final endpoint = switch (type) {
      'repositories' =>
        'https://api.github.com/search/repositories?q=$encodedQuery&per_page=$limit&sort=stars&order=desc',
      'code' =>
        'https://api.github.com/search/code?q=$encodedQuery&per_page=$limit',
      'issues' =>
        'https://api.github.com/search/issues?q=$encodedQuery&per_page=$limit&sort=created&order=desc',
      'users' =>
        'https://api.github.com/search/users?q=$encodedQuery&per_page=$limit',
      _ =>
        'https://api.github.com/search/repositories?q=$encodedQuery&per_page=$limit&sort=stars&order=desc',
    };

    try {
      final headers = <String, String>{
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'NudgeeAgent/1.0',
      };
      if (_token != null && _token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $_token';
      }

      final response = await _httpClient
          .get(Uri.parse(endpoint), headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 403) {
        // Rate limit hit
        final remaining = response.headers['x-ratelimit-remaining'];
        final reset = response.headers['x-ratelimit-reset'];
        if (remaining == '0') {
          final resetTime = reset != null
              ? DateTime.fromMillisecondsSinceEpoch(int.parse(reset) * 1000)
              : null;
          return ToolResult.error(
              'GitHub API rate limit exceeded (10 req/min for unauthenticated). '
              '${resetTime != null ? 'Resets at $resetTime.' : ''} '
              'Please wait a minute and try again.');
        }
      }

      if (response.statusCode != 200) {
        return ToolResult.error(
            'GitHub API error ${response.statusCode}: ${response.body}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final totalCount = data['total_count'] as int? ?? 0;
      final items = data['items'] as List? ?? [];

      if (items.isEmpty) {
        return ToolResult.success(
            'No GitHub $type results found for "$query".');
      }

      final formatted = switch (type) {
        'repositories' => _formatRepos(items, totalCount),
        'code' => _formatCode(items, totalCount),
        'issues' => _formatIssues(items, totalCount),
        'users' => _formatUsers(items, totalCount),
        _ => _formatRepos(items, totalCount),
      };

      return ToolResult.success(
          'GitHub $type search for "$query" '
          '($totalCount total, showing ${items.length}):\n\n$formatted');
    } catch (e) {
      return ToolResult.error('GitHub search failed: $e');
    }
  }

  String _formatRepos(List items, int total) {
    return items.asMap().entries.map((entry) {
      final i = entry.key + 1;
      final r = entry.value as Map<String, dynamic>;
      final name = r['full_name'] as String? ?? '';
      final desc = r['description'] as String? ?? '';
      final stars = r['stargazers_count'] as int? ?? 0;
      final forks = r['forks_count'] as int? ?? 0;
      final lang = r['language'] as String? ?? 'N/A';
      final url = r['html_url'] as String? ?? '';
      final updated = r['updated_at'] as String? ?? '';
      final topics = (r['topics'] as List?)?.cast<String>() ?? [];

      final parts = <String>[
        '$i. $name',
        '   Stars: $stars | Forks: $forks | Language: $lang',
      ];
      if (desc.isNotEmpty) parts.add('   $desc');
      if (topics.isNotEmpty) parts.add('   Topics: ${topics.take(5).join(', ')}');
      if (url.isNotEmpty) parts.add('   URL: $url');
      if (updated.isNotEmpty) {
        parts.add('   Updated: ${updated.substring(0, 10)}');
      }
      return parts.join('\n');
    }).join('\n\n');
  }

  String _formatCode(List items, int total) {
    return items.asMap().entries.map((entry) {
      final i = entry.key + 1;
      final r = entry.value as Map<String, dynamic>;
      final repo = r['repository']?['full_name'] as String? ?? '';
      final path = r['path'] as String? ?? '';
      final name = r['name'] as String? ?? '';
      final url = r['html_url'] as String? ?? '';
      final score = r['score'] as num? ?? 0;

      return '$i. $repo / $path\n'
          '   File: $name\n'
          '   URL: $url\n'
          '   Relevance: ${score.toStringAsFixed(2)}';
    }).join('\n\n');
  }

  String _formatIssues(List items, int total) {
    return items.asMap().entries.map((entry) {
      final i = entry.key + 1;
      final r = entry.value as Map<String, dynamic>;
      final title = r['title'] as String? ?? '';
      final state = r['state'] as String? ?? '';
      final url = r['html_url'] as String? ?? '';
      final repoUrl = r['repository_url'] as String? ?? '';
      final repoName = repoUrl.split('/').last;
      final labels = (r['labels'] as List?)
              ?.map((l) => (l as Map<String, dynamic>)['name'] as String?)
              .whereType<String>()
              .take(3)
              .join(', ') ??
          '';
      final createdAt = r['created_at'] as String? ?? '';

      final parts = <String>[
        '$i. [$state] $title',
        '   Repo: $repoName',
      ];
      if (labels.isNotEmpty) parts.add('   Labels: $labels');
      if (url.isNotEmpty) parts.add('   URL: $url');
      if (createdAt.isNotEmpty) parts.add('   Created: ${createdAt.substring(0, 10)}');
      return parts.join('\n');
    }).join('\n\n');
  }

  String _formatUsers(List items, int total) {
    return items.asMap().entries.map((entry) {
      final i = entry.key + 1;
      final r = entry.value as Map<String, dynamic>;
      final login = r['login'] as String? ?? '';
      final type = r['type'] as String? ?? '';
      final url = r['html_url'] as String? ?? '';
      final avatar = r['avatar_url'] as String? ?? '';

      return '$i. $login ($type)\n   URL: $url';
    }).join('\n\n');
  }

  void dispose() {
    _httpClient.close();
  }
}
