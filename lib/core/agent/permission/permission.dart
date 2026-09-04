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
///
/// The optional [specifier] enables granular matching based on tool
/// arguments. Supported specifier formats:
/// - `null` — matches any call to [toolName]
/// - `arg:key=value` — matches when the argument `key` equals `value`
/// - `arg:key~=value` — matches when the argument `key` contains `value`
/// - `arg:key=~regex` — matches when the argument `key` matches `regex`
class PermissionRule {
  /// Tool name (e.g. 'schedule.add', or '*' for all).
  final String toolName;

  /// Optional specifier for granular argument-based matching.
  ///
  /// Formats:
  /// - `arg:key=value` — argument equals value
  /// - `arg:key~=value` — argument contains value
  /// - `arg:key=~regex` — argument matches regex
  final String? specifier;

  /// Creates a [PermissionRule].
  const PermissionRule(this.toolName, [this.specifier]);

  /// Whether this rule matches [toolName] with optional [arguments].
  bool matches(String toolName, [Map<String, dynamic>? arguments]) {
    if (this.toolName == '*') {
      return _matchesSpecifier(arguments);
    }
    if (this.toolName != toolName) return false;
    return _matchesSpecifier(arguments);
  }

  /// Checks whether the specifier matches the given arguments.
  bool _matchesSpecifier(Map<String, dynamic>? arguments) {
    if (specifier == null) return true;
    if (arguments == null) return false;

    final spec = specifier!;

    // arg:key=value (exact match)
    if (spec.startsWith('arg:')) {
      final rest = spec.substring(4);

      // Check for ~= (contains)
      final containsIdx = rest.indexOf('~=');
      if (containsIdx != -1) {
        final key = rest.substring(0, containsIdx);
        final value = rest.substring(containsIdx + 2);
        final argValue = arguments[key]?.toString() ?? '';
        return argValue.contains(value);
      }

      // Check for =~ (regex)
      final regexIdx = rest.indexOf('=~');
      if (regexIdx != -1) {
        final key = rest.substring(0, regexIdx);
        final pattern = rest.substring(regexIdx + 2);
        final argValue = arguments[key]?.toString() ?? '';
        try {
          return RegExp(pattern).hasMatch(argValue);
        } catch (_) {
          return false;
        }
      }

      // Check for = (exact match)
      final eqIdx = rest.indexOf('=');
      if (eqIdx != -1) {
        final key = rest.substring(0, eqIdx);
        final value = rest.substring(eqIdx + 1);
        final argValue = arguments[key]?.toString() ?? '';
        return argValue == value;
      }
    }

    return false;
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
  /// [arguments] — optional tool arguments for granular rule matching.
  PermissionDecision check({
    required String toolName,
    bool requiresConfirmation = false,
    bool isMutation = false,
    Map<String, dynamic>? arguments,
  }) {
    // 1. Check deny rules first
    for (final rule in denyRules) {
      if (rule.matches(toolName, arguments)) {
        return PermissionDecision.deny('Blocked by deny rule: $rule');
      }
    }

    // 2. Check allow rules
    for (final rule in allowRules) {
      if (rule.matches(toolName, arguments)) {
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
