import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:nudgee/app/router/app_router.dart';
import 'package:nudgee/app/theme/app_colors.dart';
import 'package:nudgee/core/di/injector.dart';
import 'package:nudgee/core/extensions/context_extensions.dart';
import 'package:nudgee/core/services/auth_service.dart';
import 'package:nudgee/features/auth/presentation/nudgee_auth_widgets.dart';

/// Nudgee authentication page — mobile port of LingEchoX web's TenantAuth.
///
/// Supports three modes with animated transitions:
/// - login (password / email code)
/// - signup
/// - forgot password
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
  NudgeeLoginMethod _method = NudgeeLoginMethod.password;

  // Controllers
  final _accountController = TextEditingController();
  final _emailController = TextEditingController();
  final _emailCodeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _regUsernameController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regPasswordController = TextEditingController();
  final _forgotEmailController = TextEditingController();
  final _forgotCodeController = TextEditingController();
  final _forgotPasswordController = TextEditingController();

  // Focus nodes
  final _accountFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _emailCodeFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _regUsernameFocus = FocusNode();
  final _regEmailFocus = FocusNode();
  final _regPasswordFocus = FocusNode();
  final _forgotEmailFocus = FocusNode();
  final _forgotCodeFocus = FocusNode();
  final _forgotPasswordFocus = FocusNode();

  // State
  bool _obscurePassword = true;
  bool _obscureRegPassword = true;
  bool _obscureForgotPassword = true;
  bool _isSubmitting = false;
  bool _emailCodeSending = false;
  bool _forgotCodeSending = false;
  int _emailCodeCountdown = 0;
  int _forgotCodeCountdown = 0;
  Timer? _emailCodeTimer;
  Timer? _forgotCodeTimer;
  String? _accountError;
  String? _emailError;
  String? _emailCodeError;
  String? _passwordError;
  String? _regUsernameError;
  String? _regEmailError;
  String? _regPasswordError;
  String? _forgotEmailError;
  String? _forgotCodeError;
  String? _forgotPasswordError;
  String? _generalError;

  static const _codeResendSeconds = 60;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  @override
  void dispose() {
    _accountController.dispose();
    _emailController.dispose();
    _emailCodeController.dispose();
    _passwordController.dispose();
    _regUsernameController.dispose();
    _regEmailController.dispose();
    _regPasswordController.dispose();
    _forgotEmailController.dispose();
    _forgotCodeController.dispose();
    _forgotPasswordController.dispose();
    _accountFocus.dispose();
    _emailFocus.dispose();
    _emailCodeFocus.dispose();
    _passwordFocus.dispose();
    _regUsernameFocus.dispose();
    _regEmailFocus.dispose();
    _regPasswordFocus.dispose();
    _forgotEmailFocus.dispose();
    _forgotCodeFocus.dispose();
    _forgotPasswordFocus.dispose();
    _emailCodeTimer?.cancel();
    _forgotCodeTimer?.cancel();
    super.dispose();
  }

  // ─── Validation ───────────────────────────────────────────────────
  static bool _isValidEmail(String e) =>
      RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(e);

  void _clearAllErrors() {
    _accountError = null;
    _emailError = null;
    _emailCodeError = null;
    _passwordError = null;
    _regUsernameError = null;
    _regEmailError = null;
    _regPasswordError = null;
    _forgotEmailError = null;
    _forgotCodeError = null;
    _forgotPasswordError = null;
    _generalError = null;
  }

  bool _validateLogin() {
    setState(_clearAllErrors);
    bool ok = true;

    if (_method == NudgeeLoginMethod.password) {
      if (_accountController.text.trim().isEmpty) {
        _accountError = context.l10n.authErrEnterAccount;
        ok = false;
      }
      if (_passwordController.text.isEmpty) {
        _passwordError = context.l10n.authErrEnterPassword;
        ok = false;
      }
    } else if (_method == NudgeeLoginMethod.emailCode) {
      final email = _emailController.text.trim();
      if (email.isEmpty) {
        _emailError = context.l10n.authErrEnterEmail;
        ok = false;
      } else if (!_isValidEmail(email)) {
        _emailError = context.l10n.authErrInvalidEmail;
        ok = false;
      }
      final code = _emailCodeController.text.trim();
      if (code.isEmpty) {
        _emailCodeError = context.l10n.authErrEnterCode;
        ok = false;
      } else if (code.length != 6) {
        _emailCodeError = context.l10n.authErrCodeSixDigits;
        ok = false;
      }
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

    final email = _regEmailController.text.trim();
    if (email.isEmpty) {
      _regEmailError = context.l10n.authErrEnterEmail;
      ok = false;
    } else if (!_isValidEmail(email)) {
      _regEmailError = context.l10n.authErrInvalidEmail;
      ok = false;
    }

    final pwd = _regPasswordController.text;
    if (pwd.isEmpty) {
      _regPasswordError = context.l10n.authErrEnterPassword;
      ok = false;
    } else if (pwd.length < 8) {
      _regPasswordError = context.l10n.authErrPasswordMinLength;
      ok = false;
    }

    if (!ok) setState(() {});
    return ok;
  }

  bool _validateForgot() {
    setState(_clearAllErrors);
    bool ok = true;

    final email = _forgotEmailController.text.trim();
    if (email.isEmpty) {
      _forgotEmailError = context.l10n.authErrEnterEmail;
      ok = false;
    } else if (!_isValidEmail(email)) {
      _forgotEmailError = context.l10n.authErrInvalidEmail;
      ok = false;
    }

    final code = _forgotCodeController.text.trim();
    if (code.isEmpty) {
      _forgotCodeError = context.l10n.authErrEnterCode;
      ok = false;
    } else if (code.length != 6) {
      _forgotCodeError = context.l10n.authErrCodeSixDigits;
      ok = false;
    }

    final pwd = _forgotPasswordController.text;
    if (pwd.isEmpty) {
      _forgotPasswordError = context.l10n.authErrEnterNewPassword;
      ok = false;
    } else if (pwd.length < 8) {
      _forgotPasswordError = context.l10n.authErrPasswordMinLength;
      ok = false;
    }

    if (!ok) setState(() {});
    return ok;
  }

  // ─── Send codes ───────────────────────────────────────────────────
  Future<void> _sendEmailCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _emailError = context.l10n.authErrEnterEmail);
      return;
    }
    if (!_isValidEmail(email)) {
      setState(() => _emailError = context.l10n.authErrInvalidEmail);
      return;
    }
    if (_emailCodeCountdown > 0 || _emailCodeSending) return;

    setState(() {
      _emailCodeSending = true;
      _emailError = null;
    });

    final ok = await sl<AuthService>().sendEmailCode(email);
    if (!mounted) return;

    if (ok) {
      setState(() {
        _emailCodeSending = false;
        _emailCodeCountdown = _codeResendSeconds;
      });
      _emailCodeFocus.requestFocus();
      _emailCodeTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (mounted) {
          setState(() {
            _emailCodeCountdown--;
            if (_emailCodeCountdown <= 0) t.cancel();
          });
        } else {
          t.cancel();
        }
      });
    } else {
      setState(() {
        _emailCodeSending = false;
        _generalError = context.l10n.authCodeSendFailed;
      });
    }
  }

  Future<void> _sendForgotCode() async {
    final email = _forgotEmailController.text.trim();
    if (email.isEmpty) {
      setState(() => _forgotEmailError = context.l10n.authErrEnterEmail);
      return;
    }
    if (!_isValidEmail(email)) {
      setState(() => _forgotEmailError = context.l10n.authErrInvalidEmail);
      return;
    }
    if (_forgotCodeCountdown > 0 || _forgotCodeSending) return;

    setState(() {
      _forgotCodeSending = true;
      _forgotEmailError = null;
    });

    final ok = await sl<AuthService>().sendForgotPasswordCode(email);
    if (!mounted) return;

    if (ok) {
      setState(() {
        _forgotCodeSending = false;
        _forgotCodeCountdown = _codeResendSeconds;
      });
      _forgotCodeFocus.requestFocus();
      _forgotCodeTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (mounted) {
          setState(() {
            _forgotCodeCountdown--;
            if (_forgotCodeCountdown <= 0) t.cancel();
          });
        } else {
          t.cancel();
        }
      });
    } else {
      setState(() {
        _forgotCodeSending = false;
        _generalError = context.l10n.authCodeSendFailed;
      });
    }
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
      final auth = sl<AuthService>();
      bool success;
      switch (_method) {
        case NudgeeLoginMethod.password:
          success = await auth.login(
            _accountController.text.trim(),
            _passwordController.text,
          );
        case NudgeeLoginMethod.emailCode:
          success = await auth.loginWithEmailCode(
            _emailController.text.trim(),
            _emailCodeController.text.trim(),
          );
      }
      if (!mounted) return;
      if (success) {
        context.go(AppRouter.home);
      } else {
        setState(() {
          _generalError = context.l10n.authLoginFailed;
          _isSubmitting = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _generalError = context.l10n.authNetworkError;
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
      final success = await sl<AuthService>().register(
        username: _regUsernameController.text.trim(),
        password: _regPasswordController.text,
        email: _regEmailController.text.trim(),
      );
      if (!mounted) return;
      if (success) {
        context.go(AppRouter.home);
      } else {
        setState(() {
          _generalError = context.l10n.authRegisterFailed;
          _isSubmitting = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _generalError = context.l10n.authNetworkError;
        _isSubmitting = false;
      });
    }
  }

  Future<void> _submitForgot() async {
    FocusScope.of(context).unfocus();
    if (!_validateForgot()) return;
    setState(() {
      _isSubmitting = true;
      _generalError = null;
    });

    try {
      final success = await sl<AuthService>().resetPassword(
        email: _forgotEmailController.text.trim(),
        code: _forgotCodeController.text.trim(),
        password: _forgotPasswordController.text,
      );
      if (!mounted) return;
      if (success) {
        setState(() {
          _isSubmitting = false;
          _generalError = null;
        });
        // Show success then go back to login
        if (mounted) {
          NudgeeAuthSuccessToast.show(context, context.l10n.authPasswordResetSuccess);
          _switchMode(NudgeeAuthMode.login);
        }
      } else {
        setState(() {
          _generalError = context.l10n.authResetFailed;
          _isSubmitting = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _generalError = context.l10n.authNetworkError;
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

  void _switchMethod(NudgeeLoginMethod m) {
    if (m == _method) return;
    setState(() {
      _clearAllErrors();
      _method = m;
    });
  }

  // ─── Build ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SafeArea(
        child: isWide ? _buildWideLayout() : _buildNarrowLayout(),
      ),
    );
  }

  Widget _buildNarrowLayout() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: _buildAnimatedForm(),
          ),
        ),
        _buildFooter(),
      ],
    );
  }

  Widget _buildWideLayout() {
    return Row(
      children: [
        SizedBox(
          width: MediaQuery.of(context).size.width * 0.44,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 48, vertical: 32),
                  child: _buildAnimatedForm(),
                ),
              ),
              _buildFooter(),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 20, right: 20, bottom: 20),
            child: LingOrbitCarousel(
              title: 'Nudgee',
              subtitle: context.l10n.splashTagline,
            ),
          ),
        ),
      ],
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
      child: _buildFormForKey(),
    );
  }

  Widget _buildFormForKey() {
    switch (_mode) {
      case NudgeeAuthMode.login:
        return KeyedSubtree(
          key: const ValueKey('login'),
          child: _buildLoginForm(),
        );
      case NudgeeAuthMode.signup:
        return KeyedSubtree(
          key: const ValueKey('signup'),
          child: _buildRegisterForm(),
        );
      case NudgeeAuthMode.forgot:
        return KeyedSubtree(
          key: const ValueKey('forgot'),
          child: _buildForgotForm(),
        );
    }
  }

  // ── Footer ────────────────────────────────────────────────────────
  Widget _buildFooter() {
    final year = DateTime.now().year;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        '© $year LingEdge · Nudgee',
        style: TextStyle(fontSize: 12, color: AppColors.lightTextHint),
      ),
    );
  }

  // ── Login form ────────────────────────────────────────────────────
  Widget _buildLoginForm() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
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
          LingMethodTabBar(
            method: _method,
            onChanged: _switchMethod,
            tabs: [
              (NudgeeLoginMethod.password, context.l10n.authPasswordLogin),
              (NudgeeLoginMethod.emailCode, context.l10n.authEmailCodeLogin),
            ],
          ),
          const SizedBox(height: 20),
          if (_generalError != null) ...[
            NudgeeAuthErrorBanner(message: _generalError!),
            const SizedBox(height: 16),
          ],
          _buildLoginFields(),
          const SizedBox(height: 20),
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
                onTap: _isSubmitting ? null : () => _switchMode(NudgeeAuthMode.signup),
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
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildLoginFields() {
    switch (_method) {
      case NudgeeLoginMethod.password:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: _isSubmitting ? null : () => _switchMode(NudgeeAuthMode.forgot),
                child: Text(
                  context.l10n.authForgotPassword,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.lightTextSecondary,
                  ),
                ),
              ),
            ),
          ],
        );

      case NudgeeLoginMethod.emailCode:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NudgeeAuthTextField(
              controller: _emailController,
              focusNode: _emailFocus,
              label: context.l10n.authEmailLabel,
              hint: context.l10n.authEmailHint,
              prefixIcon: Icons.email_outlined,
              errorText: _emailError,
              enabled: !_isSubmitting,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _emailCodeFocus.requestFocus(),
            ),
            const SizedBox(height: 16),
            NudgeeAuthTextField(
              controller: _emailCodeController,
              focusNode: _emailCodeFocus,
              label: context.l10n.authEmailCodeLabel,
              hint: context.l10n.authEmailCodeHint,
              prefixIcon: Icons.mark_email_read_outlined,
              errorText: _emailCodeError,
              enabled: !_isSubmitting,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textInputAction: TextInputAction.done,
              suffix: LingCodeButton(
                countdown: _emailCodeCountdown,
                sending: _emailCodeSending,
                onTap: _isSubmitting ? null : _sendEmailCode,
              ),
              onSubmitted: (_) => _submitLogin(),
            ),
          ],
        );
    }
  }

  // ── Register form ─────────────────────────────────────────────────
  Widget _buildRegisterForm() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
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
            onSubmitted: (_) => _regEmailFocus.requestFocus(),
          ),
          const SizedBox(height: 16),
          NudgeeAuthTextField(
            controller: _regEmailController,
            focusNode: _regEmailFocus,
            label: context.l10n.authEmailLabel,
            hint: context.l10n.authEmailHint,
            prefixIcon: Icons.email_outlined,
            errorText: _regEmailError,
            enabled: !_isSubmitting,
            keyboardType: TextInputType.emailAddress,
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
                onTap: _isSubmitting ? null : () => _switchMode(NudgeeAuthMode.login),
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
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Forgot password form ──────────────────────────────────────────
  Widget _buildForgotForm() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Text(
            context.l10n.authForgotTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.authForgotSubtitle,
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
            controller: _forgotEmailController,
            focusNode: _forgotEmailFocus,
            label: context.l10n.authEmailLabel,
            hint: context.l10n.authRegisteredEmailHint,
            prefixIcon: Icons.email_outlined,
            errorText: _forgotEmailError,
            enabled: !_isSubmitting,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _forgotCodeFocus.requestFocus(),
          ),
          const SizedBox(height: 16),
          NudgeeAuthTextField(
            controller: _forgotCodeController,
            focusNode: _forgotCodeFocus,
            label: context.l10n.authCodeLabel,
            hint: context.l10n.authEmailCodeHint,
            prefixIcon: Icons.mark_email_read_outlined,
            errorText: _forgotCodeError,
            enabled: !_isSubmitting,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textInputAction: TextInputAction.next,
            suffix: LingCodeButton(
              countdown: _forgotCodeCountdown,
              sending: _forgotCodeSending,
              onTap: _isSubmitting ? null : _sendForgotCode,
            ),
            onSubmitted: (_) => _forgotPasswordFocus.requestFocus(),
          ),
          const SizedBox(height: 16),
          NudgeeAuthTextField(
            controller: _forgotPasswordController,
            focusNode: _forgotPasswordFocus,
            label: context.l10n.authNewPasswordLabel,
            hint: context.l10n.authPasswordMinHint,
            prefixIcon: Icons.lock_outline,
            errorText: _forgotPasswordError,
            obscureText: _obscureForgotPassword,
            enabled: !_isSubmitting,
            textInputAction: TextInputAction.done,
            suffix: IconButton(
              icon: Icon(
                _obscureForgotPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.lightTextHint,
                size: 20,
              ),
              onPressed: () => setState(
                  () => _obscureForgotPassword = !_obscureForgotPassword),
            ),
            onSubmitted: (_) => _submitForgot(),
          ),
          const SizedBox(height: 24),
          NudgeeAuthSubmitButton(
            text: context.l10n.authResetPasswordButton,
            loading: _isSubmitting,
            onPressed: _isSubmitting ? null : _submitForgot,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                context.l10n.authRememberedPassword,
                style: TextStyle(
                    fontSize: 14, color: AppColors.lightTextSecondary),
              ),
              GestureDetector(
                onTap: _isSubmitting ? null : () => _switchMode(NudgeeAuthMode.login),
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
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Simple success toast using SnackBar.
class NudgeeAuthSuccessToast {
  static void show(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
