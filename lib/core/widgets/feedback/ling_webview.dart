import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:nudgee/core/widgets/feedback/ling_error_view.dart';
import 'package:nudgee/core/widgets/feedback/ling_loading_indicator.dart';
import 'package:nudgee/core/errors/app_exception.dart';

/// A named JavaScript bridge channel for [LingWebView].
///
/// Each channel registers a global JS function `window.<name>` that the page
/// can call to send a message back to Flutter.
class JsChannel {
  /// Name of the channel — becomes the JS function name on `window`.
  final String name;

  /// Callback invoked when the page posts a message on this channel.
  final void Function(JavaScriptMessage) onMessage;

  const JsChannel({
    required this.name,
    required this.onMessage,
  });
}

/// A self-contained WebView page with an optional app bar, loading progress
/// bar, error view and JS bridge support.
///
/// Wraps `webview_flutter` so the rest of the app can embed web content with
/// a consistent Ling UI chrome.
class LingWebView extends StatefulWidget {
  /// The URL to load.
  final String url;

  /// Title shown in the app bar. Ignored when [showAppBar] is `false`.
  final String? title;

  /// Whether to show the navigation app bar. Defaults to `true`.
  final bool showAppBar;

  /// Extra HTTP headers sent with the initial request.
  final Map<String, String>? headers;

  /// Called once the [WebViewController] is ready, so callers can drive the
  /// WebView programmatically (reload, go back, run JS, …).
  final void Function(WebViewController)? onControllerReady;

  /// JavaScript bridge channels to register on the page.
  final List<JsChannel> jsChannels;

  const LingWebView({
    super.key,
    required this.url,
    this.title,
    this.showAppBar = true,
    this.headers,
    this.onControllerReady,
    this.jsChannels = const [],
  });

  @override
  State<LingWebView> createState() => _LingWebViewState();
}

class _LingWebViewState extends State<LingWebView> {
  late final WebViewController _controller;
  final ValueNotifier<int> _progressNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> _loadingNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<bool> _hasErrorNotifier = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _setupController();
  }

  void _setupController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            _progressNotifier.value = progress;
          },
          onPageStarted: (_) {
            _loadingNotifier.value = true;
            _hasErrorNotifier.value = false;
          },
          onPageFinished: (_) {
            _loadingNotifier.value = false;
          },
          onWebResourceError: (error) {
            _hasErrorNotifier.value = true;
            _loadingNotifier.value = false;
          },
        ),
      );

    // Register JS bridge channels.
    for (final channel in widget.jsChannels) {
      _controller.addJavaScriptChannel(
        channel.name,
        onMessageReceived: channel.onMessage,
      );
    }

    // Kick off the initial load.
    _controller.loadRequest(
      Uri.parse(widget.url),
      headers: widget.headers ?? const {},
    );

    widget.onControllerReady?.call(_controller);
  }

  @override
  void dispose() {
    _progressNotifier.dispose();
    _loadingNotifier.dispose();
    _hasErrorNotifier.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    _hasErrorNotifier.value = false;
    _loadingNotifier.value = true;
    await _controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: Text(widget.title ?? widget.url),
              leading: widget.showAppBar
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).maybePop(),
                    )
                  : null,
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _reload,
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: ValueListenableBuilder<int>(
                  valueListenable: _progressNotifier,
                  builder: (_, progress, __) {
                    if (progress >= 100) return const SizedBox.shrink();
                    return LinearProgressIndicator(
                      value: progress / 100,
                      minHeight: 3,
                      color: theme.colorScheme.primary,
                    );
                  },
                ),
              ),
            )
          : null,
      body: ValueListenableBuilder<bool>(
        valueListenable: _hasErrorNotifier,
        builder: (_, hasError, __) {
          if (hasError) {
            return LingErrorView(
              error: const NetworkException('Failed to load page'),
              onRetry: _reload,
            );
          }
          return Stack(
            children: [
              WebViewWidget(controller: _controller),
              ValueListenableBuilder<bool>(
                valueListenable: _loadingNotifier,
                builder: (_, loading, __) {
                  if (!loading) return const SizedBox.shrink();
                  return const LingLoadingIndicator(message: 'Loading…');
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
