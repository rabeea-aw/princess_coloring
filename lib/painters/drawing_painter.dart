import 'package:flutter/material.dart';
import '../screens/coloring_screen.dart';

class DrawingPainter extends CustomPainter {
  final List<DrawPoint?> points;

  DrawingPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];

      if (current != null && next != null) {
        final paint = Paint()
          ..color = current.color
          ..strokeWidth = current.strokeWidth
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

        canvas.drawLine(current.offset, next.offset, paint);
      } else if (current != null && next == null) {
        final paint = Paint()
          ..color = current.color
          ..strokeWidth = current.strokeWidth
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.fill;

        canvas.drawCircle(current.offset, current.strokeWidth / 2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) => true;
}