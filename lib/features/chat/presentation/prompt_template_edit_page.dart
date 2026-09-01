import 'package:flutter/material.dart';

import 'package:nudgee/core/di/injector.dart';
import 'package:nudgee/core/models/prompt_template.dart';
import 'package:nudgee/core/services/prompt_template_service.dart';
import 'package:nudgee/features/common/widgets/page_scaffold.dart';

/// 模板创建/编辑页面。
///
/// 编辑模式传入 [template]，新建模式不传。
class PromptTemplateEditPage extends StatefulWidget {
  final PromptTemplate? template;

  const PromptTemplateEditPage({super.key, this.template});

  @override
  State<PromptTemplateEditPage> createState() => _PromptTemplateEditPageState();
}

class _PromptTemplateEditPageState extends State<PromptTemplateEditPage> {
  final _nameController = TextEditingController();
  final _iconController = TextEditingController();
  final _descController = TextEditingController();
  final _promptController = TextEditingController();
  final _categoryController = TextEditingController();

  static const List<String> _presetIcons = ['📝', '💰', '💻', '🌐', '📅', '✍️', '📚', '🫂', '💡', '🎯', '🔬', '🎨', '🎵', '🏋️', '🧘'];
  static const List<String> _presetCategories = ['生活助手', '学习提升', '效率工具', '自定义'];

  bool get _isEditing => widget.template != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final t = widget.template!;
      _nameController.text = t.name;
      _iconController.text = t.icon;
      _descController.text = t.description;
      _promptController.text = t.systemPrompt;
      _categoryController.text = t.category;
    } else {
      _iconController.text = '📝';
      _categoryController.text = '自定义';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _iconController.dispose();
    _descController.dispose();
    _promptController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final prompt = _promptController.text.trim();
    if (name.isEmpty) {
      _showError('请输入模板名称');
      return;
    }
    if (prompt.isEmpty) {
      _showError('请输入提示词内容');
      return;
    }

    final service = sl<PromptTemplateService>();
    final now = DateTime.now();

    if (_isEditing) {
      final updated = widget.template!.copyWith(
        name: name,
        icon: _iconController.text.trim().isEmpty ? '📝' : _iconController.text.trim(),
        description: _descController.text.trim().isEmpty ? '自定义模板' : _descController.text.trim(),
        systemPrompt: prompt,
        category: _categoryController.text.trim().isEmpty ? '自定义' : _categoryController.text.trim(),
        updatedAt: now,
      );
      await service.updateTemplate(updated);
    } else {
      final template = PromptTemplate(
        id: 'custom_${now.millisecondsSinceEpoch}',
        name: name,
        icon: _iconController.text.trim().isEmpty ? '📝' : _iconController.text.trim(),
        description: _descController.text.trim().isEmpty ? '自定义模板' : _descController.text.trim(),
        systemPrompt: prompt,
        category: _categoryController.text.trim().isEmpty ? '自定义' : _categoryController.text.trim(),
        isBuiltIn: false,
        createdAt: now,
      );
      await service.addTemplate(template);
    }

    if (mounted) Navigator.of(context).pop();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// 从 prompt 文本中提取变量预览。
  List<String> get _variables {
    final regex = RegExp(r'\{\{(\w+)\}\}');
    return regex.allMatches(_promptController.text).map((m) => m.group(1)!).toSet().toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PageScaffold(
      title: Text(_isEditing ? '编辑模板' : '新建模板'),
      customActions: [
        TextButton(
          onPressed: _save,
          child: Text(_isEditing ? '保存' : '创建',
              style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
        ),
      ],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icon picker
            Text('图标', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presetIcons.map((emoji) {
                final selected = _iconController.text == emoji;
                return GestureDetector(
                  onTap: () => setState(() => _iconController.text = emoji),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest,
                      border: selected ? Border.all(color: theme.colorScheme.primary, width: 2) : null,
                    ),
                    child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Name
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '模板名称',
                hintText: '如：理财专家',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Category
            DropdownMenu<String>(
              controller: _categoryController,
              label: const Text('分类'),
              width: double.infinity,
              initialSelection: _categoryController.text,
              onSelected: (v) => _categoryController.text = v ?? '自定义',
              dropdownMenuEntries: _presetCategories
                  .map((c) => DropdownMenuEntry(value: c, label: c))
                  .toList(),
            ),
            const SizedBox(height: 16),

            // Description
            TextField(
              controller: _descController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '描述',
                hintText: '简要描述模板用途',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // System prompt
            TextField(
              controller: _promptController,
              maxLines: 8,
              decoration: InputDecoration(
                labelText: '提示词 (System Prompt)',
                hintText: '输入提示词内容，可用 {{变量名}} 添加变量',
                border: const OutlineInputBorder(),
                helperText: '变量用 {{变量名}} 格式，如 {{语言}}、{{主题}}',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),

            // Variables preview
            if (_variables.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('检测到变量：', style: TextStyle(fontSize: 13, color: theme.colorScheme.onSecondaryContainer, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: _variables.map((v) => Chip(
                        label: Text('{{$v}}', style: const TextStyle(fontSize: 12)),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      )).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Preview filled prompt (if no variables)
            if (_variables.isEmpty && _promptController.text.isNotEmpty) ...[
              Text('预览', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_promptController.text, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
