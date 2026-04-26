import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
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

  static final Path _unitStarPath = _createUnitStarPath();

  static Path _createUnitStarPath() {
    const int points = 5;
    final path = Path();

    for (int i = 0; i < points * 2; i++) {
      final isOuter = i.isEven;
      final radius = isOuter ? 1.0 : 0.45;
      final angle = -math.pi / 2 + (i * math.pi / points);
      final x = math.cos(angle) * radius;
      final y = math.sin(angle) * radius;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    path.close();
    return path;
  }

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

      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.amber.withOpacity(opacity);

      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.yellowAccent.withOpacity(opacity * 0.9);

      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(particle.rotation * (1 - t) * 0.5);
      canvas.scale(particle.size / 2.0);

      canvas.drawPath(_unitStarPath, fillPaint);
      canvas.drawPath(_unitStarPath, glowPaint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant FillParticlesPainter oldDelegate) {
    return true;
  }
}