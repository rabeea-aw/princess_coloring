import 'package:flutter/material.dart';
import 'dart:ui' as ui;

class FillParticle {
  final Offset start;
  final Offset end;
  final double size;
  final double rotation;
  final Duration duration;
  final DateTime createdAt;

  FillParticle({
    required this.start,
    required this.end,
    required this.size,
    required this.rotation,
    required this.duration,
    required this.createdAt,
  });

  double progress(DateTime now) {
    final elapsed = now.difference(createdAt).inMilliseconds;
    return (elapsed / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  bool isAlive(DateTime now) {
    return progress(now) < 1.0;
  }
}

class FillParticlesPainter extends CustomPainter {
  final List<FillParticle> particles;
  final DateTime now;

  FillParticlesPainter({
    required this.particles,
    required this.now,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final t = particle.progress(now);
      final opacity = (1.0 - t).clamp(0.0, 1.0);

      final dx = ui.lerpDouble(
        particle.start.dx,
        particle.end.dx,
        Curves.easeOut.transform(t),
      )!;

      final dy = ui.lerpDouble(
        particle.start.dy,
        particle.end.dy - (18 * t),
        Curves.easeOut.transform(t),
      )!;

      final textPainter = TextPainter(
        text: TextSpan(
          text: '⭐',
          style: TextStyle(
            fontSize: particle.size,
            color: Colors.amber.withOpacity(opacity),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(particle.rotation * (1 - t) * 0.5);
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant FillParticlesPainter oldDelegate) {
    return true;
  }
}