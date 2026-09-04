import 'dart:async';
import 'dart:convert';

import 'package:nudgee/core/agent/skills/agent_skill.dart';
import 'package:nudgee/core/agent/skills/skill_models.dart';
import 'package:http/http.dart' as http;

/// Skill: oss_trend_analysis
///
/// Two modes:
/// 1. **Trend mode** (default): discovers today's fastest-growing GitHub repos
///    and analyzes them in depth.
/// 2. **Specific repo mode**: when user asks about a specific repo (e.g.
///    "分析一下 facebook/react 的底层实现"), deeply analyzes that repo.
class OssTrendAnalysisSkill extends AgentSkill {
  @override
  String get id => 'oss_trend_analysis';

  @override
  String get name => 'OSS Trend Analysis';

  @override
  String get summary =>
      'Deep analysis of trending open-source projects or a specific GitHub repo. '
      'Discovers today\'s fastest-growing repos, fetches full repo details '
      '(README, code, commits, contributors), scans code via grep.app and '
      'GitHub code search, and generates a structured report with unique '
      'innovation analysis and code-level implementation details.';

  @override
  String get fullDescription =>
      'This skill performs comprehensive open-source project analysis:\n\n'
      '**Trend mode** (when user asks about "trending" or "hot" projects):\n'
      '1. Searches GitHub for repos created in last 7-30 days with rising stars\n'
      '2. Searches for repos pushed today with high star counts\n'
      '3. Uses web.search to find GitHub trending pages\n'
      '4. Checks memory to avoid re-analyzing previously covered projects\n'
      '5. Deeply analyzes each new project\n\n'
      '**Specific repo mode** (when user mentions a repo name):\n'
      '1. Fetches full repo details via github.repo tool\n'
      '2. Scans code structure and key files\n'
      '3. Analyzes architecture, data flow, and implementation patterns\n'
      '4. Searches for source code analysis articles\n\n'
      'Output: structured markdown report with code-level details.';

  @override
  List<String> get keywords => [
        'oss', 'open source', 'github', 'trending', 'trend',
        'star', 'repo', 'repository', 'project analysis',
        'code analysis', 'open source analysis', '开源', '项目分析',
        '趋势', 'github trending', '底层实现', '源码分析', '代码分析',
      ];

  @override
  List<String> get allowedTools => [
        'github.search', 'github.repo', 'web.search',
        'workspace.js.exec', 'workspace.fs',
        'memory.save', 'memory.query',
        'datetime', 'todo.write',
      ];

  @override
  String get terminationCriteria =>
      'The skill completes when a full analysis report has been generated, '
      'saved to workspace, and Top 3 recommendations presented (trend mode) '
      'or a comprehensive repo analysis is delivered (specific repo mode).';

  @override
  Stream<SkillEvent> execute({
    required String userInput,
    required SkillContext context,
    Map<String, dynamic> params = const {},
  }) async* {
    final today = _formatDate(DateTime.now());
    final weekAgo = _formatDate(DateTime.now().subtract(const Duration(days: 7)));
    final monthAgo = _formatDate(DateTime.now().subtract(const Duration(days: 30)));

    final specificRepo = _extractRepoName(userInput);

    if (specificRepo != null) {
      yield* _analyzeSpecificRepo(specificRepo, userInput, context, today);
    } else {
      yield* _analyzeTrends(context, today, weekAgo, monthAgo);
    }
  }

  // ─── Specific repo mode ──────────────────────────────────────────────

