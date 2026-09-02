import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nudgee/core/agent/tools/agent_tool.dart';
import 'package:nudgee/core/agent/tools/tool_result.dart';

/// Tool: web.news
///
/// Fetches real-time news headlines from free RSS/JSON feeds.
/// Sources:
/// - ChinaDaily (China news, free JSON)
/// - Hacker News (tech news, free API)
/// - Reuters/BBC RSS (world news, free RSS)
///
/// No API key required.
class WebNewsTool extends AgentTool {
  final http.Client _httpClient;

  WebNewsTool({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  @override
  String get name => 'web.news';

  @override
  String get description =>
      'Fetch real-time news headlines. Use this when the user asks about '
      'current events, latest news, or what\'s happening today. '
      'Supports categories: general, tech, china, world. '
      'No API key required.';

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'category': {
            'type': 'string',
            'description': 'News category: general, tech, china, world',
          },
          'limit': {
            'type': 'integer',
            'description': 'Max results (default 5, max 10)',
          },
        },
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final category = (args['category'] as String?) ?? 'general';
    final limit = (args['limit'] as int?)?.clamp(1, 10) ?? 5;

    final results = <String>[];

    try {
      switch (category.toLowerCase()) {
        case 'tech':
          results.addAll(await _fetchHackerNews(limit));
          break;
        case 'china':
          results.addAll(await _fetchChinaNews(limit));
          break;
        case 'world':
          results.addAll(await _fetchWorldNews(limit));
          break;
        default:
          // General: mix of sources
          final hn = await _fetchHackerNews(limit ~/ 2 + 1);
          final world = await _fetchWorldNews(limit - hn.length);
          results.addAll(hn);
          results.addAll(world);
      }
    } catch (e) {
      return ToolResult.error('Failed to fetch news: $e');
    }

    if (results.isEmpty) {
      return ToolResult.success('No news found for category "$category".');
    }

    return ToolResult.success(
        'News ($category, ${results.length} items):\n\n${results.take(limit).join('\n\n')}');
  }

  /// Fetches top stories from Hacker News (free, no key).
  Future<List<String>> _fetchHackerNews(int limit) async {
    final idsResp = await _httpClient.get(
      Uri.parse('https://hacker-news.firebaseio.com/v0/topstories.json'),
    ).timeout(const Duration(seconds: 10));

    if (idsResp.statusCode != 200) return [];

    final ids = (jsonDecode(idsResp.body) as List).take(limit).toList();
    final stories = <String>[];

    for (final id in ids) {
      try {
        final itemResp = await _httpClient.get(
          Uri.parse('https://hacker-news.firebaseio.com/v0/item/$id.json'),
        ).timeout(const Duration(seconds: 5));
        if (itemResp.statusCode == 200) {
          final item = jsonDecode(itemResp.body) as Map<String, dynamic>;
          final title = item['title'] as String? ?? '';
          final url = item['url'] as String? ?? '';
          final score = item['score'] as int? ?? 0;
          stories.add('• $title (score: $score)\n  $url');
        }
      } catch (_) {}
    }

    return stories;
  }

