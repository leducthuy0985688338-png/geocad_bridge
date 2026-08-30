import 'dart:math' as math;

import '../models/map_feature.dart';

class MapSelectionService {
  const MapSelectionService();

  /// Tìm đối tượng gần vị trí click nhất.
  ///
  /// [tolerance] được tính trong đơn vị tọa độ CAD.
  ///
  /// Nếu không có đối tượng nào nằm trong phạm vi tolerance,
  /// hàm trả về null.
  MapSelectionResult? findNearestFeature({
    required List<MapFeature> features,
    required MapCoordinate position,
    required double tolerance,
  }) {
    if (features.isEmpty || tolerance <= 0) {
      return null;
    }

    MapSelectionResult? bestResult;

    for (final feature in features) {
      if (!feature.visible ||
          feature.coordinates.isEmpty) {
        continue;
      }

      final distance = _distanceToFeature(
        feature,
        position,
      );

      if (distance == null ||
          distance > tolerance) {
        continue;
      }

      if (bestResult == null ||
          distance < bestResult.distance) {
        bestResult = MapSelectionResult(
          feature: feature,
          distance: distance,
        );
      }
    }

    return bestResult;
  }

  double? _distanceToFeature(
    MapFeature feature,
    MapCoordinate position,
  ) {
    switch (feature.type) {
      case MapFeatureType.point:
        return _distanceToPoint(
          position,
          feature.coordinates.first,
        );

      case MapFeatureType.line:
        return _distanceToLineFeature(
          feature,
          position,
        );

      case MapFeatureType.polyline:
        return _distanceToPolyline(
          feature.coordinates,
          position,
          closePath: false,
        );

      case MapFeatureType.polygon:
        return _distanceToPolygon(
          feature.coordinates,
          position,
        );

      case MapFeatureType.text:
        return _distanceToPoint(
          position,
          feature.coordinates.first,
        );
    }
  }

  double? _distanceToLineFeature(
    MapFeature feature,
    MapCoordinate position,
  ) {
    if (feature.coordinates.length < 2) {
      return null;
    }

    return _distanceToSegment(
      position,
      feature.coordinates[0],
      feature.coordinates[1],
    );
  }

  double? _distanceToPolyline(
    List<MapCoordinate> coordinates,
    MapCoordinate position, {
    required bool closePath,
  }) {
    if (coordinates.isEmpty) {
      return null;
    }

    if (coordinates.length == 1) {
      return _distanceToPoint(
        position,
        coordinates.first,
      );
    }

    double? minimumDistance;

    for (var index = 0;
        index < coordinates.length - 1;
        index++) {
      final distance = _distanceToSegment(
        position,
        coordinates[index],
        coordinates[index + 1],
      );

      if (minimumDistance == null ||
          distance < minimumDistance) {
        minimumDistance = distance;
      }
    }

    if (closePath &&
        coordinates.length >= 3) {
      final closingDistance = _distanceToSegment(
        position,
        coordinates.last,
        coordinates.first,
      );

      if (minimumDistance == null ||
          closingDistance < minimumDistance) {
        minimumDistance = closingDistance;
      }
    }

    return minimumDistance;
  }

  double? _distanceToPolygon(
    List<MapCoordinate> coordinates,
    MapCoordinate position,
  ) {
    if (coordinates.isEmpty) {
      return null;
    }

    // Click bên trong polygon cũng được xem là chọn polygon.
    if (coordinates.length >= 3 &&
        _isPointInsidePolygon(
          position,
          coordinates,
        )) {
      return 0;
    }

    return _distanceToPolyline(
      coordinates,
      position,
      closePath: true,
    );
  }

  bool _isPointInsidePolygon(
    MapCoordinate point,
    List<MapCoordinate> polygon,
  ) {
    var inside = false;

    for (var i = 0, j = polygon.length - 1;
        i < polygon.length;
        j = i++) {
      final xi = polygon[i].x;
      final yi = polygon[i].y;

      final xj = polygon[j].x;
      final yj = polygon[j].y;

      final crosses =
          ((yi > point.y) != (yj > point.y)) &&
          (point.x <
              (xj - xi) *
                      (point.y - yi) /
                      (yj - yi) +
                  xi);

      if (crosses) {
        inside = !inside;
      }
    }

    return inside;
  }

  double _distanceToPoint(
    MapCoordinate first,
    MapCoordinate second,
  ) {
    final deltaX = first.x - second.x;
    final deltaY = first.y - second.y;

    return math.sqrt(
      deltaX * deltaX +
          deltaY * deltaY,
    );
  }

  double _distanceToSegment(
    MapCoordinate point,
    MapCoordinate start,
    MapCoordinate end,
  ) {
    final segmentX = end.x - start.x;
    final segmentY = end.y - start.y;

    final segmentLengthSquared =
        segmentX * segmentX +
        segmentY * segmentY;

    if (segmentLengthSquared == 0) {
      return _distanceToPoint(
        point,
        start,
      );
    }

    final pointX = point.x - start.x;
    final pointY = point.y - start.y;

    var t =
        (pointX * segmentX +
                pointY * segmentY) /
            segmentLengthSquared;

    t = t.clamp(
      0.0,
      1.0,
    );

    final nearestX =
        start.x + t * segmentX;

    final nearestY =
        start.y + t * segmentY;

    final deltaX =
        point.x - nearestX;

    final deltaY =
        point.y - nearestY;

    return math.sqrt(
      deltaX * deltaX +
          deltaY * deltaY,
    );
  }
}

class MapSelectionResult {
  final MapFeature feature;

  /// Khoảng cách từ vị trí click tới hình học,
  /// tính theo đơn vị tọa độ CAD.
  final double distance;

  const MapSelectionResult({
    required this.feature,
    required this.distance,
  });

  @override
  String toString() {
    return 'MapSelectionResult('
        'feature: ${feature.id}, '
        'distance: $distance'
        ')';
  }
}