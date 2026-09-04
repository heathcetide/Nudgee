import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Full-screen Mermaid diagram viewer with pinch-to-zoom, pan, and fullscreen.
///
/// Renders the mermaid diagram via WebView + mermaid.js CDN, then allows
/// the user to zoom (pinch / buttons), pan (drag), and toggle fullscreen.
class LingMermaidViewer extends StatefulWidget {
  final String mermaidCode;
  final String? title;

  const LingMermaidViewer({
    super.key,
    required this.mermaidCode,
    this.title,
  });

  @override
  State<LingMermaidViewer> createState() => _LingMermaidViewerState();
}

class _LingMermaidViewerState extends State<LingMermaidViewer> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFAFAFA))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) {
              // Give mermaid.js a moment to render
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted) setState(() => _isLoading = false);
              });
            }
          },
          onWebResourceError: (e) {
            if (mounted) setState(() => _hasError = true);
          },
        ),
      )
      ..loadHtmlString(_buildHtml());
  }

  String _buildHtml() {
    final escaped = jsonEncode(widget.mermaidCode);
    return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=5.0, user-scalable=yes">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      background: #FAFAFA;
      display: flex;
      justify-content: center;
      align-items: flex-start;
      min-height: 100vh;
      padding: 16px;
      overflow: auto;
    }
    #diagram {
      display: flex;
      justify-content: center;
      align-items: center;
      width: 100%;
      min-height: 100vh;
    }
    #diagram svg {
      max-width: 100%;
      height: auto;
    }
    .error-msg {
      color: #d32f2f;
      font-family: monospace;
      font-size: 14px;
      padding: 20px;
      text-align: center;
      white-space: pre-wrap;
    }
  </style>
  <script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"></script>
</head>
<body>
  <div id="diagram"></div>
  <script>
    (function() {
      var code = $escaped;
      try {
        mermaid.initialize({
          startOnLoad: false,
          theme: 'default',
          securityLevel: 'loose',
          flowchart: { useMaxWidth: true },
          sequence: { useMaxWidth: true },
          gantt: { useMaxWidth: true },
        });
        mermaid.render('m', code).then(function(result) {
          document.getElementById('diagram').innerHTML = result.svg;
        }).catch(function(err) {
          document.getElementById('diagram').innerHTML =
            '<div class="error-msg">Mermaid render error:\\n' + err.message + '</div>';
        });
      } catch(e) {
        document.getElementById('diagram').innerHTML =
          '<div class="error-msg">Mermaid init error:\\n' + e.message + '</div>';
      }
    })();
  </script>
</body>
</html>''';
  }

  void _reload() {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    _controller.loadHtmlString(_buildHtml());
  }

  void _zoomIn() {
    _controller.runJavaScript('document.body.style.zoom = (parseFloat(document.body.style.zoom || 1) + 0.2)');
  }

  void _zoomOut() {
    _controller.runJavaScript('document.body.style.zoom = Math.max(0.3, parseFloat(document.body.style.zoom || 1) - 0.2)');
  }

  void _resetZoom() {
    _controller.runJavaScript('document.body.style.zoom = 1');
  }

  void _toggleFullscreen() {
    setState(() => _isFullscreen = !_isFullscreen);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isFullscreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            _buildWebView(),
            _buildFullscreenControls(theme),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title ?? 'Mermaid 图表',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: _zoomIn,
            tooltip: '放大',
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: _zoomOut,
            tooltip: '缩小',
          ),
          IconButton(
            icon: const Icon(Icons.fit_screen),
            onPressed: _resetZoom,
            tooltip: '重置缩放',
          ),
          IconButton(
            icon: const Icon(Icons.fullscreen),
            onPressed: _toggleFullscreen,
            tooltip: '全屏',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
            tooltip: '重新加载',
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildWebView(),
          if (_isLoading && !_hasError)
            const Center(child: CircularProgressIndicator()),
          if (_hasError)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 8),
                  const Text('图表加载失败'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _reload,
                    child: const Text('重试'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWebView() {
    return Positioned.fill(
      child: InteractiveViewer(
        minScale: 0.3,
        maxScale: 4.0,
        boundaryMargin: const EdgeInsets.all(double.infinity),
        child: WebViewWidget(controller: _controller),
      ),
    );
  }

  Widget _buildFullscreenControls(ThemeData theme) {
    return Positioned(
      bottom: 24,
      right: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'fs_zoom_in',
            onPressed: _zoomIn,
            backgroundColor: Colors.white.withAlpha(230),
            child: const Icon(Icons.zoom_in, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'fs_zoom_out',
            onPressed: _zoomOut,
            backgroundColor: Colors.white.withAlpha(230),
            child: const Icon(Icons.zoom_out, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'fs_reset',
            onPressed: _resetZoom,
            backgroundColor: Colors.white.withAlpha(230),
            child: const Icon(Icons.fit_screen, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'fs_exit',
            onPressed: _toggleFullscreen,
            backgroundColor: Colors.white.withAlpha(230),
            child: const Icon(Icons.fullscreen_exit, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}

/// Inline mermaid preview widget — renders a small preview of the mermaid
/// diagram inside a message bubble. Tapping opens the full-screen viewer.
class LingMermaidPreview extends StatefulWidget {
  final String mermaidCode;

  const LingMermaidPreview({super.key, required this.mermaidCode});

  @override
  State<LingMermaidPreview> createState() => _LingMermaidPreviewState();
}

class _LingMermaidPreviewState extends State<LingMermaidPreview> {
  late final WebViewController _controller;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) {
              Future.delayed(const Duration(milliseconds: 400), () {
                if (mounted) setState(() => _loaded = true);
              });
            }
          },
        ),
      )
      ..loadHtmlString(_buildInlineHtml());
  }

  String _buildInlineHtml() {
    final escaped = jsonEncode(widget.mermaidCode);
    return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      background: transparent;
      display: flex;
      justify-content: center;
      align-items: center;
      width: 100%;
      overflow: hidden;
    }
    #diagram { width: 100%; text-align: center; }
    #diagram svg { max-width: 100%; height: auto; }
    .error-msg {
      color: #d32f2f; font-family: monospace; font-size: 12px;
      padding: 8px; text-align: center;
    }
  </style>
  <script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"></script>
</head>
<body>
  <div id="diagram"></div>
  <script>
    (function() {
      var code = $escaped;
      try {
        mermaid.initialize({ startOnLoad: false, theme: 'default', securityLevel: 'loose' });
        mermaid.render('m', code).then(function(r) {
          document.getElementById('diagram').innerHTML = r.svg;
        }).catch(function(e) {
          document.getElementById('diagram').innerHTML =
            '<div class="error-msg">' + e.message + '</div>';
        });
      } catch(e) {
        document.getElementById('diagram').innerHTML =
          '<div class="error-msg">' + e.message + '</div>';
      }
    })();
  </script>
</body>
</html>''';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LingMermaidViewer(
              mermaidCode: widget.mermaidCode,
            ),
          ),
        );
      },
      child: Container(
        constraints: const BoxConstraints(maxHeight: 300),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withAlpha(60),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withAlpha(40),
            width: 0.5,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 300,
                child: WebViewWidget(controller: _controller),
              ),
            ),
            if (!_loaded)
              const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fullscreen, size: 12, color: Colors.white70),
                    SizedBox(width: 2),
                    Text('点击放大', style: TextStyle(color: Colors.white70, fontSize: 10)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
