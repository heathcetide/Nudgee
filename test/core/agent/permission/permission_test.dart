import 'package:flutter_test/flutter_test.dart';
import 'package:nudgee/core/agent/permission/permission.dart';

void main() {
  group('PermissionMode', () {
    test('has all 5 modes', () {
      expect(PermissionMode.values, hasLength(5));
      expect(PermissionMode.values, contains(PermissionMode.normal));
      expect(PermissionMode.values, contains(PermissionMode.acceptEdits));
      expect(PermissionMode.values, contains(PermissionMode.bypassPermissions));
      expect(PermissionMode.values, contains(PermissionMode.plan));
      expect(PermissionMode.values, contains(PermissionMode.dontAsk));
    });
  });

  group('PermissionDecision', () {
    test('allow decision', () {
      const decision = PermissionDecision.allow();
      expect(decision.isAllow, true);
      expect(decision.isDeny, false);
      expect(decision.isAsk, false);
      expect(decision.message, isEmpty);
    });

    test('deny decision', () {
      const decision = PermissionDecision.deny('Not allowed');
      expect(decision.isDeny, true);
      expect(decision.isAllow, false);
      expect(decision.message, 'Not allowed');
    });

    test('ask decision', () {
      const decision = PermissionDecision.ask('Please confirm');
      expect(decision.isAsk, true);
      expect(decision.isAllow, false);
      expect(decision.message, 'Please confirm');
    });
  });

  group('PermissionRule', () {
    test('matches exact tool name', () {
      const rule = PermissionRule('schedule.add');
      expect(rule.matches('schedule.add'), true);
      expect(rule.matches('schedule.query'), false);
    });

    test('wildcard matches any tool', () {
      const rule = PermissionRule('*');
      expect(rule.matches('schedule.add'), true);
      expect(rule.matches('anything'), true);
    });

    test('toString contains tool name', () {
      const rule = PermissionRule('delete');
      expect(rule.toString(), contains('delete'));
    });
  });

  group('PermissionContext', () {
    test('fixed mode returns the same mode', () {
      final ctx = PermissionContext.fixed(PermissionMode.plan);
      expect(ctx.mode, PermissionMode.plan);
    });

    test('live mode getter reflects changes', () {
      var mode = PermissionMode.normal;
      final ctx = PermissionContext(modeGetter: () => mode);
      expect(ctx.mode, PermissionMode.normal);
      mode = PermissionMode.bypassPermissions;
      expect(ctx.mode, PermissionMode.bypassPermissions);
    });

    test('normal mode allows non-sensitive tools', () {
      final ctx = PermissionContext.fixed(PermissionMode.normal);
      final decision = ctx.check(
        toolName: 'echo',
        requiresConfirmation: false,
        isMutation: false,
      );
      expect(decision.isAllow, true);
    });

    test('normal mode asks for sensitive tools', () {
      final ctx = PermissionContext.fixed(PermissionMode.normal);
      final decision = ctx.check(
        toolName: 'delete',
        requiresConfirmation: true,
        isMutation: true,
      );
      expect(decision.isAsk, true);
    });

    test('bypassPermissions allows everything', () {
      final ctx = PermissionContext.fixed(PermissionMode.bypassPermissions);
      final decision = ctx.check(
        toolName: 'delete',
        requiresConfirmation: true,
        isMutation: true,
      );
      expect(decision.isAllow, true);
    });

    test('plan mode blocks mutations', () {
      final ctx = PermissionContext.fixed(PermissionMode.plan);
      final decision = ctx.check(
        toolName: 'schedule.add',
        requiresConfirmation: false,
        isMutation: true,
      );
      expect(decision.isDeny, true);
    });

    test('plan mode allows read-only tools', () {
      final ctx = PermissionContext.fixed(PermissionMode.plan);
      final decision = ctx.check(
        toolName: 'schedule.query',
        requiresConfirmation: false,
        isMutation: false,
      );
      expect(decision.isAllow, true);
    });

    test('dontAsk denies unconfirmed tools', () {
      final ctx = PermissionContext.fixed(PermissionMode.dontAsk);
      final decision = ctx.check(
        toolName: 'delete',
        requiresConfirmation: true,
        isMutation: true,
      );
      expect(decision.isDeny, true);
    });

    test('dontAsk allows safe tools', () {
      final ctx = PermissionContext.fixed(PermissionMode.dontAsk);
      final decision = ctx.check(
        toolName: 'echo',
        requiresConfirmation: false,
        isMutation: false,
      );
      expect(decision.isAllow, true);
    });

    test('acceptEdits allows mutations without asking', () {
      final ctx = PermissionContext.fixed(PermissionMode.acceptEdits);
      final decision = ctx.check(
        toolName: 'file.edit',
        requiresConfirmation: true,
        isMutation: true,
      );
      expect(decision.isAllow, true);
    });

    test('acceptEdits still asks for non-mutation sensitive ops', () {
      final ctx = PermissionContext.fixed(PermissionMode.acceptEdits);
      final decision = ctx.check(
        toolName: 'send.email',
        requiresConfirmation: true,
        isMutation: false,
      );
      expect(decision.isAsk, true);
    });

    test('deny rules take priority', () {
      final ctx = PermissionContext(
        modeGetter: () => PermissionMode.bypassPermissions,
        denyRules: const [PermissionRule('dangerous')],
      );
      final decision = ctx.check(
        toolName: 'dangerous',
        requiresConfirmation: false,
        isMutation: false,
      );
      expect(decision.isDeny, true);
    });

    test('allow rules take priority over mode', () {
      final ctx = PermissionContext(
        modeGetter: () => PermissionMode.dontAsk,
        allowRules: const [PermissionRule('safe.tool')],
      );
      final decision = ctx.check(
        toolName: 'safe.tool',
        requiresConfirmation: true,
        isMutation: true,
      );
      expect(decision.isAllow, true);
    });

    test('deny rules take priority over allow rules', () {
      final ctx = PermissionContext(
        modeGetter: () => PermissionMode.normal,
        allowRules: const [PermissionRule('*')],
        denyRules: const [PermissionRule('blocked')],
      );
      final decision = ctx.check(
        toolName: 'blocked',
        requiresConfirmation: false,
        isMutation: false,
      );
      expect(decision.isDeny, true);
    });

    test('wildcard allow rule matches any tool', () {
      final ctx = PermissionContext(
        modeGetter: () => PermissionMode.dontAsk,
        allowRules: const [PermissionRule('*')],
      );
      final decision = ctx.check(
        toolName: 'anything',
        requiresConfirmation: true,
        isMutation: true,
      );
      expect(decision.isAllow, true);
    });
  });
}
