import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:nudgee/app/router/app_router.dart';
import 'package:nudgee/core/constants/app_constants.dart';
import 'package:nudgee/core/di/injector.dart';
import 'package:nudgee/core/services/auth_service.dart';
import 'package:nudgee/core/widgets/buttons/ling_button.dart';
import 'package:nudgee/core/widgets/inputs/ling_text_field.dart';

/// Login page with username/password authentication.
///
/// Uses the existing [AuthService] for credential verification and
/// token persistence. On success, navigates to the home route.
class LingLoginPage extends StatefulWidget {
  const LingLoginPage({super.key});

  @override
  State<LingLoginPage> createState() => _LingLoginPageState();
}

class _LingLoginPageState extends State<LingLoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _usernameError;
  String? _passwordError;
  String? _generalError;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    // Clear previous errors
    setState(() {
      _usernameError = null;
      _passwordError = null;
      _generalError = null;
    });

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    // Validate
    if (username.isEmpty) {
      setState(() => _usernameError = '请输入用户名');
      return;
    }
    if (password.isEmpty) {
      setState(() => _passwordError = '请输入密码');
      return;
    }
    if (password.length < 6) {
      setState(() => _passwordError = '密码至少 6 位');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final auth = sl<AuthService>();
      final success = await auth.login(username, password);

      if (!mounted) return;

      if (success) {
        context.go(AppRouter.home);
      } else {
        setState(() {
          _generalError = '用户名或密码错误';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _generalError = '登录失败，请检查网络后重试';
        _isLoading = false;
      });
    }
  }

  void _goRegister() {
    context.go(AppRouter.register);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
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
                  // Logo / App name
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
                    hint: '请输入用户名',
                    prefixIcon: Icons.person_outline,
                    errorText: _usernameError,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _passwordFocus.requestFocus(),
                  ),
                  const SizedBox(height: AppConstants.spacingMd),

                  // Password
                  LingTextField(
                    controller: _passwordController,
                    focusNode: _passwordFocus,
                    label: '密码',
                    hint: '请输入密码',
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
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _handleLogin(),
                  ),
                  const SizedBox(height: AppConstants.spacingSm),

                  // Forgot password
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        // TODO: forgot password flow
                      },
                      child: Text(
                        '忘记密码？',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingMd),

                  // Login button
                  LingButton(
                    label: '登录',
                    variant: LingButtonVariant.filled,
                    size: LingButtonSize.large,
                    expanded: true,
                    loading: _isLoading,
                    onPressed: _isLoading ? null : _handleLogin,
                  ),
                  const SizedBox(height: AppConstants.spacingLg),

                  // Register link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '还没有账号？',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      TextButton(
                        onPressed: _goRegister,
                        child: Text(
                          '立即注册',
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
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppConstants.radiusXl),
          ),
          child: Icon(
            Icons.graphic_eq,
            size: 40,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: AppConstants.spacingMd),
        Text(
          'Nudgee',
          style: theme.textTheme.displayMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: AppConstants.spacingXs),
        Text(
          '语音中台客户端',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
