import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// A full-screen WebView container page for opening external links.
///
/// Usage:
/// ```dart
/// Navigator.push(context, MaterialPageRoute(
///   builder: (_) => LingWebViewPage(url: 'https://example.com'),
/// ));
/// ```
class LingWebViewPage extends StatefulWidget {
  final String url;
  final String? title;

  const LingWebViewPage({
    super.key,
    required this.url,
    this.title,
  });

  @override
  State<LingWebViewPage> createState() => _LingWebViewPageState();
}

class _LingWebViewPageState extends State<LingWebViewPage> {
  late final WebViewController _controller;
  String _title = '';
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _title = widget.title ?? '';
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) async {
            if (mounted) {
              setState(() => _isLoading = false);
              final t = await _controller.getTitle();
              if (mounted && (t?.isNotEmpty ?? false)) {
                setState(() => _title = t!);
              }
            }
          },
          onWebResourceError: (e) {
            if (mounted) setState(() => _hasError = true);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _title.isNotEmpty ? _title : widget.url,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.reload(),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            onPressed: () {
              // 在实际应用中会用 url_launcher 打开系统浏览器
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('在浏览器中打开: ${widget.url}')),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          if (!_hasError)
            WebViewWidget(controller: _controller)
          else
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 8),
                  Text('加载失败: ${widget.url}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() => _hasError = false);
                      _controller.reload();
                    },
                    child: const Text('重试'),
                  ),
                ],
              ),
            ),
          if (_isLoading && !_hasError)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
