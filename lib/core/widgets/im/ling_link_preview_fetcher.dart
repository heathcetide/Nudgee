import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:enough_convert/enough_convert.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;

/// Link metadata extracted from a URL.
class LingLinkMetadata {
  final String url;
  final String? title;
  final String? description;
  final String? imageUrl;

  const LingLinkMetadata({
    required this.url,
    this.title,
    this.description,
    this.imageUrl,
  });
}

/// Fetches link metadata (title, description, image) by parsing HTML.
///
/// Uses the `html` package for proper HTML parsing and `enough_convert`
/// for GBK/GB2312 encoding support.
class LingLinkPreviewFetcher {
  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
    followRedirects: true,
    maxRedirects: 5,
    headers: {
      'User-Agent':
          'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
    },
    responseType: ResponseType.bytes,
  ));

  /// Detect charset from HTML meta tag.
  static String _detectCharsetFromMeta(String htmlSample) {
    // <meta charset="gbk">
    final m1 = RegExp(
      r'<meta[^>]+charset=["\x27]?([\w-]+)',
      caseSensitive: false,
    ).firstMatch(htmlSample);
    if (m1 != null) return m1.group(1)!.toLowerCase();
    // <?xml encoding="gbk"?>
    final m2 = RegExp(
      r'encoding=["\x27]([\w-]+)',
      caseSensitive: false,
    ).firstMatch(htmlSample);
    if (m2 != null) return m2.group(1)!.toLowerCase();
    return 'utf-8';
  }

  /// Decode bytes using the detected charset.
  static String _decodeBytes(Uint8List bytes, String charset) {
    // Try specific codecs for GBK variants
    if (charset == 'gbk' || charset == 'gb2312' || charset == 'gb18030') {
      try {
        final codec = GbkCodec(allowInvalid: true);
        return codec.decode(bytes);
      } catch (_) {
        // fallback below
      }
    }
    // Default: UTF-8 with allowMalformed
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// Fetch metadata for [url]. Returns null on failure.
  static Future<LingLinkMetadata?> fetch(String url) async {
    try {
      final res = await _dio.get<dynamic>(url);
      if (res.statusCode != 200 || res.data == null) {
        debugPrint('LingLinkPreview: status=${res.statusCode}');
        return null;
      }

      // Get raw bytes
      final Uint8List bytes;
      final data = res.data;
      if (data is Uint8List) {
        bytes = data;
      } else if (data is List<int>) {
        bytes = Uint8List.fromList(data);
      } else if (data is String) {
        bytes = Uint8List.fromList(utf8.encode(data));
      } else {
        debugPrint('LingLinkPreview: unexpected data type ${data.runtimeType}');
        return null;
      }

      // Step 1: Detect charset from Content-Type header
      String charset = 'utf-8';
      final contentType = res.headers.value('content-type');
      if (contentType != null) {
        final match = RegExp(
          r'charset=([\w-]+)',
          caseSensitive: false,
        ).firstMatch(contentType);
        if (match != null) charset = match.group(1)!.toLowerCase();
      }

      // Step 2: If header didn't specify charset, do a preliminary ASCII decode
      // to check the meta tag
      if (charset == 'utf-8') {
        // Decode first 2KB as ASCII to find meta charset
        final sampleBytes = bytes.length > 2048
            ? Uint8List.sublistView(bytes, 0, 2048)
            : bytes;
        final asciiSample = latin1.decode(sampleBytes);
        final metaCharset = _detectCharsetFromMeta(asciiSample);
        if (metaCharset != 'utf-8') {
          charset = metaCharset;
        }
      }

      // Step 3: Decode with the correct charset
      final html = _decodeBytes(bytes, charset);

      // Parse with html package
      final doc = html_parser.parse(html);

      // Title: try og:title first, then <title> tag
      String? title;
      final ogTitle = doc.querySelector('meta[property="og:title"]');
      if (ogTitle != null) {
        title = ogTitle.attributes['content'];
      }
      if (title == null || title.isEmpty) {
        final titleTag = doc.querySelector('title');
        if (titleTag != null) {
          title = titleTag.text.trim();
        }
      }

      // Description: try og:description, then meta description
      String? description;
      final ogDesc = doc.querySelector('meta[property="og:description"]');
      if (ogDesc != null) {
        description = ogDesc.attributes['content'];
      }
      if (description == null || description.isEmpty) {
        final metaDesc = doc.querySelector('meta[name="description"]');
        if (metaDesc != null) {
          description = metaDesc.attributes['content'];
        }
      }

      // Image: try og:image, then og:image:url
      String? imageUrl;
      final ogImage = doc.querySelector('meta[property="og:image"]');
      if (ogImage != null) {
        imageUrl = ogImage.attributes['content'];
      }
      if (imageUrl == null || imageUrl.isEmpty) {
        final ogImageUrl = doc.querySelector('meta[property="og:image:url"]');
        if (ogImageUrl != null) {
          imageUrl = ogImageUrl.attributes['content'];
        }
      }

      // Handle relative URLs for image
      if (imageUrl != null && imageUrl.isNotEmpty) {
        if (imageUrl.startsWith('//')) {
          imageUrl = 'https:$imageUrl';
        } else if (imageUrl.startsWith('/')) {
          final uri = Uri.parse(url);
          imageUrl = '${uri.scheme}://${uri.host}$imageUrl';
        }
      }

      final meta = LingLinkMetadata(
        url: url,
        title: (title != null && title.isNotEmpty) ? title : null,
        description: (description != null && description.isNotEmpty)
            ? description
            : null,
        imageUrl:
            (imageUrl != null && imageUrl.isNotEmpty) ? imageUrl : null,
      );

      debugPrint(
        'LingLinkPreview: charset=$charset, title=${meta.title}, '
        'desc=${meta.description != null ? (meta.description!.length > 40 ? '${meta.description!.substring(0, 40)}...' : meta.description) : 'null'}, '
        'img=${meta.imageUrl}',
      );

      return meta;
    } catch (e) {
      debugPrint('LingLinkPreview fetch error: $e');
      return null;
    }
  }
}
