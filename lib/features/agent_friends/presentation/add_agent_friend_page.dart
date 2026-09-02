import 'package:flutter/material.dart';

import 'package:nudgee/core/di/injector.dart';
import 'package:nudgee/core/extensions/context_extensions.dart';
import 'package:nudgee/core/services/agent_friend_service.dart';
import 'package:nudgee/features/common/widgets/page_scaffold.dart';

/// 添加 Agent 好友页面。
///
/// 用户可以自定义 Agent 的名称、图标、简介、系统提示词和工具集。
class AddAgentFriendPage extends StatefulWidget {
  const AddAgentFriendPage({super.key});

  @override
  State<AddAgentFriendPage> createState() => _AddAgentFriendPageState();
}

class _AddAgentFriendPageState extends State<AddAgentFriendPage> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _promptController = TextEditingController();
  final _welcomeController = TextEditingController();
  String _selectedIcon = '🤖';
  final Set<String> _selectedTools = {};

  // 可选工具列表 (name → description)
  static const _allTools = <String, String>{
    'schedule.add': '添加日程',
    'schedule.query': '查询日程',
    'schedule.remove': '删除日程',
    'notification.schedule': '定时提醒',
    'memory.save': '保存记忆',
    'memory.query': '查询记忆',
    'user.profile': '用户画像',
    'web.search': '网络搜索',
    'web.news': '实时新闻',
    'web.weather': '天气查询',
    'web.stock': '股价查询',
    'github.search': 'GitHub 搜索',
    'workspace.js.exec': 'JS 执行',
    'workspace.fs': '文件读写',
    'cloud.exec': '云端沙箱',
    'datetime': '日期时间',
    'tool.search': '工具搜索',
    'ask_user': '向用户提问',
    'todo.write': '待办清单',
  };

  // 可选图标
  static const _icons = [
    '🤖', '🎯', '💪', '📚', '🧠', '🎨', '🎵', '🍳',
    '💰', '✈️', '🏥', '⚖️', '🔬', '📝', '🌱', '⭐',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _promptController.dispose();
    _welcomeController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError('请输入 Agent 名称');
      return;
    }
    if (_promptController.text.trim().isEmpty) {
      _showError('请输入系统提示词');
      return;
    }

    final service = sl<AgentFriendService>();
    await service.createFriend(
      name: name,
      icon: _selectedIcon,
      description: _descController.text.trim().isEmpty
          ? '自定义 Agent'
          : _descController.text.trim(),
      systemPrompt: _promptController.text.trim(),
      toolNames: _selectedTools.toList(),
      welcomeMessage: _welcomeController.text.trim().isEmpty
          ? null
          : _welcomeController.text.trim(),
    );

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PageScaffold(
      title: const Text('添加 Agent 好友'),
      leading: getPopLeading(context),
      customActions: [
        TextButton(
          onPressed: _create,
          child: Text(
            context.l10n.save,
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── 图标选择 ──────────────────────────────────────────────────
          Text('选择图标', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _icons.map((icon) {
              final selected = icon == _selectedIcon;
              return GestureDetector(
                onTap: () => setState(() => _selectedIcon = icon),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: selected
                        ? theme.colorScheme.primary.withAlpha(30)
                        : theme.colorScheme.surfaceContainerHighest
                            .withAlpha(100),
                    borderRadius: BorderRadius.circular(12),
                    border: selected
                        ? Border.all(
                            color: theme.colorScheme.primary, width: 2)
                        : null,
                  ),
                  child: Center(
                    child: Text(icon, style: const TextStyle(fontSize: 24)),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // ── 名称 ──────────────────────────────────────────────────────
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '名称 *',
              hintText: '如：秋招助手、健身教练',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.label_outline),
            ),
          ),
          const SizedBox(height: 16),

          // ── 简介 ──────────────────────────────────────────────────────
          TextField(
            controller: _descController,
            decoration: const InputDecoration(
              labelText: '简介',
              hintText: '一句话描述这个 Agent 的用途',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.description_outlined),
            ),
          ),
          const SizedBox(height: 16),

          // ── 系统提示词 ────────────────────────────────────────────────
          TextField(
            controller: _promptController,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: '系统提示词 *',
              hintText: '定义 Agent 的人设、职责和行为规则。\n'
                  '例如：你是一位秋招助手，负责追踪投递进度、提醒面试...',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.smart_toy_outlined),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),

          // ── 欢迎消息 ──────────────────────────────────────────────────
          TextField(
            controller: _welcomeController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '欢迎消息（可选）',
              hintText: '用户打开对话时 Agent 发送的第一条消息',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.waving_hand_outlined),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 24),

          // ── 工具选择 ──────────────────────────────────────────────────
          Text('选择工具', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            'Agent 可以使用选中的工具来帮助你',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.hintColor,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _allTools.entries.map((entry) {
              final selected = _selectedTools.contains(entry.key);
              return FilterChip(
                label: Text('${entry.key.split('.').last} · ${entry.value}'),
                selected: selected,
                onSelected: (value) {
                  setState(() {
                    if (value) {
                      _selectedTools.add(entry.key);
                    } else {
                      _selectedTools.remove(entry.key);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
