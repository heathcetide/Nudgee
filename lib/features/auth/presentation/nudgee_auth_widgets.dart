import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:nudgee/app/theme/app_colors.dart';
import 'package:nudgee/core/extensions/context_extensions.dart';

/// ─── Auth mode ───────────────────────────────────────────────────────
enum NudgeeAuthMode { login, signup }

/// ─── NudgeeAuthLogo ────────────────────────────────────────────────────
/// Logo in a rounded white container with ring, matching LingEchoX header.
class NudgeeAuthLogo extends StatelessWidget {
  final String logoAsset;
  final double size;
  final double iconSize;

  const NudgeeAuthLogo({
    super.key,
    this.logoAsset = 'assets/images/logo.png',
    this.size = 48,
    this.iconSize = 36,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(size * 0.25),
        border: Border.all(color: Theme.of(context).dividerColor, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.25),
        child: Image.asset(
          logoAsset,
          fit: BoxFit.contain,
          width: iconSize,
          height: iconSize,
        ),
      ),
    );
  }
}

/// ─── NudgeeAuthTextField ───────────────────────────────────────────────
/// Filled-style text field matching LingEchoX's `variant="filled" size="lg"`.
/// - Light gray background
/// - Rounded corners
/// - Prefix icon
/// - Optional suffix (e.g. "send code" button)
class NudgeeAuthTextField extends StatelessWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? label;
  final String hint;
  final IconData prefixIcon;
  final Widget? suffix;
  final bool obscureText;
  final String? errorText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final int? maxLength;

  const NudgeeAuthTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    required this.hint,
    required this.prefixIcon,
    this.suffix,
    this.obscureText = false,
    this.errorText,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.enabled = true,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    // theme unused
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              label!,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        TextField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          enabled: enabled,
          maxLength: maxLength,
          style: TextStyle(
            fontSize: 16,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(150),
              fontSize: 15,
            ),
            prefixIcon: Icon(prefixIcon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(150)),
            suffixIcon: suffix,
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            counterText: '',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.error, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.error, width: 2),
            ),
            errorText: errorText,
            errorStyle: TextStyle(color: AppColors.error, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

/// ─── NudgeeAuthSubmitButton ────────────────────────────────────────────
/// Black rounded button matching LingEchoX's
/// `!h-11 !rounded-xl !bg-neutral-900 !text-white`.
class NudgeeAuthSubmitButton extends StatefulWidget {
  final String text;
  final bool loading;
  final VoidCallback? onPressed;

  const NudgeeAuthSubmitButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.loading = false,
  });

  @override
  State<NudgeeAuthSubmitButton> createState() => _NudgeeAuthSubmitButtonState();
}

class _NudgeeAuthSubmitButtonState extends State<NudgeeAuthSubmitButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scale = Tween<double>(begin: 1, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.loading || widget.onPressed == null;
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: disabled ? null : widget.onPressed,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            color: disabled ? Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(150) : Theme.of(context).colorScheme.onSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: widget.loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Text(
                  widget.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}

/// ─── LingSocialButton ────────────────────────────────────────────────
/// Outline social login button matching LingEchoX's outline style.
/// Accepts a [iconWidget] (e.g. `Brand(Brands.wechat)`) for brand logos.
class LingSocialButton extends StatelessWidget {
  final Widget iconWidget;
  final String label;
  final VoidCallback? onPressed;

  const LingSocialButton({
    super.key,
    required this.iconWidget,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 20, height: 20, child: iconWidget),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ─── LingCodeButton ──────────────────────────────────────────────────
/// Inline "send verification code" button for use as a TextField suffix.
/// Shows countdown timer after sending.
class LingCodeButton extends StatelessWidget {
  final int countdown;
  final bool sending;
  final VoidCallback? onTap;

  const LingCodeButton({
    super.key,
    required this.countdown,
    required this.sending,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final canSend = countdown == 0 && !sending && onTap != null;
    return GestureDetector(
      onTap: canSend ? onTap : null,
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        height: 32,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: canSend
              ? Theme.of(context).colorScheme.primary.withOpacity(0.08)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: sending
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              )
            : Text(
                countdown > 0 ? '${countdown}s' : context.l10n.authSendCode,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.0,
                  color: canSend
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(150),
                  fontWeight: canSend ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
      ),
    );
  }
}

/// ─── NudgeeAuthDivider ─────────────────────────────────────────────────
/// "其他登录方式" divider matching LingEchoX.
class NudgeeAuthDivider extends StatelessWidget {
  final String label;
  const NudgeeAuthDivider({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: Theme.of(context).dividerColor,
            thickness: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(150),
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: Theme.of(context).dividerColor,
            thickness: 1,
          ),
        ),
      ],
    );
  }
}

