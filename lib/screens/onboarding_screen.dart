import 'dart:math';
import 'package:flutter/material.dart';
import 'package:majorproject_app/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  int _phase = 0; // 0: Logo, 1: Text, 2: Flash out

  // Phase 0 — Logo animations
  late AnimationController _logoController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;

  // Phase 1 — Letter animations
  late AnimationController _letterController;
  late AnimationController _lineController;
  late AnimationController _taglineController;

  // Phase 2 — Flash out
  late AnimationController _flashController;

  // Background orb animations
  late AnimationController _orb1Controller;
  late AnimationController _orb2Controller;

  // Logo pulse
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final String _brandName = 'e-pasal';

  @override
  void initState() {
    super.initState();

    // ── Background Orbs ──
    _orb1Controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();

    _orb2Controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    // ── Phase 0: Logo ──
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _logoScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOut),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOut),
    );

    // Logo pulse glow
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // ── Phase 1: Letters ──
    _letterController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _brandName.length * 80 + 400),
    );

    _lineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _taglineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // ── Phase 2: Flash ──
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _runSequence();
  }

  Future<void> _runSequence() async {
    // Phase 0: Show logo
    _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 800));

    // Transition to Phase 1
    if (!mounted) return;
    setState(() => _phase = 1);
    await Future.delayed(const Duration(milliseconds: 100));

    // Animate letters
    _letterController.forward();
    await Future.delayed(const Duration(milliseconds: 800));

    // Animate gradient line
    _lineController.forward();
    await Future.delayed(const Duration(milliseconds: 400));

    // Animate tagline
    _taglineController.forward();
    await Future.delayed(const Duration(milliseconds: 1000));

    // Phase 2: Flash out
    if (!mounted) return;
    setState(() => _phase = 2);
    _flashController.forward();
    await Future.delayed(const Duration(milliseconds: 800));

    // Complete onboarding
    if (!mounted) return;
    _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    if (mounted) {
      Provider.of<AuthProvider>(context, listen: false).completeOnboarding();
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _letterController.dispose();
    _lineController.dispose();
    _taglineController.dispose();
    _flashController.dispose();
    _orb1Controller.dispose();
    _orb2Controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Stack(
        children: [
          // ── Animated Background Orbs ──
          _buildOrb(
            controller: _orb1Controller,
            size: size.width * 0.9,
            color: const Color(0xFF6366F1).withOpacity(0.20),
            baseOffset: Offset(-size.width * 0.15, -size.height * 0.08),
            xRange: 100,
            yRange: 50,
          ),
          _buildOrb(
            controller: _orb2Controller,
            size: size.width * 1.1,
            color: const Color(0xFF818CF8).withOpacity(0.10),
            baseOffset: Offset(size.width * 0.3, size.height * 0.6),
            xRange: -100,
            yRange: 100,
          ),

          // ── Main Content ──
          Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.9, end: 1.0).animate(
                      CurvedAnimation(
                          parent: animation, curve: Curves.easeOut),
                    ),
                    child: child,
                  ),
                );
              },
              child: _phase == 0
                  ? _buildLogoPhase()
                  : _phase == 1
                      ? _buildTextPhase()
                      : const SizedBox.shrink(),
            ),
          ),

          // ── Phase 2: Flash Overlay ──
          if (_phase == 2)
            AnimatedBuilder(
              animation: _flashController,
              builder: (context, _) {
                return Opacity(
                  opacity: _flashController.value,
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: const Color(0xFF050505),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ── Phase 0: Logo Icon ──
  Widget _buildLogoPhase() {
    return AnimatedBuilder(
      key: const ValueKey('logo'),
      animation: _logoController,
      builder: (context, child) {
        return Opacity(
          opacity: _logoOpacity.value,
          child: Transform.scale(
            scale: _logoScale.value,
            child: child,
          ),
        );
      },
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(
                color: Colors.white.withOpacity(0.12),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1)
                      .withOpacity(0.25 * _pulseAnimation.value),
                  blurRadius: 60,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Icon(
              Icons.store_rounded,
              size: 80,
              color: Color.lerp(
                const Color(0xFF6366F1),
                const Color(0xFF818CF8),
                _pulseAnimation.value,
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Phase 1: Animated Text ──
  Widget _buildTextPhase() {
    final letters = _brandName.split('');

    return Column(
      key: const ValueKey('text'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Animated letters
        SizedBox(
          height: 80,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(letters.length, (i) {
              // Each letter has its own staggered animation
              final letterStart = (i * 0.08) /
                  (_letterController.duration!.inMilliseconds / 1000);
              final letterEnd = letterStart + 0.4;
              final letterAnimation = Tween<double>(begin: 0.0, end: 1.0)
                  .animate(CurvedAnimation(
                parent: _letterController,
                curve: Interval(
                  letterStart.clamp(0.0, 1.0),
                  letterEnd.clamp(0.0, 1.0),
                  curve: Curves.elasticOut,
                ),
              ));

              return AnimatedBuilder(
                animation: letterAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, 80 * (1 - letterAnimation.value)),
                    child: Opacity(
                      opacity: letterAnimation.value.clamp(0.0, 1.0),
                      child: child,
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Text(
                    letters[i],
                    style: const TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -2,
                      height: 1.0,
                      fontFamily: 'Outfit',
                      shadows: [
                        Shadow(
                          color: Color(0x1A000000),
                          blurRadius: 30,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),

        const SizedBox(height: 16),

        // Animated gradient line
        AnimatedBuilder(
          animation: _lineController,
          builder: (context, _) {
            return Container(
              height: 4,
              width: 200 * _lineController.value,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    const Color(0xFF6366F1).withOpacity(_lineController.value),
                    Colors.transparent,
                  ],
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 24),

        // Animated tagline
        AnimatedBuilder(
          animation: _taglineController,
          builder: (context, _) {
            return Transform.translate(
              offset: Offset(0, 10 * (1 - _taglineController.value)),
              child: Opacity(
                opacity: _taglineController.value,
                child: const Text(
                  'YOUR SMART MARKETPLACE',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 4,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ── Animated Background Orb ──
  Widget _buildOrb({
    required AnimationController controller,
    required double size,
    required Color color,
    required Offset baseOffset,
    required double xRange,
    required double yRange,
  }) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value * 2 * pi;
        final dx = baseOffset.dx + sin(t) * xRange;
        final dy = baseOffset.dy + cos(t) * yRange;
        final scale = 1.0 + 0.2 * sin(t * 0.7);

        return Positioned(
          left: dx,
          top: dy,
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color,
                    blurRadius: 120,
                    spreadRadius: 40,
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
