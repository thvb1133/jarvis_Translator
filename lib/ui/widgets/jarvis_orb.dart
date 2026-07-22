import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../pipeline/pipeline_controller.dart';
import '../theme/app_theme.dart';

/// The centrepiece: a large glowing, sun-like JARVIS orb wrapped in a live
/// circular voice visualizer. The ring of bars reacts to the real microphone
/// level while listening and animates like a talking assistant while speaking,
/// so it reads as a live AI interpreter.
class JarvisOrb extends StatefulWidget {
  const JarvisOrb({
    super.key,
    required this.status,
    this.level,
    this.size = 320,
  });

  final PipelineStatus status;

  /// Live normalized mic level (0..1); drives the visualizer while listening.
  final ValueListenable<double>? level;

  final double size;

  @override
  State<JarvisOrb> createState() => _JarvisOrbState();
}

class _JarvisOrbState extends State<JarvisOrb> with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _spin;
  late final AnimationController _talk;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    )..repeat();
    _talk = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _spin.dispose();
    _talk.dispose();
    super.dispose();
  }

  Color get _coreColor => switch (widget.status) {
        PipelineStatus.listening => JarvisColors.coreGlow,
        PipelineStatus.thinking => const Color(0xFFB388FF),
        PipelineStatus.speaking => const Color(0xFF7CF7C4),
        PipelineStatus.error => const Color(0xFFFF6B7A),
        PipelineStatus.idle => JarvisColors.coreGlow,
      };

  double get _baseIntensity => switch (widget.status) {
        PipelineStatus.idle => 0.55,
        PipelineStatus.listening => 0.9,
        PipelineStatus.thinking => 0.8,
        PipelineStatus.speaking => 1.0,
        PipelineStatus.error => 0.7,
      };

  @override
  Widget build(BuildContext context) {
    final listenables = <Listenable>[_pulse, _spin, _talk];
    if (widget.level != null) listenables.add(widget.level!);

    return AnimatedBuilder(
      animation: Listenable.merge(listenables),
      builder: (context, _) {
        final micLevel = widget.level?.value ?? 0.0;
        return CustomPaint(
          size: Size.square(widget.size),
          painter: _OrbPainter(
            core: _coreColor,
            intensity: _baseIntensity,
            status: widget.status,
            micLevel: micLevel,
            pulseT: _pulse.value,
            spinT: _spin.value,
            talkT: _talk.value,
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
    required this.status,
    required this.micLevel,
    required this.pulseT,
    required this.spinT,
    required this.talkT,
  });

  final Color core;
  final double intensity;
  final PipelineStatus status;
  final double micLevel;
  final double pulseT;
  final double spinT;
  final double talkT;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.width / 2;
    final coreRadius = maxRadius * 0.34;

    final active =
        status == PipelineStatus.listening || status == PipelineStatus.speaking;
    final pulse = active
        ? 0.5 + 0.5 * sin(pulseT * pi)
        : 0.2 + 0.1 * sin(pulseT * pi);

    _drawGlow(canvas, center, coreRadius, pulse);
    _drawVisualizer(canvas, center, coreRadius, maxRadius);
    _drawCorona(canvas, center, coreRadius, pulse);
    _drawCore(canvas, center, coreRadius, pulse);
    _drawHudRings(canvas, center, maxRadius);
  }

  void _drawGlow(Canvas canvas, Offset center, double coreRadius, double pulse) {
    final glowRadius = coreRadius * (1.9 + pulse * 0.6 + micLevel * 0.8);
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          core.withValues(alpha: 0.45 * intensity),
          core.withValues(alpha: 0.14 * intensity),
          core.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: glowRadius));
    canvas.drawCircle(center, glowRadius, glow);
  }

  /// The live voice visualizer: a symmetric ring of bars that bounces with the
  /// mic level (listening) or a talking rhythm (speaking).
  void _drawVisualizer(
    Canvas canvas,
    Offset center,
    double coreRadius,
    double maxRadius,
  ) {
    const bars = 72;
    final inner = coreRadius * 1.18;
    final maxBar = maxRadius - inner - 6;
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < bars; i++) {
      final angle = spinT * 2 * pi + (i / bars) * 2 * pi;
      final amp = _barAmplitude(i, bars);
      final barLen = maxBar * (0.08 + amp * 0.92);
      final dir = Offset(cos(angle), sin(angle));
      paint
        ..strokeWidth = 2.2 + amp * 2.5
        ..color = core.withValues(alpha: (0.25 + amp * 0.6) * intensity);
      canvas.drawLine(
        center + dir * inner,
        center + dir * (inner + barLen),
        paint,
      );
    }
  }

  /// Per-bar amplitude in 0..1 depending on the current state.
  double _barAmplitude(int i, int bars) {
    // Symmetric index so the spectrum mirrors across the orb (voice-assistant
    // look) rather than being random noise.
    final sym = (i <= bars / 2 ? i : bars - i) / (bars / 2);
    switch (status) {
      case PipelineStatus.speaking:
        // A lively, multi-harmonic "talking" pattern.
        final t = talkT * 2 * pi;
        final a = 0.5 +
            0.30 * sin(t * 2 + sym * 6) +
            0.20 * sin(t * 3 + sym * 11) +
            0.15 * sin(t * 5 + i * 0.7);
        return (0.25 + a.abs() * 0.75).clamp(0.0, 1.0);
      case PipelineStatus.listening:
        final wobble = 0.5 + 0.5 * sin(talkT * 2 * pi * 2 + i * 0.9);
        final base = 0.12 + micLevel * (0.55 + 0.45 * wobble);
        return base.clamp(0.0, 1.0);
      case PipelineStatus.thinking:
        final t = talkT * 2 * pi;
        return (0.18 + 0.18 * (0.5 + 0.5 * sin(t * 1.5 + sym * 4)))
            .clamp(0.0, 1.0);
      case PipelineStatus.idle:
      case PipelineStatus.error:
        final t = pulseT * 2 * pi;
        return (0.08 + 0.07 * (0.5 + 0.5 * sin(t + i * 0.5)))
            .clamp(0.0, 1.0);
    }
  }

  void _drawCorona(
      Canvas canvas, Offset center, double coreRadius, double pulse) {
    const rayCount = 60;
    final paint = Paint()
      ..color = core.withValues(alpha: 0.18 * intensity)
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < rayCount; i++) {
      final angle = -spinT * 2 * pi + (i / rayCount) * 2 * pi;
      final wobble = 0.5 + 0.5 * sin(angle * 3 - spinT * 4 * pi);
      final innerR = coreRadius * 1.02;
      final outerR = coreRadius * (1.08 + 0.22 * wobble * (0.6 + pulse));
      paint.strokeWidth = 1.0 + wobble * 1.4;
      canvas.drawLine(
        center + Offset(cos(angle), sin(angle)) * innerR,
        center + Offset(cos(angle), sin(angle)) * outerR,
        paint,
      );
    }
  }

  void _drawCore(Canvas canvas, Offset center, double coreRadius, double pulse) {
    final r = coreRadius * (1 + micLevel * 0.06 + (pulse - 0.5) * 0.04);
    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          JarvisColors.coreHot,
          core,
          core.withValues(alpha: 0.9),
        ],
        stops: const [0.0, 0.62, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, corePaint);

    final highlight = Paint()
      ..color = Colors.white.withValues(alpha: 0.5 * intensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22);
    canvas.drawCircle(
      center.translate(-r * 0.28, -r * 0.28),
      r * 0.34,
      highlight,
    );
  }

  void _drawHudRings(Canvas canvas, Offset center, double maxRadius) {
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = core.withValues(alpha: 0.22 * intensity);
    canvas.drawCircle(center, maxRadius * 0.96, ring);

    // A rotating arc segment for the HUD feel.
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.4
      ..color = core.withValues(alpha: 0.5 * intensity);
    final rect = Rect.fromCircle(center: center, radius: maxRadius * 0.88);
    canvas.drawArc(rect, spinT * 2 * pi, pi * 0.4, false, arc);
    canvas.drawArc(rect, spinT * 2 * pi + pi, pi * 0.25, false, arc);
  }

  @override
  bool shouldRepaint(covariant _OrbPainter oldDelegate) =>
      oldDelegate.pulseT != pulseT ||
      oldDelegate.spinT != spinT ||
      oldDelegate.talkT != talkT ||
      oldDelegate.micLevel != micLevel ||
      oldDelegate.status != status ||
      oldDelegate.core != core;
}
