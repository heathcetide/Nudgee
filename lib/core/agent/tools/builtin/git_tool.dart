import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:nudgee/core/agent/tools/agent_tool.dart';
import 'package:nudgee/core/agent/tools/tool_result.dart';
import 'package:nudgee/core/config/app_config.dart';

/// Tool: git
///
/// A comprehensive Git operations tool that uses REST APIs (HTTP + token)
/// to interact with Git providers (GitHub, Gitea, GitLab).
///
/// Since mobile devices can't install git CLI, all operations go through
/// the provider's REST API with a Personal Access Token.
///
/// Supported actions:
/// - **read**: Read file content from a repo
/// - **list**: List directory contents / branches / commits
/// - **write**: Create or update a single file (auto-commits)
/// - **delete**: Delete a file (auto-commits)
/// - **commit_multi**: Atomic multi-file commit via Git Database API
/// - **create_branch**: Create a new branch from an existing ref
/// - **create_pr**: Create a pull request
/// - **merge_pr**: Merge a pull request
/// - **list_prs**: List open PRs
/// - **list_issues**: List issues
/// - **create_issue**: Create an issue
/// - **repo_info**: Get repository metadata
/// - **create_repo**: Create a new repository
///
/// Configuration: set `git.provider` and `git.token` in config.yaml.
class GitTool extends AgentTool {
  final http.Client _httpClient;
  final GitConfig? _config;

  GitTool({http.Client? httpClient, GitConfig? config})
      : _httpClient = httpClient ?? http.Client(),
        _config = config ?? AppConfig.git;

  @override
  String get name => 'git';

