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

  test('writes deterministic ASCII DXF R12 AC1009 with CRLF', () {
    final source = [
      layer([
        feature('p', MapFeatureType.point, const [
          MapCoordinate(x: -0.0, y: 1.25),
        ]),
      ]),
    ];

    final first = service.serialize(documentName: 'Test', layers: source);
    final second = service.serialize(documentName: 'Test', layers: source);

    expect(first.content, second.content);
    expect(first.bytes, second.bytes);
    expect(first.content, contains('9\r\n\$ACADVER\r\n1\r\nAC1009\r\n'));
    expect(first.content, endsWith('0\r\nEOF\r\n'));
    expect(first.content.replaceAll('\r\n', ''), isNot(contains('\n')));
    expect(first.content, isNot(contains('AcDb')));
    expect(first.content, isNot(contains('BLOCK_RECORD')));
    expect(first.content, isNot(contains('OBJECTS')));
    expect(first.content, isNot(contains('CLASSES')));
  });

  test('writes only HEADER TABLES ENTITIES sections', () {
    final result = exportFeatures([
      feature('p', MapFeatureType.point, const [MapCoordinate(x: 1, y: 2)]),
    ]);

    expect(_sectionNames(_pairs(result.content)), [
      'HEADER',
      'TABLES',
      'ENTITIES',
    ]);
  });

  test('exports AutoCAD fixture semantic five-object set in R12 form', () {
    final result = exportFeatures([
      feature('p', MapFeatureType.point, const [MapCoordinate(x: 100, y: 100)]),
      feature('polygon', MapFeatureType.polygon, const [
        MapCoordinate(x: 400, y: 100),
        MapCoordinate(x: 114.712311489149, y: 100),
        MapCoordinate(x: 114.712311489149, y: 7.2048773688217),
        MapCoordinate(x: 400, y: 7.2048773688217),
      ]),
      feature(
        'text',
        MapFeatureType.text,
        const [MapCoordinate(x: 400, y: 350)],
        properties: const {'text': 'GeoCAD Test 01', 'textHeight': '20'},
      ),
      feature('line', MapFeatureType.line, const [
        MapCoordinate(x: 100, y: 200),
        MapCoordinate(x: 400, y: 450),
      ]),
      feature('polyline', MapFeatureType.polyline, const [
        MapCoordinate(x: 100, y: 300),
        MapCoordinate(x: 230.580969403789, y: -24.7285180417123),
        MapCoordinate(x: 342.507514607037, y: -303.067247791751),
      ]),
    ]);

    expect(result.entityCount, 5);
    expect(_recordCount(result.content, 'POINT'), 1);
    expect(_recordCount(result.content, 'TEXT'), 1);
    expect(_recordCount(result.content, 'LINE'), 1);
    expect(_recordCount(result.content, 'POLYLINE'), 2);
    expect(_recordCount(result.content, 'VERTEX'), 7);
    expect(_recordCount(result.content, 'SEQEND'), 2);
    expect(_recordCount(result.content, 'LWPOLYLINE'), 0);
    expect(result.content, contains('1\r\nGeoCAD Test 01\r\n'));
  });

  test('R12 POLYLINE uses VERTEX SEQEND and closed flag', () {
    final result = exportFeatures([
      feature('open', MapFeatureType.polyline, const [
        MapCoordinate(x: 0, y: 0),
        MapCoordinate(x: 2, y: 2),
      ]),
      feature('closed', MapFeatureType.polygon, const [
        MapCoordinate(x: 0, y: 0),
        MapCoordinate(x: 3, y: 0),
        MapCoordinate(x: 0, y: 3),
        MapCoordinate(x: 0, y: 0),
      ]),
    ]);

    final records = _records(_pairs(result.content));
    final polylines = records
        .where((record) => record.type == 'POLYLINE')
        .toList();
    expect(polylines, hasLength(2));
    expect(polylines[0].value(66), '1');
    expect(polylines[0].value(70), '0');
    expect(polylines[1].value(66), '1');
    expect(polylines[1].value(70), '1');
    expect(records.where((record) => record.type == 'VERTEX'), hasLength(5));
    expect(records.where((record) => record.type == 'SEQEND'), hasLength(2));
  });

  test('TEXT STANDARD style has matching R12 STYLE record', () {
    final result = exportFeatures([
      feature(
        'text',
        MapFeatureType.text,
        const [MapCoordinate(x: 10, y: 20)],
        properties: const {'text': 'GeoCAD Test'},
      ),
    ]);

    expect(result.content, contains('0\r\nSTYLE\r\n2\r\nSTANDARD\r\n'));
    expect(result.content, contains('7\r\nSTANDARD\r\n'));
  });

  test('exports POINT XY Z and explicit zero Z', () {
    final result = exportFeatures([
      feature('p1', MapFeatureType.point, const [
        MapCoordinate(x: 1, y: 2, z: 3),
      ]),
      feature('p2', MapFeatureType.point, const [MapCoordinate(x: 4, y: 5)]),
    ]);

    expect(result.entityCount, 2);
    expect(_recordCount(result.content, 'POINT'), 2);
    expect(result.content, contains('30\r\n3\r\n'));
    expect(result.content, contains('10\r\n4\r\n20\r\n5\r\n30\r\n0\r\n'));
  });

  test('exports LINE with independent endpoint Z', () {
    final result = exportFeatures([
      feature('line', MapFeatureType.line, const [
        MapCoordinate(x: 1, y: 2, z: 3),
        MapCoordinate(x: 4, y: 5, z: 6),
      ]),
    ]);

    expect(result.content, contains('10\r\n1\r\n20\r\n2\r\n30\r\n3\r\n'));
    expect(result.content, contains('11\r\n4\r\n21\r\n5\r\n31\r\n6\r\n'));
  });

  test('exports TEXT values defaults Unicode and multiline warning', () {
    final result = exportFeatures([
      feature(
        't1',
        MapFeatureType.text,
        const [MapCoordinate(x: 10, y: 20)],
        name: 'Tên điểm',
        properties: const {'textHeight': '2.5', 'rotationDegrees': '15'},
      ),
      feature(
        't2',
        MapFeatureType.text,
        const [MapCoordinate(x: 30, y: 40)],
        properties: const {'text': 'Dòng 1\nDòng 2'},
      ),
    ]);

    expect(result.content, contains('1\r\nTên điểm\r\n'));
    expect(result.content, contains('40\r\n2.5\r\n'));
    expect(result.content, contains('50\r\n15\r\n'));
    expect(result.content, contains('1\r\nDòng 1 Dòng 2\r\n'));
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
            const [MapCoordinate(x: 1, y: 1)],
            properties: const {'cadLayer': 'A/B'},
          ),
          feature(
            'b',
            MapFeatureType.point,
            const [MapCoordinate(x: 2, y: 2)],
            properties: const {'cadLayer': 'A\\B'},
          ),
        ], name: 'Fallback'),
      ],
    );

    expect(result.layerCount, 2);
    expect(result.content, contains('2\r\nA_B\r\n'));
    expect(result.content, contains('2\r\nA_B_2\r\n'));
  });

  test('locked layer exports while invisible data is excluded', () {
    final result = service.serialize(
      documentName: 'Visibility',
      layers: [
        layer([
          feature('shown', MapFeatureType.point, const [
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

  test(
    'accepts local CAD and valid UTM without AC1021 INSUNITS dependency',
    () {
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
      expect(utm.content, isNot(contains(r'$INSUNITS')));
    },
  );

  test('rejects empty malformed and nonfinite geometry', () {
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

  group('DXF R12 entity color export', () {
    test(
      'exports cad.colorIndex as entity group 62 and round trips it',
      () async {
        final exported = exportFeatures([
          feature(
            'point-color',
            MapFeatureType.point,
            const [MapCoordinate(x: 1, y: 2)],
            properties: const {'cad.colorIndex': '3'},
          ),
        ]);

        final point = _records(_pairs(exported.content))
            .singleWhere((record) => record.type == 'POINT');
        expect(point.value(62), '3');

        final directory = await Directory.systemTemp.createTemp(
          'geocad-r12-color-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final file = File(
          '${directory.path}${Platform.pathSeparator}color-roundtrip.dxf',
        );
        await file.writeAsBytes(exported.bytes);

        final parsed = await const DxfParserService().parseFile(file.path);

        expect(parsed.features.single.properties['cad.colorIndex'], '3');
        expect(
          parsed.features.single.properties.containsKey('cad.trueColor'),
          isFalse,
        );
      },
    );

    test('does not emit post-R12 group 420 from cad.trueColor', () {
      final result = exportFeatures([
        feature(
          'true-color',
          MapFeatureType.line,
          const [MapCoordinate(x: 0, y: 0), MapCoordinate(x: 10, y: 10)],
          properties: const {'cad.trueColor': '16711680'},
        ),
      ]);

      expect(result.content, contains('1\r\nAC1009\r\n'));
      final line = _records(_pairs(result.content))
          .singleWhere((record) => record.type == 'LINE');
      expect(line.value(420), isNull);
      expect(_pairs(result.content).where((pair) => pair.code == 420), isEmpty);
    });

    test('POLYLINE writes color only on header not VERTEX or SEQEND', () {
      final result = exportFeatures([
        feature(
          'polyline-color',
          MapFeatureType.polyline,
          const [
            MapCoordinate(x: 0, y: 0),
            MapCoordinate(x: 5, y: 5),
            MapCoordinate(x: 10, y: 0),
          ],
          properties: const {'cad.colorIndex': '2'},
        ),
      ]);

      final records = _records(_pairs(result.content));
      final polyline = records.singleWhere(
        (record) => record.type == 'POLYLINE',
      );
      final vertices = records
          .where((record) => record.type == 'VERTEX')
          .toList();
      final seqend = records.singleWhere((record) => record.type == 'SEQEND');

      expect(polyline.value(62), '2');
      expect(vertices, hasLength(3));
      expect(vertices.every((record) => record.value(62) == null), isTrue);
      expect(seqend.value(62), isNull);
    });

    test('keeps ACI export when cad.trueColor is also present', () {
      final result = exportFeatures([
        feature(
          'both-colors',
          MapFeatureType.text,
          const [MapCoordinate(x: 10, y: 20)],
          properties: const {
            'text': 'Điểm màu – ຈຸດສີ – Color point',
            'cad.colorIndex': '5',
            'cad.trueColor': '255',
          },
        ),
      ]);

      final textRecord = _records(_pairs(result.content))
          .singleWhere((record) => record.type == 'TEXT');

      expect(textRecord.value(62), '5');
      expect(textRecord.value(420), isNull);
      expect(textRecord.value(1), 'Điểm màu – ຈຸດສີ – Color point');
    });

    test('does not reconstruct imported BYLAYER color or emit entity 256', () {
      final result = exportFeatures([
        feature(
          'bylayer',
          MapFeatureType.point,
          const [MapCoordinate(x: 1, y: 2)],
          properties: const {
            'cadLayer': 'ROADS',
            'cad.colorIndex': '256',
            'cad.layer.colorIndex': '3',
            'cad.layer.flags': '4',
            'style.strokeColor': '#00FF00',
          },
        ),
      ]);

      final records = _records(_pairs(result.content));
      final point = records.singleWhere((record) => record.type == 'POINT');
      final layerRecord = records.singleWhere(
        (record) => record.type == 'LAYER' && record.value(2) == 'ROADS',
      );
      expect(point.value(8), 'ROADS');
      expect(point.value(62), isNull);
      expect(layerRecord.value(62), '7');
      expect(layerRecord.value(70), '0');
    });
  });

  test('current parser still round trips R12 POINT LINE and TEXT', () async {
    final exported = exportFeatures([
      feature('point', MapFeatureType.point, const [
        MapCoordinate(x: 1, y: 2, z: 3),
      ]),
      feature('line', MapFeatureType.line, const [
        MapCoordinate(x: 4, y: 5, z: 6),
        MapCoordinate(x: 7, y: 8, z: 9),
      ]),
      feature(
        'text',
        MapFeatureType.text,
        const [MapCoordinate(x: 10, y: 20, z: 5)],
        properties: const {
          'text': 'GeoCAD',
          'textHeight': '2.5',
          'rotationDegrees': '15',
        },
      ),
    ]);

    final directory = await Directory.systemTemp.createTemp('geocad-r12-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File(
      '${directory.path}${Platform.pathSeparator}roundtrip.dxf',
    );
    await file.writeAsBytes(exported.bytes);

    final parsed = await const DxfParserService().parseFile(file.path);

    expect(parsed.features, hasLength(3));
    expect(parsed.features.map((item) => item.type), [
      MapFeatureType.point,
      MapFeatureType.line,
      MapFeatureType.text,
    ]);
    expect(parsed.features[0].coordinates.single.z, 3);
    expect(parsed.features[1].coordinates.last.z, 9);
    expect(parsed.features[2].name, 'GeoCAD');
  });
}

class _DxfPair {
  final int code;
  final String value;

  const _DxfPair(this.code, this.value);
}

class _DxfRecord {
  final String type;
  final List<_DxfPair> pairs;

  const _DxfRecord(this.type, this.pairs);

  String? value(int code) {
    for (final pair in pairs) {
      if (pair.code == code) return pair.value;
    }
    return null;
  }
}

List<_DxfPair> _pairs(String content) {
  final lines = content.split('\r\n');
  if (lines.isNotEmpty && lines.last.isEmpty) {
    lines.removeLast();
  }
  expect(lines.length.isEven, isTrue);

  final pairs = <_DxfPair>[];
  for (var index = 0; index < lines.length; index += 2) {
    pairs.add(_DxfPair(int.parse(lines[index]), lines[index + 1]));
  }
  return pairs;
}

List<String> _sectionNames(List<_DxfPair> pairs) {
  final names = <String>[];
  for (var index = 0; index + 1 < pairs.length; index++) {
    if (pairs[index].code == 0 &&
        pairs[index].value == 'SECTION' &&
        pairs[index + 1].code == 2) {
      names.add(pairs[index + 1].value);
    }
  }
  return names;
}

List<_DxfRecord> _records(List<_DxfPair> pairs) {
  final records = <_DxfRecord>[];
  var index = 0;
  while (index < pairs.length) {
    if (pairs[index].code != 0) {
      index++;
      continue;
    }

    final type = pairs[index].value;
    final recordPairs = <_DxfPair>[];
    index++;
    while (index < pairs.length && pairs[index].code != 0) {
      recordPairs.add(pairs[index]);
      index++;
    }
    records.add(_DxfRecord(type, recordPairs));
  }
  return records;
}

int _recordCount(String content, String type) {
  return _records(_pairs(content))
      .where((record) => record.type == type)
      .length;
}
