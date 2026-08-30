import 'package:flutter_test/flutter_test.dart';

import 'package:autocad_googleearth/models/coordinate_reference_system.dart';
import 'package:autocad_googleearth/models/map_feature.dart';
import 'package:autocad_googleearth/models/map_layer.dart';
import 'package:autocad_googleearth/services/coordinate_transform_service.dart';
import 'package:autocad_googleearth/services/layer_reprojection_service.dart';

void main() {
  const transformService = CoordinateTransformService();
  const service = LayerReprojectionService();

  test(
    'reprojects UTM layer to WGS84 and preserves feature data',
    () {
      const longitude = 106.0;
      const latitude = 16.0;

      final utm = transformService.wgs84ToUtm(
        longitude: longitude,
        latitude: latitude,
        zone: 48,
        hemisphere: UtmHemisphere.north,
      );

      final sourceFeature = MapFeature(
        id: 'feature-1',
        type: MapFeatureType.point,
        name: 'Điểm kiểm tra',
        description: 'Giữ nguyên metadata',
        visible: false,
        properties: const {
          'code': 'P01',
        },
        coordinates: [
          MapCoordinate(
            x: utm.x,
            y: utm.y,
            z: 25.5,
          ),
        ],
      );

      final sourceLayer = MapLayer(
        id: 'layer-1',
        name: 'DXF kiểm tra',
        sourceType: MapLayerSourceType.dxf,
        sourcePath: r'C:\data\test.dxf',
        crs: const CoordinateReferenceSystem.utm(
          utmZone: 48,
          hemisphere: UtmHemisphere.north,
        ),
        features: [sourceFeature],
        locked: true,
        properties: const {
          'custom': 'keep-me',
        },
      );

      final result = service.reprojectLayer(
        sourceLayer: sourceLayer,
        targetCrs:
            const CoordinateReferenceSystem.wgs84(),
        newLayerId: 'layer-wgs84',
        newLayerName: 'DXF kiểm tra - WGS84',
      );

      expect(result.transformedFeatureCount, 1);
      expect(result.transformedCoordinateCount, 1);

      final layer = result.layer;
      final feature = layer.features.single;
      final coordinate = feature.coordinates.single;

      expect(layer.id, 'layer-wgs84');
      expect(layer.name, 'DXF kiểm tra - WGS84');
      expect(layer.crs.isWgs84, isTrue);
      expect(layer.sourceType, sourceLayer.sourceType);
      expect(layer.sourcePath, sourceLayer.sourcePath);
      expect(layer.locked, sourceLayer.locked);
      expect(layer.properties['custom'], 'keep-me');
      expect(layer.properties['reprojected'], 'true');
      expect(layer.properties['sourceEpsg'], '32648');
      expect(layer.properties['targetEpsg'], '4326');

      expect(feature.id, sourceFeature.id);
      expect(feature.type, sourceFeature.type);
      expect(feature.name, sourceFeature.name);
      expect(
        feature.description,
        sourceFeature.description,
      );
      expect(feature.visible, sourceFeature.visible);
      expect(feature.properties['code'], 'P01');

      expect(
        coordinate.x,
        closeTo(longitude, 0.000001),
      );
      expect(
        coordinate.y,
        closeTo(latitude, 0.000001),
      );
      expect(coordinate.z, 25.5);

      expect(
        sourceLayer.features.single.coordinates.single.x,
        closeTo(utm.x, 0.001),
      );
      expect(
        sourceLayer.crs.epsgCode,
        32648,
      );
    },
  );

  test(
    'reprojects WGS84 layer to UTM and back accurately',
    () {
      final sourceLayer = MapLayer(
        id: 'wgs84-layer',
        name: 'WGS84 layer',
        sourceType: MapLayerSourceType.manual,
        crs:
            const CoordinateReferenceSystem.wgs84(),
        features: const [
          MapFeature(
            id: 'line-1',
            type: MapFeatureType.line,
            coordinates: [
              MapCoordinate(
                x: 106.0,
                y: 16.0,
                z: 10,
              ),
              MapCoordinate(
                x: 106.01,
                y: 16.01,
                z: 20,
              ),
            ],
          ),
        ],
      );

      const utmCrs = CoordinateReferenceSystem.utm(
        utmZone: 48,
        hemisphere: UtmHemisphere.north,
      );

      final utmResult = service.reprojectLayer(
        sourceLayer: sourceLayer,
        targetCrs: utmCrs,
      );

      final restoredResult = service.reprojectLayer(
        sourceLayer: utmResult.layer,
        targetCrs:
            const CoordinateReferenceSystem.wgs84(),
      );

      final restored =
          restoredResult.layer.features.single.coordinates;

      expect(restored.length, 2);
      expect(restored[0].x, closeTo(106.0, 0.000001));
      expect(restored[0].y, closeTo(16.0, 0.000001));
      expect(restored[0].z, 10);

      expect(restored[1].x, closeTo(106.01, 0.000001));
      expect(restored[1].y, closeTo(16.01, 0.000001));
      expect(restored[1].z, 20);
    },
  );

  test(
    'rejects local CAD layer without georeferencing',
    () {
      const sourceLayer = MapLayer(
        id: 'local-layer',
        name: 'Local CAD',
        sourceType: MapLayerSourceType.dxf,
        features: [
          MapFeature(
            id: 'point-1',
            type: MapFeatureType.point,
            coordinates: [
              MapCoordinate(x: 100, y: 200),
            ],
          ),
        ],
      );

      expect(
        () => service.reprojectLayer(
          sourceLayer: sourceLayer,
          targetCrs:
              const CoordinateReferenceSystem.wgs84(),
        ),
        throwsStateError,
      );
    },
  );

  test(
    'preserves polygon coordinate count and Z values',
    () {
      const sourceLayer = MapLayer(
        id: 'polygon-layer',
        name: 'Polygon',
        sourceType: MapLayerSourceType.manual,
        crs:
            CoordinateReferenceSystem.wgs84(),
        features: [
          MapFeature(
            id: 'polygon-1',
            type: MapFeatureType.polygon,
            coordinates: [
              MapCoordinate(x: 106.0, y: 16.0, z: 1),
              MapCoordinate(x: 106.1, y: 16.0, z: 2),
              MapCoordinate(x: 106.1, y: 16.1, z: 3),
              MapCoordinate(x: 106.0, y: 16.0, z: 1),
            ],
          ),
        ],
      );

      final result = service.reprojectLayer(
        sourceLayer: sourceLayer,
        targetCrs: const CoordinateReferenceSystem.utm(
          utmZone: 48,
          hemisphere: UtmHemisphere.north,
        ),
      );

      final coordinates =
          result.layer.features.single.coordinates;

      expect(coordinates.length, 4);
      expect(
        coordinates.map((item) => item.z).toList(),
        [1, 2, 3, 1],
      );
    },
  );
}
