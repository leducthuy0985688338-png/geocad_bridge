import 'package:flutter/material.dart';

import '../models/map_feature.dart';

class SelectionPainter extends CustomPainter {
  final MapFeature? selectedFeature;

  final Offset Function(MapCoordinate coordinate) toCanvas;

  final double zoom;

  const SelectionPainter({
    required this.selectedFeature,
    required this.toCanvas,
    required this.zoom,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final feature = selectedFeature;

    if (feature == null ||
        feature.coordinates.isEmpty) {
      return;
    }

    final highlightPaint = Paint()
      ..color = const Color(0xFFFF9800)
      ..strokeWidth = 3.0 / zoom
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final vertexPaint = Paint()
      ..color = const Color(0xFFFF9800)
      ..style = PaintingStyle.fill;

    final vertexBorderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.2 / zoom
      ..style = PaintingStyle.stroke;

    switch (feature.type) {
      case MapFeatureType.point:
        _drawPoint(
          canvas,
          feature,
          highlightPaint,
          vertexPaint,
          vertexBorderPaint,
        );
        break;

      case MapFeatureType.line:
        _drawLine(
          canvas,
          feature,
          highlightPaint,
          vertexPaint,
          vertexBorderPaint,
        );
        break;

      case MapFeatureType.polyline:
        _drawPolyline(
          canvas,
          feature,
          highlightPaint,
          vertexPaint,
          vertexBorderPaint,
          closePath: false,
        );
        break;

      case MapFeatureType.polygon:
        _drawPolyline(
          canvas,
          feature,
          highlightPaint,
          vertexPaint,
          vertexBorderPaint,
          closePath: true,
        );
        break;

      case MapFeatureType.text:
        _drawPoint(
          canvas,
          feature,
          highlightPaint,
          vertexPaint,
          vertexBorderPaint,
        );
        break;
    }
  }

  void _drawPoint(
    Canvas canvas,
    MapFeature feature,
    Paint highlightPaint,
    Paint vertexPaint,
    Paint vertexBorderPaint,
  ) {
    final position = toCanvas(
      feature.coordinates.first,
    );

    canvas.drawCircle(
      position,
      7 / zoom,
      highlightPaint,
    );

    _drawVertex(
      canvas,
      position,
      vertexPaint,
      vertexBorderPaint,
    );
  }

  void _drawLine(
    Canvas canvas,
    MapFeature feature,
    Paint highlightPaint,
    Paint vertexPaint,
    Paint vertexBorderPaint,
  ) {
    if (feature.coordinates.length < 2) {
      return;
    }

    final start = toCanvas(
      feature.coordinates[0],
    );

    final end = toCanvas(
      feature.coordinates[1],
    );

    canvas.drawLine(
      start,
      end,
      highlightPaint,
    );

    _drawVertex(
      canvas,
      start,
      vertexPaint,
      vertexBorderPaint,
    );

    _drawVertex(
      canvas,
      end,
      vertexPaint,
      vertexBorderPaint,
    );
  }

  void _drawPolyline(
    Canvas canvas,
    MapFeature feature,
    Paint highlightPaint,
    Paint vertexPaint,
    Paint vertexBorderPaint, {
    required bool closePath,
  }) {
    if (feature.coordinates.length < 2) {
      return;
    }

    final path = Path();

    final first = toCanvas(
      feature.coordinates.first,
    );

    path.moveTo(
      first.dx,
      first.dy,
    );

    for (var index = 1;
        index < feature.coordinates.length;
        index++) {
      final position = toCanvas(
        feature.coordinates[index],
      );

      path.lineTo(
        position.dx,
        position.dy,
      );
    }

    if (closePath) {
      path.close();
    }

    canvas.drawPath(
      path,
      highlightPaint,
    );

    for (final coordinate in feature.coordinates) {
      _drawVertex(
        canvas,
        toCanvas(coordinate),
        vertexPaint,
        vertexBorderPaint,
      );
    }
  }

  void _drawVertex(
    Canvas canvas,
    Offset position,
    Paint fillPaint,
    Paint borderPaint,
  ) {
    final radius = 4.5 / zoom;

    canvas.drawCircle(
      position,
      radius,
      fillPaint,
    );

    canvas.drawCircle(
      position,
      radius,
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(
    covariant SelectionPainter oldDelegate,
  ) {
    return oldDelegate.selectedFeature !=
            selectedFeature ||
        oldDelegate.zoom != zoom ||
        oldDelegate.toCanvas != toCanvas;
  }
}