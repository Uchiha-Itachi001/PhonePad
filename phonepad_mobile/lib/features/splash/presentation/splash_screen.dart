import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spring_bounce_tap.dart';
import 'border_glow_badge.dart';
import 'circling_particle_ring_painter.dart';
import 'wave_photon_progress_bar.dart';

/// Full-screen cinematic Splash Screen adapted from Developer Bucket components:
/// - Circling Particle Orbital Ring (`circling-particle-ring.html`)
/// - Specular Conic Border Glow Squircle (`border-glow.html`)
/// - Wave-Light Radial Photon Progress Bar (`wave-progress-bar.html`)
/// - Dynamic Spring Physics & Glassmorphism (`user-preference-dna.json`)
class SplashScreen extends StatefulWidget {
  final VoidCallback onFinish;
  final Duration bootDuration;
  final bool autoDismiss;

  const SplashScreen({
    super.key,
    required this.onFinish,
    this.bootDuration = const Duration(milliseconds: 2200),
    this.autoDismiss = true,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _orbitController;
  late final AnimationController _pulseController;
  late final AnimationController _bootController;
  late final AnimationController _exitController;

  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  final List<String> _steps = const [
    'Initializing touch digitizer...',
    'Scanning local Wi-Fi subnet for PC...',
    'Calibrating 120Hz gesture engine...',
    'PhonePad Ready.',
  ];

  String _currentStep = 'Initializing touch digitizer...';

  @override
  void initState() {
    super.initState();

    // 1. Continuous orbital spin controller (counter-rotating particles)
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    // 2. Ambient breathing pulse controller
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    // 3. Boot progress controller
    _bootController = AnimationController(
      vsync: this,
      duration: widget.bootDuration,
    );

    // 4. Exit transition controller (smooth scale-down & fade-out)
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeInCubic),
    );

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeOut),
    );

    _bootController.addListener(() {
      final p = _bootController.value;
      String nextStep;
      if (p < 0.3) {
        nextStep = _steps[0];
      } else if (p < 0.65) {
        nextStep = _steps[1];
      } else if (p < 0.95) {
        nextStep = _steps[2];
      } else {
        nextStep = _steps[3];
      }

      if (nextStep != _currentStep && mounted) {
        setState(() {
          _currentStep = nextStep;
        });
      }
    });

    _bootController.addStatusListener((status) {
      if (status == AnimationStatus.completed && widget.autoDismiss && mounted) {
        _handleFinish();
      }
    });

    if (widget.bootDuration > Duration.zero) {
      _bootController.forward();
    } else {
      _bootController.value = 1.0;
      if (widget.autoDismiss) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _handleFinish());
      }
    }
  }

  void _handleFinish() {
    if (_exitController.isAnimating || _exitController.isCompleted) return;

    _exitController.forward().then((_) {
      if (mounted) {
        widget.onFinish();
      }
    });
  }

  @override
  void dispose() {
    _orbitController.dispose();
    _pulseController.dispose();
    _bootController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _orbitController,
        _pulseController,
        _bootController,
        _exitController,
      ]),
      builder: (context, _) {
        final orbitValue = _orbitController.value;
        final pulseValue = _pulseController.value;
        final bootProgress = _bootController.value;

        return Scaffold(
          backgroundColor: PhonePadColors.backgroundPrimary,
          body: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Stack(
                children: [
                  // 1. Ambient Background Gradient Spots
                  Positioned(
                    top: -100,
                    right: -100,
                    child: Container(
                      width: 320,
                      height: 320,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            PhonePadColors.accentEmerald.withValues(alpha: 0.12),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -80,
                    left: -80,
                    child: Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            PhonePadColors.accentCyan.withValues(alpha: 0.10),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 2. Top Skip Button (For immediate bypass)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 12,
                    right: 20,
                    child: SpringBounceTap(
                      onTap: _handleFinish,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              bootProgress >= 1.0 ? 'Launch' : 'Skip',
                              style: const TextStyle(
                                color: PhonePadColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 11,
                              color: PhonePadColors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 3. Center Hero Stage (Orbital Particles + BorderGlow Badge)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 260,
                          height: 260,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Circling Particle Ring Canvas
                              CustomPaint(
                                size: const Size(260, 260),
                                painter: CirclingParticleRingPainter(
                                  animationValue: orbitValue,
                                  pulseValue: pulseValue,
                                ),
                              ),

                              // Central Conic Border Glow Squircle
                              BorderGlowBadge(
                                rotationAngle: orbitValue * 2 * math.pi,
                                pulse: pulseValue,
                                size: 108,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Brand Title & Animated Status Chip
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Phone',
                              style: TextStyle(
                                color: PhonePadColors.textPrimary,
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              'Pad',
                              style: TextStyle(
                                color: PhonePadColors.accentEmerald,
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                shadows: [
                                  Shadow(
                                    color: PhonePadColors.accentEmerald.withValues(alpha: 0.6),
                                    blurRadius: 16,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 6),

                        // Subtitle with Live Ping Dot
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: PhonePadColors.accentCyan,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: PhonePadColors.accentCyan,
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'NATIVE REAL-TIME WI-FI TRACKPAD',
                              style: TextStyle(
                                color: PhonePadColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 48),

                        // Wave Photon Progress Bar
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: WavePhotonProgressBar(
                            progress: bootProgress,
                            sweepProgress: (orbitValue * 2) % 1.0,
                            statusText: _currentStep,
                            maxWidth: 340,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 4. Bottom Footer Specs
                  Positioned(
                    bottom: MediaQuery.of(context).padding.bottom + 16,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Text(
                        '120Hz Low Latency • Zero-Overhead Protocol',
                        style: TextStyle(
                          color: PhonePadColors.textSecondary.withValues(alpha: 0.5),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
