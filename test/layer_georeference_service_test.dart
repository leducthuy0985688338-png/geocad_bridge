import 'package:flutter_test/flutter_test.dart';

import 'package:autocad_googleearth/models/coordinate_reference_system.dart';
import 'package:autocad_googleearth/models/map_feature.dart';
import 'package:autocad_googleearth/models/map_layer.dart';
import 'package:autocad_googleearth/services/layer_georeference_service.dart';

void main() {
  const service = LayerGeoreferenceService();

  test(
    'calculates two-point similarity transform',
    () {
      const point1 = GeoreferenceControlPoint(
        local: MapCoordinate(x: 0, y: 0),
        target: MapCoordinate(
          x: 500000,
          y: 1800000,
        ),
      );

      const point2 = GeoreferenceControlPoint(
        local: MapCoordinate(x: 100, y: 0),
        target: MapCoordinate(
          x: 500200,
          y: 1800000,
        ),
      );

      final transform = service.calculateTransform(
        point1: point1,
        point2: point2,
      );

      expect(transform.scale, closeTo(2, 1e-12));
      expect(
        transform.rotationDegrees,
        closeTo(0, 1e-12),
      );
      expect(
        transform.translationX,
        closeTo(500000, 1e-9),
      );
      expect(
        transform.translationY,
        closeTo(1800000, 1e-9),
      );

      final transformed = transform.transform(
        const MapCoordinate(
          x: 50,
          y: 25,
          z: 7,
        ),
      );

      expect(
        transformed.x,
        closeTo(500100, 1e-9),
      );
      expect(
        transformed.y,
        closeTo(1800050, 1e-9),
      );
      expect(transformed.z, 7);
    },
  );

  test(
    'supports rotation scale and translation',
    () {
      const point1 = GeoreferenceControlPoint(
        local: MapCoordinate(x: 0, y: 0),
        target: MapCoordinate(
          x: 500000,
          y: 1800000,
        ),
      );

      const point2 = GeoreferenceControlPoint(
        local: MapCoordinate(x: 100, y: 0),
        target: MapCoordinate(
          x: 500000,
          y: 1800200,
        ),
      );

      final transform = service.calculateTransform(
        point1: point1,
        point2: point2,
      );

      expect(transform.scale, closeTo(2, 1e-12));
      expect(
        transform.rotationDegrees,
        closeTo(90, 1e-10),
      );

      final transformed = transform.transform(
        const MapCoordinate(x: 0, y: 50),
      );

      expect(
        transformed.x,
        closeTo(499900, 1e-8),
      );
      expect(
        transformed.y,
        closeTo(1800000, 1e-8),
      );
    },
  );

  test(
    'georeferences whole layer and preserves original',
    () {
      const sourceLayer = MapLayer(
        id: 'local-layer',
        name: 'Drawing1.dxf',
        sourceType: MapLayerSourceType.dxf,
        features: [
          MapFeature(
            id: 'line-1',
            type: MapFeatureType.line,
            name: 'Test line',
            properties: {'code': 'L01'},
            coordinates: [
              MapCoordinate(x: 10, y: 10, z: 3),
              MapCoordinate(x: 20, y: 10, z: 4),
            ],
          ),
        ],
      );

      const point1 = GeoreferenceControlPoint(
        local: MapCoordinate(x: 10, y: 10),
        target: MapCoordinate(
          x: 500000,
          y: 1800000,
        ),
      );

      const point2 = GeoreferenceControlPoint(
        local: MapCoordinate(x: 20, y: 10),
        target: MapCoordinate(
          x: 500010,
          y: 1800000,
        ),
      );

      final result = service.georeferenceLayer(
        sourceLayer: sourceLayer,
        point1: point1,
        point2: point2,
        targetCrs:
            const CoordinateReferenceSystem.utm(
          utmZone: 48,
          hemisphere: UtmHemisphere.north,
        ),
        newLayerId: 'utm-layer',
        newLayerName: 'Drawing1.dxf - UTM',
      );

      expect(result.transformedFeatureCount, 1);
      expect(result.transformedCoordinateCount, 2);
      expect(
        result.controlPointError,
        closeTo(0, 1e-8),
      );

      final layer = result.layer;
      final coordinates =
          layer.features.single.coordinates;

      expect(layer.id, 'utm-layer');
      expect(layer.name, 'Drawing1.dxf - UTM');
      expect(layer.crs.epsgCode, 32648);
      expect(layer.properties['georeferenced'], 'true');
      expect(layer.properties['targetEpsg'], '32648');

      expect(
        coordinates[0].x,
        closeTo(500000, 1e-8),
      );
      expect(
        coordinates[0].y,
        closeTo(1800000, 1e-8),
      );
      expect(coordinates[0].z, 3);

      expect(
        coordinates[1].x,
        closeTo(500010, 1e-8),
      );
      expect(
        coordinates[1].y,
        closeTo(1800000, 1e-8),
      );
      expect(coordinates[1].z, 4);

      expect(
        sourceLayer.features.single.coordinates.first.x,
        10,
      );
      expect(sourceLayer.crs.isLocalCad, isTrue);
    },
  );

  test(
    'rejects duplicate control points',
    () {
      const point1 = GeoreferenceControlPoint(
        local: MapCoordinate(x: 10, y: 10),
        target: MapCoordinate(
          x: 500000,
          y: 1800000,
        ),
      );

      const point2 = GeoreferenceControlPoint(
        local: MapCoordinate(x: 10, y: 10),
        target: MapCoordinate(
          x: 500100,
          y: 1800000,
        ),
      );

      expect(
        () => service.calculateTransform(
          point1: point1,
          point2: point2,
        ),
        throwsArgumentError,
      );
    },
  );
}
