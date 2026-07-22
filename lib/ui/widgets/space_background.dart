import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A blue-to-black space backdrop with a slowly twinkling starfield, painted
/// with a [CustomPainter] so it scales cleanly on every platform.
class SpaceBackground extends StatefulWidget {
  const SpaceBackground({super.key, this.child});

  final Widget? child;

  @override
  State<SpaceBackground> createState() => _SpaceBackgroundState();
}

class _SpaceBackgroundState extends State<SpaceBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Star> _stars;

  @override
  void initState() {
    super.initState();
    final random = Random(42);
    _stars = List.generate(140, (_) {
      return _Star(
        position: Offset(random.nextDouble(), random.nextDouble()),
        radius: random.nextDouble() * 1.4 + 0.3,
        phase: random.nextDouble() * 2 * pi,
        twinkleSpeed: random.nextDouble() * 1.5 + 0.5,
      );
    });
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _SpacePainter(_stars, _controller.value),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _Star {
  const _Star({
    required this.position,
    required this.radius,
    required this.phase,
    required this.twinkleSpeed,
  });

  final Offset position;
  final double radius;
  final double phase;
  final double twinkleSpeed;
}

class _SpacePainter extends CustomPainter {
  _SpacePainter(this.stars, this.t);

  final List<_Star> stars;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    const gradient = RadialGradient(
      center: Alignment(0, -0.2),
      radius: 1.2,
      colors: [
        JarvisColors.spaceNavy,
        JarvisColors.deepSpace,
        Color(0xFF01020A),
      ],
      stops: [0.0, 0.55, 1.0],
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));

    final starPaint = Paint()..color = Colors.white;
    for (final star in stars) {
      final twinkle =
          (sin(t * 2 * pi * star.twinkleSpeed + star.phase) + 1) / 2;
      final opacity = 0.25 + twinkle * 0.75;
      starPaint.color = Colors.white.withValues(alpha: opacity);
      canvas.drawCircle(
        Offset(star.position.dx * size.width, star.position.dy * size.height),
        star.radius,
        starPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpacePainter oldDelegate) =>
      oldDelegate.t != t;
}
