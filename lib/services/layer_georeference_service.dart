import 'dart:math' as math;

import '../models/coordinate_reference_system.dart';
import '../models/map_feature.dart';
import '../models/map_layer.dart';
import 'coordinate_transform_service.dart';

class GeoreferenceControlPoint {
  final MapCoordinate local;
  final MapCoordinate target;

  const GeoreferenceControlPoint({required this.local, required this.target});
}

class GeoreferenceTransform {
  final double scale;
  final double rotationRadians;
  final double translationX;
  final double translationY;

  const GeoreferenceTransform({
    required this.scale,
    required this.rotationRadians,
    required this.translationX,
    required this.translationY,
  });

  double get rotationDegrees => rotationRadians * 180 / math.pi;

  MapCoordinate transform(MapCoordinate coordinate) {
    if (!coordinate.x.isFinite ||
        !coordinate.y.isFinite ||
        (coordinate.z != null && !coordinate.z!.isFinite)) {
      throw ArgumentError('Tọa độ cần định vị phải là số hữu hạn.');
    }

    if (!scale.isFinite ||
        !rotationRadians.isFinite ||
        !translationX.isFinite ||
        !translationY.isFinite ||
        scale <= LayerGeoreferenceService.minimumControlPointDistance) {
      throw StateError('Phép định vị không hợp lệ.');
    }

    final cosAngle = math.cos(rotationRadians);
    final sinAngle = math.sin(rotationRadians);

    final x =
        scale * (coordinate.x * cosAngle - coordinate.y * sinAngle) +
        translationX;

    final y =
        scale * (coordinate.x * sinAngle + coordinate.y * cosAngle) +
        translationY;

    if (!x.isFinite || !y.isFinite) {
      throw StateError('Kết quả định vị không phải là số hữu hạn.');
    }

    return MapCoordinate(x: x, y: y, z: coordinate.z);
  }
}

class LayerGeoreferenceResult {
  final MapLayer layer;
  final GeoreferenceTransform transform;
  final int transformedFeatureCount;
  final int transformedCoordinateCount;
  final double controlPointError;

  const LayerGeoreferenceResult({
    required this.layer,
    required this.transform,
    required this.transformedFeatureCount,
    required this.transformedCoordinateCount,
    required this.controlPointError,
  });
}

class LayerGeoreferenceService {
  static const double minimumControlPointDistance = 1e-9;

  final CoordinateTransformService coordinateTransformService;

  const LayerGeoreferenceService({
    this.coordinateTransformService = const CoordinateTransformService(),
  });

  GeoreferenceTransform calculateTransform({
    required GeoreferenceControlPoint point1,
    required GeoreferenceControlPoint point2,
  }) {
    _validateCoordinate(point1.local, 'Điểm CAD 1');
    _validateCoordinate(point2.local, 'Điểm CAD 2');
    _validateCoordinate(point1.target, 'Điểm target 1');
    _validateCoordinate(point2.target, 'Điểm target 2');

    final localDx = point2.local.x - point1.local.x;
    final localDy = point2.local.y - point1.local.y;

    final targetDx = point2.target.x - point1.target.x;
    final targetDy = point2.target.y - point1.target.y;

    final localDistance = math.sqrt(localDx * localDx + localDy * localDy);

    final targetDistance = math.sqrt(targetDx * targetDx + targetDy * targetDy);

    if (!localDistance.isFinite ||
        localDistance <= minimumControlPointDistance) {
      throw ArgumentError(
        'Hai điểm CAD khống chế không được trùng hoặc quá gần nhau.',
      );
    }

    if (!targetDistance.isFinite ||
        targetDistance <= minimumControlPointDistance) {
      throw ArgumentError(
        'Hai điểm tọa độ thực không được trùng hoặc quá gần nhau.',
      );
    }

    final scale = targetDistance / localDistance;

    if (!scale.isFinite || scale <= minimumControlPointDistance) {
      throw ArgumentError('Scale của phép định vị không hợp lệ.');
    }

    final localAngle = math.atan2(localDy, localDx);
    final targetAngle = math.atan2(targetDy, targetDx);

    final rotation = targetAngle - localAngle;

    final cosAngle = math.cos(rotation);
    final sinAngle = math.sin(rotation);

    final transformedPoint1X =
        scale * (point1.local.x * cosAngle - point1.local.y * sinAngle);

    final transformedPoint1Y =
        scale * (point1.local.x * sinAngle + point1.local.y * cosAngle);

    final translationX = point1.target.x - transformedPoint1X;
    final translationY = point1.target.y - transformedPoint1Y;

    if (!rotation.isFinite ||
        !translationX.isFinite ||
        !translationY.isFinite) {
      throw ArgumentError(
        'Rotation hoặc translation của phép định vị không hợp lệ.',
      );
    }

    return GeoreferenceTransform(
      scale: scale,
      rotationRadians: rotation,
      translationX: translationX,
      translationY: translationY,
    );
  }