  Stream<SkillEvent> _analyzeSpecificRepo(
    String repo,
    String userInput,
    SkillContext context,
    String today,
  ) async* {
    final stepsCompleted = <String>[];
    final toolsUsed = <String>[];

    yield SkillEvent.step(
        'Fetching detailed info for $repo...',
        stepNumber: 1,
        totalSteps: 5);
    stepsCompleted.add('fetch_repo');

    // Check if this repo was already analyzed
    final prevResult = await context.runTool('memory.query', {
      'key': 'oss_analyzed_$repo',
    });
    toolsUsed.add('memory.query');
    if (prevResult.success &&
        !prevResult.output!.contains('No memory found')) {
      yield SkillEvent.output(
          '⚠️ $repo was already analyzed before:\n${prevResult.output}\n\nProceeding with a fresh analysis...');
    }

    final repoResult = await context.runTool('github.repo', {
      'repo': repo,
      'sections': 'meta,readme,languages,commits,contributors,tree',
    });
    toolsUsed.add('github.repo');
    yield SkillEvent.toolResult(
        'github.repo', repoResult.success, repoResult.output ?? '');

    yield SkillEvent.step(
        'Scanning code structure and key files...',
        stepNumber: 2,
        totalSteps: 5);
    stepsCompleted.add('scan_code');

    final codeAnalyses = <String>[];

    final ghCodeResult = await context.runTool('github.search', {
      'query': 'repo:$repo extension:dart OR extension:ts OR extension:go OR extension:py OR extension:rs OR extension:java OR extension:cpp',
      'type': 'code',
      'limit': 10,
    });
    toolsUsed.add('github.search');
    if (ghCodeResult.success) {
      codeAnalyses.add('### GitHub code search results\n\n${ghCodeResult.output}');
      yield SkillEvent.output(
          'GitHub code search: ${ghCodeResult.output.length} chars');
    }

    final grepResult = await _searchCodeGrepApp(repo, maxFiles: 8, maxChars: 800);
    if (grepResult != null) {
      codeAnalyses.add('### grep.app code scan\n\n$grepResult');
      yield SkillEvent.output('grep.app scan: ${grepResult.length} chars');
    }

    yield SkillEvent.step(
        'Searching for source code analysis articles...',
        stepNumber: 3,
        totalSteps: 5);
    stepsCompleted.add('search_articles');

    final articleResult = await context.runTool('web.search', {
      'query': '$repo source code analysis architecture 源码解析',
      'limit': 5,
    });
    toolsUsed.add('web.search');
    yield SkillEvent.toolResult(
        'web.search', articleResult.success, articleResult.output ?? '');

    yield SkillEvent.step(
        'Performing deep code-level analysis...',
        stepNumber: 4,
        totalSteps: 5);
    stepsCompleted.add('deep_analysis');

    final memoryCtx = context.getMemoryContext();
    final analysisPrompt = '你是一位资深的开源项目分析师和代码架构专家。'
        '请对以下 GitHub 项目进行深度代码级分析。\n\n'
        '## 仓库详情\n\n${repoResult.output}\n\n'
        '## 代码扫描结果\n\n${codeAnalyses.join('\n\n---\n\n')}\n\n'
        '## 相关文章\n\n${articleResult.output}\n\n'
        '${memoryCtx.isNotEmpty ? "## 用户上下文\n$memoryCtx\n\n" : ""}'
        '## 分析要求\n\n'
        '请用中文输出，使用 markdown 格式，包含以下部分：\n\n'
        '### 1. 项目概览\n'
        '- 名称、描述、Star/Fork/Watcher 数、主要语言、License\n'
        '- 创建时间、最近更新、最近推送\n\n'
        '### 2. 技术栈与架构\n'
        '- 核心技术、依赖关系、架构风格（单体/微服务/插件式等）\n'
        '- 语言分布百分比\n\n'
        '### 3. 独到之处（重点，至少 200 字）\n'
        '- 这个项目有什么独特的设计理念或创新架构？\n'
        '- 和同类项目相比最大的差异化在哪里？\n'
        '- 举出具体的代码或设计例子\n\n'
        '### 4. 代码实现深度分析（重点，至少 300 字）\n'
        '- 根据目录结构和代码扫描，分析核心模块划分\n'
        '- 指出关键文件路径和核心函数/方法名\n'
        '- 描述核心数据流：从输入到输出的完整路径\n'
        '- 分析关键设计模式和算法选择\n'
        '- 如果有 README 中的架构说明，结合代码验证\n'
        '- 引用实际代码片段（来自 grep.app 或 GitHub code search 结果）\n\n'
        '### 5. 社区与维护\n'
        '- 贡献者数量和活跃度（从 commits 分析）\n'
        '- Issue 处理速度、PR 合并频率\n'
        '- 版本发布频率\n\n'
        '### 6. 风险评估\n'
        '- License 兼容性\n'
        '- 安全漏洞历史\n'
        '- Bus factor（关键维护者数量）\n\n'
        '### 7. 综合评价\n'
        '- 置信度标注（高/中/低）\n'
        '- 适用场景\n'
        '- 替代方案对比\n\n'
        '## 注意\n'
        '- 代码分析部分必须具体到文件路径和函数名\n'
        '- 如果代码扫描结果不足，基于目录结构和 README 推断架构\n'
        '- 不要空泛描述，要有技术深度';

    final analysis = await context.llmChat(analysisPrompt);
    yield SkillEvent.output(analysis);

    yield SkillEvent.step(
        'Saving analysis to workspace...',
        stepNumber: 5,
        totalSteps: 5);
    stepsCompleted.add('save');

    await context.runTool('memory.save', {
      'key': 'oss_analyzed_$repo',
      'value': 'Analyzed on $today: $repo — deep code analysis',
    });
    toolsUsed.add('memory.save');

    final reportPath = 'reports/oss-analysis/${repo.replaceAll('/', '_')}_$today.md';
    final fsResult = await context.runTool('workspace.fs', {
      'action': 'write',
      'path': reportPath,
      'content': '# $repo 深度分析报告 — $today\n\n$analysis',
    });
    toolsUsed.add('workspace.fs');
    yield SkillEvent.toolResult(
        'workspace.fs', fsResult.success, fsResult.output ?? '');

    yield SkillEvent.done(SkillResult.ok(
      '$repo 深度分析完成。报告已保存到 $reportPath。',
      data: {
        'report': analysis,
        'reportPath': reportPath,
        'repo': repo,
        'date': today,
      },
      stepsCompleted: stepsCompleted.length,
      toolsUsed: toolsUsed,
    ));
  }

