import 'dart:convert';

import 'package:nudgee/core/agent/tools/agent_tool.dart';
import 'package:nudgee/core/agent/tools/tool_result.dart';
import 'package:http/http.dart' as http;

/// Tool: github.repo
///
/// Fetches detailed information about a specific GitHub repository:
/// - Full metadata (stars, forks, watchers, license, topics, etc.)
/// - README content (rendered as markdown)
/// - Language breakdown
/// - Recent commits (latest 10)
/// - Top contributors (top 5)
/// - Directory structure (top-level files/folders via tree API)
///
/// Uses GitHub's free REST API — no API key required (rate limited to
/// 60 req/hr unauthenticated, 5000 req/hr with token).
class GitHubRepoTool extends AgentTool {
  @override
  String get name => 'github.repo';

  @override
  String get description =>
      'Get detailed information about a GitHub repository: full metadata, '
      'README content, language breakdown, recent commits, top contributors, '
      'and directory structure. Use this when you need to deeply analyze '
      'a specific repository. Pass "owner/repo" as the repo parameter. '
      'No API key required.';

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'repo': {
            'type': 'string',
            'description': 'Repository in "owner/repo" format (e.g. "facebook/react")',
          },
          'sections': {
            'type': 'string',
            'description': 'Comma-separated list of sections to fetch: '
                '"meta,readme,languages,commits,contributors,tree". '
                'Default: "meta,readme,languages,commits"',
          },
        },
        'required': ['repo'],
      };

  final http.Client _httpClient;
  final String? _token;

  GitHubRepoTool({http.Client? httpClient, String? token})
      : _httpClient = httpClient ?? http.Client(),
        _token = token;

  @override
  bool get isMutation => false;

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final repo = args['repo'] as String?;
    if (repo == null || repo.isEmpty || !repo.contains('/')) {
      return const ToolResult.error('Missing or invalid "repo" field. Expected "owner/repo" format.');
    }

    final sectionsStr = args['sections'] as String? ??
        'meta,readme,languages,commits';
    final sections = sectionsStr.split(',').map((s) => s.trim()).toSet();

    final parts = <String>[];
    final headers = <String, String>{
      'Accept': 'application/vnd.github+json',
      'User-Agent': 'NudgeeAgent/1.0',
    };
    if (_token != null && _token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }

    final baseUrl = 'https://api.github.com/repos/$repo';

    // 1. Metadata
    if (sections.contains('meta')) {
      try {
        final resp = await _httpClient
            .get(Uri.parse(baseUrl), headers: headers)
            .timeout(const Duration(seconds: 15));
        if (resp.statusCode == 200) {
          final d = jsonDecode(resp.body) as Map<String, dynamic>;
          parts.add('## Repository Metadata\n'
              '- Name: ${d['full_name'] ?? 'N/A'}\n'
              '- Description: ${d['description'] ?? 'N/A'}\n'
              '- Stars: ${d['stargazers_count'] ?? 0}\n'
              '- Forks: ${d['forks_count'] ?? 0}\n'
              '- Watchers: ${d['subscribers_count'] ?? 0}\n'
              '- Open Issues: ${d['open_issues_count'] ?? 0}\n'
              '- Language: ${d['language'] ?? 'N/A'}\n'
              '- License: ${d['license']?['spdx_id'] ?? 'N/A'}\n'
              '- Topics: ${(d['topics'] as List?)?.join(', ') ?? 'N/A'}\n'
              '- Created: ${d['created_at']?.substring(0, 10) ?? 'N/A'}\n'
              '- Updated: ${d['updated_at']?.substring(0, 10) ?? 'N/A'}\n'
              '- Pushed: ${d['pushed_at']?.substring(0, 10) ?? 'N/A'}\n'
              '- Default Branch: ${d['default_branch'] ?? 'main'}\n'
              '- Homepage: ${d['homepage'] ?? 'N/A'}\n'
              '- Size: ${d['size'] ?? 0} KB\n'
              '- URL: ${d['html_url'] ?? 'N/A'}');
        } else if (resp.statusCode == 404) {
          return const ToolResult.error('Repository not found. Check the owner/repo name.');
        }
      } catch (e) {
        parts.add('## Metadata: Failed to fetch ($e)');
      }
    }

    // 2. README
    if (sections.contains('readme')) {
      try {
        final resp = await _httpClient
            .get(Uri.parse('$baseUrl/readme'), headers: {
          ...headers,
          'Accept': 'application/vnd.github.raw+json',
        }).timeout(const Duration(seconds: 15));
        if (resp.statusCode == 200) {
          final readme = resp.body;
          // Truncate to ~4000 chars to keep context manageable
          final truncated = readme.length > 4000
              ? '${readme.substring(0, 4000)}\n\n... (truncated, ${readme.length} total chars)'
              : readme;
          parts.add('## README\n$truncated');
        }
      } catch (e) {
        parts.add('## README: Failed to fetch ($e)');
      }
    }

    // 3. Languages
    if (sections.contains('languages')) {
      try {
        final resp = await _httpClient
            .get(Uri.parse('$baseUrl/languages'), headers: headers)
            .timeout(const Duration(seconds: 10));
        if (resp.statusCode == 200) {
          final langs = jsonDecode(resp.body) as Map<String, dynamic>;
          final total = langs.values.fold(0, (a, b) => (a as int) + (b as int));
          final sorted = langs.entries.toList()
            ..sort((a, b) => (b.value as int).compareTo(a.value as int));
          final lines = sorted.take(10).map((e) {
            final pct = total > 0 ? ((e.value as int) / total * 100).toStringAsFixed(1) : '0';
            return '- ${e.key}: ${pct}%';
          }).join('\n');
          parts.add('## Language Breakdown\n$lines');
        }
      } catch (e) {
        parts.add('## Languages: Failed to fetch ($e)');
      }
    }

    // 4. Recent commits
    if (sections.contains('commits')) {
      try {
        final resp = await _httpClient
            .get(Uri.parse('$baseUrl/commits?per_page=10'), headers: headers)
            .timeout(const Duration(seconds: 10));
        if (resp.statusCode == 200) {
          final commits = jsonDecode(resp.body) as List;
          final lines = commits.take(10).map((c) {
            final commit = c['commit'] as Map<String, dynamic>?;
            final msg = commit?['message'] as String? ?? '';
            final date = commit?['author']?['date'] as String? ?? '';
            final author = commit?['author']?['name'] as String? ?? '';
            final firstLine = msg.split('\n').first;
            return '- ${date.substring(0, 10)} [$author]: $firstLine';
          }).join('\n');
          parts.add('## Recent Commits (latest 10)\n$lines');
        }
      } catch (e) {
        parts.add('## Commits: Failed to fetch ($e)');
      }
    }

    // 5. Contributors
    if (sections.contains('contributors')) {
      try {
        final resp = await _httpClient
            .get(Uri.parse('$baseUrl/contributors?per_page=5'), headers: headers)
            .timeout(const Duration(seconds: 10));
        if (resp.statusCode == 200) {
          final contributors = jsonDecode(resp.body) as List;
          final lines = contributors.take(5).map((c) {
            final login = c['login'] as String? ?? '';
            final contributions = c['contributions'] as int? ?? 0;
            return '- $login: $contributions contributions';
          }).join('\n');
          parts.add('## Top Contributors\n$lines');
        }
      } catch (e) {
        parts.add('## Contributors: Failed to fetch ($e)');
      }
    }

    // 6. Directory tree (top-level)
    if (sections.contains('tree')) {
      try {
        // First get default branch
        final metaResp = await _httpClient
            .get(Uri.parse(baseUrl), headers: headers)
            .timeout(const Duration(seconds: 10));
        if (metaResp.statusCode == 200) {
          final meta = jsonDecode(metaResp.body) as Map<String, dynamic>;
          final branch = meta['default_branch'] as String? ?? 'main';
          final treeResp = await _httpClient
              .get(Uri.parse('$baseUrl/git/trees/$branch'), headers: headers)
              .timeout(const Duration(seconds: 10));
          if (treeResp.statusCode == 200) {
            final treeData = jsonDecode(treeResp.body) as Map<String, dynamic>;
            final tree = treeData['tree'] as List? ?? [];
            final dirs = <String>[];
            final files = <String>[];
            for (final item in tree) {
              final path = item['path'] as String? ?? '';
              final type = item['type'] as String? ?? '';
              if (type == 'tree') {
                dirs.add('  $path/');
              } else {
                files.add('  $path');
              }
            }
            parts.add('## Directory Structure ($branch)\n'
                '${dirs.join('\n')}\n${files.join('\n')}');
          }
        }
      } catch (e) {
        parts.add('## Tree: Failed to fetch ($e)');
      }
    }

    if (parts.isEmpty) {
      return const ToolResult.error('No sections fetched. Check your "sections" parameter.');
    }

    return ToolResult.success(
        'GitHub repo details for "$repo":\n\n${parts.join('\n\n')}');
  }

  void dispose() {
    _httpClient.close();
  }
}
