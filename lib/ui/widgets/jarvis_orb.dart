import 'dart:math';

import 'package:flutter/material.dart';

import '../../pipeline/pipeline_controller.dart';
import '../theme/app_theme.dart';

/// The centrepiece: a large glowing, sun-like JARVIS orb that pulses while the
/// app is listening or speaking. Rendered with a [CustomPainter] so the glow,
/// corona and rotating rings stay crisp at any size.
class JarvisOrb extends StatefulWidget {
  const JarvisOrb({
    super.key,
    required this.status,
    this.size = 260,
  });

  final PipelineStatus status;
  final double size;

  @override
  State<JarvisOrb> createState() => _JarvisOrbState();
}

class _JarvisOrbState extends State<JarvisOrb>
    with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _spin.dispose();
    super.dispose();
  }

  Color get _coreColor => switch (widget.status) {
        PipelineStatus.listening => JarvisColors.coreGlow,
        PipelineStatus.thinking => const Color(0xFFB388FF),
        PipelineStatus.speaking => const Color(0xFF7CF7C4),
        PipelineStatus.error => const Color(0xFFFF6B7A),
        PipelineStatus.idle => JarvisColors.coreGlow,
      };

  double get _intensity => switch (widget.status) {
        PipelineStatus.idle => 0.55,
        PipelineStatus.listening => 1.0,
        PipelineStatus.thinking => 0.8,
        PipelineStatus.speaking => 1.0,
        PipelineStatus.error => 0.7,
      };

  @override
  Widget build(BuildContext context) {
    final active = widget.status == PipelineStatus.listening ||
        widget.status == PipelineStatus.speaking;
    return AnimatedBuilder(
      animation: Listenable.merge([_pulse, _spin]),
      builder: (context, _) {
        final pulseValue = active
            ? 0.5 + 0.5 * (sin(_pulse.value * pi))
            : 0.15 + 0.1 * (sin(_pulse.value * pi));
        return CustomPaint(
          size: Size.square(widget.size),
          painter: _OrbPainter(
            core: _coreColor,
            intensity: _intensity,
            pulse: pulseValue,
            rotation: _spin.value * 2 * pi,
          ),
        );
      },
    );
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter({
    required this.core,
    required this.intensity,
    required this.pulse,
    required this.rotation,
  });

  final Color core;
  final double intensity;
  final double pulse;
  final double rotation;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final baseRadius = size.width * 0.30;
    final glowRadius = baseRadius * (1.35 + pulse * 0.5);

    // Outer atmospheric glow (the "sun corona").
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          core.withValues(alpha: 0.55 * intensity),
          core.withValues(alpha: 0.18 * intensity),
          core.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: glowRadius));
    canvas.drawCircle(center, glowRadius, glowPaint);

    // Rotating corona rays for the sun-like feel.
    _drawRays(canvas, center, baseRadius, glowRadius);

    // Bright molten core.
    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          JarvisColors.coreHot,
          core,
          core.withValues(alpha: 0.85),
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: baseRadius));
    canvas.drawCircle(center, baseRadius, corePaint);

    // Inner highlight for depth.
    final highlight = Paint()
      ..color = Colors.white.withValues(alpha: 0.5 * intensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawCircle(
      center.translate(-baseRadius * 0.25, -baseRadius * 0.25),
      baseRadius * 0.35,
      highlight,
    );

    // Thin orbiting ring (JARVIS HUD accent).
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = core.withValues(alpha: 0.4);
    canvas.drawCircle(center, glowRadius * 0.82, ringPaint);
  }

  void _drawRays(
    Canvas canvas,
    Offset center,
    double baseRadius,
    double glowRadius,
  ) {
    const rayCount = 48;
    final rayPaint = Paint()
      ..color = core.withValues(alpha: 0.22 * intensity)
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < rayCount; i++) {
      final angle = rotation + (i / rayCount) * 2 * pi;
      final wobble = 0.5 + 0.5 * sin(angle * 3 + rotation * 2);
      final inner = baseRadius * 1.05;
      final outer = baseRadius * (1.15 + 0.35 * wobble * (0.6 + pulse));
      rayPaint.strokeWidth = 1.2 + wobble * 1.6;
      canvas.drawLine(
        center + Offset(cos(angle), sin(angle)) * inner,
        center + Offset(cos(angle), sin(angle)) * outer,
        rayPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OrbPainter oldDelegate) =>
      oldDelegate.pulse != pulse ||
      oldDelegate.rotation != rotation ||
      oldDelegate.core != core ||
      oldDelegate.intensity != intensity;
}