  /// Fetches China news from ChinaDaily RSS feed.
  Future<List<String>> _fetchChinaNews(int limit) async {
    // Use RSS to JSON converter (free, no key)
    final resp = await _httpClient.get(
      Uri.parse('https://api.rss2json.com/v1/api.json?rss_url='
          '${Uri.encodeComponent('https://www.chinadaily.com.cn/rss/china_rss.xml')}'),
    ).timeout(const Duration(seconds: 10));

    if (resp.statusCode != 200) return [];

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final items = data['items'] as List?;
    if (items == null) return [];

    return items.take(limit).map((item) {
      final m = item as Map<String, dynamic>;
      final title = m['title'] as String? ?? '';
      final link = m['link'] as String? ?? '';
      final desc = (m['description'] as String? ?? '').replaceAll(RegExp(r'<[^>]*>'), '').trim();
      final snippet = desc.length > 150 ? '${desc.substring(0, 150)}...' : desc;
      return '• $title\n  $snippet\n  $link';
    }).toList();
  }

  /// Fetches world news from BBC RSS feed.
  Future<List<String>> _fetchWorldNews(int limit) async {
    final resp = await _httpClient.get(
      Uri.parse('https://api.rss2json.com/v1/api.json?rss_url='
          '${Uri.encodeComponent('http://feeds.bbci.co.uk/news/world/rss.xml')}'),
    ).timeout(const Duration(seconds: 10));

    if (resp.statusCode != 200) return [];

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final items = data['items'] as List?;
    if (items == null) return [];

    return items.take(limit).map((item) {
      final m = item as Map<String, dynamic>;
      final title = m['title'] as String? ?? '';
      final link = m['link'] as String? ?? '';
      final desc = (m['description'] as String? ?? '').replaceAll(RegExp(r'<[^>]*>'), '').trim();
      final snippet = desc.length > 150 ? '${desc.substring(0, 150)}...' : desc;
      return '• $title\n  $snippet\n  $link';
    }).toList();
  }
}

/// Tool: web.weather
///
/// Fetches current weather for a city using the free Open-Meteo API.
/// No API key required.
class WebWeatherTool extends AgentTool {
  final http.Client _httpClient;

  WebWeatherTool({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  @override
  String get name => 'web.weather';

  @override
  String get description =>
      'Get current weather for a city. Returns temperature, humidity, '
      'wind speed, and weather condition. Use this when the user asks '
      'about weather, or when planning outdoor activities. '
      'No API key required (uses Open-Meteo free API).';

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'city': {
            'type': 'string',
            'description': 'City name (e.g. "Beijing", "Shanghai", "New York")',
          },
          'units': {
            'type': 'string',
            'description': 'Temperature unit: "celsius" (default) or "fahrenheit"',
          },
        },
        'required': ['city'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final city = args['city'] as String?;
    if (city == null || city.isEmpty) {
      return const ToolResult.error('Missing required field: city');
    }
    final units = (args['units'] as String?) ?? 'celsius';

    try {
      // 1. Geocode city name to lat/lon (Open-Meteo geocoding, free)
      final geoResp = await _httpClient.get(
        Uri.parse('https://geocoding-api.open-meteo.com/v1/search?'
            'name=${Uri.encodeComponent(city)}&count=1&language=zh'),
      ).timeout(const Duration(seconds: 10));

      if (geoResp.statusCode != 200) {
        return const ToolResult.error('Weather service unavailable');
      }

      final geoData = jsonDecode(geoResp.body) as Map<String, dynamic>;
      final results = geoData['results'] as List?;
      if (results == null || results.isEmpty) {
        return ToolResult.error('City "$city" not found');
      }

      final geo = results[0] as Map<String, dynamic>;
      final lat = geo['latitude'] as num;
      final lon = geo['longitude'] as num;
      final name = geo['name'] as String? ?? city;
      final country = geo['country'] as String? ?? '';

      // 2. Fetch current weather
      final tempUnit = units == 'fahrenheit' ? 'fahrenheit' : 'celsius';
      final weatherResp = await _httpClient.get(
        Uri.parse('https://api.open-meteo.com/v1/forecast?'
            'latitude=$lat&longitude=$lon&current=temperature_2m,'
            'relative_humidity_2m,weather_code,wind_speed_10m&'
            'temperature_unit=$tempUnit'),
      ).timeout(const Duration(seconds: 10));

      if (weatherResp.statusCode != 200) {
        return ToolResult.error('Weather data unavailable for $city');
      }

      final wData = jsonDecode(weatherResp.body) as Map<String, dynamic>;
      final current = wData['current'] as Map<String, dynamic>?;

      if (current == null) {
        return const ToolResult.error('No current weather data');
      }

      final temp = current['temperature_2m'] as num?;
      final humidity = current['relative_humidity_2m'] as num?;
      final wind = current['wind_speed_10m'] as num?;
      final code = current['weather_code'] as int?;
      final condition = _weatherCodeToString(code);

      final unitSymbol = tempUnit == 'fahrenheit' ? '°F' : '°C';

      return ToolResult.success(
          'Weather for $name${country.isNotEmpty ? ', $country' : ''}:\n'
          '  Temperature: $temp$unitSymbol\n'
          '  Condition: $condition\n'
          '  Humidity: $humidity%\n'
          '  Wind: $wind km/h');
    } catch (e) {
      return ToolResult.error('Failed to fetch weather: $e');
    }
  }

  /// Maps WMO weather code to human-readable condition.
  String _weatherCodeToString(int? code) {
    if (code == null) return 'Unknown';
    switch (code) {
      case 0: return 'Clear sky';
      case 1: case 2: case 3: return 'Partly cloudy';
      case 45: case 48: return 'Foggy';
      case 51: case 53: case 55: return 'Drizzle';
      case 61: case 63: case 65: return 'Rain';
      case 66: case 67: return 'Freezing rain';
      case 71: case 73: case 75: return 'Snow';
      case 77: return 'Snow grains';
      case 80: case 81: case 82: return 'Rain showers';
      case 85: case 86: return 'Snow showers';
      case 95: return 'Thunderstorm';
      case 96: case 99: return 'Thunderstorm with hail';
      default: return 'Unknown';
    }
  }
}

/// Tool: web.stock
///
/// Fetches stock/finance data using free APIs.
/// Uses Alpha Vantage demo key for basic queries (limited but free).
/// For crypto, uses CoinGecko free API.
class WebStockTool extends AgentTool {
  final http.Client _httpClient;

  WebStockTool({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  @override
  String get name => 'web.stock';

  @override
  String get description =>
      'Get stock price or crypto price. Use this when the user asks about '
      'stock prices, crypto prices, or financial market data. '
      'Supports: stock symbols (e.g. "AAPL", "TSLA") and crypto (e.g. "bitcoin", "ethereum"). '
      'Uses free APIs (Alpha Vantage demo + CoinGecko).';

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'symbol': {
            'type': 'string',
            'description': 'Stock symbol (e.g. "AAPL") or crypto name (e.g. "bitcoin")',
          },
          'type': {
            'type': 'string',
            'description': 'Asset type: "stock" or "crypto" (default: auto-detect)',
          },
        },
        'required': ['symbol'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final symbol = (args['symbol'] as String?)?.trim();
    if (symbol == null || symbol.isEmpty) {
      return const ToolResult.error('Missing required field: symbol');
    }
    final type = args['type'] as String?;

    // Auto-detect: if symbol looks like a stock ticker (uppercase, short),
    // treat as stock. Otherwise try crypto.
    final isStock = type == 'stock' ||
        (type == null && RegExp(r'^[A-Z]{1,5}$').hasMatch(symbol));

    if (isStock) {
      return _fetchStock(symbol);
    } else {
      return _fetchCrypto(symbol.toLowerCase());
    }
  }

  /// Fetches stock price from Alpha Vantage (demo key, limited).
  Future<ToolResult> _fetchStock(String symbol) async {
    try {
      final resp = await _httpClient.get(
        Uri.parse('https://www.alphavantage.co/query?function=GLOBAL_QUOTE'
            '&symbol=$symbol&apikey=demo'),
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200) {
        return const ToolResult.error('Stock service unavailable');
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final quote = data['Global Quote'] as Map<String, dynamic>?;

      if (quote == null || quote.isEmpty) {
        // Fall back to crypto if stock lookup fails
        return _fetchCrypto(symbol.toLowerCase());
      }

      final price = quote['05. price'] as String? ?? 'N/A';
      final change = quote['10. change percent'] as String? ?? 'N/A';
      final volume = quote['06. volume'] as String? ?? 'N/A';

      return ToolResult.success(
          'Stock $symbol:\n'
          '  Price: \$$price\n'
          '  Change: $change\n'
          '  Volume: $volume\n'
          '  (Source: Alpha Vantage, may be delayed)');
    } catch (e) {
      return ToolResult.error('Failed to fetch stock data: $e');
    }
  }

  /// Fetches crypto price from CoinGecko (free, no key).
  Future<ToolResult> _fetchCrypto(String coinId) async {
    // Map common names to CoinGecko IDs
    final coinMap = {
      'bitcoin': 'bitcoin', 'btc': 'bitcoin',
      'ethereum': 'ethereum', 'eth': 'ethereum',
      'solana': 'solana', 'sol': 'solana',
      'doge': 'dogecoin', 'dogecoin': 'dogecoin',
      'cardano': 'cardano', 'ada': 'cardano',
      'ripple': 'ripple', 'xrp': 'ripple',
      'polkadot': 'polkadot', 'dot': 'polkadot',
    };
    final id = coinMap[coinId] ?? coinId;

    try {
      final resp = await _httpClient.get(
        Uri.parse('https://api.coingecko.com/api/v3/simple/price?'
            'ids=$id&vs_currencies=usd&include_24hr_change=true'),
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200) {
        return const ToolResult.error('Crypto service unavailable');
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final coinData = data[id] as Map<String, dynamic>?;

      if (coinData == null) {
        return ToolResult.error('Crypto "$coinId" not found. '
            'Try: bitcoin, ethereum, solana, dogecoin, etc.');
      }

      final price = coinData['usd'] as num?;
      final change = coinData['usd_24h_change'] as num?;

      return ToolResult.success(
          'Crypto $coinId:\n'
          '  Price: \$$price USD\n'
          '  24h change: ${change?.toStringAsFixed(2)}%\n'
          '  (Source: CoinGecko)');
    } catch (e) {
      return ToolResult.error('Failed to fetch crypto data: $e');
    }
  }
}
