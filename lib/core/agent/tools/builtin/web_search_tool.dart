import 'dart:convert';

import 'package:nudgee/core/agent/tools/agent_tool.dart';
import 'package:nudgee/core/agent/tools/tool_result.dart';
import 'package:http/http.dart' as http;

/// Tool: web.search
///
/// Searches the web for information using **free, no-API-key** sources:
/// 1. **Wikipedia API** — for encyclopedic knowledge (REST API, free)
/// 2. **DuckDuckGo Instant Answer API** — for quick facts (free)
/// 3. **DuckDuckGo HTML search** — for general web results (free, scraped)
///
/// The tool automatically tries multiple sources and merges results,
/// so the agent gets useful answers even when one source has no data.
///
/// Read-only tool — no mutation, no confirmation needed, no API key required.
class WebSearchTool extends AgentTool {
  @override
  String get name => 'web.search';

  @override
  String get description =>
      'Search the web for current information. Use this when the user asks '
      'about recent events, facts you\'re unsure about, or anything that '
      'requires up-to-date information. Returns search results with titles, '
      'snippets, and source URLs. No API key required — uses Wikipedia and '
      'DuckDuckGo free APIs.';

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
    final results = <SearchResult>[];

    // 1. Try Wikipedia API (great for factual/encyclopedic queries)
    try {
      final wikiResults = await _searchWikipedia(query, limit);
      results.addAll(wikiResults);
    } catch (_) {
      // Wikipedia may fail for non-encyclopedic queries — that's OK
    }

    // 2. Try DuckDuckGo Instant Answer API (quick facts)
    if (results.length < limit) {
      try {
        final ddgResults = await _searchDuckDuckGo(query, limit - results.length);
        results.addAll(ddgResults);
      } catch (_) {
        // DDG may not have instant answers for all queries
      }
    }

    // 3. Try DuckDuckGo HTML search (general web results, fallback)
    if (results.length < limit) {
      try {
        final htmlResults = await _searchDuckDuckGoHtml(
          query,
          limit - results.length,
        );
        results.addAll(htmlResults);
      } catch (_) {
        // HTML scraping may fail — that's OK, we have other sources
      }
    }

    if (results.isEmpty) {
      return ToolResult.success(
          'No results found for "$query". '
          'Try rephrasing the search query.');
    }

    // Deduplicate by URL
    final seen = <String>{};
    final unique = results.where((r) {
      if (r.url == null) return true;
      if (seen.contains(r.url)) return false;
      seen.add(r.url!);
      return true;
    }).take(limit).toList();

    final formatted = unique.asMap().entries.map((entry) {
      final i = entry.key + 1;
      final r = entry.value;
      final parts = <String>['$i. ${r.title}'];
      if (r.snippet.isNotEmpty) parts.add('   ${r.snippet}');
      if (r.url != null) parts.add('   URL: ${r.url}');
      return parts.join('\n');
    }).join('\n\n');

