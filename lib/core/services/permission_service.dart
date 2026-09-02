import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show IconData, Icons;

import 'package:nudgee/core/agent/permission/permission.dart';

/// Manages the agent's permission mode and rules at runtime.
///
/// This is a [ChangeNotifier] so the UI can react to mode changes.
/// The [PermissionContext] returned by [context] uses a live mode getter,
/// so changes take effect immediately for the next tool call.
///
/// Modes:
/// - [PermissionMode.normal]: Ask user for dangerous operations (default)
/// - [PermissionMode.acceptEdits]: Auto-accept file edits, ask for other ops
/// - [PermissionMode.bypassPermissions]: Skip all checks (dangerous)
/// - [PermissionMode.plan]: Read-only, block all mutations
/// - [PermissionMode.dontAsk]: Non-interactive, deny unapproved
class PermissionService extends ChangeNotifier {
  PermissionMode _mode = PermissionMode.normal;

  /// Allow rules — tool calls matching these are auto-approved.
  final List<PermissionRule> _allowRules = [];

  /// Deny rules — tool calls matching these are auto-rejected.
  final List<PermissionRule> _denyRules = [];

  /// Creates a [PermissionService] with the given initial mode.
  PermissionService({PermissionMode initialMode = PermissionMode.normal})
      : _mode = initialMode;

  /// The current permission mode.
  PermissionMode get mode => _mode;

  /// Whether the current mode allows all operations without asking.
  bool get isBypass => _mode == PermissionMode.bypassPermissions;

  /// Whether the current mode is read-only (plan mode).
  bool get isPlanMode => _mode == PermissionMode.plan;

  /// The allow rules.
  List<PermissionRule> get allowRules => List.unmodifiable(_allowRules);

  /// The deny rules.
  List<PermissionRule> get denyRules => List.unmodifiable(_denyRules);

  /// Builds a live [PermissionContext] that reads the current mode.
  PermissionContext get context => PermissionContext(
        modeGetter: () => _mode,
        allowRules: _allowRules,
        denyRules: _denyRules,
      );

  /// Sets the permission mode and notifies listeners.
  void setMode(PermissionMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    debugPrint('[PermissionService] mode changed to: ${mode.name}');
    notifyListeners();
  }

  /// Adds an allow rule for a tool.
  void allow(String toolName) {
    _allowRules.add(PermissionRule(toolName));
    notifyListeners();
  }

  /// Adds a deny rule for a tool.
  void deny(String toolName) {
    _denyRules.add(PermissionRule(toolName));
    notifyListeners();
  }

  /// Removes an allow rule for a tool.
  void removeAllow(String toolName) {
    _allowRules.removeWhere((r) => r.toolName == toolName);
    notifyListeners();
  }

  /// Removes a deny rule for a tool.
  void removeDeny(String toolName) {
    _denyRules.removeWhere((r) => r.toolName == toolName);
    notifyListeners();
  }

  /// Human-readable label for a permission mode.
  static String modeLabel(PermissionMode mode) {
    switch (mode) {
      case PermissionMode.normal:
        return '正常模式';
      case PermissionMode.acceptEdits:
        return '自动接受编辑';
      case PermissionMode.bypassPermissions:
        return '跳过所有检查';
      case PermissionMode.plan:
        return '计划模式 (只读)';
      case PermissionMode.dontAsk:
        return '非交互模式';
    }
  }

  /// Human-readable description for a permission mode.
  static String modeDescription(PermissionMode mode) {
    switch (mode) {
      case PermissionMode.normal:
        return '执行危险操作前询问用户确认';
      case PermissionMode.acceptEdits:
        return '自动接受文件编辑，其他危险操作仍询问';
      case PermissionMode.bypassPermissions:
        return '跳过所有权限检查（危险，不推荐）';
      case PermissionMode.plan:
        return '只读模式，阻止所有修改操作';
      case PermissionMode.dontAsk:
        return '非交互模式，拒绝未预批准的操作';
    }
  }

  /// Icon for a permission mode.
  static IconData modeIcon(PermissionMode mode) {
    switch (mode) {
      case PermissionMode.normal:
        return Icons.shield_outlined;
      case PermissionMode.acceptEdits:
        return Icons.edit_note;
      case PermissionMode.bypassPermissions:
        return Icons.shield_moon;
      case PermissionMode.plan:
        return Icons.visibility_outlined;
      case PermissionMode.dontAsk:
        return Icons.block;
    }
  }
}
