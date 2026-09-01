import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:nudgee/app/router/app_router.dart';
import 'package:nudgee/app/theme/app_colors.dart';
import 'package:nudgee/core/di/injector.dart';
import 'package:nudgee/core/extensions/context_extensions.dart';
import 'package:nudgee/core/services/auth_service.dart';
import 'package:nudgee/core/services/chat_service.dart';
import 'package:nudgee/core/services/post_service.dart';
import 'package:nudgee/core/services/prompt_template_service.dart';
import 'package:nudgee/core/services/schedule_service.dart';

/// Splash / loading page shown on app launch.
///
/// Displays an orbit carousel animation inspired by LingEchoX's web auth
/// right panel: concentric orbit rings with rotating icons + floating
/// particles around a central logo, on a soft blue gradient background.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Stopwatch _stopwatch;
  Timer? _navTimer;

  // Orbit config — large enough to overflow screen edges (like LingEchoX web).
  // Built in initState so each layer gets its own random harmonic params
  // (no two layers share the same chaotic signature).
  late final List<_OrbitConfig> _orbits;

  static const _particleCount = 80;
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

  final _particles = <_Particle>[];

  @override
  void initState() {
    super.initState();

    final rng = math.Random(0xC0FFEE);

    // Three layers, each with its own base spin + 3 random harmonics.
    // The harmonics make angular velocity wander (speed up / slow down /
    // briefly reverse) so the rotation never settles into a steady loop.
    _orbits = [
      _makeOrbit(rng, size: 240.0, baseSpeed: 0.45, iconCount: 4),
      _makeOrbit(rng, size: 420.0, baseSpeed: -0.32, iconCount: 6),
      _makeOrbit(rng, size: 600.0, baseSpeed: 0.22, iconCount: 8),
    ];

    for (var i = 0; i < _particleCount; i++) {
      _particles.add(_Particle(
        angle: rng.nextDouble() * math.pi * 2,
        radius: 60 + rng.nextDouble() * 360,
        speed: (rng.nextDouble() - 0.5) * 0.8,
      ));
    }

    _stopwatch = Stopwatch()..start();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _controller.addListener(_tick);

    _navTimer = Timer(const Duration(milliseconds: 2800), () async {
      if (!mounted) return;
      // Check auth status and navigate accordingly.
      try {
        final auth = sl<AuthService>();
        final isLoggedIn = await auth.checkAuthStatus();
        if (!mounted) return;
        if (isLoggedIn) {
          // Bind services to the restored user.
          final user = auth.currentUser.value;
          if (user != null) {
            sl<ScheduleService>().setUserId(user.id);
            sl<PostService>().setUserId(user.id);
            sl<ChatService>().setUserId(user.id);
            sl<PromptTemplateService>().setUserId(user.id);
          }
          context.go(AppRouter.home);
        } else {
          context.go(AppRouter.login);
        }
      } catch (_) {
        if (!mounted) return;
        context.go(AppRouter.login);
      }
    });
  }

  _OrbitConfig _makeOrbit(
    math.Random rng, {
    required double size,
    required double baseSpeed,
    required int iconCount,
  }) {
    final harmonics = <_Harmonic>[];
    for (var k = 0; k < 3; k++) {
      harmonics.add(_Harmonic(
        amp: 0.6 + rng.nextDouble() * 0.9, // angular-velocity wobble magnitude
        freq: 0.4 + rng.nextDouble() * 1.6, // wobble frequency (rad/s)
        phase: rng.nextDouble() * math.pi * 2,
      ));
    }
    // Per-icon drift: each icon gets its own slow phase + radial breathing
    // so they don't stay perfectly evenly spaced on the ring.
    final iconDrifts = <_IconDrift>[];
    for (var j = 0; j < iconCount; j++) {
      iconDrifts.add(_IconDrift(
        phaseSpeed: (rng.nextDouble() - 0.5) * 1.2,
        phaseAmp: 0.15 + rng.nextDouble() * 0.25,
        phaseOffset: rng.nextDouble() * math.pi * 2,
        radialFreq: 0.5 + rng.nextDouble() * 1.5,
        radialAmp: 6 + rng.nextDouble() * 14,
        radialPhase: rng.nextDouble() * math.pi * 2,
      ));
    }
    return _OrbitConfig(
      size: size,
      baseSpeed: baseSpeed,
      iconCount: iconCount,
      harmonics: harmonics,
      iconDrifts: iconDrifts,
    );
  }

  void _tick() {
    // Particles still integrate by dt; orbits read elapsed time directly so
    // the harmonic sum stays smooth regardless of frame rate.
    const dt = 1 / 60;
    for (final p in _particles) {
      p.angle += p.speed * dt;
    }
    if (mounted) setState(() {});
  }

  /// Layer angle at time [t] (seconds). Base spin + integrated harmonics:
  /// angle(t) = baseSpeed*t + Σ (-amp/freq) * cos(freq*t + phase)
  double _orbitAngle(_OrbitConfig orbit, double t) {
    var a = orbit.baseSpeed * t;
    for (final h in orbit.harmonics) {
      a += -h.amp / h.freq * math.cos(h.freq * t + h.phase);
    }
    return a;
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _controller.removeListener(_tick);
    _controller.dispose();
    _stopwatch.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE8F1FC),
              Color(0xFFF4F8FD),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Orbit animation — centered, overflows screen edges intentionally
              Center(
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
                            color:
                                AppColors.primary.withOpacity(0.12 + i * 0.04),
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
                                color:
                                    const Color(0xFF7EC2FF).withOpacity(0.3),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Center logo
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.85),
                            spreadRadius: 8,
                          ),
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.35),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom text + loading indicator
              Positioned(
                bottom: 80,
                left: 0,
                right: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Nudgee',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.splashTagline,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Offset _orbitPosition(int orbitIdx, int iconIdx) {
    final orbit = _orbits[orbitIdx];
    final t = _stopwatch.elapsedMilliseconds / 1000;
    final drift = orbit.iconDrifts[iconIdx];
    // Base ring angle (chaotic layer rotation) + even spacing + per-icon
    // wandering phase, so icons don't hold a fixed constellation.
    final angle = _orbitAngle(orbit, t) +
        (math.pi * 2 * iconIdx) / orbit.iconCount +
        drift.phaseAmp * math.sin(drift.phaseSpeed * t + drift.phaseOffset);
    // Radial breathing: each icon drifts in/out from the ring independently.
    final radius = orbit.size / 2 +
        drift.radialAmp * math.sin(drift.radialFreq * t + drift.radialPhase);
    return Offset(math.cos(angle) * radius, math.sin(angle) * radius);
  }

  Widget _orbitIcon(int orbitIdx, int iconIdx) {
    final icon = _icons[(orbitIdx * _orbits[orbitIdx].iconCount + iconIdx) %
        _icons.length];
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, size: 18, color: AppColors.primary),
    );
  }
}

class _Particle {
  double angle;
  final double radius;
  final double speed;
  _Particle({required this.angle, required this.radius, required this.speed});
}

/// One harmonic component of a layer's chaotic angular velocity.
/// omega(t) = baseSpeed + Σ amp_k * sin(freq_k * t + phase_k)
class _Harmonic {
  final double amp;
  final double freq;
  final double phase;
  const _Harmonic(
      {required this.amp, required this.freq, required this.phase});
}

/// Per-icon drift so icons on the same ring don't stay evenly spaced.
class _IconDrift {
  final double phaseSpeed;
  final double phaseAmp;
  final double phaseOffset;
  final double radialFreq;
  final double radialAmp;
  final double radialPhase;
  const _IconDrift({
    required this.phaseSpeed,
    required this.phaseAmp,
    required this.phaseOffset,
    required this.radialFreq,
    required this.radialAmp,
    required this.radialPhase,
  });
}

class _OrbitConfig {
  final double size;
  final double baseSpeed;
  final int iconCount;
  final List<_Harmonic> harmonics;
  final List<_IconDrift> iconDrifts;
  const _OrbitConfig({
    required this.size,
    required this.baseSpeed,
    required this.iconCount,
    required this.harmonics,
    required this.iconDrifts,
  });
}
