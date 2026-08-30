import 'dart:math' as math;

import '../models/map_feature.dart';

enum MapSnapType {
  endpoint,
  vertex,
}

class MapSnapResult {
  final MapFeature feature;
  final MapCoordinate coordinate;
  final MapSnapType type;

  /// Khoảng cách từ con trỏ đến điểm snap,
  /// tính theo đơn vị tọa độ CAD.
  final double distance;

  /// Vị trí của điểm trong danh sách coordinates.
  final int coordinateIndex;

  const MapSnapResult({
    required this.feature,
    required this.coordinate,
    required this.type,
    required this.distance,
    required this.coordinateIndex,
  });

  String get label {
    switch (type) {
      case MapSnapType.endpoint:
        return 'Endpoint';

      case MapSnapType.vertex:
        return 'Vertex';
    }
  }

  @override
  String toString() {
    return 'MapSnapResult('
        'feature: ${feature.id}, '
        'type: $type, '
        'coordinateIndex: $coordinateIndex, '
        'distance: $distance'
        ')';
  }
}

class MapSnapService {
  const MapSnapService();

  /// Tìm điểm Endpoint / Vertex gần con trỏ nhất.
  ///
  /// [tolerance] sử dụng đơn vị tọa độ CAD.
  MapSnapResult? findNearestSnap({
    required List<MapFeature> features,
    required MapCoordinate position,
    required double tolerance,
  }) {
    if (features.isEmpty || tolerance <= 0) {
      return null;
    }

    MapSnapResult? bestResult;

    for (final feature in features) {
      if (!feature.visible ||
          feature.coordinates.isEmpty) {
        continue;
      }

      final result = _findFeatureSnap(
        feature: feature,
        position: position,
        tolerance: tolerance,
      );

      if (result == null) {
        continue;
      }

      if (bestResult == null ||
          result.distance < bestResult.distance) {
        bestResult = result;
      }
    }

    return bestResult;
  }

  MapSnapResult? _findFeatureSnap({
    required MapFeature feature,
    required MapCoordinate position,
    required double tolerance,
  }) {
    switch (feature.type) {
      case MapFeatureType.point:
        return _testCoordinate(
          feature: feature,
          coordinate: feature.coordinates.first,
          coordinateIndex: 0,
          position: position,
          tolerance: tolerance,
          type: MapSnapType.endpoint,
        );

      case MapFeatureType.line:
        return _findLineSnap(
          feature: feature,
          position: position,
          tolerance: tolerance,
        );

      case MapFeatureType.polyline:
        return _findPolylineSnap(
          feature: feature,
          position: position,
          tolerance: tolerance,
          closed: false,
        );

      case MapFeatureType.polygon:
        return _findPolylineSnap(
          feature: feature,
          position: position,
          tolerance: tolerance,
          closed: true,
        );

      case MapFeatureType.text:
        return _testCoordinate(
          feature: feature,
          coordinate: feature.coordinates.first,
          coordinateIndex: 0,
          position: position,
          tolerance: tolerance,
          type: MapSnapType.endpoint,
        );
    }
  }

  MapSnapResult? _findLineSnap({
    required MapFeature feature,
    required MapCoordinate position,
    required double tolerance,
  }) {
    if (feature.coordinates.isEmpty) {
      return null;
    }

    MapSnapResult? bestResult;

    for (var index = 0;
        index < feature.coordinates.length;
        index++) {
      final result = _testCoordinate(
        feature: feature,
        coordinate: feature.coordinates[index],
        coordinateIndex: index,
        position: position,
        tolerance: tolerance,
        type: MapSnapType.endpoint,
      );

      bestResult = _chooseNearest(
        bestResult,
        result,
      );
    }

    return bestResult;
  }

  MapSnapResult? _findPolylineSnap({
    required MapFeature feature,
    required MapCoordinate position,
    required double tolerance,
    required bool closed,
  }) {
    if (feature.coordinates.isEmpty) {
      return null;
    }

    MapSnapResult? bestResult;

    for (var index = 0;
        index < feature.coordinates.length;
        index++) {
      final isEndpoint =
          !closed &&
          (index == 0 ||
              index ==
                  feature.coordinates.length - 1);

      final result = _testCoordinate(
        feature: feature,
        coordinate: feature.coordinates[index],
        coordinateIndex: index,
        position: position,
        tolerance: tolerance,
        type: isEndpoint
            ? MapSnapType.endpoint
            : MapSnapType.vertex,
      );

      bestResult = _chooseNearest(
        bestResult,
        result,
      );
    }

    return bestResult;
  }

  MapSnapResult? _testCoordinate({
    required MapFeature feature,
    required MapCoordinate coordinate,
    required int coordinateIndex,
    required MapCoordinate position,
    required double tolerance,
    required MapSnapType type,
  }) {
    final distance = _distance(
      position,
      coordinate,
    );

    if (distance > tolerance) {
      return null;
    }

    return MapSnapResult(
      feature: feature,
      coordinate: coordinate,
      type: type,
      distance: distance,
      coordinateIndex: coordinateIndex,
    );
  }

  MapSnapResult? _chooseNearest(
    MapSnapResult? current,
    MapSnapResult? candidate,
  ) {
    if (candidate == null) {
      return current;
    }

    if (current == null) {
      return candidate;
    }

    if (candidate.distance <
        current.distance) {
      return candidate;
    }

    return current;
  }

  double _distance(
    MapCoordinate first,
    MapCoordinate second,
  ) {
    final deltaX =
        first.x - second.x;

    final deltaY =
        first.y - second.y;

    return math.sqrt(
      deltaX * deltaX +
          deltaY * deltaY,
    );
  }
}