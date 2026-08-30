import 'dart:math' as math;

import 'package:flutter/material.dart';

class CadGridPainter extends CustomPainter {
  final double minX;
  final double minY;
  final double maxX;
  final double maxY;

  final double baseScale;
  final double offsetX;
  final double offsetY;

  final double zoom;
  final Offset pan;

  const CadGridPainter({
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
    required this.baseScale,
    required this.offsetX,
    required this.offsetY,
    required this.zoom,
    required this.pan,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    if (size.width <= 0 ||
        size.height <= 0 ||
        baseScale <= 0 ||
        zoom <= 0) {
      return;
    }

    final spacing = _chooseGridSpacing();

    if (spacing <= 0) {
      return;
    }

    final visibleBounds = _calculateVisibleCadBounds(
      size,
    );

    final minorPaint = Paint()
      ..color = const Color(0xFFE6E9ED)
      ..strokeWidth = 1;

    final majorPaint = Paint()
      ..color = const Color(0xFFCDD3D9)
      ..strokeWidth = 1;

    final axisPaint = Paint()
      ..color = const Color(0xFF78909C)
      ..strokeWidth = 1.5;

    final startX =
        (visibleBounds.minX / spacing).floor() *
        spacing;

    final endX =
        (visibleBounds.maxX / spacing).ceil() *
        spacing;

    final startY =
        (visibleBounds.minY / spacing).floor() *
        spacing;

    final endY =
        (visibleBounds.maxY / spacing).ceil() *
        spacing;

    var xIndex = 0;

    for (double x = startX;
        x <= endX + spacing * 0.5;
        x += spacing) {
      if (xIndex > 2000) {
        break;
      }

      final screenX = _cadXToScreen(
        x,
        size,
      );

      final isAxis = _nearlyZero(x);

      final isMajor = _isMajorGridLine(
        x,
        spacing,
      );

      canvas.drawLine(
        Offset(
          screenX,
          0,
        ),
        Offset(
          screenX,
          size.height,
        ),
        isAxis
            ? axisPaint
            : isMajor
                ? majorPaint
                : minorPaint,
      );

      if (isMajor) {
        _drawXLabel(
          canvas,
          size,
          x,
          screenX,
        );
      }

      xIndex++;
    }

    var yIndex = 0;

    for (double y = startY;
        y <= endY + spacing * 0.5;
        y += spacing) {
      if (yIndex > 2000) {
        break;
      }

      final screenY = _cadYToScreen(
        y,
        size,
      );

      final isAxis = _nearlyZero(y);

      final isMajor = _isMajorGridLine(
        y,
        spacing,
      );

      canvas.drawLine(
        Offset(
          0,
          screenY,
        ),
        Offset(
          size.width,
          screenY,
        ),
        isAxis
            ? axisPaint
            : isMajor
                ? majorPaint
                : minorPaint,
      );

      if (isMajor) {
        _drawYLabel(
          canvas,
          size,
          y,
          screenY,
        );
      }

      yIndex++;
    }
  }

  double _chooseGridSpacing() {
    final effectiveScale =
        math.max(baseScale * zoom, 0.000000001);

    // Mục tiêu: khoảng cách giữa hai đường lưới nhỏ
    // khoảng 45–90 pixel.
    const targetPixels = 65.0;

    final rawSpacing =
        targetPixels / effectiveScale;

    if (rawSpacing <= 0 ||
        !rawSpacing.isFinite) {
      return 1;
    }

    final exponent = math
        .pow(
          10,
          (math.log(rawSpacing) / math.ln10).floor(),
        )
        .toDouble();

    final normalized =
        rawSpacing / exponent;

    double niceValue;

    if (normalized <= 1) {
      niceValue = 1;
    } else if (normalized <= 2) {
      niceValue = 2;
    } else if (normalized <= 5) {
      niceValue = 5;
    } else {
      niceValue = 10;
    }

    return niceValue * exponent;
  }

  _CadVisibleBounds _calculateVisibleCadBounds(
    Size size,
  ) {
    final topLeft = _screenToCad(
      Offset.zero,
      size,
    );

    final bottomRight = _screenToCad(
      Offset(
        size.width,
        size.height,
      ),
      size,
    );

    return _CadVisibleBounds(
      minX: math.min(
        topLeft.dx,
        bottomRight.dx,
      ),
      minY: math.min(
        topLeft.dy,
        bottomRight.dy,
      ),
      maxX: math.max(
        topLeft.dx,
        bottomRight.dx,
      ),
      maxY: math.max(
        topLeft.dy,
        bottomRight.dy,
      ),
    );
  }

  Offset _screenToCad(
    Offset screenPosition,
    Size size,
  ) {
    final center = Offset(
      size.width / 2,
      size.height / 2,
    );

    final baseX =
        center.dx +
        (screenPosition.dx -
                center.dx -
                pan.dx) /
            zoom;

    final baseY =
        center.dy +
        (screenPosition.dy -
                center.dy -
                pan.dy) /
            zoom;

    final x =
        minX +
        (baseX - offsetX) / baseScale;

    final y =
        minY +
        (size.height -
                offsetY -
                baseY) /
            baseScale;

    return Offset(
      x,
      y,
    );
  }

  double _cadXToScreen(
    double x,
    Size size,
  ) {
    final baseX =
        offsetX +
        (x - minX) * baseScale;

    final centerX =
        size.width / 2;

    return centerX +
        (baseX - centerX) * zoom +
        pan.dx;
  }

  double _cadYToScreen(
    double y,
    Size size,
  ) {
    final baseY =
        size.height -
        offsetY -
        (y - minY) * baseScale;

    final centerY =
        size.height / 2;

    return centerY +
        (baseY - centerY) * zoom +
        pan.dy;
  }

  bool _isMajorGridLine(
    double value,
    double spacing,
  ) {
    final majorSpacing =
        spacing * 5;

    if (majorSpacing == 0) {
      return false;
    }

    final ratio =
        value / majorSpacing;

    return (ratio - ratio.round()).abs() <
        0.000001;
  }

  bool _nearlyZero(double value) {
    return value.abs() < 0.0000001;
  }

  void _drawXLabel(
    Canvas canvas,
    Size size,
    double value,
    double screenX,
  ) {
    if (screenX < 0 ||
        screenX > size.width) {
      return;
    }

    final painter = TextPainter(
      text: TextSpan(
        text: _formatValue(value),
        style: const TextStyle(
          color: Color(0xFF607D8B),
          fontSize: 10,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    var x =
        screenX - painter.width / 2;

    x = x.clamp(
      2.0,
      math.max(
        2.0,
        size.width - painter.width - 2,
      ),
    );

    painter.paint(
      canvas,
      Offset(
        x,
        4,
      ),
    );
  }

  void _drawYLabel(
    Canvas canvas,
    Size size,
    double value,
    double screenY,
  ) {
    if (screenY < 0 ||
        screenY > size.height) {
      return;
    }

    final painter = TextPainter(
      text: TextSpan(
        text: _formatValue(value),
        style: const TextStyle(
          color: Color(0xFF607D8B),
          fontSize: 10,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    var y =
        screenY - painter.height / 2;

    y = y.clamp(
      2.0,
      math.max(
        2.0,
        size.height - painter.height - 2,
      ),
    );

    painter.paint(
      canvas,
      Offset(
        4,
        y,
      ),
    );
  }

  String _formatValue(double value) {
    final absoluteValue = value.abs();

    if (absoluteValue >= 1000000) {
      return value.toStringAsFixed(0);
    }

    if (absoluteValue >= 1000) {
      return value.toStringAsFixed(1);
    }

    if (absoluteValue >= 10) {
      return value.toStringAsFixed(2);
    }

    return value.toStringAsFixed(3);
  }

  @override
  bool shouldRepaint(
    covariant CadGridPainter oldDelegate,
  ) {
    return oldDelegate.minX != minX ||
        oldDelegate.minY != minY ||
        oldDelegate.maxX != maxX ||
        oldDelegate.maxY != maxY ||
        oldDelegate.baseScale != baseScale ||
        oldDelegate.offsetX != offsetX ||
        oldDelegate.offsetY != offsetY ||
        oldDelegate.zoom != zoom ||
        oldDelegate.pan != pan;
  }
}

class _CadVisibleBounds {
  final double minX;
  final double minY;
  final double maxX;
  final double maxY;

  const _CadVisibleBounds({
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
  });
}