  // ─── Trend mode ──────────────────────────────────────────────────────

  Stream<SkillEvent> _analyzeTrends(
    SkillContext context,
    String today,
    String weekAgo,
    String monthAgo,
  ) async* {
    final stepsCompleted = <String>[];
    final toolsUsed = <String>[];

    yield SkillEvent.step(
        'Searching GitHub for today\'s trending repositories...',
        stepNumber: 1,
        totalSteps: 7);
    stepsCompleted.add('search_trending');

    final breakoutResult = await context.runTool('github.search', {
      'query': 'stars:>500 created:>$monthAgo sort:stars',
      'type': 'repositories',
      'limit': 10,
    });
    toolsUsed.add('github.search');
    yield SkillEvent.toolResult(
        'github.search (breakout)', breakoutResult.success,
        breakoutResult.output ?? '');

    final activeTodayResult = await context.runTool('github.search', {
      'query': 'stars:>1000 pushed:>$today sort:updated',
      'type': 'repositories',
      'limit': 10,
    });
    toolsUsed.add('github.search');
    yield SkillEvent.toolResult(
        'github.search (active today)', activeTodayResult.success,
        activeTodayResult.output ?? '');

    final newThisWeekResult = await context.runTool('github.search', {
      'query': 'stars:>100 created:>$weekAgo sort:stars',
      'type': 'repositories',
      'limit': 10,
    });
    toolsUsed.add('github.search');
    yield SkillEvent.toolResult(
        'github.search (new this week)', newThisWeekResult.success,
        newThisWeekResult.output ?? '');

    final trendingWebResult = await context.runTool('web.search', {
      'query': 'github trending repositories today $today',
      'limit': 5,
    });
    toolsUsed.add('web.search');
    yield SkillEvent.toolResult(
        'web.search (trending)', trendingWebResult.success,
        trendingWebResult.output ?? '');

    final allResults = '${breakoutResult.output}\n\n'
        '${activeTodayResult.output}\n\n'
        '${newThisWeekResult.output}\n\n'
        '${trendingWebResult.output}';

    yield SkillEvent.step(
        'Checking previously analyzed projects...',
        stepNumber: 2,
        totalSteps: 7);
    stepsCompleted.add('check_memory');

    final memoryResult = await context.runTool('memory.query', {});
    toolsUsed.add('memory.query');
    yield SkillEvent.output(
        'Previously analyzed:\n${memoryResult.output}');

    yield SkillEvent.step(
        'Selecting new trending projects for analysis...',
        stepNumber: 3,
        totalSteps: 7);
    stepsCompleted.add('select_projects');

    final selectPrompt = 'Based on these GitHub search results:\n'
        '$allResults\n\n'
        'And these previously analyzed projects (DO NOT select these):\n'
        '${memoryResult.output}\n\n'
        'Select 3-5 NEW projects that have NOT been analyzed before. '
        'Prioritize by:\n'
        '1. Fastest star growth (recently created but already high stars)\n'
        '2. Pushed today (actively maintained)\n'
        '3. Interesting technology or innovation\n'
        'Output ONLY the list of "owner/repo" names, one per line. '
        'Do not include any other text.';

    final projectList = await context.llmChat(selectPrompt);
    final repos = _parseRepoList(projectList);
    yield SkillEvent.output(
        'Selected ${repos.length} projects: ${repos.take(5).join(', ')}');

    yield SkillEvent.step(
        'Fetching detailed repo info and scanning code...',
        stepNumber: 4,
        totalSteps: 7);
    stepsCompleted.add('fetch_details');

    final repoDetails = <String>[];
    final codeAnalyses = <String>[];

    for (final repo in repos.take(5)) {
      final detailResult = await context.runTool('github.repo', {
        'repo': repo,
        'sections': 'meta,readme,languages,commits,contributors,tree',
      });
      toolsUsed.add('github.repo');
      if (detailResult.success) {
        repoDetails.add('### $repo\n\n${detailResult.output}');
        yield SkillEvent.output(
            'Repo details: $repo — ${detailResult.output.length} chars');
      }

      final ghCodeResult = await context.runTool('github.search', {
        'query': 'repo:$repo extension:dart OR extension:ts OR extension:go OR extension:py OR extension:rs',
        'type': 'code',
        'limit': 5,
      });
      toolsUsed.add('github.search');
      if (ghCodeResult.success) {
        codeAnalyses.add('### Code: $repo\n\n${ghCodeResult.output}');
      }

      final grepResult = await _searchCodeGrepApp(repo, maxFiles: 5, maxChars: 600);
      if (grepResult != null) {
        codeAnalyses.add('### grep.app: $repo\n\n$grepResult');
      }
    }

    yield SkillEvent.step(
        'Searching for source code analysis articles...',
        stepNumber: 5,
        totalSteps: 7);
    stepsCompleted.add('search_articles');

    final articleResults = <String>[];
    for (final repo in repos.take(3)) {
      final result = await context.runTool('web.search', {
        'query': '$repo 源码解析 architecture analysis',
        'limit': 3,
      });
      toolsUsed.add('web.search');
      if (result.success) {
        articleResults.add('### $repo\n${result.output}');
      }
    }

    yield SkillEvent.step(
        'Performing deep analysis...',
        stepNumber: 6,
        totalSteps: 7);
    stepsCompleted.add('deep_analysis');

    final memoryCtx = context.getMemoryContext();
    final analysisPrompt = '你是一位资深的开源项目分析师和代码架构专家。'
        '请对以下今日 GitHub 热门项目进行深度分析。\n\n'
        '## 仓库详情\n\n${repoDetails.join('\n\n---\n\n')}\n\n'
        '## 代码扫描结果\n\n${codeAnalyses.join('\n\n---\n\n')}\n\n'
        '## 相关文章\n\n${articleResults.join('\n\n---\n\n')}\n\n'
        '${memoryCtx.isNotEmpty ? "## 用户上下文\n$memoryCtx\n\n" : ""}'
        '## 已分析过的项目（不要重复分析）\n${memoryResult.output}\n\n'
        '## 分析要求\n\n'
        '对每个 NEW 项目（未分析过的），提供以下分析（每个项目至少 400 字）：\n\n'
        '### 1. 项目概览\n'
        '- 名称、描述、Star/Fork 数、主要语言、License\n'
        '- 创建时间、最近更新时间\n'
        '- **增长趋势**：是爆发式增长还是稳步增长？创建多久就到了当前 Star 数？\n\n'
        '### 2. 技术栈与架构\n'
        '- 核心技术、依赖关系、架构风格\n'
        '- 语言分布\n\n'
        '### 3. 独到之处（重点，至少 150 字）\n'
        '- 这个项目有什么独特的设计理念或创新实现？\n'
        '- 和同类项目最大的差异化在哪里？\n'
        '- 举出具体的代码或设计例子\n\n'
        '### 4. 代码实现深度分析（重点，至少 200 字）\n'
        '- 根据目录结构和代码扫描，分析核心模块划分\n'
        '- 指出关键文件路径和核心函数/方法名\n'
        '- 描述核心数据流和设计模式\n'
        '- 引用实际代码片段\n\n'
        '### 5. 社区与维护\n'
        '- 贡献者数量和活跃度\n'
        '- 最近 commit 频率\n\n'
        '### 6. 风险评估\n'
        '- License、安全历史、Bus factor\n\n'
        '### 7. 综合评价\n'
        '- 置信度（高/中/低）、适用场景、替代方案\n\n'
        '## 输出格式\n'
        '- 每个项目用 `##` 标题分隔，标题后标注 Star 数和增长趋势\n'
        '- 代码分析必须具体到文件路径和函数名\n'
        '- 最后给出 `## 今日推荐 Top 3`，每条附 1-2 句推荐理由\n'
        '- 末尾添加 `## 总结`（3-5 句话概括今日发现）\n'
        '- 全部用中文';

    final analysis = await context.llmChat(analysisPrompt);
    yield SkillEvent.output(analysis);

    yield SkillEvent.step(
        'Saving analysis to memory and workspace...',
        stepNumber: 7,
        totalSteps: 7);
    stepsCompleted.add('save');

    for (final repo in repos.take(5)) {
      await context.runTool('memory.save', {
        'key': 'oss_analyzed_$repo',
        'value': 'Analyzed on $today: $repo — trend analysis',
      });
      toolsUsed.add('memory.save');
    }

    final reportPath = 'reports/oss-analysis/$today.md';
    final fsResult = await context.runTool('workspace.fs', {
      'action': 'write',
      'path': reportPath,
      'content': '# 开源项目趋势分析报告 — $today\n\n$analysis',
    });
    toolsUsed.add('workspace.fs');
    yield SkillEvent.toolResult(
        'workspace.fs', fsResult.success, fsResult.output ?? '');

    yield SkillEvent.done(SkillResult.ok(
      '分析了 ${repos.take(5).length} 个新热门项目。报告已保存到 $reportPath。',
      data: {
        'report': analysis,
        'reportPath': reportPath,
        'reposAnalyzed': repos.take(5).toList(),
        'date': today,
      },
      stepsCompleted: stepsCompleted.length,
      toolsUsed: toolsUsed,
    ));
  }

