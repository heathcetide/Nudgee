/// Permission mode — controls how the Agent handles tool authorization.
///
/// The user can switch modes mid-run; subsequent tool calls see the new mode.
enum PermissionMode {
  /// Default — ask user for dangerous operations.
  normal,

  /// Auto-accept file edits; other dangerous ops still ask.
  acceptEdits,

  /// Skip all permission checks (dangerous).
  bypassPermissions,

  /// Plan mode — read-only, mutations blocked.
  plan,

  /// Non-interactive — deny anything not pre-approved.
  dontAsk,
}

/// Permission decision returned by [PermissionContext.check].
enum PermissionBehavior {
  /// Tool call is allowed.
  allow,

  /// Tool call is denied.
  deny,

  /// User must confirm before executing.
  ask,
}

/// The outcome of a permission check.
class PermissionDecision {
  /// The behavior: allow, deny, or ask.
  final PermissionBehavior behavior;

  /// Human-readable explanation (for deny/ask).
  final String message;

  /// Creates a [PermissionDecision].
  const PermissionDecision(this.behavior, [this.message = '']);

  /// Creates an allow decision.
  const PermissionDecision.allow() : behavior = PermissionBehavior.allow, message = '';

  /// Creates a deny decision.
  const PermissionDecision.deny(String reason)
      : behavior = PermissionBehavior.deny,
        message = reason;

  /// Creates an ask decision.
  const PermissionDecision.ask(String reason)
      : behavior = PermissionBehavior.ask,
        message = reason;

  /// Whether this is an allow.
  bool get isAllow => behavior == PermissionBehavior.allow;

  /// Whether this is a deny.
  bool get isDeny => behavior == PermissionBehavior.deny;

  /// Whether this is an ask.
  bool get isAsk => behavior == PermissionBehavior.ask;
}

/// Allow/deny rule for a specific tool.
class PermissionRule {
  /// Tool name (e.g. 'schedule.add', or '*' for all).
  final String toolName;

  /// Optional specifier (e.g. specific argument pattern).
  /// Currently unused; reserved for future granular rules.
  final String? specifier;

  /// Creates a [PermissionRule].
  const PermissionRule(this.toolName, [this.specifier]);

  /// Whether this rule matches [toolName].
  bool matches(String toolName) {
    if (this.toolName == '*') return true;
    return this.toolName == toolName;
  }

  @override
  String toString() => 'PermissionRule($toolName${specifier != null ? ":$specifier" : ""})';
}

/// Permission context — holds the active mode and rule sets.
///
/// The mode is a function so it can be read live at decision time
/// (user can switch modes mid-run).
class PermissionContext {
  /// Returns the current permission mode.
  final PermissionMode Function() _modeGetter;

  /// Allow rules — tool calls matching these are auto-approved.
  final List<PermissionRule> allowRules;

  /// Deny rules — tool calls matching these are auto-rejected.
  final List<PermissionRule> denyRules;

  /// Creates a [PermissionContext] with a live mode source.
  PermissionContext({
    required PermissionMode Function() modeGetter,
    this.allowRules = const [],
    this.denyRules = const [],
  }) : _modeGetter = modeGetter;

  /// Creates a [PermissionContext] with a fixed mode (for tests/headless).
  factory PermissionContext.fixed(PermissionMode mode) {
    return PermissionContext(modeGetter: () => mode);
  }

  /// The current permission mode.
  PermissionMode get mode => _modeGetter();

  /// Checks whether a tool call should be allowed, denied, or asked.
  ///
  /// [toolName] — the tool being called.
  /// [requiresConfirmation] — whether the tool declares it needs confirmation.
  /// [isMutation] — whether the tool modifies state.
  PermissionDecision check({
    required String toolName,
    bool requiresConfirmation = false,
    bool isMutation = false,
  }) {
    // 1. Check deny rules first
    for (final rule in denyRules) {
      if (rule.matches(toolName)) {
        return PermissionDecision.deny('Blocked by deny rule: $rule');
      }
    }

    // 2. Check allow rules
    for (final rule in allowRules) {
      if (rule.matches(toolName)) {
        return PermissionDecision.allow();
      }
    }

    // 3. Apply mode logic
    switch (mode) {
      case PermissionMode.bypassPermissions:
        return const PermissionDecision.allow();

      case PermissionMode.acceptEdits:
        // Auto-accept edits, ask for other dangerous ops
        if (requiresConfirmation && !isMutation) {
          return const PermissionDecision.ask('Requires confirmation');
        }
        return const PermissionDecision.allow();

      case PermissionMode.plan:
        // Read-only — block all mutations
        if (isMutation) {
          return const PermissionDecision.deny('Plan mode: mutations are blocked');
        }
        return const PermissionDecision.allow();

      case PermissionMode.dontAsk:
        // Non-interactive — deny anything not pre-approved
        if (requiresConfirmation) {
          return const PermissionDecision.deny('Not pre-approved (dontAsk mode)');
        }
        return const PermissionDecision.allow();

      case PermissionMode.normal:
        if (requiresConfirmation) {
          return const PermissionDecision.ask('This operation requires confirmation');
        }
        return const PermissionDecision.allow();
    }
  }
}
