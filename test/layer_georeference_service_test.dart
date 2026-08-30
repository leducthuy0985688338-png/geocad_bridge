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
}
