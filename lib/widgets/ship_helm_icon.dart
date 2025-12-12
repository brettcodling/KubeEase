import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Custom widget that draws a ship's helm icon with 8 spokes
class ShipHelmIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const ShipHelmIcon({
    super.key,
    this.size = 24.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? Theme.of(context).iconTheme.color ?? Colors.white;
    
    return CustomPaint(
      size: Size(size, size),
      painter: _ShipHelmPainter(color: iconColor),
    );
  }
}

/// Custom painter that draws a ship's helm with 8 spokes
class _ShipHelmPainter extends CustomPainter {
  final Color color;

  _ShipHelmPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.06
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width * 0.43;
    final innerRadius = size.width * 0.15;
    final rimWidth = size.width * 0.08;
    final handleLength = size.width * 0.17;
    final handleWidth = size.width * 0.10;

    // Draw outer rim (thicker)
    final rimPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = rimWidth;
    canvas.drawCircle(center, outerRadius - rimWidth / 2, rimPaint);

    // Draw 8 spokes with ornate handles
    for (int i = 0; i < 8; i++) {
      final angle = (i * math.pi / 4) - (math.pi / 2); // Start from top

      // Calculate spoke start and end points (spoke goes from center to inner edge of rim)
      final startX = center.dx + innerRadius * math.cos(angle);
      final startY = center.dy + innerRadius * math.sin(angle);
      final spokeEndRadius = outerRadius - rimWidth / 2;
      final endX = center.dx + spokeEndRadius * math.cos(angle);
      final endY = center.dy + spokeEndRadius * math.sin(angle);

      // Draw spoke
      canvas.drawLine(
        Offset(startX, startY),
        Offset(endX, endY),
        paint,
      );

      // Draw ornate handle extending outward past the rim
      final handleStartRadius = outerRadius - rimWidth / 2;
      final handleEndRadius = outerRadius + handleLength;

      // Create rounded rectangular handle
      final handlePath = Path();
      final handleStartX = center.dx + handleStartRadius * math.cos(angle);
      final handleStartY = center.dy + handleStartRadius * math.sin(angle);
      final handleEndX = center.dx + handleEndRadius * math.cos(angle);
      final handleEndY = center.dy + handleEndRadius * math.sin(angle);

      // Calculate perpendicular offset for handle width
      final perpAngle = angle + math.pi / 2;
      final offsetX = handleWidth / 2 * math.cos(perpAngle);
      final offsetY = handleWidth / 2 * math.sin(perpAngle);

      // Draw handle as a rounded rectangle
      handlePath.moveTo(handleStartX + offsetX, handleStartY + offsetY);
      handlePath.lineTo(handleEndX + offsetX, handleEndY + offsetY);
      handlePath.lineTo(handleEndX - offsetX, handleEndY - offsetY);
      handlePath.lineTo(handleStartX - offsetX, handleStartY - offsetY);
      handlePath.close();

      canvas.drawPath(handlePath, fillPaint);

      // Draw decorative circle at the end of handle
      final decorativeCircleRadius = handleWidth * 0.6;
      canvas.drawCircle(
        Offset(handleEndX, handleEndY),
        decorativeCircleRadius,
        fillPaint,
      );

      // Add inner decorative circle
      final innerDecorativePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.02;
      canvas.drawCircle(
        Offset(handleEndX, handleEndY),
        decorativeCircleRadius * 0.5,
        innerDecorativePaint,
      );
    }

    // Draw center hub (filled circle)
    canvas.drawCircle(center, innerRadius, fillPaint);

    // Draw decorative rings in center hub
    final hubRingPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.03;
    canvas.drawCircle(center, innerRadius * 0.6, hubRingPaint);

    // Draw center hub outline
    canvas.drawCircle(center, innerRadius, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