/// ─── LingOrbitCarousel ───────────────────────────────────────────────
/// Simplified Flutter port of LingEchoX's AuthCarousel.
///
/// Shows the logo in the center with orbiting icon dots and particles.
/// Used as a decorative element on tablet/desktop auth screens.
class LingOrbitCarousel extends StatefulWidget {
  final String logoAsset;
  final String title;
  final String? subtitle;

  const LingOrbitCarousel({
    super.key,
    this.logoAsset = 'assets/images/logo.png',
    this.title = 'Nudgee',
    this.subtitle,
  });

  @override
  State<LingOrbitCarousel> createState() => _LingOrbitCarouselState();
}

class _LingOrbitCarouselState extends State<LingOrbitCarousel>
    with SingleTickerProviderStateMixin {
  late final TickerProvider _vsync = this;
  late final AnimationController _controller;

  static const _orbits = [
    (size: 140.0, speed: 0.0012, iconCount: 4),
    (size: 240.0, speed: -0.0026, iconCount: 6),
    (size: 340.0, speed: 0.0036, iconCount: 8),
  ];

  static const _particleCount = 40;
  static const _icons = [
    Icons.mic,
    Icons.graphic_eq,
    Icons.videocam,
    Icons.phone,
    Icons.cloud,
    Icons.hub,
    Icons.surround_sound,
    Icons.stream,
  ];

  final _orbitAngles = <double>[0, 0, 0];
  final _particles = <_Particle>[];

  @override
  void initState() {
    super.initState();
    final rng = math.Random();
    for (var i = 0; i < _particleCount; i++) {
      _particles.add(_Particle(
        angle: rng.nextDouble() * math.pi * 2,
        radius: 40 + rng.nextDouble() * 200,
        speed: (rng.nextDouble() - 0.5) * 0.02,
      ));
    }
    _controller = AnimationController(
      vsync: _vsync,
      duration: const Duration(seconds: 1),
    )..repeat();
    _controller.addListener(_tick);
  }

  void _tick() {
    for (var i = 0; i < _orbits.length; i++) {
      _orbitAngles[i] += _orbits[i].speed * 1000;
    }
    for (final p in _particles) {
      p.angle += p.speed;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_tick);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFE8F1FC),
            Color(0xFFF4F8FD),
            Colors.white,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor, width: 1),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Orbit rings
          for (var i = 0; i < _orbits.length; i++)
            Container(
              width: _orbits[i].size,
              height: _orbits[i].size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.12 + i * 0.04),
                  width: 1,
                ),
              ),
            ),

          // Orbiting icons
          for (var i = 0; i < _orbits.length; i++)
            for (var j = 0; j < _orbits[i].iconCount; j++)
              Transform.translate(
                offset: _orbitPosition(i, j),
                child: _orbitIcon(i, j),
              ),

          // Particles
          for (final p in _particles)
            Transform.translate(
              offset: Offset(
                math.cos(p.angle) * p.radius,
                math.sin(p.angle) * p.radius,
              ),
              child: Container(
                width: 3,
                height: 3,
                decoration: BoxDecoration(
                  color: const Color(0xFF7EC2FF).withOpacity(0.5),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7EC2FF).withOpacity(0.3),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),

          // Center logo
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.85),
                  spreadRadius: 7,
                ),
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.35),
                  blurRadius: 18,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Image.asset(widget.logoAsset, fit: BoxFit.contain),
            ),
          ),

          // Bottom text
          Positioned(
            bottom: 32,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.subtitle ?? context.l10n.splashTagline,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Offset _orbitPosition(int orbitIdx, int iconIdx) {
    final orbit = _orbits[orbitIdx];
    final angle = _orbitAngles[orbitIdx] +
        (math.pi * 2 * iconIdx) / orbit.iconCount;
    return Offset(
      math.cos(angle) * orbit.size / 2,
      math.sin(angle) * orbit.size / 2,
    );
  }

  Widget _orbitIcon(int orbitIdx, int iconIdx) {
    final icon = _icons[iconIdx % _icons.length];
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withAlpha(20),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
    );
  }
}

class _Particle {
  double angle;
  final double radius;
  final double speed;
  _Particle({required this.angle, required this.radius, required this.speed});
}

/// ─── NudgeeAuthErrorBanner ─────────────────────────────────────────────
/// Amber warning banner matching LingEchoX's device-verify alert style.
class NudgeeAuthErrorBanner extends StatelessWidget {
  final String message;
  final bool isWarning;

  const NudgeeAuthErrorBanner({
    super.key,
    required this.message,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isWarning ? const Color(0xFFFFFBEB) : const Color(0xFFFEF2F2);
    final border = isWarning ? const Color(0xFFFDE68A) : const Color(0xFFFECACA);
    final text = isWarning ? const Color(0xFF92400E) : const Color(0xFF991B1B);
    final icon = isWarning ? Icons.warning_amber : Icons.error_outline;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: text, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: text, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