    return ToolResult.success(
        'Search results for "$query" (${unique.length} results):\n\n$formatted');
  }

  /// Searches Wikipedia's REST API for opensearch results + extracts.
  ///
  /// Wikipedia's API is completely free, no key required.
  /// Returns titles, snippets, and URLs.
  Future<List<SearchResult>> _searchWikipedia(
    String query,
    int limit,
  ) async {
    // 1. Opensearch to get titles
    final searchUri = Uri.parse(
      'https://en.wikipedia.org/w/api.php?action=opensearch'
      '&search=${Uri.encodeComponent(query)}'
      '&limit=$limit&namespace=0&format=json&origin=*',
    );

    final searchResp = await _httpClient.get(searchUri, headers: {
      'User-Agent': 'NudgeeAgent/1.0 (https://nudgee.app)',
    }).timeout(const Duration(seconds: 10));

    if (searchResp.statusCode != 200) return [];

    final searchData = jsonDecode(searchResp.body) as List;
    if (searchData.length < 4) return [];

    final titles = (searchData[1] as List).cast<String>();
    final urls = (searchData[3] as List).cast<String>();

    if (titles.isEmpty) return [];

    // 2. Get extracts for the first few titles
    final titlesParam = titles.take(limit).join('|');
    final extractUri = Uri.parse(
      'https://en.wikipedia.org/w/api.php?action=query'
      '&prop=extracts&exintro=true&explaintext=true'
      '&titles=${Uri.encodeComponent(titlesParam)}'
      '&format=json&origin=*&redirects=1',
    );

    final extractResp = await _httpClient.get(extractUri, headers: {
      'User-Agent': 'NudgeeAgent/1.0 (https://nudgee.app)',
    }).timeout(const Duration(seconds: 10));

    final results = <SearchResult>[];
    if (extractResp.statusCode == 200) {
      final extractData = jsonDecode(extractResp.body) as Map<String, dynamic>;
      final pages = extractData['query']?['pages'] as Map<String, dynamic>?;
      if (pages != null) {
        for (final page in pages.values) {
          final title = page['title'] as String? ?? '';
          final extract = page['extract'] as String? ?? '';
          final snippet = extract.length > 300
              ? '${extract.substring(0, 300)}...'
              : extract;
          // Find matching URL
          final urlIdx = titles.indexOf(title);
          final url = urlIdx >= 0 && urlIdx < urls.length ? urls[urlIdx] : null;
          results.add(SearchResult(
            title: title,
            snippet: snippet,
            url: url,
            source: 'Wikipedia',
          ));
        }
      }
    }

    // If extracts failed, at least return titles + URLs
    if (results.isEmpty) {
      for (var i = 0; i < titles.length && i < limit; i++) {
        results.add(SearchResult(
          title: titles[i],
          snippet: '',
          url: urls.length > i ? urls[i] : null,
          source: 'Wikipedia',
        ));
      }
    }

    return results;
  }

  /// Searches DuckDuckGo's Instant Answer API.
  ///
  /// Returns abstract, related topics, and definitions.
  /// Free, no API key required.
  Future<List<SearchResult>> _searchDuckDuckGo(
    String query,
    int limit,
  ) async {
    final uri = Uri.parse(
      'https://api.duckduckgo.com/?q=${Uri.encodeComponent(query)}'
      '&format=json&no_html=1&skip_disambig=1',
    );

    final response = await _httpClient.get(uri, headers: {
      'User-Agent': 'NudgeeAgent/1.0',
    }).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final results = <SearchResult>[];

    // Abstract (main answer)
    final abstract = data['Abstract'] as String?;
    if (abstract != null && abstract.isNotEmpty) {
      results.add(SearchResult(
        title: data['Heading'] as String? ?? query,
        snippet: abstract,
        url: data['AbstractURL'] as String?,
        source: data['AbstractSource'] as String? ?? 'DuckDuckGo',
      ));
    }

    // Related topics
    final relatedTopics = data['RelatedTopics'] as List?;
    if (relatedTopics != null) {
      for (final topic in relatedTopics) {
        if (results.length >= limit) break;
        if (topic is Map<String, dynamic>) {
          final text = topic['Text'] as String?;
          if (text != null && text.isNotEmpty) {
            final firstLink = topic['FirstURL'] as String?;
            results.add(SearchResult(
              title: text.split(' - ').first,
              snippet: text,
              url: firstLink,
              source: 'DuckDuckGo',
            ));
          }
        }
      }
    }

    // Definition
    final definition = data['Definition'] as String?;
    if (definition != null && definition.isNotEmpty) {
      results.add(SearchResult(
        title: 'Definition',
        snippet: definition,
        url: data['DefinitionURL'] as String?,
        source: data['DefinitionSource'] as String? ?? 'DuckDuckGo',
      ));
    }

    return results;
  }

  /// Searches DuckDuckGo's HTML endpoint (lite.duckduckgo.com).
  ///
  /// This is a fallback for queries that don't have instant answers.
  /// Parses the HTML to extract result titles, snippets, and URLs.
  /// Free, no API key required.
  Future<List<SearchResult>> _searchDuckDuckGoHtml(
    String query,
    int limit,
  ) async {
    final uri = Uri.parse(
      'https://html.duckduckgo.com/html/?q=${Uri.encodeComponent(query)}',
    );

    final response = await _httpClient.get(uri, headers: {
      'User-Agent':
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
    }).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) return [];

    final html = response.body;
    final results = <SearchResult>[];

    // Parse result blocks: <a class="result__a" href="...">Title</a>
    // and snippets: <a class="result__snippet" ...>Snippet text</a>
    final resultPattern = RegExp(
      r'<a[^>]*class="result__a"[^>]*href="([^"]+)"[^>]*>(.*?)</a>',
      dotAll: true,
    );
    final snippetPattern = RegExp(
      r'<a[^>]*class="result__snippet"[^>]*>(.*?)</a>',
      dotAll: true,
    );

    final titleMatches = resultPattern.allMatches(html).toList();
    final snippetMatches = snippetPattern.allMatches(html).toList();

    for (var i = 0; i < titleMatches.length && results.length < limit; i++) {
      final match = titleMatches[i];
      var url = match.group(1) ?? '';
      var title = _stripHtml(match.group(2) ?? '');

      // DDG wraps URLs in a redirect — extract the actual URL
      final uddgMatch = RegExp(r'uddg=([^&]+)').firstMatch(url);
      if (uddgMatch != null) {
        url = Uri.decodeComponent(uddgMatch.group(1)!);
      }

      var snippet = '';
      if (i < snippetMatches.length) {
        snippet = _stripHtml(snippetMatches[i].group(1) ?? '');
      }

      if (title.isNotEmpty) {
        results.add(SearchResult(
          title: title,
          snippet: snippet,
          url: url.isNotEmpty ? url : null,
          source: 'DuckDuckGo',
        ));
      }
    }

    return results;
  }

  /// Strips HTML tags from a string.
  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .trim();
  }

  void dispose() {
    _httpClient.close();
  }
}

/// A single search result.
class SearchResult {
  final String title;
  final String snippet;
  final String? url;
  final String source;

  const SearchResult({
    required this.title,
    required this.snippet,
    this.url,
    required this.source,
  });

  @override
  String toString() => 'SearchResult($source: $title)';
}
