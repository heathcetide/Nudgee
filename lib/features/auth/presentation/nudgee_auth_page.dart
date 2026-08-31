import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:nudgee/app/router/app_router.dart';
import 'package:nudgee/app/theme/app_colors.dart';
import 'package:nudgee/core/di/injector.dart';
import 'package:nudgee/core/extensions/context_extensions.dart';
import 'package:nudgee/core/services/auth_service.dart';
import 'package:nudgee/features/auth/presentation/nudgee_auth_widgets.dart';

/// Nudgee authentication page — login + register.
///
/// No email verification, no social login. Just username + password.
/// Credentials are synced to Qiniu object storage for cross-device access.
class NudgeeAuthPage extends StatefulWidget {
  final NudgeeAuthMode initialMode;

  const NudgeeAuthPage({
    super.key,
    this.initialMode = NudgeeAuthMode.login,
  });

  @override
  State<NudgeeAuthPage> createState() => _NudgeeAuthPageState();
}

class _NudgeeAuthPageState extends State<NudgeeAuthPage>
    with TickerProviderStateMixin {
  late NudgeeAuthMode _mode;

  // Controllers
  final _accountController = TextEditingController();
  final _passwordController = TextEditingController();
  final _regUsernameController = TextEditingController();
  final _regPasswordController = TextEditingController();

  // Focus nodes
  final _accountFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _regUsernameFocus = FocusNode();
  final _regPasswordFocus = FocusNode();

  // State
  bool _obscurePassword = true;
  bool _obscureRegPassword = true;
  bool _isSubmitting = false;
  String? _accountError;
  String? _passwordError;
  String? _regUsernameError;
  String? _regPasswordError;
  String? _generalError;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    _regUsernameController.dispose();
    _regPasswordController.dispose();
    _accountFocus.dispose();
    _passwordFocus.dispose();
    _regUsernameFocus.dispose();
    _regPasswordFocus.dispose();
    super.dispose();
  }

  // ─── Validation ───────────────────────────────────────────────────
  void _clearAllErrors() {
    _accountError = null;
    _passwordError = null;
    _regUsernameError = null;
    _regPasswordError = null;
    _generalError = null;
  }

  bool _validateLogin() {
    setState(_clearAllErrors);
    bool ok = true;

    if (_accountController.text.trim().isEmpty) {
      _accountError = context.l10n.authErrEnterAccount;
      ok = false;
    }
    if (_passwordController.text.isEmpty) {
      _passwordError = context.l10n.authErrEnterPassword;
      ok = false;
    }

    if (!ok) setState(() {});
    return ok;
  }

  bool _validateRegister() {
    setState(_clearAllErrors);
    bool ok = true;

    final username = _regUsernameController.text.trim();
    if (username.isEmpty) {
      _regUsernameError = context.l10n.authErrEnterUsername;
      ok = false;
    } else if (username.length < 3) {
      _regUsernameError = context.l10n.authErrUsernameMinLength;
      ok = false;
    }

    final pwd = _regPasswordController.text;
    if (pwd.isEmpty) {
      _regPasswordError = context.l10n.authErrEnterPassword;
      ok = false;
    } else if (pwd.length < 6) {
      _regPasswordError = context.l10n.authErrPasswordMinLength;
      ok = false;
    }

    if (!ok) setState(() {});
    return ok;
  }

  // ─── Submit ───────────────────────────────────────────────────────
  Future<void> _submitLogin() async {
    FocusScope.of(context).unfocus();
    if (!_validateLogin()) return;
    setState(() {
      _isSubmitting = true;
      _generalError = null;
    });

    try {
      final success = await sl<AuthService>().login(
        _accountController.text.trim(),
        _passwordController.text,
      );
      if (!mounted) return;
      if (success) {
        context.go(AppRouter.home);
      } else {
        setState(() {
          _generalError = '登录失败：用户名或密码错误，或存储配置未加载';
          _isSubmitting = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _generalError = '登录异常: $e';
        _isSubmitting = false;
      });
    }
  }

  Future<void> _submitRegister() async {
    FocusScope.of(context).unfocus();
    if (!_validateRegister()) return;
    setState(() {
      _isSubmitting = true;
      _generalError = null;
    });

    try {
      final (success, error) = await sl<AuthService>().register(
        username: _regUsernameController.text.trim(),
        password: _regPasswordController.text,
      );
      if (!mounted) return;
      if (success) {
        context.go(AppRouter.home);
      } else {
        setState(() {
          _generalError = error ?? context.l10n.authRegisterFailed;
          _isSubmitting = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _generalError = '注册异常: $e';
        _isSubmitting = false;
      });
    }
  }

  // ─── Switch mode ──────────────────────────────────────────────────
  void _switchMode(NudgeeAuthMode mode) {
    FocusScope.of(context).unfocus();
    setState(() {
      _mode = mode;
      _clearAllErrors();
    });
  }

  // ─── Build ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: _buildAnimatedForm(),
            ),
          ),
        ),
      ),
    );
  }

  /// AnimatedSwitcher provides slide + fade transition between forms.
  Widget _buildAnimatedForm() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final offset = Tween<Offset>(
          begin: const Offset(0.15, 0),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: _mode == NudgeeAuthMode.login
          ? KeyedSubtree(
              key: const ValueKey('login'),
              child: _buildLoginForm(),
            )
          : KeyedSubtree(
              key: const ValueKey('signup'),
              child: _buildRegisterForm(),
            ),
    );
  }

  // ── Login form ────────────────────────────────────────────────────
  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          context.l10n.authWelcomeLogin,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: AppColors.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 24),
        if (_generalError != null) ...[
          NudgeeAuthErrorBanner(message: _generalError!),
          const SizedBox(height: 16),
        ],
        NudgeeAuthTextField(
          controller: _accountController,
          focusNode: _accountFocus,
          label: context.l10n.authAccountLabel,
          hint: context.l10n.authAccountHint,
          prefixIcon: Icons.person_outline,
          errorText: _accountError,
          enabled: !_isSubmitting,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _passwordFocus.requestFocus(),
        ),
        const SizedBox(height: 16),
        NudgeeAuthTextField(
          controller: _passwordController,
          focusNode: _passwordFocus,
          label: context.l10n.authPasswordLabel,
          hint: context.l10n.authPasswordHint,
          prefixIcon: Icons.lock_outline,
          errorText: _passwordError,
          obscureText: _obscurePassword,
          enabled: !_isSubmitting,
          textInputAction: TextInputAction.done,
          suffix: IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: AppColors.lightTextHint,
              size: 20,
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
          onSubmitted: (_) => _submitLogin(),
        ),
        const SizedBox(height: 24),
        NudgeeAuthSubmitButton(
          text: context.l10n.authLoginButton,
          loading: _isSubmitting,
          onPressed: _isSubmitting ? null : _submitLogin,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              context.l10n.authNoAccount,
              style: TextStyle(
                  fontSize: 14, color: AppColors.lightTextSecondary),
            ),
            GestureDetector(
              onTap: _isSubmitting
                  ? null
                  : () => _switchMode(NudgeeAuthMode.signup),
              child: Text(
                context.l10n.authRegisterNow,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Register form ─────────────────────────────────────────────────
  Widget _buildRegisterForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          context.l10n.authRegisterTitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: AppColors.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.authRegisterSubtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 24),
        if (_generalError != null) ...[
          NudgeeAuthErrorBanner(message: _generalError!),
          const SizedBox(height: 16),
        ],
        NudgeeAuthTextField(
          controller: _regUsernameController,
          focusNode: _regUsernameFocus,
          label: context.l10n.authUsernameLabel,
          hint: context.l10n.authUsernameHint,
          prefixIcon: Icons.person_outline,
          errorText: _regUsernameError,
          enabled: !_isSubmitting,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _regPasswordFocus.requestFocus(),
        ),
        const SizedBox(height: 16),
        NudgeeAuthTextField(
          controller: _regPasswordController,
          focusNode: _regPasswordFocus,
          label: context.l10n.authPasswordLabel,
          hint: context.l10n.authPasswordMinHint,
          prefixIcon: Icons.lock_outline,
          errorText: _regPasswordError,
          obscureText: _obscureRegPassword,
          enabled: !_isSubmitting,
          textInputAction: TextInputAction.done,
          suffix: IconButton(
            icon: Icon(
              _obscureRegPassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: AppColors.lightTextHint,
              size: 20,
            ),
            onPressed: () =>
                setState(() => _obscureRegPassword = !_obscureRegPassword),
          ),
          onSubmitted: (_) => _submitRegister(),
        ),
        const SizedBox(height: 24),
        NudgeeAuthSubmitButton(
          text: context.l10n.authRegisterButton,
          loading: _isSubmitting,
          onPressed: _isSubmitting ? null : _submitRegister,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              context.l10n.authHaveAccount,
              style: TextStyle(
                  fontSize: 14, color: AppColors.lightTextSecondary),
            ),
            GestureDetector(
              onTap: _isSubmitting
                  ? null
                  : () => _switchMode(NudgeeAuthMode.login),
              child: Text(
                context.l10n.authBackToLogin,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
