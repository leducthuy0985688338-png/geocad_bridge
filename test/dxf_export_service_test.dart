import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:autocad_googleearth/models/coordinate_reference_system.dart';
import 'package:autocad_googleearth/models/map_feature.dart';
import 'package:autocad_googleearth/models/map_layer.dart';
import 'package:autocad_googleearth/services/dxf_export_service.dart';
import 'package:autocad_googleearth/services/dxf_parser_service.dart';

void main() {
  const service = DxfExportService();

  MapFeature feature(
    String id,
    MapFeatureType type,
    List<MapCoordinate> coordinates, {
    String name = '',
    Map<String, String> properties = const {},
    bool visible = true,
  }) {
    return MapFeature(
      id: id,
      type: type,
      coordinates: coordinates,
      name: name,
      properties: properties,
      visible: visible,
    );
  }

  MapLayer layer(
    List<MapFeature> features, {
    String id = 'layer-1',
    String name = 'Survey',
    CoordinateReferenceSystem crs = const CoordinateReferenceSystem.localCad(),
    bool visible = true,
    bool locked = false,
  }) {
    return MapLayer(
      id: id,
      name: name,
      sourceType: MapLayerSourceType.manual,
      crs: crs,
      features: features,
      visible: visible,
      locked: locked,
    );
  }

  DxfExportResult exportFeatures(List<MapFeature> features) {
    return service.serialize(documentName: 'Test', layers: [layer(features)]);
  }

  DxfExportException exportError(List<MapLayer> layers) {
    try {
      service.serialize(documentName: 'Test', layers: layers);
      fail('Expected DxfExportException');
    } on DxfExportException catch (error) {
      return error;
    }
  }

  test('writes AC1021 UTF-8 CRLF deterministic header and footer', () {
    final source = [
      layer([
        feature('p', MapFeatureType.point, const [
          MapCoordinate(x: -0.0, y: 1.25),
        ]),
      ]),
    ];
    final first = service.serialize(documentName: 'Đo đạc', layers: source);
    final second = service.serialize(documentName: 'Đo đạc', layers: source);

    expect(first.content, second.content);
    expect(first.bytes, second.bytes);
    expect(first.content, contains('9\r\n\$ACADVER\r\n1\r\nAC1021\r\n'));
    expect(first.content, contains('9\r\n\$INSUNITS\r\n70\r\n0\r\n'));
    expect(first.content.replaceAll('\r\n', ''), isNot(contains('\n')));
    expect(first.content, endsWith('0\r\nEOF\r\n'));
    expect(first.content, contains('10\r\n0\r\n20\r\n1.25\r\n'));
  });

  test('exports POINT XY Z and null Z', () {
    final result = exportFeatures([
      feature('p1', MapFeatureType.point, const [
        MapCoordinate(x: 1, y: 2, z: 3),
      ]),
      feature('p2', MapFeatureType.point, const [MapCoordinate(x: 4, y: 5)]),
    ]);

    expect(result.entityCount, 2);
    expect(result.content, contains('30\r\n3\r\n'));
    expect(RegExp(r'0\r\nPOINT\r\n').allMatches(result.content), hasLength(2));
  });

  test('exports LINE with independent endpoint Z', () {
    final result = exportFeatures([
      feature('line', MapFeatureType.line, const [
        MapCoordinate(x: 1, y: 2, z: 3),
        MapCoordinate(x: 4, y: 5, z: 6),
      ]),
    ]);

    expect(result.content, contains('30\r\n3\r\n'));
    expect(result.content, contains('31\r\n6\r\n'));
  });

  test('exports open polyline and canonical closed polygon', () {
    final result = exportFeatures([
      feature('open', MapFeatureType.polyline, const [
        MapCoordinate(x: 0, y: 0),
        MapCoordinate(x: 1, y: 1),
      ]),
      feature('closed', MapFeatureType.polygon, const [
        MapCoordinate(x: 0, y: 0),
        MapCoordinate(x: 2, y: 0),
        MapCoordinate(x: 0, y: 2),
        MapCoordinate(x: 0, y: 0),
      ]),
    ]);

    expect(result.content, contains('90\r\n2\r\n70\r\n0\r\n'));
    expect(result.content, contains('90\r\n3\r\n70\r\n1\r\n'));
  });

  test('exports TEXT values defaults Unicode and multiline warning', () {
    final result = exportFeatures([
      feature(
        'text1',
        MapFeatureType.text,
        const [MapCoordinate(x: 10, y: 20, z: 30)],
        name: 'fallback',
        properties: const {
          'text': 'Điểm đo\nຈຸດວັດ',
          'textHeight': '2.5',
          'rotationDegrees': '30',
        },
      ),
      feature('text2', MapFeatureType.text, const [
        MapCoordinate(x: 0, y: 0),
      ], name: 'Default'),
    ]);

    expect(result.content, contains('1\r\nĐiểm đo ຈຸດວັດ\r\n'));
    expect(result.content, contains('40\r\n2.5\r\n'));
    expect(result.content, contains('50\r\n30\r\n'));
    expect(result.content, contains('40\r\n1\r\n'));
    expect(result.content, contains('50\r\n0\r\n'));
    expect(result.warnings, hasLength(1));
  });

  test('maps CAD layers with precedence sanitization and collision suffix', () {
    final result = service.serialize(
      documentName: 'Layers',
      layers: [
        layer([
          feature(
            'a',
            MapFeatureType.point,
            const [MapCoordinate(x: 0, y: 0)],
            properties: const {'cadLayer': 'Road/Center'},
          ),
          feature(
            'b',
            MapFeatureType.point,
            const [MapCoordinate(x: 1, y: 1)],
            properties: const {'cadLayer': 'Road:Center'},
          ),
          feature(
            'c',
            MapFeatureType.point,
            const [MapCoordinate(x: 2, y: 2)],
            properties: const {'cadLayer': '0'},
          ),
        ], name: 'Fallback'),
      ],
    );

    expect(result.layerCount, 3);
    expect(result.content, contains('8\r\nRoad_Center\r\n'));
    expect(result.content, contains('8\r\nRoad_Center_2\r\n'));
    expect(result.content, contains('8\r\n0\r\n'));
  });

  test('locked is exported while invisible data is intentionally excluded', () {
    final result = service.serialize(
      documentName: 'Visibility',
      layers: [
        layer([
          feature('visible', MapFeatureType.point, const [
            MapCoordinate(x: 1, y: 1),
          ]),
          feature('hidden', MapFeatureType.point, const [
            MapCoordinate(x: 2, y: 2),
          ], visible: false),
        ], locked: true),
      ],
    );
    expect(result.entityCount, 1);
    expect(result.content, isNot(contains('10\r\n2\r\n20\r\n2\r\n')));
  });

  test('accepts local CAD and valid UTM with correct INSUNITS', () {
    final local = exportFeatures([
      feature('p', MapFeatureType.point, const [MapCoordinate(x: 1, y: 2)]),
    ]);
    final utm = service.serialize(
      documentName: 'UTM',
      layers: [
        layer(
          [
            feature('p', MapFeatureType.point, const [
              MapCoordinate(x: 500000, y: 1800000),
            ]),
          ],
          crs: const CoordinateReferenceSystem.utm(
            utmZone: 48,
            hemisphere: UtmHemisphere.north,
          ),
        ),
      ],
    );
    expect(local.exportedCrs.isLocalCad, isTrue);
    expect(utm.exportedCrs.displayName, 'UTM Zone 48N');
    expect(utm.content, contains('9\r\n\$INSUNITS\r\n70\r\n6\r\n'));
  });

  test('rejects empty, malformed and nonfinite geometry', () {
    expect(exportError(const []).code, DxfExportErrorCode.emptyExport);
    expect(
      exportError([
        layer([
          feature('line', MapFeatureType.line, const [
            MapCoordinate(x: 1, y: 2),
          ]),
        ]),
      ]).code,
      DxfExportErrorCode.invalidGeometry,
    );
    expect(
      exportError([
        layer([
          feature('bad', MapFeatureType.point, const [
            MapCoordinate(x: double.nan, y: 2),
          ]),
        ]),
      ]).code,
      DxfExportErrorCode.nonFiniteCoordinate,
    );
  });

  test('rejects polyline and polygon Z without flattening', () {
    for (final type in [MapFeatureType.polyline, MapFeatureType.polygon]) {
      final coordinates = type == MapFeatureType.polyline
          ? const [
              MapCoordinate(x: 0, y: 0, z: 0),
              MapCoordinate(x: 1, y: 1, z: 0),
            ]
          : const [
              MapCoordinate(x: 0, y: 0, z: 0),
              MapCoordinate(x: 1, y: 0, z: 0),
              MapCoordinate(x: 0, y: 1, z: 0),
            ];
      expect(
        exportError([
          layer([feature('z', type, coordinates)]),
        ]).code,
        DxfExportErrorCode.unsupportedElevation,
      );
    }
  });

  test('rejects degenerate polygon and invalid text properties', () {
    expect(
      exportError([
        layer([
          feature('polygon', MapFeatureType.polygon, const [
            MapCoordinate(x: 0, y: 0),
            MapCoordinate(x: 1, y: 1),
            MapCoordinate(x: 2, y: 2),
          ]),
        ]),
      ]).code,
      DxfExportErrorCode.invalidGeometry,
    );
    for (final properties in [
      const <String, String>{'text': ''},
      const <String, String>{'text': 'A', 'textHeight': '0'},
      const <String, String>{'text': 'A', 'rotationDegrees': 'NaN'},
    ]) {
      expect(
        exportError([
          layer([
            feature('text', MapFeatureType.text, const [
              MapCoordinate(x: 0, y: 0),
            ], properties: properties),
          ]),
        ]).code,
        DxfExportErrorCode.invalidText,
      );
    }
  });

  test('rejects invalid UTM CRS and coordinate bounds', () {
    final pointFeature = feature('utm', MapFeatureType.point, const [
      MapCoordinate(x: 1, y: 2),
    ]);
    expect(
      exportError([
        layer(
          [pointFeature],
          crs: const CoordinateReferenceSystem.utm(
            utmZone: 0,
            hemisphere: UtmHemisphere.north,
          ),
        ),
      ]).code,
      DxfExportErrorCode.unsupportedCrs,
    );
    expect(
      exportError([
        layer(
          [pointFeature],
          crs: const CoordinateReferenceSystem.utm(
            utmZone: 48,
            hemisphere: UtmHemisphere.north,
          ),
        ),
      ]).code,
      DxfExportErrorCode.invalidGeometry,
    );
  });
  test('rejects WGS84 mixed types and different UTM definitions', () {
    MapLayer crsLayer(String id, CoordinateReferenceSystem crs) => layer(
      [
        feature(id, MapFeatureType.point, const [MapCoordinate(x: 1, y: 2)]),
      ],
      id: id,
      crs: crs,
    );

    expect(
      exportError([crsLayer('wgs', const CoordinateReferenceSystem.wgs84())])
          .code,
      DxfExportErrorCode.unsupportedCrs,
    );
    expect(
      exportError([
        crsLayer('local', const CoordinateReferenceSystem.localCad()),
        crsLayer(
          'utm',
          const CoordinateReferenceSystem.utm(
            utmZone: 48,
            hemisphere: UtmHemisphere.north,
          ),
        ),
      ]).code,
      DxfExportErrorCode.mixedCrs,
    );
    expect(
      exportError([
        crsLayer(
          '48n',
          const CoordinateReferenceSystem.utm(
            utmZone: 48,
            hemisphere: UtmHemisphere.north,
          ),
        ),
        crsLayer(
          '49s',
          const CoordinateReferenceSystem.utm(
            utmZone: 49,
            hemisphere: UtmHemisphere.south,
          ),
        ),
      ]).code,
      DxfExportErrorCode.mixedCrs,
    );
  });

  test('serialization does not mutate source objects', () {
    final properties = <String, String>{'cadLayer': 'Original'};
    final coordinates = <MapCoordinate>[const MapCoordinate(x: 1, y: 2)];
    final sourceFeature = feature(
      'p',
      MapFeatureType.point,
      coordinates,
      properties: properties,
    );
    final sourceLayer = layer([sourceFeature]);

    service.serialize(documentName: 'Immutable', layers: [sourceLayer]);

    expect(identical(sourceLayer.features.single, sourceFeature), isTrue);
    expect(identical(sourceFeature.coordinates, coordinates), isTrue);
    expect(identical(sourceFeature.properties, properties), isTrue);
    expect(sourceFeature.coordinates.single.x, 1);
    expect(sourceFeature.properties, {'cadLayer': 'Original'});
  });

  test(
    'round trips the supported semantic subset through current parser',
    () async {
      final source = layer([
        feature(
          'point',
          MapFeatureType.point,
          const [MapCoordinate(x: 1, y: 2, z: 3)],
          properties: const {'cadLayer': 'POINTS'},
        ),
        feature(
          'line',
          MapFeatureType.line,
          const [
            MapCoordinate(x: 4, y: 5, z: 6),
            MapCoordinate(x: 7, y: 8, z: 9),
          ],
          properties: const {'cadLayer': 'LINES'},
        ),
        feature(
          'open',
          MapFeatureType.polyline,
          const [MapCoordinate(x: 0, y: 0), MapCoordinate(x: 2, y: 2)],
          properties: const {'cadLayer': 'PATHS'},
        ),
        feature(
          'polygon',
          MapFeatureType.polygon,
          const [
            MapCoordinate(x: 0, y: 0),
            MapCoordinate(x: 3, y: 0),
            MapCoordinate(x: 0, y: 3),
          ],
          properties: const {'cadLayer': 'AREAS'},
        ),
        feature(
          'text',
          MapFeatureType.text,
          const [MapCoordinate(x: 10, y: 20, z: 5)],
          properties: const {
            'cadLayer': 'NOTES',
            'text': 'Điểm A',
            'textHeight': '2.5',
            'rotationDegrees': '15',
          },
        ),
      ]);
      final exported = service.serialize(
        documentName: 'Round trip',
        layers: [source],
      );
      final directory = await Directory.systemTemp.createTemp(
        'geocad-dxf-export-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File(
        '${directory.path}${Platform.pathSeparator}roundtrip.dxf',
      );
      await file.writeAsBytes(exported.bytes);

      final parsed = await const DxfParserService().parseFile(file.path);

      expect(parsed.features.map((item) => item.type), [
        MapFeatureType.point,
        MapFeatureType.line,
        MapFeatureType.polyline,
        MapFeatureType.polygon,
        MapFeatureType.text,
      ]);
      expect(parsed.features[0].coordinates.single.z, 3);
      expect(parsed.features[1].coordinates.last.z, 9);
      expect(parsed.features[2].coordinates, hasLength(2));
      expect(parsed.features[3].properties['closed'], 'true');
      expect(parsed.features[4].name, 'Điểm A');
      expect(parsed.features[4].properties['textHeight'], '2.5');
      expect(parsed.features[4].properties['rotationDegrees'], '15.0');
      expect(parsed.features.map((item) => item.properties['cadLayer']), [
        'POINTS',
        'LINES',
        'PATHS',
        'AREAS',
        'NOTES',
      ]);
    },
  );
}
