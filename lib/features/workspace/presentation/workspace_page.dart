import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:highlight/languages/javascript.dart';
import 'package:highlight/languages/json.dart';
import 'package:highlight/languages/python.dart';
import 'package:highlight/languages/dart.dart';
import 'package:highlight/languages/xml.dart';
import 'package:highlight/languages/yaml.dart';
import 'package:highlight/languages/markdown.dart';
import 'package:highlight/highlight.dart' show Mode;

import 'package:nudgee/core/agent/tools/builtin/js_executor_tool.dart';
import 'package:nudgee/core/di/injector.dart';
import 'package:nudgee/core/extensions/context_extensions.dart';
import 'package:nudgee/core/services/workspace_service.dart';
import 'package:nudgee/features/workspace/presentation/html_preview_page.dart';

/// 个人空间页面 — 浏览和管理 AI 工作区文件。
///
/// 功能:
/// - 文件/文件夹浏览 (面包屑导航)
/// - 创建文件/文件夹
/// - 查看文件内容 (代码高亮预览)
/// - 编辑文件内容 (代码编辑器 + 行号 + 语法高亮)
/// - 运行 JS 代码 (运行按钮 + 输出面板)
/// - 删除文件/文件夹
/// - 重命名文件
class WorkspacePage extends StatefulWidget {
  const WorkspacePage({super.key});

  @override
  State<WorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends State<WorkspacePage> {
  final _workspace = sl<WorkspaceService>();
  final _currentPath = <String>[];
  List<WorkspaceEntry> _entries = [];
  bool _isLoading = true;
  int _totalFiles = 0;
  int _totalSize = 0;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    setState(() => _isLoading = true);
    try {
      if (!_workspace.isInitialized) {
        await _workspace.init();
      }
      final path = _currentPath.join('/');
      _entries = await _workspace.listDir(path.isEmpty ? '.' : path);

      final all = await _workspace.listDir('.');
      _totalFiles = all.where((e) => !e.isDirectory).length;
      _totalSize = all.where((e) => e.size != null).fold(0, (s, e) => s + e.size!);
    } catch (e) {
      debugPrint('[WorkspacePage] load error: $e');
    }
    setState(() => _isLoading = false);
  }

  void _enterDir(WorkspaceEntry entry) {
    _currentPath.add(entry.name);
    _loadEntries();
  }

  void _goToPath(int index) {
    _currentPath.removeRange(index + 1, _currentPath.length);
    if (index < 0) _currentPath.clear();
    _loadEntries();
  }

