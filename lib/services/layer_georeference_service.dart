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

class GeoreferenceResidual {
  final int controlPointIndex;
  final double deltaX;
  final double deltaY;
  final double planarError;

  const GeoreferenceResidual({
    required this.controlPointIndex,
    required this.deltaX,
    required this.deltaY,
    required this.planarError,
  });
}

class GeoreferenceFitResult {
  final GeoreferenceTransform transform;
  final List<GeoreferenceResidual> residuals;
  final double rmse;
  final GeoreferenceResidual maxResidual;
  final String method;

  GeoreferenceFitResult({
    required this.transform,
    required List<GeoreferenceResidual> residuals,
    required this.rmse,
    required this.maxResidual,
    required this.method,
  }) : residuals = List<GeoreferenceResidual>.unmodifiable(residuals);

  int get controlPointCount => residuals.length;
  int get maxResidualIndex => maxResidual.controlPointIndex;
}

class LayerGeoreferenceResult {
  final MapLayer layer;
  final GeoreferenceTransform transform;
  final int transformedFeatureCount;
  final int transformedCoordinateCount;

  /// Backward-compatible name for the maximum planar residual.
  final double controlPointError;
  final List<GeoreferenceResidual> residuals;
  final double rmse;
  final GeoreferenceResidual? maxResidual;
  final int controlPointCount;
  final String georeferenceMethod;

  const LayerGeoreferenceResult({
    required this.layer,
    required this.transform,
    required this.transformedFeatureCount,
    required this.transformedCoordinateCount,
    required this.controlPointError,
    this.residuals = const [],
    this.rmse = 0,
    this.maxResidual,
    this.controlPointCount = 2,
    this.georeferenceMethod = '2-point similarity transform',
  });

  int get maxResidualIndex => maxResidual?.controlPointIndex ?? -1;
}

class LayerGeoreferenceService {
  static const double minimumControlPointDistance = 1e-9;
  static const String twoPointMethod = '2-point similarity transform';
  static const String leastSquaresMethod = 'least-squares similarity transform';

  final CoordinateTransformService coordinateTransformService;

  const LayerGeoreferenceService({
    this.coordinateTransformService = const CoordinateTransformService(),
  });

  /// Backward-compatible exact two-point similarity transform.
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

    _validateTransformParameters(
      scale: scale,
      rotation: rotation,
      translationX: translationX,
      translationY: translationY,
    );

