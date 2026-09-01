import 'package:flutter/material.dart';

import '../models/map_feature.dart';
import '../services/drawing_controller.dart';

class DrawingPainter extends CustomPainter {
  final DrawingMode mode;
  final List<MapCoordinate> coordinates;
  final MapCoordinate? hoverCoordinate;
  final Offset Function(MapCoordinate coordinate) toScreen;

  DrawingPainter({
    required this.mode,
    required this.coordinates,
    required this.hoverCoordinate,
    required this.toScreen,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (mode == DrawingMode.none) return;

    final stroke = Paint()
      ..color = const Color(0xFFFF6D00)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final preview = Paint()
      ..color = const Color(0xFFFF6D00).withValues(alpha: 0.7)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final vertex = Paint()
      ..color = const Color(0xFFFF6D00)
      ..style = PaintingStyle.fill;

    if (coordinates.length >= 2) {
      final path = Path();
      final first = toScreen(coordinates.first);
      path.moveTo(first.dx, first.dy);
      for (var index = 1; index < coordinates.length; index++) {
        final point = toScreen(coordinates[index]);
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, stroke);
    }

    for (final coordinate in coordinates) {
      canvas.drawCircle(toScreen(coordinate), 4, vertex);
    }

    final hover = hoverCoordinate;
    if (hover != null) {
      final hoverPosition = toScreen(hover);
      if (coordinates.isEmpty) {
        canvas.drawCircle(hoverPosition, 4, vertex);
      } else if (mode != DrawingMode.point) {
        canvas.drawLine(toScreen(coordinates.last), hoverPosition, preview);
      }
    }

    if (mode == DrawingMode.polygon && coordinates.length >= 2) {
      final closingStart = hover == null
          ? toScreen(coordinates.last)
          : toScreen(hover);
      canvas.drawLine(closingStart, toScreen(coordinates.first), preview);
    }
  }

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) {
    return oldDelegate.mode != mode ||
        oldDelegate.coordinates != coordinates ||
        oldDelegate.hoverCoordinate != hoverCoordinate ||
        oldDelegate.toScreen != toScreen;
  }
}
