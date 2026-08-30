import 'package:flutter_test/flutter_test.dart';

import 'package:autocad_googleearth/models/coordinate_reference_system.dart';
import 'package:autocad_googleearth/models/map_feature.dart';
import 'package:autocad_googleearth/models/map_layer.dart';
import 'package:autocad_googleearth/services/kml_export_service.dart';
import 'package:autocad_googleearth/services/layer_georeference_service.dart';
import 'package:autocad_googleearth/services/layer_reprojection_service.dart';

void main() {
  const service = LayerGeoreferenceService();

  GeoreferenceControlPoint controlPoint({
    required double localX,
    required double localY,
    required double targetX,
    required double targetY,
  }) {
    return GeoreferenceControlPoint(
      local: MapCoordinate(x: localX, y: localY),
      target: MapCoordinate(x: targetX, y: targetY),
    );
  }

  MapLayer localPointLayer({MapCoordinate? coordinate}) {
    return MapLayer(
      id: 'local-layer',
      name: 'Drawing.dxf',
      sourceType: MapLayerSourceType.dxf,
      features: [
        MapFeature(
          id: 'point',
          type: MapFeatureType.point,
          coordinates: [coordinate ?? const MapCoordinate(x: 0, y: 0)],
        ),
      ],
    );
  }

  test('calculates translation-only transform', () {
    final transform = service.calculateTransform(
      point1: controlPoint(localX: 0, localY: 0, targetX: 100, targetY: 200),
      point2: controlPoint(localX: 10, localY: 0, targetX: 110, targetY: 200),
    );

    final output = transform.transform(const MapCoordinate(x: 2, y: 3));

    expect(transform.scale, closeTo(1, 1e-12));
    expect(transform.rotationDegrees, closeTo(0, 1e-12));
    expect(output.x, closeTo(102, 1e-10));
    expect(output.y, closeTo(203, 1e-10));
  });

  test('calculates scale-only transform', () {
    final transform = service.calculateTransform(
      point1: controlPoint(localX: 0, localY: 0, targetX: 0, targetY: 0),
      point2: controlPoint(localX: 10, localY: 0, targetX: 20, targetY: 0),
    );

    final output = transform.transform(const MapCoordinate(x: 3, y: 4));

    expect(transform.scale, closeTo(2, 1e-12));
    expect(output.x, closeTo(6, 1e-10));
    expect(output.y, closeTo(8, 1e-10));
  });

  test('calculates a 90-degree rotation', () {
    final transform = service.calculateTransform(
      point1: controlPoint(localX: 0, localY: 0, targetX: 0, targetY: 0),
      point2: controlPoint(localX: 10, localY: 0, targetX: 0, targetY: 10),
    );

    final output = transform.transform(const MapCoordinate(x: 2, y: 3));

    expect(transform.rotationDegrees, closeTo(90, 1e-10));
    expect(output.x, closeTo(-3, 1e-10));
    expect(output.y, closeTo(2, 1e-10));
  });

  test('combines scale rotation translation and preserves Z', () {
    final transform = service.calculateTransform(
      point1: controlPoint(
        localX: 0,
        localY: 0,
        targetX: 500000,
        targetY: 1800000,
      ),
      point2: controlPoint(
        localX: 100,
        localY: 0,
        targetX: 500000,
        targetY: 1800200,
      ),
    );

    final output = transform.transform(const MapCoordinate(x: 0, y: 50, z: 7));

    expect(transform.scale, closeTo(2, 1e-12));
    expect(transform.rotationDegrees, closeTo(90, 1e-10));
    expect(output.x, closeTo(499900, 1e-8));
    expect(output.y, closeTo(1800000, 1e-8));
    expect(output.z, 7);
  });

  test('transforms every feature type and preserves metadata', () {
    final featureProperties = <String, String>{
      'cadLayer': 'SURVEY',
      'textStyle': 'STANDARD',
    };
    final layerProperties = <String, String>{'sourceFormat': 'DXF'};
    final features = MapFeatureType.values.indexed.map((entry) {
      final (index, type) = entry;
      final coordinates = switch (type) {
        MapFeatureType.point || MapFeatureType.text => [
          MapCoordinate(x: index.toDouble(), y: 0, z: index.toDouble()),
        ],
        MapFeatureType.line => const [
          MapCoordinate(x: 0, y: 0, z: 1),
          MapCoordinate(x: 1, y: 1, z: 2),
        ],
        MapFeatureType.polyline || MapFeatureType.polygon => const [
          MapCoordinate(x: 0, y: 0, z: 1),
          MapCoordinate(x: 1, y: 0, z: 2),
          MapCoordinate(x: 1, y: 1, z: 3),
        ],
      };

      return MapFeature(
        id: 'feature-$index',
        type: type,
        name: type.name,
        description: 'description-$index',
        coordinates: coordinates,
        properties: Map<String, String>.from(featureProperties),
        visible: index.isEven,
      );
    }).toList();
    final source = MapLayer(
      id: 'source',
      name: 'Survey.dxf',
      sourcePath: r'C:\survey\Survey.dxf',
      sourceType: MapLayerSourceType.dxf,
      features: features,
      visible: false,
      locked: true,
      properties: layerProperties,
    );

    final result = service.georeferenceLayer(
      sourceLayer: source,
      point1: controlPoint(
        localX: 0,
        localY: 0,
        targetX: 500000,
        targetY: 1800000,
      ),
      point2: controlPoint(
        localX: 10,
        localY: 0,
        targetX: 500010,
        targetY: 1800000,
      ),
      targetCrs: const CoordinateReferenceSystem.utm(
        utmZone: 48,
        hemisphere: UtmHemisphere.north,
      ),
    );

    expect(result.transformedFeatureCount, MapFeatureType.values.length);
    expect(
      result.layer.features.map((feature) => feature.type),
      MapFeatureType.values,
    );
    expect(result.layer.sourcePath, source.sourcePath);
    expect(result.layer.sourceType, source.sourceType);
    expect(result.layer.visible, source.visible);
    expect(result.layer.locked, source.locked);
    expect(result.layer.properties['sourceFormat'], 'DXF');
    expect(result.layer.properties['georeferenced'], 'true');
    expect(result.layer.properties['targetEpsg'], '32648');

    for (var index = 0; index < features.length; index++) {
      final input = features[index];
      final output = result.layer.features[index];
      expect(output.id, input.id);
      expect(output.name, input.name);
      expect(output.description, input.description);
      expect(output.visible, input.visible);
      expect(output.properties, input.properties);
      expect(
        output.coordinates.map((coordinate) => coordinate.z),
        input.coordinates.map((coordinate) => coordinate.z),
      );
    }
  });

  test('deep-copies output so mutations do not affect source', () {
    final sourceCoordinates = [const MapCoordinate(x: 0, y: 0, z: 5)];
    final featureProperties = <String, String>{'cadLayer': 'POINTS'};
    final layerProperties = <String, String>{'owner': 'source'};
    final sourceFeature = MapFeature(
      id: 'point',
      type: MapFeatureType.point,
      coordinates: sourceCoordinates,
      properties: featureProperties,
    );
    final source = MapLayer(
      id: 'source',
      name: 'Source',
      sourceType: MapLayerSourceType.dxf,
      features: [sourceFeature],
      properties: layerProperties,
    );

    final result = service.georeferenceLayer(
      sourceLayer: source,
      point1: controlPoint(
        localX: 0,
        localY: 0,
        targetX: 500000,
        targetY: 1800000,
      ),
      point2: controlPoint(
        localX: 10,
        localY: 0,
        targetX: 500010,
        targetY: 1800000,
      ),
      targetCrs: const CoordinateReferenceSystem.utm(
        utmZone: 48,
        hemisphere: UtmHemisphere.north,
      ),
    );
    final outputFeature = result.layer.features.single;

    expect(result.layer, isNot(same(source)));
    expect(result.layer.features, isNot(same(source.features)));
    expect(result.layer.properties, isNot(same(layerProperties)));
    expect(outputFeature, isNot(same(sourceFeature)));
    expect(outputFeature.coordinates, isNot(same(sourceCoordinates)));
    expect(
      outputFeature.coordinates.single,
      isNot(same(sourceCoordinates.single)),
    );
    expect(outputFeature.properties, isNot(same(featureProperties)));

    result.layer.properties['owner'] = 'changed';
    outputFeature.properties['cadLayer'] = 'changed';
    outputFeature.coordinates.add(const MapCoordinate(x: 1, y: 1));

    expect(source.properties, {'owner': 'source'});
    expect(sourceFeature.properties, {'cadLayer': 'POINTS'});
    expect(sourceFeature.coordinates, hasLength(1));
    expect(sourceFeature.coordinates.single.z, 5);
  });

  test('rejects coincident or too-close CAD control points', () {
    for (final distance in [0.0, 5e-10]) {
      expect(
        () => service.calculateTransform(
          point1: controlPoint(
            localX: 0,
            localY: 0,
            targetX: 500000,
            targetY: 1800000,
          ),
          point2: controlPoint(
            localX: distance,
            localY: 0,
            targetX: 500010,
            targetY: 1800000,
          ),
        ),
        throwsArgumentError,
      );
    }
  });

  test('rejects coincident or too-close target control points', () {
    for (final distance in [0.0, 5e-10]) {
      expect(
        () => service.calculateTransform(
          point1: controlPoint(
            localX: 0,
            localY: 0,
            targetX: 500000,
            targetY: 1800000,
          ),
          point2: controlPoint(
            localX: 10,
            localY: 0,
            targetX: 500000 + distance,
            targetY: 1800000,
          ),
        ),
        throwsArgumentError,
      );
    }
  });

  test('rejects NaN and infinity in control points', () {
    for (final invalid in [
      double.nan,
      double.infinity,
      double.negativeInfinity,
    ]) {
      expect(
        () => service.calculateTransform(
          point1: GeoreferenceControlPoint(
            local: MapCoordinate(x: invalid, y: 0),
            target: const MapCoordinate(x: 500000, y: 1800000),
          ),
          point2: const GeoreferenceControlPoint(
            local: MapCoordinate(x: 10, y: 0),
            target: MapCoordinate(x: 500010, y: 1800000),
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => service.calculateTransform(
          point1: GeoreferenceControlPoint(
            local: const MapCoordinate(x: 0, y: 0),
            target: MapCoordinate(x: 500000, y: invalid),
          ),
          point2: const GeoreferenceControlPoint(
            local: MapCoordinate(x: 10, y: 0),
            target: MapCoordinate(x: 500010, y: 1800000),
          ),
        ),
        throwsArgumentError,
      );
    }
  });

  test('rejects NaN infinity and non-finite Z in source geometry', () {
    for (final coordinate in [
      const MapCoordinate(x: double.nan, y: 0),
      const MapCoordinate(x: 0, y: double.infinity),
      const MapCoordinate(x: 0, y: 0, z: double.negativeInfinity),
    ]) {
      expect(
        () => service.georeferenceLayer(
          sourceLayer: localPointLayer(coordinate: coordinate),
          point1: controlPoint(
            localX: 0,
            localY: 0,
            targetX: 500000,
            targetY: 1800000,
          ),
          point2: controlPoint(
            localX: 10,
            localY: 0,
            targetX: 500010,
            targetY: 1800000,
          ),
          targetCrs: const CoordinateReferenceSystem.utm(
            utmZone: 48,
            hemisphere: UtmHemisphere.north,
          ),
        ),
        throwsArgumentError,
      );
    }
  });

  test('rejects local and incomplete UTM target CRS', () {
    for (final targetCrs in [
      const CoordinateReferenceSystem.localCad(),
      const CoordinateReferenceSystem.utm(
        utmZone: 0,
        hemisphere: UtmHemisphere.north,
      ),
      const CoordinateReferenceSystem.utm(
        utmZone: 61,
        hemisphere: UtmHemisphere.north,
      ),
      const CoordinateReferenceSystem.utm(utmZone: 48, hemisphere: null),
    ]) {
      expect(
        () => service.georeferenceLayer(
          sourceLayer: localPointLayer(),
          point1: controlPoint(
            localX: 0,
            localY: 0,
            targetX: 500000,
            targetY: 1800000,
          ),
          point2: controlPoint(
            localX: 10,
            localY: 0,
            targetX: 500010,
            targetY: 1800000,
          ),
          targetCrs: targetCrs,
        ),
        throwsArgumentError,
      );
    }
  });

  test('rejects invalid UTM target coordinates', () {
    for (final target in [
      const MapCoordinate(x: 99999, y: 1800000),
      const MapCoordinate(x: 500000, y: -1),
      const MapCoordinate(x: 500000, y: 10000001),
    ]) {
      expect(
        () => service.georeferenceLayer(
          sourceLayer: localPointLayer(),
          point1: GeoreferenceControlPoint(
            local: const MapCoordinate(x: 0, y: 0),
            target: target,
          ),
          point2: const GeoreferenceControlPoint(
            local: MapCoordinate(x: 10, y: 0),
            target: MapCoordinate(x: 500010, y: 1800000),
          ),
          targetCrs: const CoordinateReferenceSystem.utm(
            utmZone: 48,
            hemisphere: UtmHemisphere.north,
          ),
        ),
        throwsArgumentError,
      );
    }
  });

  test('rejects invalid WGS84 target coordinates', () {
    for (final target in [
      const MapCoordinate(x: 180.0001, y: 16),
      const MapCoordinate(x: 105, y: 90.0001),
    ]) {
      expect(
        () => service.georeferenceLayer(
          sourceLayer: localPointLayer(),
          point1: GeoreferenceControlPoint(
            local: const MapCoordinate(x: 0, y: 0),
            target: target,
          ),
          point2: const GeoreferenceControlPoint(
            local: MapCoordinate(x: 10, y: 0),
            target: MapCoordinate(x: 105.001, y: 16),
          ),
          targetCrs: const CoordinateReferenceSystem.wgs84(),
        ),
        throwsArgumentError,
      );
    }
  });

  test('rejects a source layer that is not localCad', () {
    final source = localPointLayer().copyWith(
      crs: const CoordinateReferenceSystem.utm(
        utmZone: 48,
        hemisphere: UtmHemisphere.north,
      ),
    );

    expect(
      () => service.georeferenceLayer(
        sourceLayer: source,
        point1: controlPoint(
          localX: 0,
          localY: 0,
          targetX: 500000,
          targetY: 1800000,
        ),
        point2: controlPoint(
          localX: 10,
          localY: 0,
          targetX: 500010,
          targetY: 1800000,
        ),
        targetCrs: const CoordinateReferenceSystem.utm(
          utmZone: 48,
          hemisphere: UtmHemisphere.north,
        ),
      ),
      throwsArgumentError,
    );
  });

  test('integrates localCad to UTM to WGS84 and KML export', () {
    final georeferenced = service.georeferenceLayer(
      sourceLayer: localPointLayer(
        coordinate: const MapCoordinate(x: 0, y: 0, z: 25),
      ),
      point1: controlPoint(
        localX: 0,
        localY: 0,
        targetX: 500000,
        targetY: 1768935.376,
      ),
      point2: controlPoint(
        localX: 10,
        localY: 0,
        targetX: 500010,
        targetY: 1768935.376,
      ),
      targetCrs: const CoordinateReferenceSystem.utm(
        utmZone: 48,
        hemisphere: UtmHemisphere.north,
      ),
    );

    final wgs84 = const LayerReprojectionService().reprojectLayer(
      sourceLayer: georeferenced.layer,
      targetCrs: const CoordinateReferenceSystem.wgs84(),
    );
    final coordinate = wgs84.layer.features.single.coordinates.single;

    expect(georeferenced.layer.crs.epsgCode, 32648);
    expect(wgs84.layer.crs.isWgs84, isTrue);
    expect(coordinate.x, closeTo(105, 0.000001));
    expect(coordinate.y, closeTo(16, 0.000001));
    expect(coordinate.z, 25);
    expect(
      () => const KmlExportService().exportLayers(
        documentName: 'Georeferenced',
        layers: [wgs84.layer],
      ),
      returnsNormally,
    );
  });

  test('list API with two points preserves legacy behavior', () {
    final point1 = controlPoint(
      localX: 10,
      localY: 20,
      targetX: 500000,
      targetY: 1800000,
    );
    final point2 = controlPoint(
      localX: 110,
      localY: 20,
      targetX: 500000,
      targetY: 1800200,
    );

    final legacy = service.calculateTransform(point1: point1, point2: point2);
    final fit = service.fitControlPoints(controlPoints: [point1, point2]);

    expect(fit.method, LayerGeoreferenceService.twoPointMethod);
    expect(fit.transform.scale, legacy.scale);
    expect(fit.transform.rotationRadians, legacy.rotationRadians);
    expect(fit.transform.translationX, legacy.translationX);
    expect(fit.transform.translationY, legacy.translationY);
    expect(fit.controlPointCount, 2);
    expect(fit.rmse, closeTo(0, 1e-8));
  });

  test('solves an exact multi-point similarity dataset', () {
    const points = [
      GeoreferenceControlPoint(
        local: MapCoordinate(x: 0, y: 0),
        target: MapCoordinate(x: 500000, y: 1800000),
      ),
      GeoreferenceControlPoint(
        local: MapCoordinate(x: 10, y: 0),
        target: MapCoordinate(x: 500000, y: 1800020),
      ),
      GeoreferenceControlPoint(
        local: MapCoordinate(x: 0, y: 10),
        target: MapCoordinate(x: 499980, y: 1800000),
      ),
      GeoreferenceControlPoint(
        local: MapCoordinate(x: 10, y: 10),
        target: MapCoordinate(x: 499980, y: 1800020),
      ),
    ];

    final fit = service.fitControlPoints(controlPoints: points);

    expect(fit.method, LayerGeoreferenceService.leastSquaresMethod);
    expect(fit.transform.scale, closeTo(2, 1e-12));
    expect(fit.transform.rotationDegrees, closeTo(90, 1e-10));
    expect(fit.transform.translationX, closeTo(500000, 1e-8));
    expect(fit.transform.translationY, closeTo(1800000, 1e-8));
    expect(fit.rmse, closeTo(0, 1e-8));
    expect(
      fit.residuals.map((residual) => residual.planarError),
      everyElement(closeTo(0, 1e-8)),
    );
  });

  test('computes deterministic noisy residuals RMSE and max index', () {
    const points = [
      GeoreferenceControlPoint(
        local: MapCoordinate(x: -1, y: -1),
        target: MapCoordinate(x: 99.1, y: 199),
      ),
      GeoreferenceControlPoint(
        local: MapCoordinate(x: 1, y: -1),
        target: MapCoordinate(x: 100.9, y: 199),
      ),
      GeoreferenceControlPoint(
        local: MapCoordinate(x: 1, y: 1),
        target: MapCoordinate(x: 101.1, y: 201),
      ),
      GeoreferenceControlPoint(
        local: MapCoordinate(x: -1, y: 1),
        target: MapCoordinate(x: 98.9, y: 201),
      ),
    ];

    final fit = service.fitControlPoints(controlPoints: points);

    expect(fit.transform.scale, closeTo(1, 1e-12));
    expect(fit.transform.rotationDegrees, closeTo(0, 1e-10));
    expect(fit.transform.translationX, closeTo(100, 1e-12));
    expect(fit.transform.translationY, closeTo(200, 1e-12));
    expect(fit.residuals.map((residual) => residual.deltaX).toList(), [
      closeTo(-0.1, 1e-12),
      closeTo(0.1, 1e-12),
      closeTo(-0.1, 1e-12),
      closeTo(0.1, 1e-12),
    ]);
    expect(
      fit.residuals.map((residual) => residual.deltaY),
      everyElement(closeTo(0, 1e-12)),
    );
    expect(fit.rmse, closeTo(0.1, 1e-12));
    expect(fit.maxResidual.planarError, closeTo(0.1, 1e-12));
    expect(fit.maxResidualIndex, 0);
  });

  test('accepts collinear multi-point control points', () {
    final fit = service.fitControlPoints(
      controlPoints: [
        controlPoint(localX: 0, localY: 0, targetX: 100, targetY: 200),
        controlPoint(localX: 10, localY: 0, targetX: 120, targetY: 200),
        controlPoint(localX: 20, localY: 0, targetX: 140, targetY: 200),
      ],
    );

    expect(fit.transform.scale, closeTo(2, 1e-12));
    expect(fit.rmse, closeTo(0, 1e-10));
  });

  test('rejects fewer than two control points', () {
    for (final points in <List<GeoreferenceControlPoint>>[
      const [],
      [controlPoint(localX: 0, localY: 0, targetX: 100, targetY: 200)],
    ]) {
      expect(
        () => service.fitControlPoints(controlPoints: points),
        throwsArgumentError,
      );
    }
  });

  test('rejects pairwise duplicate local and target points', () {
    final valid = [
      controlPoint(localX: 0, localY: 0, targetX: 100, targetY: 200),
      controlPoint(localX: 10, localY: 0, targetX: 110, targetY: 200),
    ];

    expect(
      () => service.fitControlPoints(
        controlPoints: [
          ...valid,
          controlPoint(localX: 5e-10, localY: 0, targetX: 120, targetY: 200),
        ],
      ),
      throwsArgumentError,
    );
    expect(
      () => service.fitControlPoints(
        controlPoints: [
          ...valid,
          controlPoint(
            localX: 20,
            localY: 0,
            targetX: 100 + 5e-10,
            targetY: 200,
          ),
        ],
      ),
      throwsArgumentError,
    );
  });

  test('rejects a near-zero least-squares scale', () {
    expect(
      () => service.fitControlPoints(
        controlPoints: [
          controlPoint(localX: 0, localY: 0, targetX: 0, targetY: 0),
          controlPoint(localX: 1e12, localY: 0, targetX: 0.001, targetY: 0),
          controlPoint(localX: 0, localY: 1e12, targetX: 0, targetY: 0.001),
        ],
      ),
      throwsArgumentError,
    );
  });

  test('stores multi-point quality metadata and immutable residuals', () {
    final points = [
      controlPoint(localX: 0, localY: 0, targetX: 500000, targetY: 1800000),
      controlPoint(localX: 10, localY: 0, targetX: 500010, targetY: 1800000),
      controlPoint(localX: 0, localY: 10, targetX: 500000, targetY: 1800010),
    ];
    final result = service.georeferenceLayerWithControlPoints(
      sourceLayer: localPointLayer(),
      controlPoints: points,
      targetCrs: const CoordinateReferenceSystem.utm(
        utmZone: 48,
        hemisphere: UtmHemisphere.north,
      ),
    );

    expect(result.controlPointCount, 3);
    expect(
      result.georeferenceMethod,
      LayerGeoreferenceService.leastSquaresMethod,
    );
    expect(result.controlPointError, result.maxResidual!.planarError);
    expect(result.layer.properties['georeferenceControlPointCount'], '3');
    expect(
      result.layer.properties['georeferenceMethod'],
      LayerGeoreferenceService.leastSquaresMethod,
    );
    expect(result.layer.properties, contains('georeferenceRmse'));
    expect(result.layer.properties, contains('georeferenceMaxResidual'));
    expect(result.layer.properties, contains('georeferenceMaxResidualIndex'));
    expect(
      () => result.residuals.add(
        const GeoreferenceResidual(
          controlPointIndex: 3,
          deltaX: 0,
          deltaY: 0,
          planarError: 0,
        ),
      ),
      throwsUnsupportedError,
    );
  });

  test('integrates multi-point localCad to UTM to WGS84 and KML', () {
    final georeferenced = service.georeferenceLayerWithControlPoints(
      sourceLayer: localPointLayer(
        coordinate: const MapCoordinate(x: 0, y: 0, z: 30),
      ),
      controlPoints: [
        controlPoint(
          localX: 0,
          localY: 0,
          targetX: 500000,
          targetY: 1768935.376,
        ),
        controlPoint(
          localX: 10,
          localY: 0,
          targetX: 500010,
          targetY: 1768935.376,
        ),
        controlPoint(
          localX: 0,
          localY: 10,
          targetX: 500000,
          targetY: 1768945.376,
        ),
      ],
      targetCrs: const CoordinateReferenceSystem.utm(
        utmZone: 48,
        hemisphere: UtmHemisphere.north,
      ),
    );
    final wgs84 = const LayerReprojectionService().reprojectLayer(
      sourceLayer: georeferenced.layer,
      targetCrs: const CoordinateReferenceSystem.wgs84(),
    );

    expect(georeferenced.controlPointCount, 3);
    expect(wgs84.layer.features.single.coordinates.single.z, 30);
    expect(
      () => const KmlExportService().exportLayers(
        documentName: 'Multi-point',
        layers: [wgs84.layer],
      ),
      returnsNormally,
    );
  });

  List<GeoreferenceControlPoint> qualityPoints(int count) {
    return List.generate(
      count,
      (index) => controlPoint(
        localX: index.toDouble(),
        localY: index.isEven ? 0 : 1,
        targetX: 500000 + index * 10,
        targetY: 1800000 + (index.isEven ? 0 : 10),
      ),
    );
  }

  List<GeoreferenceResidual> qualityResiduals(List<double> errors) {
    return List.generate(
      errors.length,
      (index) => GeoreferenceResidual(
        controlPointIndex: index,
        deltaX: errors[index],
        deltaY: 0,
        planarError: errors[index],
      ),
    );
  }

  test(
    'two-point quality control is not applicable without worst highlight',
    () {
      final assessment = service.assessResiduals(
        controlPoints: qualityPoints(2),
        residuals: qualityResiduals([0, 0]),
      );

      expect(assessment.status, GeoreferenceReviewStatus.notApplicable);
      expect(assessment.suspectedPointIndices, isEmpty);
      expect(assessment.uniqueWorstPointIndex, isNull);
    },
  );

  test('three and four points are insufficient samples without suspects', () {
    for (final count in [3, 4]) {
      final assessment = service.assessResiduals(
        controlPoints: qualityPoints(count),
        residuals: qualityResiduals([
          for (var index = 0; index < count; index++) index.toDouble(),
        ]),
      );
      expect(assessment.status, GeoreferenceReviewStatus.insufficientSample);
      expect(assessment.suspectedPointIndices, isEmpty);
      expect(assessment.uniqueWorstPointIndex, count - 1);
    }
  });

  test('clean five-point dataset has no relative anomaly', () {
    final assessment = service.assessResiduals(
      controlPoints: qualityPoints(5),
      residuals: qualityResiduals([1, 1.1, 0.9, 1.05, 0.95]),
    );

    expect(assessment.status, GeoreferenceReviewStatus.noRelativeAnomaly);
    expect(assessment.suspectedPointIndices, isEmpty);
  });

  test('modified Z deterministically identifies one suspected point', () {
    final assessment = service.assessResiduals(
      controlPoints: qualityPoints(5),
      residuals: qualityResiduals([1, 1.1, 0.9, 1.05, 2]),
    );

    expect(assessment.status, GeoreferenceReviewStatus.reviewSuggested);
    expect(assessment.suspectedPointIndices, [4]);
    expect(assessment.uniqueWorstPointIndex, 4);
    expect(assessment.hasTiedMaximum, isFalse);
  });

  test('tied maximum has no unique worst point', () {
    final assessment = service.assessResiduals(
      controlPoints: qualityPoints(5),
      residuals: qualityResiduals([1, 1, 1, 5, 5]),
    );

    expect(assessment.status, GeoreferenceReviewStatus.multipleLargeResiduals);
    expect(assessment.uniqueWorstPointIndex, isNull);
    expect(assessment.hasTiedMaximum, isTrue);
    expect(assessment.suspectedPointIndices, isEmpty);
  });

  test('MAD zero handles equal and near-zero residuals deterministically', () {
    for (final errors in [
      [1.0, 1.0, 1.0, 1.0, 1.0],
      [0.0, 1e-12, 0.0, 1e-12, 0.0],
    ]) {
      final assessment = service.assessResiduals(
        controlPoints: qualityPoints(5),
        residuals: qualityResiduals(errors),
      );
      expect(assessment.status, GeoreferenceReviewStatus.noRelativeAnomaly);
      expect(assessment.suspectedPointIndices, isEmpty);
    }
  });

  test('MAD zero identifies exactly one deviation from a unique baseline', () {
    final assessment = service.assessResiduals(
      controlPoints: qualityPoints(5),
      residuals: qualityResiduals([1, 1, 1, 1, 5]),
    );

    expect(assessment.status, GeoreferenceReviewStatus.reviewSuggested);
    expect(assessment.suspectedPointIndices, [4]);
  });

  test('MAD zero does not blame one point when multiple deviations exist', () {
    final assessment = service.assessResiduals(
      controlPoints: qualityPoints(5),
      residuals: qualityResiduals([1, 1, 1, 5, 6]),
    );

    expect(assessment.status, GeoreferenceReviewStatus.multipleLargeResiduals);
    expect(assessment.suspectedPointIndices, isEmpty);
  });

  test('custom outlier threshold is honored without changing fit values', () {
    final points = qualityPoints(5);
    final residuals = qualityResiduals([1, 1.1, 0.9, 1.05, 2]);
    final normal = service.assessResiduals(
      controlPoints: points,
      residuals: residuals,
    );
    final strict = service.assessResiduals(
      controlPoints: points,
      residuals: residuals,
      options: const GeoreferenceOutlierOptions(modifiedZThreshold: 20),
    );

    expect(normal.suspectedPointIndices, [4]);
    expect(strict.suspectedPointIndices, isEmpty);

    final fit = service.fitControlPoints(
      controlPoints: [
        controlPoint(localX: 0, localY: 0, targetX: 100, targetY: 200),
        controlPoint(localX: 10, localY: 0, targetX: 110, targetY: 200),
        controlPoint(localX: 0, localY: 10, targetX: 100, targetY: 210),
        controlPoint(localX: 10, localY: 10, targetX: 110, targetY: 210),
        controlPoint(localX: 5, localY: 5, targetX: 105, targetY: 205),
      ],
    );
    expect(fit.controlPointCount, 5);
    expect(fit.residuals, hasLength(5));
    expect(fit.rmse, closeTo(0, 1e-10));
    expect(fit.transform.scale, closeTo(1, 1e-12));
  });
}
