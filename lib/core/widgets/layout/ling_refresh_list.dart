import 'package:flutter/material.dart';

/// A scrollable list with pull-to-refresh and optional load-more.
///
/// Wraps [RefreshIndicator] + [ListView] with a standardized
/// refresh indicator and load-more footer.
class LingRefreshList<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Future<void> Function() onRefresh;
  final Future<void> Function()? onLoadMore;
  final bool hasMore;
  final Widget? header;
  final EdgeInsets? padding;
  final ScrollController? controller;
  final bool reverse;

  const LingRefreshList({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.onRefresh,
    this.onLoadMore,
    this.hasMore = false,
    this.header,
    this.padding,
    this.controller,
    this.reverse = false,
  });

  @override
  State<LingRefreshList<T>> createState() => _LingRefreshListState<T>();
}

class _LingRefreshListState<T> extends State<LingRefreshList<T>> {
  final _scrollController = ScrollController();
  bool _isLoadingMore = false;

  ScrollController get _effectiveController =>
      widget.controller ?? _scrollController;

  @override
  void initState() {
    super.initState();
    _effectiveController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (widget.onLoadMore == null || widget.hasMore == false || _isLoadingMore) return;

    if (_effectiveController.position.pixels >=
        _effectiveController.position.maxScrollExtent - 100) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    try {
      await widget.onLoadMore!();
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView.builder(
        controller: _effectiveController,
        reverse: widget.reverse,
        padding: widget.padding,
        itemCount: widget.items.length + (widget.header != null ? 1 : 0) + 1,
        itemBuilder: (context, index) {
          // Header
          if (widget.header != null && index == 0) {
            return widget.header!;
          }
          final itemIndex = widget.header != null ? index - 1 : index;

          // Footer (load more indicator)
          if (itemIndex >= widget.items.length) {
            return _buildFooter(theme);
          }

          return widget.itemBuilder(context, widget.items[itemIndex], itemIndex);
        },
      ),
    );
  }

  Widget _buildFooter(ThemeData theme) {
    if (!widget.hasMore && widget.items.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            '没有更多了',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    if (_isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
