import 'package:flutter/material.dart';

import '../models/map_feature.dart';
import '../services/map_snap_service.dart';

class SnapPainter extends CustomPainter {
  final MapSnapResult? snapResult;

  /// Chuyển tọa độ CAD thành tọa độ màn hình.
  final Offset Function(MapCoordinate coordinate) toScreen;

  const SnapPainter({
    required this.snapResult,
    required this.toScreen,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final snap = snapResult;

    if (snap == null) {
      return;
    }

    final position = toScreen(
      snap.coordinate,
    );

    if (!_isVisible(
      position,
      size,
    )) {
      return;
    }

    switch (snap.type) {
      case MapSnapType.endpoint:
        _drawEndpoint(
          canvas,
          position,
        );
        break;

      case MapSnapType.vertex:
        _drawVertex(
          canvas,
          position,
        );
        break;
    }

    _drawLabel(
      canvas,
      size,
      position,
      snap,
    );
  }

  bool _isVisible(
    Offset position,
    Size size,
  ) {
    const margin = 30.0;

    return position.dx >= -margin &&
        position.dy >= -margin &&
        position.dx <= size.width + margin &&
        position.dy <= size.height + margin;
  }

  void _drawEndpoint(
    Canvas canvas,
    Offset position,
  ) {
    const markerSize = 12.0;

    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = const Color(0xFF00A86B)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final rect = Rect.fromCenter(
      center: position,
      width: markerSize,
      height: markerSize,
    );

    canvas.drawRect(
      rect,
      fillPaint,
    );

    canvas.drawRect(
      rect,
      borderPaint,
    );
  }

  void _drawVertex(
    Canvas canvas,
    Offset position,
  ) {
    const radius = 6.0;

    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = const Color(0xFF00A86B)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(
        position.dx,
        position.dy - radius,
      )
      ..lineTo(
        position.dx + radius,
        position.dy,
      )
      ..lineTo(
        position.dx,
        position.dy + radius,
      )
      ..lineTo(
        position.dx - radius,
        position.dy,
      )
      ..close();

    canvas.drawPath(
      path,
      fillPaint,
    );

    canvas.drawPath(
      path,
      borderPaint,
    );
  }

  void _drawLabel(
    Canvas canvas,
    Size size,
    Offset position,
    MapSnapResult snap,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: snap.label,
            style: const TextStyle(
              color: Color(0xFF006B45),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(
            text:
                '\nX: ${_formatCoordinate(snap.coordinate.x)}'
                '   Y: ${_formatCoordinate(snap.coordinate.y)}',
            style: const TextStyle(
              color: Color(0xFF37474F),
              fontSize: 10,
              fontFeatures: [
                FontFeature.tabularFigures(),
              ],
            ),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout(
        maxWidth: 260,
      );

    const horizontalPadding = 8.0;
    const verticalPadding = 6.0;

    final boxWidth =
        textPainter.width +
        horizontalPadding * 2;

    final boxHeight =
        textPainter.height +
        verticalPadding * 2;

    var left = position.dx + 14;
    var top = position.dy + 14;

    if (left + boxWidth >
        size.width - 4) {
      left =
          position.dx -
          boxWidth -
          14;
    }

    if (top + boxHeight >
        size.height - 4) {
      top =
          position.dy -
          boxHeight -
          14;
    }

    if (left < 4) {
      left = 4;
    }

    if (top < 4) {
      top = 4;
    }

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        left,
        top,
        boxWidth,
        boxHeight,
      ),
      const Radius.circular(5),
    );

    final backgroundPaint = Paint()
      ..color = Colors.white.withValues(
        alpha: 0.96,
      )
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = const Color(0xFF00A86B)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(
      rect,
      backgroundPaint,
    );

    canvas.drawRRect(
      rect,
      borderPaint,
    );

    textPainter.paint(
      canvas,
      Offset(
        left + horizontalPadding,
        top + verticalPadding,
      ),
    );
  }

  String _formatCoordinate(
    double value,
  ) {
    final absoluteValue = value.abs();

    if (absoluteValue >= 1000000) {
      return value.toStringAsFixed(2);
    }

    if (absoluteValue >= 1000) {
      return value.toStringAsFixed(3);
    }

    return value.toStringAsFixed(4);
  }

  @override
  bool shouldRepaint(
    covariant SnapPainter oldDelegate,
  ) {
    return oldDelegate.snapResult != snapResult ||
        oldDelegate.toScreen != toScreen;
  }
}