  // ─── Helpers ─────────────────────────────────────────────────────────

  Future<String?> _searchCodeGrepApp(String repo,
      {int maxFiles = 5, int maxChars = 600}) async {
    try {
      final ownerRepo = repo.split('/');
      if (ownerRepo.length != 2) return null;
      final owner = ownerRepo[0];
      final repoName = ownerRepo[1];

      final url = Uri.parse(
          'https://grep.app/api/search?q=repo%3A$owner%2F$repoName&case=true');
      final response = await http.get(url, headers: {
        'User-Agent': 'NudgeeAgent/1.0',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final hits = data['hits']?['hits'] as List? ?? [];
      if (hits.isEmpty) return 'No code results on grep.app for $repo';

      final lines = <String>[];
      for (final hit in hits.take(maxFiles)) {
        final source = hit['_source'] as Map<String, dynamic>?;
        if (source == null) continue;
        final path = source['path']?['raw'] as String? ?? '';
        final content = source['content']?['raw'] as String? ?? '';
        final lang = source['language']?['raw'] as String? ?? '';

        final snippet = content.length > maxChars
            ? '${content.substring(0, maxChars)}...'
            : content;

        lines.add('- **$path** ($lang)\n```\n$snippet\n```');
      }

      return 'Found ${hits.length} code results:\n${lines.join('\n\n')}';
    } catch (e) {
      return null;
    }
  }

  String? _extractRepoName(String input) {
    final regex = RegExp(r'\b([\w.-]+/[\w.-]+)\b');
    final matches = regex.allMatches(input);
    for (final m in matches) {
      final candidate = m.group(1)!;
      if (candidate.contains(' ') || candidate.length < 3) continue;
      if (!RegExp(r'[a-zA-Z]').hasMatch(candidate)) continue;
      if (candidate.endsWith('.dart') ||
          candidate.endsWith('.py') ||
          candidate.endsWith('.ts') ||
          candidate.endsWith('.js') ||
          candidate.endsWith('.md')) continue;
      return candidate;
    }
    return null;
  }

  List<String> _parseRepoList(String text) {
    final regex = RegExp(r'[\w.-]+/[\w.-]+');
    return regex
        .allMatches(text)
        .map((m) => m.group(0)!)
        .where((s) => !s.contains(' ') && s.length > 3)
        .toSet()
        .toList();
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
