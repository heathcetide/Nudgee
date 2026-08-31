import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:nudgee/app/router/app_router.dart';
import 'package:nudgee/core/constants/app_constants.dart';
import 'package:nudgee/core/di/injector.dart';
import 'package:nudgee/core/services/auth_service.dart';
import 'package:nudgee/core/widgets/buttons/ling_button.dart';
import 'package:nudgee/core/widgets/inputs/ling_text_field.dart';

/// Registration page with username/email/password.
///
/// Uses the existing [AuthService.register] method. On success,
/// navigates to the home route.
class LingRegisterPage extends StatefulWidget {
  const LingRegisterPage({super.key});

  @override
  State<LingRegisterPage> createState() => _LingRegisterPageState();
}

class _LingRegisterPageState extends State<LingRegisterPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _confirmFocus = FocusNode();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _usernameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmError;
  String? _generalError;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  bool _validateEmail(String email) {
    return RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(email);
  }

  Future<void> _handleRegister() async {
    // Clear previous errors
    setState(() {
      _usernameError = null;
      _emailError = null;
      _passwordError = null;
      _confirmError = null;
      _generalError = null;
    });

    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    // Validate
    bool hasError = false;
    if (username.isEmpty) {
      _usernameError = '请输入用户名';
      hasError = true;
    } else if (username.length < 3) {
      _usernameError = '用户名至少 3 个字符';
      hasError = true;
    }

    if (email.isNotEmpty && !_validateEmail(email)) {
      _emailError = '邮箱格式不正确';
      hasError = true;
    }

    if (password.isEmpty) {
      _passwordError = '请输入密码';
      hasError = true;
    } else if (password.length < 6) {
      _passwordError = '密码至少 6 位';
      hasError = true;
    }

    if (confirm != password) {
      _confirmError = '两次密码不一致';
      hasError = true;
    }

    if (hasError) {
      setState(() {});
      return;
    }

    setState(() => _isLoading = true);

    try {
      final auth = sl<AuthService>();
      final success = await auth.register(
        username: username,
        password: password,
        email: email.isNotEmpty ? email : null,
      );

      if (!mounted) return;

      if (success) {
        context.go(AppRouter.home);
      } else {
        setState(() {
          _generalError = '注册失败，用户名可能已存在';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _generalError = '注册失败，请检查网络后重试';
        _isLoading = false;
      });
    }
  }

  void _goLogin() {
    context.go(AppRouter.login);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goLogin,
        ),
        title: const Text('注册'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingXl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  _buildHeader(theme),
                  const SizedBox(height: AppConstants.spacingXxl),

                  // General error
                  if (_generalError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline,
                              color: theme.colorScheme.onErrorContainer, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _generalError!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppConstants.spacingMd),
                  ],

                  // Username
                  LingTextField(
                    controller: _usernameController,
                    label: '用户名',
                    hint: '3-20 个字符',
                    prefixIcon: Icons.person_outline,
                    errorText: _usernameError,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _emailFocus.requestFocus(),
                  ),
                  const SizedBox(height: AppConstants.spacingMd),

                  // Email (optional)
                  LingTextField(
                    controller: _emailController,
                    focusNode: _emailFocus,
                    label: '邮箱（选填）',
                    hint: 'example@email.com',
                    prefixIcon: Icons.email_outlined,
                    errorText: _emailError,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _passwordFocus.requestFocus(),
                  ),
                  const SizedBox(height: AppConstants.spacingMd),

                  // Password
                  LingTextField(
                    controller: _passwordController,
                    focusNode: _passwordFocus,
                    label: '密码',
                    hint: '至少 6 位',
                    prefixIcon: Icons.lock_outline,
                    errorText: _passwordError,
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _confirmFocus.requestFocus(),
                  ),
                  const SizedBox(height: AppConstants.spacingMd),

                  // Confirm password
                  LingTextField(
                    controller: _confirmController,
                    focusNode: _confirmFocus,
                    label: '确认密码',
                    hint: '再次输入密码',
                    prefixIcon: Icons.lock_outline,
                    errorText: _confirmError,
                    obscureText: _obscureConfirm,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() => _obscureConfirm = !_obscureConfirm);
                      },
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _handleRegister(),
                  ),
                  const SizedBox(height: AppConstants.spacingLg),

                  // Register button
                  LingButton(
                    label: '注册',
                    variant: LingButtonVariant.filled,
                    size: LingButtonSize.large,
                    expanded: true,
                    loading: _isLoading,
                    onPressed: _isLoading ? null : _handleRegister,
                  ),
                  const SizedBox(height: AppConstants.spacingLg),

                  // Login link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '已有账号？',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      TextButton(
                        onPressed: _goLogin,
                        child: Text(
                          '返回登录',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppConstants.radiusXl),
          ),
          child: Icon(
            Icons.person_add_outlined,
            size: 36,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: AppConstants.spacingMd),
        Text(
          '创建账号',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
}