  void _goToRoot() {
    _currentPath.clear();
    _loadEntries();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('个人空间'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEntries,
            tooltip: '刷新',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'new_file':
                  _showCreateDialog(isDir: false);
                  break;
                case 'new_dir':
                  _showCreateDialog(isDir: true);
                  break;
                case 'clear':
                  _showClearDialog();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'new_file', child: Text('新建文件')),
              const PopupMenuItem(value: 'new_dir', child: Text('新建文件夹')),
              PopupMenuItem(
                value: 'clear',
                child: Text('清空空间',
                    style: TextStyle(color: theme.colorScheme.error)),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: theme.colorScheme.surfaceContainerHighest.withAlpha(60),
            child: Row(
              children: [
                Icon(Icons.folder_outlined,
                    size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('$_totalFiles 个文件', style: theme.textTheme.bodySmall),
                const SizedBox(width: 16),
                Icon(Icons.storage_outlined,
                    size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(_formatSize(_totalSize), style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          // Breadcrumb
          if (_currentPath.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    TextButton(
                      onPressed: _goToRoot,
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('根目录'),
                    ),
                    for (var i = 0; i < _currentPath.length; i++) ...[
                      Icon(Icons.chevron_right,
                          size: 16, color: theme.colorScheme.onSurfaceVariant),
                      TextButton(
                        onPressed: () => _goToPath(i),
                        style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(_currentPath[i]),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          // File list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _entries.isEmpty
                    ? _buildEmpty(theme)
                    : ListView.builder(
                        itemCount: _entries.length,
                        itemBuilder: (context, index) {
                          final entry = _entries[index];
                          return _buildEntryTile(theme, entry);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 64,
              color: theme.colorScheme.onSurfaceVariant.withAlpha(80)),
          const SizedBox(height: 16),
          Text('空间是空的',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )),
          const SizedBox(height: 8),
          Text('AI 助手会在这里创建文件',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withAlpha(120),
              )),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _showCreateDialog(isDir: false),
            icon: const Icon(Icons.add),
            label: const Text('新建文件'),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryTile(ThemeData theme, WorkspaceEntry entry) {
    final isCode = _isCodeFile(entry.name);
    final isJs = entry.name.toLowerCase().endsWith('.js');
    final isHtml = entry.name.toLowerCase().endsWith('.html') ||
        entry.name.toLowerCase().endsWith('.htm');
    return ListTile(
      leading: Icon(
        entry.isDirectory ? Icons.folder : (isCode ? Icons.code : Icons.description),
        color: entry.isDirectory ? Colors.amber.shade700 : theme.colorScheme.primary,
      ),
      title: Text(entry.name),
      subtitle: entry.isDirectory
          ? null
          : Text(_formatSize(entry.size ?? 0), style: theme.textTheme.bodySmall),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isHtml && !entry.isDirectory)
            IconButton(
              icon: const Icon(Icons.preview, size: 20),
              tooltip: '预览',
              onPressed: () => _previewHtml(entry),
            ),
          if (isJs && !entry.isDirectory)
            IconButton(
              icon: const Icon(Icons.play_arrow, size: 22),
              tooltip: '运行',
              onPressed: () => _runJsFile(entry),
            ),
          if (!entry.isDirectory)
            IconButton(
              icon: const Icon(Icons.visibility_outlined, size: 20),
              tooltip: '查看',
              onPressed: () => _showFileViewer(entry),
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'view':
                  _showFileViewer(entry);
                  break;
                case 'edit':
                  _showFileEditor(entry);
                  break;
                case 'run':
                  _runJsFile(entry);
                  break;
                case 'preview':
                  _previewHtml(entry);
                  break;
                case 'rename':
                  _showRenameDialog(entry);
                  break;
                case 'delete':
                  _showDeleteDialog(entry);
                  break;
              }
            },
            itemBuilder: (context) => [
              if (!entry.isDirectory)
                const PopupMenuItem(value: 'view', child: Text('查看')),
              if (!entry.isDirectory)
                const PopupMenuItem(value: 'edit', child: Text('编辑')),
              if (isJs && !entry.isDirectory)
                const PopupMenuItem(value: 'run', child: Text('运行')),
              if (isHtml && !entry.isDirectory)
                const PopupMenuItem(value: 'preview', child: Text('预览')),
              const PopupMenuItem(value: 'rename', child: Text('重命名')),
              PopupMenuItem(
                value: 'delete',
                child: Text('删除', style: TextStyle(color: theme.colorScheme.error)),
              ),
            ],
          ),
        ],
      ),
      onTap: entry.isDirectory
          ? () => _enterDir(entry)
          : isHtml
              ? () => _previewHtml(entry)
              : () => _showFileViewer(entry),
    );
  }

  void _previewHtml(WorkspaceEntry entry) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HtmlPreviewPage(relativePath: entry.relativePath),
      ),
    );
  }

  // ── Run JS ─────────────────────────────────────────────────────────

  void _runJsFile(WorkspaceEntry entry) async {
    final content = await _workspace.readFile(entry.relativePath);
    if (!mounted || content == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _JsRunPage(
          name: entry.name,
          code: content,
        ),
      ),
    );
  }

  // ── Dialogs ────────────────────────────────────────────────────────

