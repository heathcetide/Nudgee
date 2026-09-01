import 'package:flutter/material.dart';

import 'package:nudgee/core/di/injector.dart';
import 'package:nudgee/core/models/prompt_template.dart';
import 'package:nudgee/core/services/prompt_template_service.dart';
import 'package:nudgee/features/common/widgets/page_scaffold.dart';
import 'prompt_template_edit_page.dart';

/// 模板选择页面 — 列表 + 分类 + 搜索 + 创建。
///
/// 选择模板后返回 (PromptTemplate, filledSystemPrompt)。
/// 如果模板有变量，会先弹出变量填充对话框。
class PromptTemplatePage extends StatefulWidget {
  const PromptTemplatePage({super.key});

  @override
  State<PromptTemplatePage> createState() => _PromptTemplatePageState();
}

class _PromptTemplatePageState extends State<PromptTemplatePage> {
  String _searchQuery = '';
  String? _selectedCategory;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    final service = sl<PromptTemplateService>();
    if (!_isListening) {
      _isListening = true;
      service.addListener(_onChanged);
    }
    service.init();
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    sl<PromptTemplateService>().removeListener(_onChanged);
    super.dispose();
  }

  List<PromptTemplate> get _filtered {
    final service = sl<PromptTemplateService>();
    var list = service.templates;
    if (_selectedCategory != null) {
      list = list.where((t) => t.category == _selectedCategory).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((t) =>
          t.name.toLowerCase().contains(q) ||
          t.description.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  Future<void> _onSelectTemplate(PromptTemplate template) async {
    // If template has variables, show fill dialog.
    String filledPrompt = template.systemPrompt;
    if (template.hasVariables) {
      final values = await _showVariableDialog(template);
      if (values == null) return; // User cancelled.
      filledPrompt = template.fillVariables(values);
    }

    if (mounted) {
      Navigator.of(context).pop((template, filledPrompt));
    }
  }

  Future<Map<String, String>?> _showVariableDialog(PromptTemplate template) {
    final controllers = <String, TextEditingController>{};
    for (final v in template.variables) {
      controllers[v] = TextEditingController();
    }

    return showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${template.icon} 填写模板变量'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final v in template.variables) ...[
                TextField(
                  controller: controllers[v],
                  decoration: InputDecoration(
                    labelText: v,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final values = <String, String>{};
              for (final entry in controllers.entries) {
                values[entry.key] = entry.value.text.trim().isEmpty
                    ? '默认'
                    : entry.value.text.trim();
              }
              Navigator.of(ctx).pop(values);
            },
            child: const Text('应用'),
          ),
        ],
      ),
    );
  }

  void _onEditTemplate(PromptTemplate template) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PromptTemplateEditPage(template: template),
      ),
    );
  }

  void _onCreateTemplate() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const PromptTemplateEditPage(),
      ),
    );
  }

  Future<void> _onDeleteTemplate(PromptTemplate template) async {
    if (template.isBuiltIn) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除模板'),
        content: Text('确定删除「${template.name}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await sl<PromptTemplateService>().removeTemplate(template.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = sl<PromptTemplateService>();
    final categories = service.categories;

    return PageScaffold(
      title: const Text('提示词模板'),
      customActions: [
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: _onCreateTemplate,
        ),
      ],
      child: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: '搜索模板...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          // Category chips
          if (categories.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _categoryChip('全部', null, theme),
                  for (final cat in categories)
                    _categoryChip(cat, cat, theme),
                ],
              ),
            ),
          const SizedBox(height: 4),
          // Template list
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.dashboard_outlined, size: 56,
                            color: theme.colorScheme.onSurfaceVariant.withAlpha(60)),
                        const SizedBox(height: 12),
                        Text('没有找到模板', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final t = _filtered[index];
                      return _templateCard(t, theme);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _categoryChip(String label, String? value, ThemeData theme) {
    final selected = _selectedCategory == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _selectedCategory = value),
        selectedColor: theme.colorScheme.primaryContainer,
      ),
    );
  }

  Widget _templateCard(PromptTemplate t, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(t.icon, style: const TextStyle(fontSize: 22)),
        ),
        title: Row(
          children: [
            Text(t.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (t.hasVariables) ...[
              const SizedBox(width: 6),
              Icon(Icons.edit_note, size: 16, color: theme.colorScheme.onSurfaceVariant),
            ],
            if (t.isBuiltIn) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('内置', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSecondaryContainer)),
              ),
            ],
          ],
        ),
        subtitle: Text(
          t.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) {
            if (action == 'edit') _onEditTemplate(t);
            if (action == 'delete') _onDeleteTemplate(t);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('编辑')),
            if (!t.isBuiltIn)
              const PopupMenuItem(value: 'delete', child: Text('删除')),
          ],
        ),
        onTap: () => _onSelectTemplate(t),
      ),
    );
  }
}
