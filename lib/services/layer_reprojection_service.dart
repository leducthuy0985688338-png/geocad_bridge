import '../models/coordinate_reference_system.dart';
import '../models/map_feature.dart';
import '../models/map_layer.dart';
import 'coordinate_transform_service.dart';

class LayerReprojectionResult {
  final MapLayer layer;
  final int transformedFeatureCount;
  final int transformedCoordinateCount;

  const LayerReprojectionResult({
    required this.layer,
    required this.transformedFeatureCount,
    required this.transformedCoordinateCount,
  });
}

class LayerReprojectionService {
  final CoordinateTransformService coordinateTransformService;

  const LayerReprojectionService({
    this.coordinateTransformService =
        const CoordinateTransformService(),
  });

  bool canReproject(
    CoordinateReferenceSystem source,
    CoordinateReferenceSystem target,
  ) {
    if (!source.isValid || !target.isValid) {
      return false;
    }

    if (source.isLocalCad || target.isLocalCad) {
      return false;
    }

    return true;
  }

  LayerReprojectionResult reprojectLayer({
    required MapLayer sourceLayer,
    required CoordinateReferenceSystem targetCrs,
    String? newLayerId,
    String? newLayerName,
  }) {
    final sourceCrs = sourceLayer.crs;

    if (!canReproject(sourceCrs, targetCrs)) {
      throw StateError(
        'Không thể chuyển hệ tọa độ từ '
        '${sourceCrs.displayName} sang '
        '${targetCrs.displayName}.',
      );
    }

    if (_sameCrs(sourceCrs, targetCrs)) {
      final copiedLayer = sourceLayer.copyWith(
        id: newLayerId ?? '${sourceLayer.id}-reprojected',
        name: newLayerName ??
            '${sourceLayer.name} (${targetCrs.displayName})',
        crs: targetCrs,
        features: List<MapFeature>.from(
          sourceLayer.features,
        ),
        properties: _buildLayerProperties(
          sourceLayer: sourceLayer,
          targetCrs: targetCrs,
        ),
      );

      return LayerReprojectionResult(
        layer: copiedLayer,
        transformedFeatureCount:
            copiedLayer.features.length,
        transformedCoordinateCount:
            copiedLayer.features.fold<int>(
          0,
          (sum, feature) =>
              sum + feature.coordinates.length,
        ),
      );
    }

    var coordinateCount = 0;

    final transformedFeatures =
        sourceLayer.features.map((feature) {
      final transformedCoordinates =
          feature.coordinates.map((coordinate) {
        coordinateCount++;

        return _transformCoordinate(
          coordinate: coordinate,
          sourceCrs: sourceCrs,
          targetCrs: targetCrs,
        );
      }).toList();

      return feature.copyWith(
        coordinates: transformedCoordinates,
      );
    }).toList();

    final resultLayer = sourceLayer.copyWith(
      id: newLayerId ?? '${sourceLayer.id}-reprojected',
      name: newLayerName ??
          '${sourceLayer.name} (${targetCrs.displayName})',
      crs: targetCrs,
      features: transformedFeatures,
      properties: _buildLayerProperties(
        sourceLayer: sourceLayer,
        targetCrs: targetCrs,
      ),
    );

    return LayerReprojectionResult(
      layer: resultLayer,
      transformedFeatureCount:
          transformedFeatures.length,
      transformedCoordinateCount: coordinateCount,
    );
  }

  MapCoordinate _transformCoordinate({
    required MapCoordinate coordinate,
    required CoordinateReferenceSystem sourceCrs,
    required CoordinateReferenceSystem targetCrs,
  }) {
    final geographic =
        coordinateTransformService.toWgs84(
      coordinate: coordinate,
      sourceCrs: sourceCrs,
    );

    final transformed =
        coordinateTransformService.fromWgs84(
      coordinate: geographic,
      targetCrs: targetCrs,
    );

    return MapCoordinate(
      x: transformed.x,
      y: transformed.y,
      z: coordinate.z,
    );
  }

  bool _sameCrs(
    CoordinateReferenceSystem a,
    CoordinateReferenceSystem b,
  ) {
    return a.type == b.type &&
        a.utmZone == b.utmZone &&
        a.hemisphere == b.hemisphere;
  }

  Map<String, String> _buildLayerProperties({
    required MapLayer sourceLayer,
    required CoordinateReferenceSystem targetCrs,
  }) {
    final properties =
        Map<String, String>.from(sourceLayer.properties);

    properties.addAll({
      'reprojected': 'true',
      'sourceCrs': sourceLayer.crs.displayName,
      'targetCrs': targetCrs.displayName,
    });

    final sourceEpsg = sourceLayer.crs.epsgCode;
    final targetEpsg = targetCrs.epsgCode;

    if (sourceEpsg != null) {
      properties['sourceEpsg'] = sourceEpsg.toString();
    }

    if (targetEpsg != null) {
      properties['targetEpsg'] = targetEpsg.toString();
    }

    return properties;
  }
}
