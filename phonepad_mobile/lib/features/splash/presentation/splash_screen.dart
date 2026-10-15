import 'package:flutter/material.dart';
import 'thinking_orb_painter.dart';

/// Clean, minimalist, and authentic Splash Screen with the 3D Thinking Orb
/// adapted from Developer Bucket (`thinking-orbs.html` / Libraries.dev).
///
/// Features:
/// - 3D Halftone Thinking Orb in Electric Blue (#38BDF8 / #0284C7)
/// - Clean typography and streamlined status
/// - Slender progress indicator
/// - 0ms skip/dismiss option
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

    // 1. Continuous orbital spin controller (Thinking Orb)
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    // 2. Boot progress controller
    _bootController = AnimationController(
      vsync: this,
      duration: widget.bootDuration,
    );

    // 3. Exit transition controller
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
    _bootController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _orbitController,
        _bootController,
        _exitController,
      ]),
      builder: (context, _) {
        final orbitValue = _orbitController.value;
        final bootProgress = _bootController.value;

        return Scaffold(
          backgroundColor: const Color(0xFF07090E),
          body: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Stack(
                children: [
                  // 1. Ambient Background Blue Glow
                  Positioned(
                    top: -120,
                    right: -120,
                    child: Container(
                      width: 360,
                      height: 360,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF0284C7).withValues(alpha: 0.12),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -100,
                    left: -100,
                    child: Container(
                      width: 320,
                      height: 320,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF38BDF8).withValues(alpha: 0.10),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 2. Center Hero Stage (Developer Bucket 3D Thinking Orb)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 3D Halftone Thinking Orb in Blue Palette
                        SizedBox(
                          width: 220,
                          height: 220,
                          child: CustomPaint(
                            key: const Key('thinking_orb_custom_paint'),
                            size: const Size(220, 220),
                            painter: ThinkingOrbPainter(
                              animationProgress: orbitValue,
                              primaryColor: const Color(0xFF38BDF8),
                              accentColor: const Color(0xFF60A5FA),
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Clean Minimal Brand Title
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Phone',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              'Pad',
                              style: TextStyle(
                                color: const Color(0xFF38BDF8),
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                shadows: [
                                  Shadow(
                                    color: const Color(0xFF38BDF8).withValues(alpha: 0.65),
                                    blurRadius: 18,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 6),

                        // Subtitle with Ping Dot
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: const Color(0xFF38BDF8),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF38BDF8),
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
                                color: Color(0xFF94A3B8),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 40),

                        // Simple, Sleek Progress Section
                        SizedBox(
                          width: 240,
                          child: Column(
                            children: [
                              Text(
                                _currentStep,
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Minimal 3px Slender Progress Bar
                              Container(
                                width: 240,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  width: 240 * bootProgress.clamp(0.0, 1.0),
                                  height: 3,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF0284C7),
                                        Color(0xFF38BDF8),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF38BDF8).withValues(alpha: 0.6),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
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
                          color: const Color(0xFF94A3B8).withValues(alpha: 0.4),
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