  LayerGeoreferenceResult georeferenceLayer({
    required MapLayer sourceLayer,
    required GeoreferenceControlPoint point1,
    required GeoreferenceControlPoint point2,
    required CoordinateReferenceSystem targetCrs,
    String? newLayerId,
    String? newLayerName,
  }) {
    if (!sourceLayer.crs.isLocalCad) {
      throw ArgumentError(
        'Chỉ layer CAD cục bộ (localCad) mới có thể được định vị.',
      );
    }

    if (targetCrs.isLocalCad || !targetCrs.isValid) {
      throw ArgumentError('CRS đích phải là WGS84 hoặc UTM hợp lệ.');
    }

    _validateTargetCoordinate(point1.target, targetCrs, 'Điểm target 1');
    _validateTargetCoordinate(point2.target, targetCrs, 'Điểm target 2');

    final transform = calculateTransform(point1: point1, point2: point2);

    var coordinateCount = 0;

    final transformedFeatures = sourceLayer.features.map((feature) {
      final coordinates = feature.coordinates.map((coordinate) {
        coordinateCount++;
        return transform.transform(coordinate);
      }).toList();

      return feature.copyWith(
        coordinates: coordinates,
        properties: Map<String, String>.from(feature.properties),
      );
    }).toList();

    final transformedPoint1 = transform.transform(point1.local);
    final transformedPoint2 = transform.transform(point2.local);

    final error1 = _distance(transformedPoint1, point1.target);

    final error2 = _distance(transformedPoint2, point2.target);

    final properties = Map<String, String>.from(sourceLayer.properties)
      ..addAll({
        'georeferenced': 'true',
        'georeferenceMethod': '2-point similarity transform',
        'georeferenceScale': transform.scale.toStringAsPrecision(15),
        'georeferenceRotationDegrees': transform.rotationDegrees
            .toStringAsPrecision(15),
        'georeferenceTranslationX': transform.translationX.toStringAsPrecision(
          15,
        ),
        'georeferenceTranslationY': transform.translationY.toStringAsPrecision(
          15,
        ),
        'georeferenceControlPointError': math
            .max(error1, error2)
            .toStringAsPrecision(15),
        'targetCrs': targetCrs.displayName.toString(),
      });

    final epsg = targetCrs.epsgCode;
    if (epsg != null) {
      properties['targetEpsg'] = epsg.toString();
    }

    final layer = sourceLayer.copyWith(
      id: newLayerId ?? '${sourceLayer.id}-georeferenced',
      name: newLayerName ?? '${sourceLayer.name} - Georeferenced',
      crs: targetCrs,
      features: transformedFeatures,
      properties: properties,
    );

    return LayerGeoreferenceResult(
      layer: layer,
      transform: transform,
      transformedFeatureCount: transformedFeatures.length,
      transformedCoordinateCount: coordinateCount,
      controlPointError: math.max(error1, error2),
    );
  }

  double _distance(MapCoordinate a, MapCoordinate b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;

    return math.sqrt(dx * dx + dy * dy);
  }

  void _validateCoordinate(MapCoordinate coordinate, String label) {
    if (!coordinate.x.isFinite ||
        !coordinate.y.isFinite ||
        (coordinate.z != null && !coordinate.z!.isFinite)) {
      throw ArgumentError('$label phải chứa các giá trị hữu hạn.');
    }
  }

  void _validateTargetCoordinate(
    MapCoordinate coordinate,
    CoordinateReferenceSystem targetCrs,
    String label,
  ) {
    _validateCoordinate(coordinate, label);

    if (targetCrs.isWgs84) {
      if (!coordinateTransformService.isValidWgs84(
        longitude: coordinate.x,
        latitude: coordinate.y,
      )) {
        throw ArgumentError('$label không phải tọa độ WGS84 hợp lệ.');
      }
      return;
    }

    final zone = targetCrs.utmZone;
    final hemisphere = targetCrs.hemisphere;

    if (!targetCrs.isUtm || zone == null || hemisphere == null) {
      throw ArgumentError('CRS UTM đích không hợp lệ.');
    }

    if (!coordinateTransformService.isValidUtm(
      easting: coordinate.x,
      northing: coordinate.y,
      zone: zone,
    )) {
      throw ArgumentError('$label không phải tọa độ UTM hợp lệ.');
    }
  }
}