  void _showCreateDialog({required bool isDir}) {
    final controller = TextEditingController();
    SmartDialog.show(
      clickMaskDismiss: true,
      builder: (dialogContext) => AlertDialog(
        title: Text(isDir ? '新建文件夹' : '新建文件'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: isDir ? '文件夹名称' : '文件名 (如 hello.js)',
            hintText: isDir ? 'my-folder' : 'hello.js',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => SmartDialog.dismiss(),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              final path = _currentPath.isEmpty
                  ? name
                  : '${_currentPath.join('/')}/$name';
              try {
                if (isDir) {
                  await _workspace.createDir(path);
                } else {
                  await _workspace.writeFile(path, '');
                }
                SmartDialog.dismiss();
                _loadEntries();
              } catch (e) {
                SmartDialog.showToast('创建失败: $e');
              }
            },
            child: Text(context.l10n.confirm),
          ),
        ],
      ),
    );
  }

  void _showFileViewer(WorkspaceEntry entry) async {
    final content = await _workspace.readFile(entry.relativePath);
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FileViewerPage(
          name: entry.name,
          content: content ?? '(文件为空)',
          isCode: _isCodeFile(entry.name),
        ),
      ),
    );
  }

  void _showFileEditor(WorkspaceEntry entry) async {
    final content = await _workspace.readFile(entry.relativePath);
    if (!mounted) return;
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => _FileEditorPage(
          name: entry.name,
          initialContent: content ?? '',
        ),
      ),
    );
    if (result != null) {
      await _workspace.writeFile(entry.relativePath, result);
      _loadEntries();
    }
  }

  void _showRenameDialog(WorkspaceEntry entry) {
    final controller = TextEditingController(text: entry.name);
    SmartDialog.show(
      clickMaskDismiss: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('重命名'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '新名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => SmartDialog.dismiss(),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty || newName == entry.name) {
                SmartDialog.dismiss();
                return;
              }
              final parentPath = _currentPath.join('/');
              final newPath =
                  parentPath.isEmpty ? newName : '$parentPath/$newName';
              try {
                final content = await _workspace.readFile(entry.relativePath);
                await _workspace.delete(entry.relativePath);
                await _workspace.writeFile(newPath, content ?? '');
                SmartDialog.dismiss();
                _loadEntries();
              } catch (e) {
                SmartDialog.showToast('重命名失败: $e');
              }
            },
            child: Text(context.l10n.confirm),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(WorkspaceEntry entry) {
    SmartDialog.show(
      clickMaskDismiss: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除 "${entry.name}" 吗?'
            '${entry.isDirectory ? "\n\n文件夹内所有内容将被删除。" : ""}'),
        actions: [
          TextButton(
            onPressed: () => SmartDialog.dismiss(),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () async {
              try {
                await _workspace.delete(entry.relativePath);
                SmartDialog.dismiss();
                _loadEntries();
              } catch (e) {
                SmartDialog.showToast('删除失败: $e');
              }
            },
            child: Text(context.l10n.confirm),
          ),
        ],
      ),
    );
  }

  void _showClearDialog() {
    SmartDialog.show(
      clickMaskDismiss: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空空间'),
        content: const Text('确定要清空所有文件吗? 此操作不可恢复!'),
        actions: [
          TextButton(
            onPressed: () => SmartDialog.dismiss(),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () async {
              try {
                await _workspace.clear();
                SmartDialog.dismiss();
                _goToRoot();
              } catch (e) {
                SmartDialog.showToast('清空失败: $e');
              }
            },
            child: Text(context.l10n.confirm),
          ),
        ],
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────

  bool _isCodeFile(String name) {
    final ext = name.split('.').last.toLowerCase();
    return ['js', 'ts', 'dart', 'py', 'json', 'html', 'css', 'xml', 'yaml', 'yml', 'md']
        .contains(ext);
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

// ── Language helper ─────────────────────────────────────────────────────

/// Returns the highlight.js language mode for a file extension.
Mode? _languageForFile(String name) {
  final ext = name.split('.').last.toLowerCase();
  switch (ext) {
    case 'js':
    case 'ts':
    case 'jsx':
      return javascript;
    case 'json':
      return json;
    case 'py':
      return python;
    case 'dart':
      return dart;
    case 'html':
    case 'htm':
    case 'xml':
    case 'svg':
      return xml;
    case 'yaml':
    case 'yml':
      return yaml;
    case 'md':
    case 'markdown':
      return markdown;
    default:
      return null;
  }
}

// ── File Viewer (read-only with syntax highlighting) ────────────────────

class _FileViewerPage extends StatefulWidget {
  final String name;
  final String content;
  final bool isCode;

  const _FileViewerPage({
    required this.name,
    required this.content,
    required this.isCode,
  });

  @override
  State<_FileViewerPage> createState() => _FileViewerPageState();
}

class _FileViewerPageState extends State<_FileViewerPage> {
  late final CodeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CodeController(
      text: widget.content,
      language: _languageForFile(widget.name),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: CodeTheme(
        data: CodeThemeData(
          styles: isDark ? monokaiSublimeTheme : monokaiSublimeTheme,
        ),
        child: SingleChildScrollView(
          child: CodeField(
            controller: _controller,
            readOnly: true,
            textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            gutterStyle: GutterStyle(
              showErrors: false,
              showFoldingHandles: false,
              showLineNumbers: widget.isCode,
            ),
          ),
        ),
      ),
    );
  }
}

// ── File Editor (editable with syntax highlighting + run button) ────────

class _FileEditorPage extends StatefulWidget {
  final String name;
  final String initialContent;

  const _FileEditorPage({
    required this.name,
    required this.initialContent,
  });

  @override
  State<_FileEditorPage> createState() => _FileEditorPageState();
}

class _FileEditorPageState extends State<_FileEditorPage> {
  late final CodeController _controller;
  bool _isRunning = false;
  String _output = '';
  bool _outputIsError = false;

  @override
  void initState() {
    super.initState();
    _controller = CodeController(
      text: widget.initialContent,
      language: _languageForFile(widget.name),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isJs => widget.name.toLowerCase().endsWith('.js');

  Future<void> _runCode() async {
    setState(() {
      _isRunning = true;
      _output = '';
      _outputIsError = false;
    });

    try {
      final tool = JsExecutorTool();
      final result = await tool.execute({'code': _controller.fullText});
      tool.dispose();

      setState(() {
        _output = result.success
            ? result.output
            : (result.error ?? 'Unknown error');
        _outputIsError = !result.success;
      });
    } catch (e) {
      setState(() {
        _output = '运行失败: $e';
        _outputIsError = true;
      });
    }

    setState(() => _isRunning = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('编辑: ${widget.name}'),
        actions: [
          if (_isJs)
            IconButton(
              icon: _isRunning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow),
              onPressed: _isRunning ? null : _runCode,
              tooltip: '运行',
            ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () => Navigator.of(context).pop(_controller.fullText),
            tooltip: '保存',
          ),
        ],
      ),
      body: Column(
        children: [
          // Code editor
          Expanded(
            flex: _output.isNotEmpty ? 3 : 1,
            child: CodeTheme(
              data: CodeThemeData(styles: monokaiSublimeTheme),
              child: SingleChildScrollView(
                child: CodeField(
                  controller: _controller,
                  textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  gutterStyle: const GutterStyle(
                    showErrors: false,
                    showFoldingHandles: false,
                    showLineNumbers: true,
                  ),
                ),
              ),
            ),
          ),
          // Output panel
          if (_output.isNotEmpty || _isRunning)
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outlineVariant,
                    width: 1,
                  ),
                ),
                color: _outputIsError
                    ? theme.colorScheme.errorContainer.withAlpha(40)
                    : theme.colorScheme.surfaceContainerHighest.withAlpha(60),
              ),
              child: Column(
                children: [
                  // Output header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _outputIsError ? Icons.error_outline : Icons.terminal,
                          size: 16,
                          color: _outputIsError
                              ? theme.colorScheme.error
                              : theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _outputIsError ? '错误输出' : '运行结果',
                          style: theme.textTheme.labelMedium,
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () => setState(() {
                            _output = '';
                            _outputIsError = false;
                          }),
                          tooltip: '关闭',
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                  // Output content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(
                        _isRunning ? '运行中...' : _output,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          height: 1.4,
                          color: _outputIsError
                              ? theme.colorScheme.onErrorContainer
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── JS Run Page (run a .js file with output) ────────────────────────────

class _JsRunPage extends StatefulWidget {
  final String name;
  final String code;

  const _JsRunPage({required this.name, required this.code});

  @override
  State<_JsRunPage> createState() => _JsRunPageState();
}

class _JsRunPageState extends State<_JsRunPage> {
  bool _isRunning = true;
  String _output = '';
  bool _outputIsError = false;

  @override
  void initState() {
    super.initState();
    _runCode();
  }

  Future<void> _runCode() async {
    setState(() {
      _isRunning = true;
      _output = '';
      _outputIsError = false;
    });

    try {
      final tool = JsExecutorTool();
      final result = await tool.execute({'code': widget.code});
      tool.dispose();

      setState(() {
        _output =
            result.success ? result.output : (result.error ?? 'Unknown error');
        _outputIsError = !result.success;
      });
    } catch (e) {
      setState(() {
        _output = '运行失败: $e';
        _outputIsError = true;
      });
    }

    setState(() => _isRunning = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('运行: ${widget.name}'),
        actions: [
          IconButton(
            icon: _isRunning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isRunning ? null : _runCode,
            tooltip: '重新运行',
          ),
        ],
      ),
      body: Container(
        color: _outputIsError
            ? theme.colorScheme.errorContainer.withAlpha(30)
            : theme.colorScheme.surfaceContainerHighest.withAlpha(40),
        child: _isRunning
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _outputIsError ? Icons.error_outline : Icons.check_circle,
                          color: _outputIsError
                              ? theme.colorScheme.error
                              : Colors.green,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _outputIsError ? '执行出错' : '执行完成',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: _outputIsError
                                ? theme.colorScheme.error
                                : Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: SelectableText(
                        _output,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
