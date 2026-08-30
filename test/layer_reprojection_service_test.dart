import 'package:flutter_test/flutter_test.dart';

import 'package:autocad_googleearth/models/coordinate_reference_system.dart';
import 'package:autocad_googleearth/models/map_feature.dart';
import 'package:autocad_googleearth/models/map_layer.dart';
import 'package:autocad_googleearth/services/coordinate_transform_service.dart';
import 'package:autocad_googleearth/services/kml_export_service.dart';
import 'package:autocad_googleearth/services/layer_reprojection_service.dart';

void main() {
  const transformService = CoordinateTransformService();
  const service = LayerReprojectionService();

  test('reprojects UTM layer to WGS84 and preserves feature data', () {
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
      properties: const {'code': 'P01'},
      coordinates: [MapCoordinate(x: utm.x, y: utm.y, z: 25.5)],
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
      properties: const {'custom': 'keep-me'},
    );

    final result = service.reprojectLayer(
      sourceLayer: sourceLayer,
      targetCrs: const CoordinateReferenceSystem.wgs84(),
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
    expect(feature.description, sourceFeature.description);
    expect(feature.visible, sourceFeature.visible);
    expect(feature.properties['code'], 'P01');

    expect(coordinate.x, closeTo(longitude, 0.000001));
    expect(coordinate.y, closeTo(latitude, 0.000001));
    expect(coordinate.z, 25.5);

    expect(
      sourceLayer.features.single.coordinates.single.x,
      closeTo(utm.x, 0.001),
    );
    expect(sourceLayer.crs.epsgCode, 32648);
  });

  test('reprojects WGS84 layer to UTM and back accurately', () {
    final sourceLayer = MapLayer(
      id: 'wgs84-layer',
      name: 'WGS84 layer',
      sourceType: MapLayerSourceType.manual,
      crs: const CoordinateReferenceSystem.wgs84(),
      features: const [
        MapFeature(
          id: 'line-1',
          type: MapFeatureType.line,
          coordinates: [
            MapCoordinate(x: 106.0, y: 16.0, z: 10),
            MapCoordinate(x: 106.01, y: 16.01, z: 20),
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
      targetCrs: const CoordinateReferenceSystem.wgs84(),
    );

    final restored = restoredResult.layer.features.single.coordinates;

    expect(restored.length, 2);
    expect(restored[0].x, closeTo(106.0, 0.000001));
    expect(restored[0].y, closeTo(16.0, 0.000001));
    expect(restored[0].z, 10);

    expect(restored[1].x, closeTo(106.01, 0.000001));
    expect(restored[1].y, closeTo(16.01, 0.000001));
    expect(restored[1].z, 20);
  });

  test('rejects local CAD layer without georeferencing', () {
    const sourceLayer = MapLayer(
      id: 'local-layer',
      name: 'Local CAD',
      sourceType: MapLayerSourceType.dxf,
      features: [
        MapFeature(
          id: 'point-1',
          type: MapFeatureType.point,
          coordinates: [MapCoordinate(x: 100, y: 200)],
        ),
      ],
    );

    expect(
      () => service.reprojectLayer(
        sourceLayer: sourceLayer,
        targetCrs: const CoordinateReferenceSystem.wgs84(),
      ),
      throwsStateError,
    );
  });

  test('preserves polygon coordinate count and Z values', () {
    const sourceLayer = MapLayer(
      id: 'polygon-layer',
      name: 'Polygon',
      sourceType: MapLayerSourceType.manual,
      crs: CoordinateReferenceSystem.wgs84(),
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

    final coordinates = result.layer.features.single.coordinates;

    expect(coordinates.length, 4);
    expect(coordinates.map((item) => item.z).toList(), [1, 2, 3, 1]);
  });

  test('reprojects every feature type and produces valid KML input', () {
    const sourceCoordinates = [
      MapCoordinate(x: 500000, y: 1768935.376, z: 10),
      MapCoordinate(x: 500010, y: 1768945.376, z: 20),
      MapCoordinate(x: 500020, y: 1768935.376, z: 30),
    ];
    const types = MapFeatureType.values;
    final features = <MapFeature>[];

    for (var index = 0; index < types.length; index++) {
      final type = types[index];
      final coordinates = switch (type) {
        MapFeatureType.point ||
        MapFeatureType.text => [sourceCoordinates.first],
        MapFeatureType.line => sourceCoordinates.take(2).toList(),
        MapFeatureType.polyline ||
        MapFeatureType.polygon => List<MapCoordinate>.from(sourceCoordinates),
      };

      features.add(
        MapFeature(
          id: 'feature-$index',
          type: type,
          name: type.name,
          coordinates: coordinates,
        ),
      );
    }

    final source = MapLayer(
      id: 'all-types',
      name: 'All geometry types',
      sourceType: MapLayerSourceType.dxf,
      crs: const CoordinateReferenceSystem.utm(
        utmZone: 48,
        hemisphere: UtmHemisphere.north,
      ),
      features: features,
    );

    final output = service.reprojectLayer(
      sourceLayer: source,
      targetCrs: const CoordinateReferenceSystem.wgs84(),
    );

    expect(output.transformedFeatureCount, MapFeatureType.values.length);
    expect(
      output.layer.features.map((feature) => feature.type),
      MapFeatureType.values,
    );
    expect(
      output.layer.features
          .expand((feature) => feature.coordinates)
          .map((coordinate) => coordinate.z),
      everyElement(isNotNull),
    );

    expect(
      () => const KmlExportService().exportLayers(
        documentName: 'Transformed',
        layers: [output.layer],
      ),
      returnsNormally,
    );
  });

  test('does not mutate or share mutable source data', () {
    final sourceCoordinates = [const MapCoordinate(x: 105, y: 16, z: 7)];
    final featureProperties = {'code': 'P01'};
    final layerProperties = {'owner': 'source'};
    final sourceFeature = MapFeature(
      id: 'point',
      type: MapFeatureType.point,
      coordinates: sourceCoordinates,
      properties: featureProperties,
    );
    final source = MapLayer(
      id: 'source',
      name: 'Source',
      sourceType: MapLayerSourceType.manual,
      crs: const CoordinateReferenceSystem.wgs84(),
      features: [sourceFeature],
      properties: layerProperties,
    );

    final result = service.reprojectLayer(
      sourceLayer: source,
      targetCrs: const CoordinateReferenceSystem.wgs84(),
    );
    final outputFeature = result.layer.features.single;

    expect(result.layer, isNot(same(source)));
    expect(result.layer.features, isNot(same(source.features)));
    expect(outputFeature, isNot(same(sourceFeature)));
    expect(outputFeature.coordinates, isNot(same(sourceCoordinates)));
    expect(
      outputFeature.coordinates.single,
      isNot(same(sourceCoordinates.single)),
    );
    expect(outputFeature.properties, isNot(same(featureProperties)));
    expect(result.layer.properties, isNot(same(layerProperties)));

    outputFeature.properties['code'] = 'changed';
    result.layer.properties['owner'] = 'changed';
    outputFeature.coordinates.add(const MapCoordinate(x: 0, y: 0));

    expect(sourceFeature.properties, {'code': 'P01'});
    expect(source.properties, {'owner': 'source'});
    expect(sourceFeature.coordinates, hasLength(1));
    expect(sourceFeature.coordinates.single.z, 7);
  });

  test('rejects an incomplete UTM layer CRS', () {
    const source = MapLayer(
      id: 'invalid-utm',
      name: 'Invalid UTM',
      sourceType: MapLayerSourceType.dxf,
      crs: CoordinateReferenceSystem.utm(utmZone: 48, hemisphere: null),
      features: [
        MapFeature(
          id: 'point',
          type: MapFeatureType.point,
          coordinates: [MapCoordinate(x: 500000, y: 1768935.376)],
        ),
      ],
    );

    expect(
      () => service.reprojectLayer(
        sourceLayer: source,
        targetCrs: const CoordinateReferenceSystem.wgs84(),
      ),
      throwsStateError,
    );
  });
}