  @override
  String get description =>
      'Git operations via REST API (GitHub/Gitea/GitLab). '
      'Read/write files, create branches, open/merge PRs, manage issues, '
      'create repos. Requires git token in config.yaml. '
      'Use action field to specify the operation. '
      'For write operations, always provide a clear commit message.';

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'action': {
            'type': 'string',
            'description': 'The git operation to perform',
            'enum': [
              'read',
              'list',
              'write',
              'delete',
              'commit_multi',
              'create_branch',
              'create_pr',
              'merge_pr',
              'list_prs',
              'list_issues',
              'create_issue',
              'repo_info',
              'create_repo',
            ],
          },
          'owner': {
            'type': 'string',
            'description': 'Repository owner (username or org). '
                'Uses config defaultOwner if omitted.',
          },
          'repo': {
            'type': 'string',
            'description': 'Repository name',
          },
          'path': {
            'type': 'string',
            'description': 'File or directory path within the repo '
                '(for read/write/delete/list)',
          },
          'content': {
            'type': 'string',
            'description': 'File content (for write action, base64 not needed)',
          },
          'message': {
            'type': 'string',
            'description': 'Commit message (for write/delete/commit_multi)',
          },
          'branch': {
            'type': 'string',
            'description': 'Branch name (for read/write/list/PR). '
                'Default: repo default branch.',
          },
          'files': {
            'type': 'array',
            'description': 'Array of {path, content} for commit_multi action',
            'items': {
              'type': 'object',
              'properties': {
                'path': {'type': 'string'},
                'content': {'type': 'string'},
              },
            },
          },
          'fromBranch': {
            'type': 'string',
            'description': 'Source branch to create new branch from '
                '(for create_branch)',
          },
          'newBranch': {
            'type': 'string',
            'description': 'New branch name (for create_branch)',
          },
          'prTitle': {
            'type': 'string',
            'description': 'Pull request title (for create_pr)',
          },
          'prBody': {
            'type': 'string',
            'description': 'Pull request body/description (for create_pr)',
          },
          'head': {
            'type': 'string',
            'description': 'Head branch (source) for PR — "branch" or "owner:branch"',
          },
          'base': {
            'type': 'string',
            'description': 'Base branch (target) for PR — usually "main" or "master"',
          },
          'prNumber': {
            'type': 'integer',
            'description': 'PR number (for merge_pr)',
          },
          'issueTitle': {
            'type': 'string',
            'description': 'Issue title (for create_issue)',
          },
          'issueBody': {
            'type': 'string',
            'description': 'Issue body/description (for create_issue)',
          },
          'repoDescription': {
            'type': 'string',
            'description': 'Repository description (for create_repo)',
          },
          'private': {
            'type': 'boolean',
            'description': 'Whether new repo is private (for create_repo, default false)',
          },
          'listType': {
            'type': 'string',
            'description': 'For list action: "contents" (default), "branches", "commits"',
            'enum': ['contents', 'branches', 'commits'],
          },
        },
        'required': ['action'],
      };

  @override
  bool get isMutation => true;

  // ── API helpers ──────────────────────────────────────────────────────

  String get _apiBase => _config?.apiUrl ?? 'https://api.github.com';

  String get _token => _config?.token ?? '';

  String get _provider => _config?.provider ?? 'github';

  bool get _isGithub => _provider == 'github';

  bool get _isGitea => _provider == 'gitea';

  bool get _isGitlab => _provider == 'gitlab';

  Map<String, String> get _headers => {
        'Accept': _isGitlab ? 'application/json' : 'application/vnd.github+json',
        'Authorization': _isGitlab ? 'Bearer $_token' : 'token $_token',
        'User-Agent': 'NudgeeAgent/1.0',
        'Content-Type': 'application/json',
      };

  String _ownerOrDefault(String? owner) {
    final o = owner ?? _config?.defaultOwner;
    if (o == null || o.isEmpty) {
      throw ArgumentError('owner is required (or set git.defaultOwner in config)');
    }
    return o;
  }

  Future<http.Response> _get(String path) async {
    return _httpClient
        .get(Uri.parse('$_apiBase$path'), headers: _headers)
        .timeout(const Duration(seconds: 20));
  }

  Future<http.Response> _post(String path, Map<String, dynamic> body) async {
    return _httpClient
        .post(Uri.parse('$_apiBase$path'), headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 20));
  }

  Future<http.Response> _put(String path, Map<String, dynamic> body) async {
    return _httpClient
        .put(Uri.parse('$_apiBase$path'), headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 20));
  }

  Future<http.Response> _delete(String path, [Map<String, dynamic>? body]) async {
    final req = http.Request('DELETE', Uri.parse('$_apiBase$path'));
    req.headers.addAll(_headers);
    if (body != null) req.body = jsonEncode(body);
    return _httpClient.send(req).then((stream) => http.Response.fromStream(stream));
  }

  ToolResult _checkError(http.Response response, String operation) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return const ToolResult.success('');
    }
    String msg;
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      msg = data['message'] as String? ?? data['error'] as String? ?? response.body;
    } catch (_) {
      msg = response.body;
    }
    return ToolResult.error('Git $operation failed (${response.statusCode}): $msg');
  }

  // ── Execute ──────────────────────────────────────────────────────────

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    if (_token.isEmpty) {
      return const ToolResult.error(
          'Git token not configured. Set git.token in config.yaml.');
    }

    final action = args['action'] as String? ?? '';
    try {
      return switch (action) {
        'read' => _read(args),
        'list' => _list(args),
        'write' => _write(args),
        'delete' => _deleteFile(args),
        'commit_multi' => _commitMulti(args),
        'create_branch' => _createBranch(args),
        'create_pr' => _createPr(args),
        'merge_pr' => _mergePr(args),
        'list_prs' => _listPrs(args),
        'list_issues' => _listIssues(args),
        'create_issue' => _createIssue(args),
        'repo_info' => _repoInfo(args),
        'create_repo' => _createRepo(args),
        _ => ToolResult.error('Unknown git action: $action'),
      };
    } catch (e) {
      return ToolResult.error('Git $action error: $e');
    }
  }

  // ── Read ─────────────────────────────────────────────────────────────

  Future<ToolResult> _read(Map<String, dynamic> args) async {
    final owner = _ownerOrDefault(args['owner'] as String?);
    final repo = args['repo'] as String?;
    final path = args['path'] as String? ?? '';
    final branch = args['branch'] as String?;
    if (repo == null) return const ToolResult.error('Missing: repo');

    var url = '/repos/$owner/$repo/contents/$path';
    if (branch != null) url += '?ref=$branch';

    final res = await _get(url);
    if (res.statusCode != 200) return _checkError(res, 'read');

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final type = data['type'] as String? ?? 'file';

    if (type == 'dir') {
      return _formatDirContents(data);
    }

    // File — decode base64 content
    final encoding = data['encoding'] as String? ?? 'base64';
    final contentRaw = data['content'] as String? ?? '';
    String content;
    if (encoding == 'base64') {
      content = utf8.decode(base64.decode(contentRaw.replaceAll('\n', '')));
    } else {
      content = contentRaw;
    }

    final size = data['size'] as int? ?? content.length;
    // Chunk large files
    if (content.length > 8000) {
      final chunk = content.substring(0, 8000);
      final totalLines = content.split('\n').length;
      return ToolResult.success(
        'File: $owner/$repo/$path ($size bytes, $totalLines lines)\n'
        'Showing first 8000 chars:\n'
        '─── content ───\n$chunk\n'
        '─── truncated ───\n'
        'Use git list/read with specific path for more. '
        'File too large to return in full.',
      );
    }

    return ToolResult.success(
        'File: $owner/$repo/$path ($size bytes)\n─── content ───\n$content');
  }

  // ── List ─────────────────────────────────────────────────────────────

  Future<ToolResult> _list(Map<String, dynamic> args) async {
    final owner = _ownerOrDefault(args['owner'] as String?);
    final repo = args['repo'] as String?;
    final path = args['path'] as String? ?? '';
    final branch = args['branch'] as String?;
    final listType = args['listType'] as String? ?? 'contents';
    if (repo == null) return const ToolResult.error('Missing: repo');

    if (listType == 'branches') {
      final res = await _get('/repos/$owner/$repo/branches');
      if (res.statusCode != 200) return _checkError(res, 'list branches');
      final items = jsonDecode(res.body) as List;
      final formatted = items.map((b) {
        final m = b as Map<String, dynamic>;
        final name = m['name'] as String? ?? '';
        final protected = m['protected'] as bool? ?? false;
        return '  - $name${protected ? ' (protected)' : ''}';
      }).join('\n');
      return ToolResult.success(
          'Branches of $owner/$repo (${items.length}):\n$formatted');
    }

    if (listType == 'commits') {
      var url = '/repos/$owner/$repo/commits?per_page=10';
      if (branch != null) url += '&sha=$branch';
      final res = await _get(url);
      if (res.statusCode != 200) return _checkError(res, 'list commits');
      final items = jsonDecode(res.body) as List;
      final formatted = items.map((c) {
        final m = c as Map<String, dynamic>;
        final sha = (m['sha'] as String? ?? '').substring(0, 7);
        final commit = m['commit'] as Map<String, dynamic>? ?? {};
        final msg = (commit['message'] as String? ?? '').split('\n').first;
        final date = (commit['author'] as Map<String, dynamic>?)?['date'] as String? ?? '';
        final author = (commit['author'] as Map<String, dynamic>?)?['name'] as String? ?? '';
        return '  $sha $date [$author] $msg';
      }).join('\n');
      return ToolResult.success(
          'Recent commits of $owner/$repo:\n$formatted');
    }

    // contents (default)
    var url = '/repos/$owner/$repo/contents/$path';
    if (branch != null) url += '?ref=$branch';
    final res = await _get(url);
    if (res.statusCode != 200) return _checkError(res, 'list');
    final data = jsonDecode(res.body);
    if (data is List) {
      final formatted = data.map((e) {
        final m = e as Map<String, dynamic>;
        final type = m['type'] as String? ?? 'file';
        final name = m['name'] as String? ?? '';
        final size = m['size'] as int? ?? 0;
        final icon = type == 'dir' ? '[DIR] ' : '      ';
        return '  $icon$name${type == 'file' ? ' ($size B)' : ''}';
      }).join('\n');
      return ToolResult.success(
          'Contents of $owner/$repo/$path (${data.length} items):\n$formatted');
    }
    // Single file returned
    return _formatDirContents(data as Map<String, dynamic>);
  }

  ToolResult _formatDirContents(Map<String, dynamic> data) {
    final type = data['type'] as String? ?? 'file';
    if (type == 'dir' || data['entries'] != null) {
      final entries = data['entries'] as List? ?? [];
      final formatted = entries.map((e) {
        final m = e as Map<String, dynamic>;
        final t = m['type'] as String? ?? 'file';
        final name = m['name'] as String? ?? '';
        final icon = t == 'dir' ? '[DIR] ' : '      ';
        return '  $icon$name';
      }).join('\n');
      return ToolResult.success('Directory contents:\n$formatted');
    }
    return ToolResult.success('Item: ${data['name']} (${data['type']})');
  }

  // ── Write (single file) ──────────────────────────────────────────────

  Future<ToolResult> _write(Map<String, dynamic> args) async {
    final owner = _ownerOrDefault(args['owner'] as String?);
    final repo = args['repo'] as String?;
    final path = args['path'] as String?;
    final content = args['content'] as String? ?? '';
    final message = args['message'] as String? ?? 'Update $path';
    final branch = args['branch'] as String?;
    if (repo == null || path == null) {
      return const ToolResult.error('Missing: repo, path');
    }

    // Get current file sha (needed for update, not for create)
    var getUrl = '/repos/$owner/$repo/contents/$path';
    if (branch != null) getUrl += '?ref=$branch';
    String? sha;
    final getRes = await _get(getUrl);
    if (getRes.statusCode == 200) {
      final data = jsonDecode(getRes.body) as Map<String, dynamic>;
      sha = data['sha'] as String?;
    }

    final body = <String, dynamic>{
      'message': message,
      'content': base64.encode(utf8.encode(content)),
      if (sha != null) 'sha': sha,
      if (branch != null) 'branch': branch,
    };

    final res = await _put('/repos/$owner/$repo/contents/$path', body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return _checkError(res, 'write');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final commit = data['commit'] as Map<String, dynamic>?;
    final commitSha = (commit?['sha'] as String? ?? '').substring(0, 7);
    final lines = content.split('\n').length;
    return ToolResult.success(
        'File written: $owner/$repo/$path ($lines lines, ${content.length} bytes)\n'
        'Commit: $commitSha — "$message"');
  }

  // ── Delete file ──────────────────────────────────────────────────────

  Future<ToolResult> _deleteFile(Map<String, dynamic> args) async {
    final owner = _ownerOrDefault(args['owner'] as String?);
    final repo = args['repo'] as String?;
    final path = args['path'] as String?;
    final message = args['message'] as String? ?? 'Delete $path';
    final branch = args['branch'] as String?;
    if (repo == null || path == null) {
      return const ToolResult.error('Missing: repo, path');
    }

    // Get file sha
    var getUrl = '/repos/$owner/$repo/contents/$path';
    if (branch != null) getUrl += '?ref=$branch';
    final getRes = await _get(getUrl);
    if (getRes.statusCode != 200) return _checkError(getRes, 'delete (get sha)');
    final data = jsonDecode(getRes.body) as Map<String, dynamic>;
    final sha = data['sha'] as String?;

    final body = <String, dynamic>{
      'message': message,
      if (sha != null) 'sha': sha,
      if (branch != null) 'branch': branch,
    };

    final res = await _delete('/repos/$owner/$repo/contents/$path', body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return _checkError(res, 'delete');
    }
    return ToolResult.success('File deleted: $owner/$repo/$path\nCommit: "$message"');
  }

  // ── Multi-file commit (Git Database API) ─────────────────────────────

  Future<ToolResult> _commitMulti(Map<String, dynamic> args) async {
    final owner = _ownerOrDefault(args['owner'] as String?);
    final repo = args['repo'] as String?;
    final message = args['message'] as String? ?? 'Multi-file commit';
    final branch = args['branch'] as String? ?? 'main';
    final filesRaw = args['files'] as List?;
    if (repo == null) return const ToolResult.error('Missing: repo');
    if (filesRaw == null || filesRaw.isEmpty) {
      return const ToolResult.error('Missing: files (array of {path, content})');
    }

    // 1. Get the current commit SHA of the branch
    final branchRes = await _get('/repos/$owner/$repo/branches/$branch');
    if (branchRes.statusCode != 200) return _checkError(branchRes, 'get branch');
    final branchData = jsonDecode(branchRes.body) as Map<String, dynamic>;
    final baseSha = (branchData['commit'] as Map<String, dynamic>?)?['sha'] as String?;
    if (baseSha == null) return const ToolResult.error('Could not get branch HEAD');

    // 2. Get the base tree SHA
    final commitRes = await _get('/repos/$owner/$repo/commits/$baseSha');
    if (commitRes.statusCode != 200) return _checkError(commitRes, 'get commit');
    final commitData = jsonDecode(commitRes.body) as Map<String, dynamic>;
    final baseTreeSha = commitData['tree']?['sha'] as String?;
    if (baseTreeSha == null) return const ToolResult.error('Could not get tree SHA');

    // 3. Create blobs for each file
    final treeItems = <Map<String, dynamic>>[];
    for (final f in filesRaw) {
      final fm = f as Map<String, dynamic>;
      final path = fm['path'] as String? ?? '';
      final content = fm['content'] as String? ?? '';
      final blobRes = await _post('/repos/$owner/$repo/git/blobs', {
        'content': content,
        'encoding': 'utf-8',
      });
      if (blobRes.statusCode != 201) return _checkError(blobRes, 'create blob for $path');
      final blobData = jsonDecode(blobRes.body) as Map<String, dynamic>;
      final blobSha = blobData['sha'] as String?;
      treeItems.add({
        'path': path,
        'mode': '100644',
        'type': 'blob',
        'sha': blobSha,
      });
    }

    // 4. Create a new tree
    final treeRes = await _post('/repos/$owner/$repo/git/trees', {
      'base_tree': baseTreeSha,
      'tree': treeItems,
    });
    if (treeRes.statusCode != 201) return _checkError(treeRes, 'create tree');
    final treeData = jsonDecode(treeRes.body) as Map<String, dynamic>;
    final newTreeSha = treeData['sha'] as String?;

    // 5. Create the commit
    final newCommitRes = await _post('/repos/$owner/$repo/git/commits', {
      'message': message,
      'tree': newTreeSha,
      'parents': [baseSha],
    });
    if (newCommitRes.statusCode != 201) {
      return _checkError(newCommitRes, 'create commit');
    }
    final newCommitData = jsonDecode(newCommitRes.body) as Map<String, dynamic>;
    final newCommitSha = newCommitData['sha'] as String?;

    // 6. Update the branch ref
    final refRes = await _patch('/repos/$owner/$repo/git/refs/heads/$branch', {
      'sha': newCommitSha,
    });
    if (refRes.statusCode < 200 || refRes.statusCode >= 300) {
      return _checkError(refRes, 'update ref');
    }

    return ToolResult.success(
        'Multi-file commit: $owner/$repo@$branch\n'
        'Files: ${treeItems.length}\n'
        'Commit: ${newCommitSha!.substring(0, 7)} — "$message"');
  }

  Future<http.Response> _patch(String path, Map<String, dynamic> body) async {
    final req = http.Request('PATCH', Uri.parse('$_apiBase$path'));
    req.headers.addAll(_headers);
    req.body = jsonEncode(body);
    return _httpClient.send(req).then((s) => http.Response.fromStream(s));
  }

  // ── Create branch ────────────────────────────────────────────────────

  Future<ToolResult> _createBranch(Map<String, dynamic> args) async {
    final owner = _ownerOrDefault(args['owner'] as String?);
    final repo = args['repo'] as String?;
    final newBranch = args['newBranch'] as String?;
    final fromBranch = args['fromBranch'] as String? ?? 'main';
    if (repo == null || newBranch == null) {
      return const ToolResult.error('Missing: repo, newBranch');
    }

    // Get SHA of source branch
    final branchRes = await _get('/repos/$owner/$repo/branches/$fromBranch');
    if (branchRes.statusCode != 200) return _checkError(branchRes, 'get source branch');
    final branchData = jsonDecode(branchRes.body) as Map<String, dynamic>;
    final sha = (branchData['commit'] as Map<String, dynamic>?)?['sha'] as String?;
    if (sha == null) return const ToolResult.error('Could not get source branch SHA');

    // Create new ref
    final res = await _post('/repos/$owner/$repo/git/refs', {
      'ref': 'refs/heads/$newBranch',
      'sha': sha,
    });
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return _checkError(res, 'create branch');
    }
    return ToolResult.success(
        'Branch created: $owner/$repo $fromBranch → $newBranch (at ${sha.substring(0, 7)})');
  }

  // ── Create PR ────────────────────────────────────────────────────────

  Future<ToolResult> _createPr(Map<String, dynamic> args) async {
    final owner = _ownerOrDefault(args['owner'] as String?);
    final repo = args['repo'] as String?;
    final title = args['prTitle'] as String?;
    final body = args['prBody'] as String? ?? '';
    final head = args['head'] as String?;
    final base = args['base'] as String? ?? 'main';
    if (repo == null || title == null || head == null) {
      return const ToolResult.error('Missing: repo, prTitle, head');
    }

    final res = await _post('/repos/$owner/$repo/pulls', {
      'title': title,
      'body': body,
      'head': head,
      'base': base,
    });
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return _checkError(res, 'create PR');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final number = data['number'];
    final url = data['html_url'] as String? ?? '';
    return ToolResult.success(
        'Pull request created: #$number "$title"\n'
        '$head → $base\n'
        'URL: $url');
  }

  // ── Merge PR ─────────────────────────────────────────────────────────

  Future<ToolResult> _mergePr(Map<String, dynamic> args) async {
    final owner = _ownerOrDefault(args['owner'] as String?);
    final repo = args['repo'] as String?;
    final prNumber = args['prNumber'] as int?;
    if (repo == null || prNumber == null) {
      return const ToolResult.error('Missing: repo, prNumber');
    }

    final res = await _put('/repos/$owner/$repo/pulls/$prNumber/merge', {
      'merge_method': 'merge',
    });
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return _checkError(res, 'merge PR');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final sha = (data['sha'] as String? ?? '').substring(0, 7);
    final merged = data['merged'] as bool? ?? true;
    return ToolResult.success(
        'PR #$prNumber merged: $merged (commit $sha) in $owner/$repo');
  }

  // ── List PRs ─────────────────────────────────────────────────────────

  Future<ToolResult> _listPrs(Map<String, dynamic> args) async {
    final owner = _ownerOrDefault(args['owner'] as String?);
    final repo = args['repo'] as String?;
    if (repo == null) return const ToolResult.error('Missing: repo');

    final res = await _get('/repos/$owner/$repo/pulls?state=open&per_page=10');
    if (res.statusCode != 200) return _checkError(res, 'list PRs');
    final items = jsonDecode(res.body) as List;
    if (items.isEmpty) return ToolResult.success('No open PRs in $owner/$repo.');
    final formatted = items.map((p) {
      final m = p as Map<String, dynamic>;
      final number = m['number'];
      final title = m['title'] as String? ?? '';
      final head = (m['head'] as Map<String, dynamic>?)?['ref'] as String? ?? '';
      final base = (m['base'] as Map<String, dynamic>?)?['ref'] as String? ?? '';
      final user = (m['user'] as Map<String, dynamic>?)?['login'] as String? ?? '';
      return '  #$number [$head→$base] by @$user: $title';
    }).join('\n');
    return ToolResult.success(
        'Open PRs in $owner/$repo (${items.length}):\n$formatted');
  }

  // ── List issues ──────────────────────────────────────────────────────

  Future<ToolResult> _listIssues(Map<String, dynamic> args) async {
    final owner = _ownerOrDefault(args['owner'] as String?);
    final repo = args['repo'] as String?;
    if (repo == null) return const ToolResult.error('Missing: repo');

    final res = await _get('/repos/$owner/$repo/issues?state=open&per_page=10');
    if (res.statusCode != 200) return _checkError(res, 'list issues');
    final items = jsonDecode(res.body) as List;
    // Filter out PRs (they appear in issues endpoint)
    final issues = items.where((i) {
      final m = i as Map<String, dynamic>;
      return m['pull_request'] == null;
    }).toList();
    if (issues.isEmpty) return ToolResult.success('No open issues in $owner/$repo.');
    final formatted = issues.map((i) {
      final m = i as Map<String, dynamic>;
      final number = m['number'];
      final title = m['title'] as String? ?? '';
      final user = (m['user'] as Map<String, dynamic>?)?['login'] as String? ?? '';
      final labels = (m['labels'] as List?)
              ?.map((l) => (l as Map<String, dynamic>)['name'])
              .take(3)
              .join(', ') ??
          '';
      return '  #$number by @$user: $title${labels.isNotEmpty ? ' [$labels]' : ''}';
    }).join('\n');
    return ToolResult.success(
        'Open issues in $owner/$repo (${issues.length}):\n$formatted');
  }

  // ── Create issue ─────────────────────────────────────────────────────

  Future<ToolResult> _createIssue(Map<String, dynamic> args) async {
    final owner = _ownerOrDefault(args['owner'] as String?);
    final repo = args['repo'] as String?;
    final title = args['issueTitle'] as String?;
    final body = args['issueBody'] as String? ?? '';
    if (repo == null || title == null) {
      return const ToolResult.error('Missing: repo, issueTitle');
    }

    final res = await _post('/repos/$owner/$repo/issues', {
      'title': title,
      'body': body,
    });
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return _checkError(res, 'create issue');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final number = data['number'];
    final url = data['html_url'] as String? ?? '';
    return ToolResult.success('Issue created: #$number "$title" in $owner/$repo\nURL: $url');
  }

  // ── Repo info ────────────────────────────────────────────────────────

  Future<ToolResult> _repoInfo(Map<String, dynamic> args) async {
    final owner = _ownerOrDefault(args['owner'] as String?);
    final repo = args['repo'] as String?;
    if (repo == null) return const ToolResult.error('Missing: repo');

    final res = await _get('/repos/$owner/$repo');
    if (res.statusCode != 200) return _checkError(res, 'repo info');
    final m = jsonDecode(res.body) as Map<String, dynamic>;
    final desc = m['description'] as String? ?? '';
    final stars = m['stargazers_count'] as int? ?? 0;
    final forks = m['forks_count'] as int? ?? 0;
    final lang = m['language'] as String? ?? 'N/A';
    final defaultBranch = m['default_branch'] as String? ?? 'main';
    final private = m['private'] as bool? ?? false;
    final url = m['html_url'] as String? ?? '';
    final cloneUrl = m['clone_url'] as String? ?? '';
    final createdAt = m['created_at'] as String? ?? '';
    final updatedAt = m['updated_at'] as String? ?? '';

    return ToolResult.success(
        'Repository: $owner/$repo\n'
        'URL: $url\n'
        'Clone: $cloneUrl\n'
        'Description: $desc\n'
        'Language: $lang | Stars: $stars | Forks: $forks\n'
        'Default branch: $defaultBranch | Private: $private\n'
        'Created: ${createdAt.substring(0, 10)} | Updated: ${updatedAt.substring(0, 10)}');
  }

  // ── Create repo ──────────────────────────────────────────────────────

  Future<ToolResult> _createRepo(Map<String, dynamic> args) async {
    final repo = args['repo'] as String?;
    final desc = args['repoDescription'] as String? ?? '';
    final private = args['private'] as bool? ?? false;
    if (repo == null) return const ToolResult.error('Missing: repo name');

    // For GitHub: POST /user/repos (creates under authenticated user)
    // For Gitea: POST /user/repos
    // For GitLab: POST /projects (name field)
    final path = _isGitlab ? '/projects' : '/user/repos';
    final body = _isGitlab
        ? {'name': repo, 'description': desc, 'visibility': private ? 'private' : 'public'}
        : {'name': repo, 'description': desc, 'private': private};

    final res = await _post(path, body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return _checkError(res, 'create repo');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final url = data['html_url'] as String? ?? '';
    final cloneUrl = data['clone_url'] as String? ?? '';
    return ToolResult.success(
        'Repository created: $repo (${private ? 'private' : 'public'})\n'
        'URL: $url\nClone: $cloneUrl');
  }

  // ── Dispose ──────────────────────────────────────────────────────────

  void dispose() {
    _httpClient.close();
  }
}
