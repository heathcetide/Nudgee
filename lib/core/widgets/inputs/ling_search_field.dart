import 'package:flutter/material.dart';

/// A search field with a search icon and optional clear button.
///
/// 使用简洁的 TextField 样式，无阴影，与聊天列表搜索框风格一致。
class LingSearchField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final bool autofocus;

  const LingSearchField({
    super.key,
    this.controller,
    this.hint = '搜索',
    this.onChanged,
    this.onTap,
    this.focusNode,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      onTap: onTap,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: (controller?.text.isNotEmpty ?? false)
            ? GestureDetector(
                onTap: () {
                  controller?.clear();
                  onChanged?.call('');
                },
                child: const Icon(Icons.clear, size: 18),
              )
            : null,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
