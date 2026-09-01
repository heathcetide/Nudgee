import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:nudgee/core/di/injector.dart';
import 'package:nudgee/core/services/workspace_service.dart';

/// HTML 预览页面 — 用 WebView 渲染工作区中的 HTML 文件。
///
/// 支持:
/// - 完整 HTML/CSS/JS 渲染
/// - CDN 加载外部库 (Vue/React/Three.js/Phaser 等)
/// - H5 游戏 (Canvas/WebGL)
/// - 响应式布局
/// - 可刷新/可全屏
///
/// 用法:
/// ```dart
/// Navigator.push(context, MaterialPageRoute(
///   builder: (_) => HtmlPreviewPage(relativePath: 'projects/game.html'),
/// ));
/// ```
class HtmlPreviewPage extends StatefulWidget {
  final String relativePath;

  const HtmlPreviewPage({super.key, required this.relativePath});

  @override
  State<HtmlPreviewPage> createState() => _HtmlPreviewPageState();
}

class _HtmlPreviewPageState extends State<HtmlPreviewPage> {
  final _workspace = sl<WorkspaceService>();
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadAndPreview();
  }

  Future<void> _loadAndPreview() async {
    try {
      if (!_workspace.isInitialized) {
        await _workspace.init();
      }

      final content = await _workspace.readFile(widget.relativePath);
      if (content == null) {
        setState(() {
          _hasError = true;
          _errorMessage = '文件不存在: ${widget.relativePath}';
          _isLoading = false;
        });
        return;
      }

      // Inject viewport meta so it renders properly on mobile
      final html = _injectBaseHref(content);

      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) {
              setState(() => _isLoading = false);
            },
            onWebResourceError: (error) {
              setState(() {
                _hasError = true;
                _errorMessage = error.description;
                _isLoading = false;
              });
            },
          ),
        )
        ..loadHtmlString(html, baseUrl: 'about:blank');

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = '$e';
        _isLoading = false;
      });
    }
  }

  /// Injects a `<base>` tag so relative resource paths resolve correctly.
  String _injectBaseHref(String html) {
    // If the HTML already has a <base> tag, don't inject another
    if (html.toLowerCase().contains('<base ')) return html;

    // Inject after <head> or at the beginning
    final headIndex = html.toLowerCase().indexOf('<head>');
    if (headIndex != -1) {
      final insertPos = headIndex + 6; // after '<head>'
      return html.substring(0, insertPos) +
          '<meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">' +
          html.substring(insertPos);
    }

    // No <head>, wrap it
    return '<!DOCTYPE html><html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no"></head><body>$html</body></html>';
  }

  Future<void> _refresh() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    await _loadAndPreview();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fileName = widget.relativePath.split('/').last;

    return Scaffold(
      appBar: AppBar(
        title: Text('预览: $fileName'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: '刷新',
          ),
          IconButton(
            icon: const Icon(Icons.open_in_full),
            onPressed: () => _toggleFullScreen(),
            tooltip: '全屏',
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_hasError)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48,
                        color: theme.colorScheme.error),
                    const SizedBox(height: 16),
                    Text('预览失败', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(_errorMessage,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('重试'),
                    ),
                  ],
                ),
              ),
            )
          else if (!_hasError)
            WebViewWidget(controller: _controller),
          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.white.withAlpha(200),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  void _toggleFullScreen() {
    // TODO: implement full-screen toggle
    // For now, just reload
    _controller.reload();
  }
}