    return GeoreferenceTransform(
      scale: scale,
      rotationRadians: rotation,
      translationX: translationX,
      translationY: translationY,
    );
  }

  GeoreferenceFitResult fitControlPoints({
    required List<GeoreferenceControlPoint> controlPoints,
    CoordinateReferenceSystem? targetCrs,
  }) {
    if (controlPoints.length < 2) {
      throw ArgumentError('Cần ít nhất 2 điểm khống chế để định vị.');
    }

    for (var index = 0; index < controlPoints.length; index++) {
      final point = controlPoints[index];
      _validateCoordinate(point.local, 'Điểm CAD ${index + 1}');
      _validateCoordinate(point.target, 'Điểm target ${index + 1}');
      if (targetCrs != null) {
        _validateTargetCoordinate(
          point.target,
          targetCrs,
          'Điểm target ${index + 1}',
        );
      }
    }

    GeoreferenceTransform transform;
    String method;

    if (controlPoints.length == 2) {
      transform = calculateTransform(
        point1: controlPoints[0],
        point2: controlPoints[1],
      );
      method = twoPointMethod;
    } else {
      _validatePairwiseDistances(controlPoints);
      transform = _calculateLeastSquaresTransform(controlPoints);
      method = leastSquaresMethod;
    }

    return _buildFitResult(
      controlPoints: controlPoints,
      transform: transform,
      method: method,
    );
  }

  /// Backward-compatible layer API for exactly two control points.
  LayerGeoreferenceResult georeferenceLayer({
    required MapLayer sourceLayer,
    required GeoreferenceControlPoint point1,
    required GeoreferenceControlPoint point2,
    required CoordinateReferenceSystem targetCrs,
    String? newLayerId,
    String? newLayerName,
  }) {
    return georeferenceLayerWithControlPoints(
      sourceLayer: sourceLayer,
      controlPoints: [point1, point2],
      targetCrs: targetCrs,
      newLayerId: newLayerId,
      newLayerName: newLayerName,
    );
  }

  LayerGeoreferenceResult georeferenceLayerWithControlPoints({
    required MapLayer sourceLayer,
    required List<GeoreferenceControlPoint> controlPoints,
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

    final fit = fitControlPoints(
      controlPoints: controlPoints,
      targetCrs: targetCrs,
    );
    var coordinateCount = 0;
    final transformedFeatures = sourceLayer.features.map((feature) {
      final coordinates = feature.coordinates.map((coordinate) {
        coordinateCount++;
        return fit.transform.transform(coordinate);
      }).toList();

      return feature.copyWith(
        coordinates: coordinates,
        properties: Map<String, String>.from(feature.properties),
      );
    }).toList();

    final properties = Map<String, String>.from(sourceLayer.properties)
      ..addAll({
        'georeferenced': 'true',
        'georeferenceMethod': fit.method,
        'georeferenceScale': fit.transform.scale.toStringAsPrecision(15),
        'georeferenceRotationDegrees': fit.transform.rotationDegrees
            .toStringAsPrecision(15),
        'georeferenceTranslationX': fit.transform.translationX
            .toStringAsPrecision(15),
        'georeferenceTranslationY': fit.transform.translationY
            .toStringAsPrecision(15),
        'georeferenceControlPointError': fit.maxResidual.planarError
            .toStringAsPrecision(15),
        'georeferenceControlPointCount': fit.controlPointCount.toString(),
        'georeferenceRmse': fit.rmse.toStringAsPrecision(15),
        'georeferenceMaxResidual': fit.maxResidual.planarError
            .toStringAsPrecision(15),
        'georeferenceMaxResidualIndex': fit.maxResidualIndex.toString(),
        'targetCrs': targetCrs.displayName,
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
      transform: fit.transform,
      transformedFeatureCount: transformedFeatures.length,
      transformedCoordinateCount: coordinateCount,
      controlPointError: fit.maxResidual.planarError,
      residuals: fit.residuals,
      rmse: fit.rmse,
      maxResidual: fit.maxResidual,
      controlPointCount: fit.controlPointCount,
      georeferenceMethod: fit.method,
    );
  }

  GeoreferenceTransform _calculateLeastSquaresTransform(
    List<GeoreferenceControlPoint> controlPoints,
  ) {
    final count = controlPoints.length;
    final localMeanX = _mean(controlPoints.map((point) => point.local.x));
    final localMeanY = _mean(controlPoints.map((point) => point.local.y));
    final targetMeanX = _mean(controlPoints.map((point) => point.target.x));
    final targetMeanY = _mean(controlPoints.map((point) => point.target.y));
    var denominator = 0.0;
    var targetSpread = 0.0;
    var numeratorA = 0.0;
    var numeratorB = 0.0;

    for (final point in controlPoints) {
      final dx = point.local.x - localMeanX;
      final dy = point.local.y - localMeanY;
      final targetDx = point.target.x - targetMeanX;
      final targetDy = point.target.y - targetMeanY;
      denominator += dx * dx + dy * dy;
      targetSpread += targetDx * targetDx + targetDy * targetDy;
      numeratorA += dx * targetDx + dy * targetDy;
      numeratorB += dx * targetDy - dy * targetDx;
    }

    final localTolerance = _datasetTolerance(
      controlPoints.map((point) => point.local),
    );
    final targetTolerance = _datasetTolerance(
      controlPoints.map((point) => point.target),
    );
    final minimumLocalSpread = count * localTolerance * localTolerance;
    final minimumTargetSpread = count * targetTolerance * targetTolerance;

    if (!denominator.isFinite || denominator <= minimumLocalSpread) {
      throw ArgumentError('Phân bố điểm CAD bị suy biến hoặc quá kém.');
    }
    if (!targetSpread.isFinite || targetSpread <= minimumTargetSpread) {
      throw ArgumentError('Phân bố điểm target bị suy biến hoặc quá kém.');
    }
    if (!numeratorA.isFinite || !numeratorB.isFinite) {
      throw ArgumentError('Hệ số least-squares không hữu hạn.');
    }

    final a = numeratorA / denominator;
    final b = numeratorB / denominator;
    final scale = math.sqrt(a * a + b * b);
    final rotation = math.atan2(b, a);
    final translationX = targetMeanX - a * localMeanX + b * localMeanY;
    final translationY = targetMeanY - b * localMeanX - a * localMeanY;

    _validateTransformParameters(
      scale: scale,
      rotation: rotation,
      translationX: translationX,
      translationY: translationY,
    );

    return GeoreferenceTransform(
      scale: scale,
      rotationRadians: rotation,
      translationX: translationX,
      translationY: translationY,
    );
  }

  GeoreferenceFitResult _buildFitResult({
    required List<GeoreferenceControlPoint> controlPoints,
    required GeoreferenceTransform transform,
    required String method,
  }) {
    final residuals = <GeoreferenceResidual>[];
    var squaredErrorSum = 0.0;

    for (var index = 0; index < controlPoints.length; index++) {
      final point = controlPoints[index];
      final predicted = transform.transform(point.local);
      final deltaX = predicted.x - point.target.x;
      final deltaY = predicted.y - point.target.y;
      final planarError = math.sqrt(deltaX * deltaX + deltaY * deltaY);

      if (!deltaX.isFinite || !deltaY.isFinite || !planarError.isFinite) {
        throw StateError('Residual điểm ${index + 1} không hữu hạn.');
      }

      squaredErrorSum += planarError * planarError;
      residuals.add(
        GeoreferenceResidual(
          controlPointIndex: index,
          deltaX: deltaX,
          deltaY: deltaY,
          planarError: planarError,
        ),
      );
    }

    final rmse = math.sqrt(squaredErrorSum / controlPoints.length);
    if (!rmse.isFinite) {
      throw StateError('RMSE của phép định vị không hữu hạn.');
    }
    final maxResidual = residuals.reduce(
      (current, candidate) =>
          candidate.planarError > current.planarError ? candidate : current,
    );

    return GeoreferenceFitResult(
      transform: transform,
      residuals: residuals,
      rmse: rmse,
      maxResidual: maxResidual,
      method: method,
    );
  }

  void _validatePairwiseDistances(
    List<GeoreferenceControlPoint> controlPoints,
  ) {
    final localTolerance = _datasetTolerance(
      controlPoints.map((point) => point.local),
    );
    final targetTolerance = _datasetTolerance(
      controlPoints.map((point) => point.target),
    );

    for (var first = 0; first < controlPoints.length - 1; first++) {
      for (var second = first + 1; second < controlPoints.length; second++) {
        if (_distance(
              controlPoints[first].local,
              controlPoints[second].local,
            ) <=
            localTolerance) {
          throw ArgumentError(
            'Điểm CAD ${first + 1} và ${second + 1} trùng hoặc quá gần nhau.',
          );
        }
        if (_distance(
              controlPoints[first].target,
              controlPoints[second].target,
            ) <=
            targetTolerance) {
          throw ArgumentError(
            'Điểm target ${first + 1} và ${second + 1} trùng hoặc quá gần nhau.',
          );
        }
      }
    }
  }

  double _datasetTolerance(Iterable<MapCoordinate> coordinates) {
    final values = coordinates.toList();
    var minX = values.first.x;
    var maxX = values.first.x;
    var minY = values.first.y;
    var maxY = values.first.y;

    for (final coordinate in values.skip(1)) {
      minX = math.min(minX, coordinate.x);
      maxX = math.max(maxX, coordinate.x);
      minY = math.min(minY, coordinate.y);
      maxY = math.max(maxY, coordinate.y);
    }

    final extent = math.max(maxX - minX, maxY - minY);
    if (!extent.isFinite) {
      throw ArgumentError('Phạm vi điểm khống chế không hữu hạn.');
    }
    return math.max(minimumControlPointDistance, extent * 1e-12);
  }

  double _mean(Iterable<double> values) {
    var sum = 0.0;
    var compensation = 0.0;
    var count = 0;

    for (final value in values) {
      final adjusted = value - compensation;
      final next = sum + adjusted;
      compensation = (next - sum) - adjusted;
      sum = next;
      count++;
    }

    final result = sum / count;
    if (!result.isFinite) {
      throw ArgumentError('Centroid điểm khống chế không hữu hạn.');
    }
    return result;
  }

  double _distance(MapCoordinate first, MapCoordinate second) {
    final dx = first.x - second.x;
    final dy = first.y - second.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  void _validateTransformParameters({
    required double scale,
    required double rotation,
    required double translationX,
    required double translationY,
  }) {
    if (!scale.isFinite || scale <= minimumControlPointDistance) {
      throw ArgumentError('Scale của phép định vị không hợp lệ.');
    }
    if (!rotation.isFinite ||
        !translationX.isFinite ||
        !translationY.isFinite) {
      throw ArgumentError(
        'Rotation hoặc translation của phép định vị không hợp lệ.',
      );
    }
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
