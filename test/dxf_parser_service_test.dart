import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:autocad_googleearth/models/map_feature.dart';
import 'package:autocad_googleearth/services/dxf_parser_service.dart';

void main() {
  const service = DxfParserService();

  late Directory tempDirectory;
  var fileIndex = 0;

  setUpAll(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'geocad-dxf-parser-test-',
    );
  });

  tearDownAll(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  Future<DxfParseResult> parseEntities(String entities) async {
    final normalizedEntities = entities.trim();
    final file = File(
      '${tempDirectory.path}${Platform.pathSeparator}fixture-${fileIndex++}.dxf',
    );

    await file.writeAsString('''
0
SECTION
2
ENTITIES
$normalizedEntities
0
ENDSEC
0
EOF
''');

    return service.parseFile(file.path);
  }

  Future<DxfParseResult> parseRaw(String content) async {
    final file = File(
      '${tempDirectory.path}${Platform.pathSeparator}raw-${fileIndex++}.dxf',
    );
    await file.writeAsString(content);
    return service.parseFile(file.path);
  }

  Future<DxfParseResult> parseBytes(List<int> bytes) async {
    final file = File(
      '${tempDirectory.path}${Platform.pathSeparator}bytes-${fileIndex++}.dxf',
    );
    await file.writeAsBytes(bytes);
    return service.parseFile(file.path);
  }

  Future<DxfParseResult> parseWithLayers({
    required String layers,
    required String entities,
  }) {
    return parseRaw('''
0
SECTION
2
TABLES
0
TABLE
2
LAYER
70
0
${layers.trim()}
0
ENDTAB
0
ENDSEC
0
SECTION
2
ENTITIES
${entities.trim()}
0
ENDSEC
0
EOF
''');
  }

  test('parses CIRCLE as a smooth closed polyline and preserves Z', () async {
    final result = await parseEntities('''
0
CIRCLE
8
CURVES
10
100
20
200
30
12.5
40
10
''');

    final feature = result.features.single;

    expect(feature.type, MapFeatureType.polyline);
    expect(feature.properties['entityType'], 'CIRCLE');
    expect(feature.properties['cadLayer'], 'CURVES');
    expect(feature.properties['closed'], 'true');
    expect(feature.coordinates, hasLength(73));
    expect(feature.coordinates.first.x, 110);
    expect(feature.coordinates.first.y, 200);
    expect(feature.coordinates.last.x, feature.coordinates.first.x);
    expect(feature.coordinates.last.y, feature.coordinates.first.y);
    expect(
      feature.coordinates.every((coordinate) => coordinate.z == 12.5),
      isTrue,
    );
  });

  test(
    'parses ARC counter-clockwise with exact start and end angles',
    () async {
      final result = await parseEntities('''
0
ARC
8
CURVES
10
0
20
0
30
3
40
10
50
0
51
90
''');

      final feature = result.features.single;

      expect(feature.type, MapFeatureType.polyline);
      expect(feature.properties['entityType'], 'ARC');
      expect(feature.properties['startAngleDegrees'], '0.0');
      expect(feature.properties['endAngleDegrees'], '90.0');
      expect(feature.coordinates.first.x, closeTo(10, 1e-12));
      expect(feature.coordinates.first.y, closeTo(0, 1e-12));
      expect(feature.coordinates.last.x, closeTo(0, 1e-12));
      expect(feature.coordinates.last.y, closeTo(10, 1e-12));
      expect(
        feature.coordinates.every((coordinate) => coordinate.z == 3),
        isTrue,
      );
    },
  );

  test('handles both extreme finite ARC angle directions safely', () async {
    for (final angles in const [
      (start: '1e308', end: '-1e308'),
      (start: '-1e308', end: '1e308'),
    ]) {
      final result = await parseEntities('''
0
ARC
10
0
20
0
40
10
50
${angles.start}
51
${angles.end}
''');

      expect(result.diagnostics.totalEntityCount, 1);
      expect(
        result.diagnostics.parsedEntityCount +
            result.diagnostics.malformedEntityCount,
        1,
      );
      if (result.features.isNotEmpty) {
        final feature = result.features.single;
        expect(feature.coordinates.length - 1, lessThanOrEqualTo(72));
        expect(
          feature.coordinates.every(
            (coordinate) => coordinate.x.isFinite && coordinate.y.isFinite,
          ),
          isTrue,
        );
      }
    }
  });

  test('rejects extreme angles equivalent after normalization', () async {
    final result = await parseEntities('''
0
ARC
10
0
20
0
40
10
50
1e308
51
1e308
''');

    expect(result.features, isEmpty);
    expect(result.diagnostics.malformedEntityCount, 1);
    expect(
      result.diagnostics.issues.single.code,
      DxfDiagnosticCode.invalidGeometry,
    );
  });

  test('extreme valid ARC uses one bounded sweep semantic', () async {
    final result = await parseEntities('''
0
ARC
10
100
20
200
40
10
50
1e308
51
10
''');

    final feature = result.features.single;
    final sweep = double.parse(feature.properties['sweepAngleDegrees']!);
    final segments = int.parse(feature.properties['approximationSegments']!);
    expect(sweep, greaterThan(0));
    expect(sweep, lessThanOrEqualTo(360));
    expect(segments, (sweep / 5).ceil());
    expect(segments, lessThanOrEqualTo(72));
    expect(feature.coordinates, hasLength(segments + 1));
    expect(
      feature.coordinates.every(
        (coordinate) => coordinate.x.isFinite && coordinate.y.isFinite,
      ),
      isTrue,
    );
  });

  test('parses TEXT content insertion point layer and elevation', () async {
    final result = await parseEntities(r'''
0
TEXT
8
ANNOTATION
10
106.25
20
16.5
30
25.75
40
2.5
1
Điểm đo A
50
30
7
STANDARD
''');

    final feature = result.features.single;

    expect(feature.type, MapFeatureType.text);
    expect(feature.name, 'Điểm đo A');
    expect(feature.coordinates.single.x, 106.25);
    expect(feature.coordinates.single.y, 16.5);
    expect(feature.coordinates.single.z, 25.75);
    expect(feature.properties['cadLayer'], 'ANNOTATION');
    expect(feature.properties['textHeight'], '2.5');
    expect(feature.properties['rotationDegrees'], '30.0');
    expect(feature.properties['textStyle'], 'STANDARD');
  });

  test('parses basic MTEXT chunks and formatting controls', () async {
    final result = await parseEntities(r'''
0
MTEXT
8
NOTES
10
500000
20
1800000
30
8
40
3
3
First line
1
\PSecond\~line
''');

    final feature = result.features.single;

    expect(feature.type, MapFeatureType.text);
    expect(feature.name, 'First line\nSecond line');
    expect(feature.properties['entityType'], 'MTEXT');
    expect(feature.properties['cadLayer'], 'NOTES');
    expect(feature.coordinates.single.z, 8);
  });

  test('preserves CAD layer for every newly supported entity', () async {
    final result = await parseEntities('''
0
CIRCLE
8
LAYER-CIRCLE
10
0
20
0
40
1
0
ARC
8
LAYER-ARC
10
0
20
0
40
1
50
0
51
45
0
TEXT
8
LAYER-TEXT
10
0
20
0
1
Text
0
MTEXT
8
LAYER-MTEXT
10
0
20
0
1
MText
''');

    expect(result.features.map((feature) => feature.properties['cadLayer']), [
      'LAYER-CIRCLE',
      'LAYER-ARC',
      'LAYER-TEXT',
      'LAYER-MTEXT',
    ]);
  });

  test('regression parses POINT', () async {
    final result = await parseEntities('''
0
POINT
8
POINTS
10
1
20
2
30
3
''');

    final feature = result.features.single;

    expect(feature.type, MapFeatureType.point);
    expect(feature.coordinates.single.x, 1);
    expect(feature.coordinates.single.y, 2);
    expect(feature.coordinates.single.z, 3);
    expect(feature.properties['cadLayer'], 'POINTS');
  });

  test('regression parses LINE', () async {
    final result = await parseEntities('''
0
LINE
8
LINES
10
1
20
2
30
3
11
4
21
5
31
6
''');

    final feature = result.features.single;

    expect(feature.type, MapFeatureType.line);
    expect(feature.coordinates, hasLength(2));
    expect(feature.coordinates.first.z, 3);
    expect(feature.coordinates.last.z, 6);
    expect(feature.properties['cadLayer'], 'LINES');
  });

  test('regression parses open and closed LWPOLYLINE', () async {
    final result = await parseEntities('''
0
LWPOLYLINE
8
OPEN
70
0
10
0
20
0
10
1
20
1
0
LWPOLYLINE
8
CLOSED
70
1
10
0
20
0
10
1
20
0
10
1
20
1
''');

    expect(result.features, hasLength(2));
    expect(result.features[0].type, MapFeatureType.polyline);
    expect(result.features[0].coordinates, hasLength(2));
    expect(result.features[0].properties['cadLayer'], 'OPEN');
    expect(result.features[1].type, MapFeatureType.polygon);
    expect(result.features[1].coordinates, hasLength(3));
    expect(result.features[1].properties['closed'], 'true');
    expect(result.features[1].properties['cadLayer'], 'CLOSED');
  });

  test('rejects odd line count and invalid group-code stream', () async {
    await expectLater(
      parseRaw('0\nSECTION\n2'),
      throwsA(isA<DxfParserException>()),
    );
    await expectLater(
      parseRaw('bad\nSECTION\n'),
      throwsA(isA<DxfParserException>()),
    );
  });

  group('DXF strict UTF-8 import boundary', () {
    const asciiDxf =
        '0\nSECTION\n2\nENTITIES\n0\nPOINT\n10\n1\n20\n2\n0\nENDSEC\n0\nEOF\n';

    test('parses ASCII bytes with LF and CRLF line endings', () async {
      final lf = await parseBytes(ascii.encode(asciiDxf));
      final crlf = await parseBytes(
        ascii.encode(asciiDxf.replaceAll('\n', '\r\n')),
      );

      for (final result in [lf, crlf]) {
        expect(result.features.single.type, MapFeatureType.point);
        expect(result.features.single.coordinates.single.x, 1);
        expect(result.features.single.coordinates.single.y, 2);
      }
    });

    test('parses valid UTF-8 Vietnamese Lao and mixed TEXT bytes', () async {
      for (final label in const [
        'Điểm khảo sát',
        'ຈຸດສຳຫຼວດ',
        'Điểm khảo sát – ຈຸດສຳຫຼວດ – Survey point',
      ]) {
        final dxf =
            '0\nSECTION\n2\nENTITIES\n0\nTEXT\n8\nUNICODE\n'
            '10\n1\n20\n2\n1\n$label\n0\nENDSEC\n0\nEOF\n';
        final result = await parseBytes(utf8.encode(dxf));

        expect(result.features.single.name, label);
        expect(result.features.single.properties['cadLayer'], 'UNICODE');
      }
    });

    test('accepts UTF-8 BOM without corrupting the first group code', () async {
      final bytes = <int>[0xEF, 0xBB, 0xBF, ...utf8.encode(asciiDxf)];
      final result = await parseBytes(bytes);

      expect(result.pairs.first.code, 0);
      expect(result.pairs.first.value, 'SECTION');
      expect(result.features.single.type, MapFeatureType.point);
    });

    test('rejects malformed UTF-8 as DxfParserException', () async {
      final bytes = <int>[
        ...ascii.encode('0\nSECTION\n2\nENTITIES\n0\nTEXT\n10\n1\n20\n2\n1\n'),
        0xC3,
        0x28,
        ...ascii.encode('\n0\nENDSEC\n0\nEOF\n'),
      ];

      await expectLater(
        parseBytes(bytes),
        throwsA(
          isA<DxfParserException>().having(
            (error) => error.message,
            'message',
            contains('UTF-8'),
          ),
        ),
      );
    });

    test(
      'rejects representative legacy single-byte text deterministically',
      () async {
        final bytes = <int>[
          ...ascii.encode(
            '0\nSECTION\n2\nENTITIES\n0\nTEXT\n10\n1\n20\n2\n1\nCaf',
          ),
          0xE9,
          ...ascii.encode('\n0\nENDSEC\n0\nEOF\n'),
        ];

        Object? caught;
        try {
          await parseBytes(bytes);
        } catch (error) {
          caught = error;
        }
        expect(caught, isA<DxfParserException>());
        expect(caught, isNot(isA<FormatException>()));
        expect(caught.toString(), isNot(contains('Caf')));
      },
    );

    test('preserves Unicode layer lookup through byte decoding', () async {
      const layerName = 'Đường tưới – ສາຍຊົລະປະທານ';
      const dxf =
          '''
0
SECTION
2
TABLES
0
TABLE
2
LAYER
70
1
0
LAYER
2
$layerName
70
0
62
3
0
ENDTAB
0
ENDSEC
0
SECTION
2
ENTITIES
0
LINE
8
$layerName
62
256
10
0
20
0
11
1
21
1
0
ENDSEC
0
EOF
''';
      final result = await parseBytes(utf8.encode(dxf));
      final properties = result.features.single.properties;

      expect(properties['cadLayer'], layerName);
      expect(properties['cad.layer.colorIndex'], '3');
      expect(properties['style.strokeColor'], '#00FF00');
    });
  });

  test('skips NaN POINT and Infinity LINE with diagnostics', () async {
    final result = await parseEntities('''
0
POINT
10
NaN
20
2
0
LINE
10
0
20
0
11
Infinity
21
1
''');

    expect(result.features, isEmpty);
    expect(result.diagnostics.totalEntityCount, 2);
    expect(result.diagnostics.malformedEntityCount, 2);
    expect(
      result.diagnostics.issues.map((issue) => issue.code),
      everyElement(DxfDiagnosticCode.nonFiniteNumber),
    );
  });

  test('reports malformed LINE CIRCLE ARC TEXT and MTEXT', () async {
    final result = await parseEntities('''
0
LINE
10
0
20
0
11
1
0
CIRCLE
10
0
20
0
40
-1
0
ARC
10
0
20
0
40
1
50
10
51
10
0
TEXT
10
0
20
0
1

0
MTEXT
10
0
20
0
''');

    expect(result.features, isEmpty);
    expect(result.diagnostics.totalEntityCount, 5);
    expect(result.diagnostics.malformedEntityCount, 5);
    expect(result.diagnostics.skippedEntityCount, 5);
  });

  test('aggregates unsupported entity types deterministically', () async {
    final result = await parseEntities('''
0
SPLINE
8
A
0
INSERT
8
B
0
SPLINE
8
C
0
HATCH
8
D
''');

    expect(result.features, isEmpty);
    expect(result.diagnostics.unsupportedEntityCount, 4);
    expect(result.diagnostics.unsupportedEntityCounts.keys, [
      'HATCH',
      'INSERT',
      'SPLINE',
    ]);
    expect(result.diagnostics.unsupportedEntityCounts['SPLINE'], 2);
    expect(result.diagnostics.issues.map((issue) => issue.entityIndex), [
      1,
      2,
      3,
      4,
    ]);
  });

  test('parses finite bulge and elevation with fidelity warnings', () async {
    final result = await parseEntities('''
0
LWPOLYLINE
90
2
70
0
38
4.5
10
0
20
0
42
0.5
10
1
20
1
''');

    expect(result.features, hasLength(1));
    expect(result.diagnostics.malformedEntityCount, 0);
    expect(result.diagnostics.hasFidelityWarnings, isTrue);
    expect(
      result.diagnostics.issues.map((issue) => issue.code),
      containsAll([
        DxfDiagnosticCode.lwPolylineBulgeNotPreserved,
        DxfDiagnosticCode.lwPolylineElevationNotPreserved,
      ]),
    );
  });

  test('skips non-finite bulge and elevation', () async {
    for (final specialPair in const ['42\nNaN', '38\nInfinity']) {
      final result = await parseEntities('''
0
LWPOLYLINE
90
2
70
0
$specialPair
10
0
20
0
10
1
20
1
''');
      expect(result.features, isEmpty);
      expect(result.diagnostics.malformedEntityCount, 1);
    }
  });

  test(
    'accepts default OCS with warning and rejects non-default OCS',
    () async {
      Future<DxfParseResult> parseOcs(String z) => parseEntities('''
0
LWPOLYLINE
90
2
210
0
220
0
230
$z
10
0
20
0
10
1
20
1
''');

      final defaultOcs = await parseOcs('1');
      expect(defaultOcs.features, hasLength(1));
      expect(
        defaultOcs.diagnostics.issues.single.code,
        DxfDiagnosticCode.lwPolylineDefaultOcs,
      );

      final nonDefaultOcs = await parseOcs('-1');
      expect(nonDefaultOcs.features, isEmpty);
      expect(
        nonDefaultOcs.diagnostics.issues.single.code,
        DxfDiagnosticCode.lwPolylineOcsNotSupported,
      );
    },
  );

  test('rejects partial OCS and vertex count mismatch', () async {
    final partialOcs = await parseEntities('''
0
LWPOLYLINE
90
2
210
0
10
0
20
0
10
1
20
1
''');
    expect(partialOcs.features, isEmpty);

    final mismatch = await parseEntities('''
0
LWPOLYLINE
90
3
10
0
20
0
10
1
20
1
''');
    expect(mismatch.features, isEmpty);
    expect(
      mismatch.diagnostics.issues.single.code,
      DxfDiagnosticCode.lwPolylineVertexCountMismatch,
    );
  });

  test('missing vertex count preserves compatibility with warning', () async {
    final result = await parseEntities('''
0
LWPOLYLINE
10
0
20
0
10
1
20
1
''');

    expect(result.features, hasLength(1));
    expect(
      result.diagnostics.issues.single.code,
      DxfDiagnosticCode.lwPolylineVertexCountMissing,
    );
  });

  test('rejects orphan invalid and insufficient polyline vertices', () async {
    final fixtures = <String>[
      '10\n0\n10\n1\n20\n1',
      '20\n0\n10\n1\n20\n1',
      '10\nbad\n20\n0\n10\n1\n20\n1',
      '10\n0\n20\n0',
      '70\n1\n10\n0\n20\n0\n10\n1\n20\n1',
    ];
    for (final data in fixtures) {
      final result = await parseEntities('0\nLWPOLYLINE\n$data');
      expect(result.features, isEmpty);
      expect(result.diagnostics.malformedEntityCount, 1);
    }
  });

  test('mixed file keeps valid order and diagnostics invariants', () async {
    final result = await parseEntities('''
0
POINT
10
1
20
2
0
LINE
10
0
20
0
11
bad
21
1
0
INSERT
8
BLOCKS
0
TEXT
10
3
20
4
1
Label
''');

    expect(result.features, hasLength(2));
    expect(result.features.map((feature) => feature.type), [
      MapFeatureType.point,
      MapFeatureType.text,
    ]);
    expect(result.features.map((feature) => feature.id), [
      'dxf-point-0',
      'dxf-text-1',
    ]);
    final diagnostics = result.diagnostics;
    expect(diagnostics.totalEntityCount, 4);
    expect(diagnostics.parsedEntityCount, result.features.length);
    expect(diagnostics.malformedEntityCount, 1);
    expect(diagnostics.unsupportedEntityCount, 1);
    expect(
      diagnostics.totalEntityCount,
      diagnostics.parsedEntityCount +
          diagnostics.malformedEntityCount +
          diagnostics.unsupportedEntityCount,
    );
    expect(
      result.features
          .expand((feature) => feature.coordinates)
          .every(
            (coordinate) =>
                coordinate.x.isFinite &&
                coordinate.y.isFinite &&
                (coordinate.z?.isFinite ?? true),
          ),
      isTrue,
    );
  });

  test('diagnostics are immutable and deterministic', () async {
    const entities = '0\nSPLINE\n0\nPOINT\n10\nNaN\n20\n1';
    final first = await parseEntities(entities);
    final second = await parseEntities(entities);

    expect(
      first.diagnostics.unsupportedEntityCounts,
      second.diagnostics.unsupportedEntityCounts,
    );
    expect(
      first.diagnostics.issues.map(
        (issue) =>
            (issue.code, issue.entityType, issue.entityIndex, issue.reason),
      ),
      second.diagnostics.issues.map(
        (issue) =>
            (issue.code, issue.entityType, issue.entityIndex, issue.reason),
      ),
    );
    expect(
      () => first.diagnostics.unsupportedEntityCounts['X'] = 1,
      throwsUnsupportedError,
    );
    expect(
      () => first.diagnostics.issues.add(
        const DxfImportDiagnostic(
          code: DxfDiagnosticCode.malformedEntity,
          severity: DxfDiagnosticSeverity.error,
          entityType: 'X',
          entityIndex: 1,
          reason: 'x',
        ),
      ),
      throwsUnsupportedError,
    );
  });

  test('preserves Vietnamese Lao and English Unicode TEXT content', () async {
    const labels = [
      'Tiếng Việt – Đường thử nghiệm',
      'ພາສາລາວ – ທົດສອບ',
      'English – Test feature',
    ];

    for (final label in labels) {
      final result = await parseEntities('''
0
TEXT
8
UNICODE
10
106
20
16
1
$label
''');

      expect(result.features.single.type, MapFeatureType.text);
      expect(result.features.single.name, label);
      expect(result.features.single.properties['cadLayer'], 'UNICODE');
      expect(result.diagnostics.parsedEntityCount, 1);
      expect(result.diagnostics.hasIssues, isFalse);
    }
  });

  group('DXF entity color metadata', () {
    test('preserves ACI and canonicalizes it to stroke color', () async {
      final result = await parseEntities('''
0
LINE
8
COLOR-ACI
62
3
10
0
20
0
11
10
21
10
''');

      final feature = result.features.single;

      expect(feature.properties['cad.colorIndex'], '3');
      expect(feature.properties.containsKey('cad.trueColor'), isFalse);
      expect(feature.properties['style.strokeColor'], '#00FF00');
      expect(result.diagnostics.parsedEntityCount, 1);
      expect(result.diagnostics.hasIssues, isFalse);
    });

    test('preserves True Color and canonicalizes it to stroke color', () async {
      final result = await parseEntities('''
0
POINT
8
COLOR-TRUE
420
16711680
10
1
20
2
''');

      final feature = result.features.single;

      expect(feature.properties['cad.trueColor'], '16711680');
      expect(feature.properties.containsKey('cad.colorIndex'), isFalse);
      expect(feature.properties['style.strokeColor'], '#FF0000');
      expect(result.diagnostics.parsedEntityCount, 1);
      expect(result.diagnostics.hasIssues, isFalse);
    });

    test('True Color wins over ACI while preserving both metadata', () async {
      final result = await parseEntities(r'''
0
TEXT
8
COLOR-BOTH
62
3
420
255
10
106
20
16
1
Điểm màu – ຈຸດສີ – Color point
''');

      final feature = result.features.single;

      expect(feature.properties['cad.colorIndex'], '3');
      expect(feature.properties['cad.trueColor'], '255');
      expect(feature.properties['style.strokeColor'], '#0000FF');
      expect(feature.name, 'Điểm màu – ຈຸດສີ – Color point');
      expect(feature.properties['text'], feature.name);
      expect(result.diagnostics.parsedEntityCount, 1);
      expect(result.diagnostics.hasIssues, isFalse);
    });

    test('invalid True Color falls back to valid ACI', () async {
      final result = await parseEntities('''
0
LINE
62
5
420
invalid
10
0
20
0
11
10
21
10
''');

      final feature = result.features.single;

      expect(feature.properties['cad.colorIndex'], '5');
      expect(feature.properties['cad.trueColor'], 'invalid');
      expect(feature.properties['style.strokeColor'], '#0000FF');
      expect(result.diagnostics.hasIssues, isFalse);
    });

    test('R12 POLYLINE canonicalizes color from header metadata', () async {
      final result = await parseRaw(
        _r12PolylineDxf(
          0,
          [
            ['0', '0', '0'],
            ['10', '10', '0'],
          ],
          headerColorIndex: '2',
          headerTrueColor: '65280',
        ),
      );

      final feature = result.features.single;

      expect(feature.properties['entityType'], 'POLYLINE');
      expect(feature.properties['cad.colorIndex'], '2');
      expect(feature.properties['cad.trueColor'], '65280');
      expect(feature.properties['style.strokeColor'], '#00FF00');
      expect(result.diagnostics.parsedEntityCount, 1);
      expect(result.diagnostics.hasIssues, isFalse);
    });

    test('does not canonicalize ACI 0 BYBLOCK', () async {
      final result = await parseEntities('''
0
POINT
62
0
10
1
20
2
''');

      final feature = result.features.single;

      expect(feature.properties['cad.colorIndex'], '0');
      expect(feature.properties.containsKey('style.strokeColor'), isFalse);
      expect(result.diagnostics.hasIssues, isFalse);
    });

    test('does not canonicalize ACI 256 BYLAYER', () async {
      final result = await parseEntities('''
0
POINT
62
256
10
1
20
2
''');

      final feature = result.features.single;

      expect(feature.properties['cad.colorIndex'], '256');
      expect(feature.properties.containsKey('style.strokeColor'), isFalse);
      expect(result.diagnostics.hasIssues, isFalse);
    });

    test('does not canonicalize negative ACI', () async {
      final result = await parseEntities('''
0
POINT
62
-3
10
1
20
2
''');

      final feature = result.features.single;

      expect(feature.properties['cad.colorIndex'], '-3');
      expect(feature.properties.containsKey('style.strokeColor'), isFalse);
      expect(result.diagnostics.hasIssues, isFalse);
    });

    test('color canonicalization preserves multilingual TEXT exactly', () async {
      const label =
          'Tiếng Việt – Đường thử nghiệm | ພາສາລາວ – ທົດສອບ | English – Test feature';

      final result = await parseEntities('''
0
TEXT
8
UNICODE-COLOR
62
6
10
106
20
16
1
$label
''');

      final feature = result.features.single;

      expect(feature.type, MapFeatureType.text);
      expect(feature.name, label);
      expect(feature.properties['text'], label);
      expect(feature.properties['cadLayer'], 'UNICODE-COLOR');
      expect(feature.properties['cad.colorIndex'], '6');
      expect(feature.properties['style.strokeColor'], '#FF00FF');
      expect(result.diagnostics.parsedEntityCount, 1);
      expect(result.diagnostics.hasIssues, isFalse);
    });
  });

  group('DXF LAYER color and BYLAYER resolution', () {
    test(
      'resolves representative layer ACI values for explicit BYLAYER',
      () async {
        for (final sample in const [
          (name: 'ACI-1', aci: '1', color: '#FF0000'),
          // ACI 10-249 uses the current approximate mapping.
          (name: 'ACI-123', aci: '123', color: '#80FFDF'),
          (name: 'ACI-250', aci: '250', color: '#333333'),
        ]) {
          final result = await parseWithLayers(
            layers:
                '''
0
LAYER
2
${sample.name}
70
0
62
${sample.aci}
''',
            entities:
                '''
0
POINT
8
${sample.name}
62
256
10
1
20
2
''',
          );
          final properties = result.features.single.properties;
          expect(properties['cad.colorIndex'], '256');
          expect(properties['cad.layer.colorIndex'], sample.aci);
          expect(properties['cad.layer.flags'], '0');
          expect(properties['style.strokeColor'], sample.color);
        }
      },
    );

    test(
      'uses absolute negative layer ACI while preserving raw value',
      () async {
        final result = await parseWithLayers(
          layers: '0\nLAYER\n2\nOFF\n70\n5\n62\n-3',
          entities: '0\nLINE\n8\nOFF\n62\n256\n10\n0\n20\n0\n11\n1\n21\n1',
        );
        final properties = result.features.single.properties;
        expect(properties['cad.layer.colorIndex'], '-3');
        expect(properties['cad.layer.flags'], '5');
        expect(properties['style.strokeColor'], '#00FF00');
        expect(result.features.single.visible, isTrue);
      },
    );

    test(
      'implicit BYLAYER resolves but preserves absence of entity color',
      () async {
        final result = await parseWithLayers(
          layers: '0\nLAYER\n2\nIMPLICIT\n70\n0\n62\n2',
          entities: '0\nCIRCLE\n8\nIMPLICIT\n10\n0\n20\n0\n40\n1',
        );
        final properties = result.features.single.properties;
        expect(properties.containsKey('cad.colorIndex'), isFalse);
        expect(properties['cad.layer.colorIndex'], '2');
        expect(properties['style.strokeColor'], '#FFFF00');
      },
    );

    test('entity ACI and valid True Color override layer color', () async {
      final result = await parseWithLayers(
        layers: '0\nLAYER\n2\nOVERRIDE\n70\n0\n62\n1',
        entities: '''
0
POINT
8
OVERRIDE
62
3
10
0
20
0
0
TEXT
8
OVERRIDE
62
256
420
255
10
1
20
1
1
Blue
''',
      );
      expect(result.features[0].properties['style.strokeColor'], '#00FF00');
      expect(result.features[1].properties['style.strokeColor'], '#0000FF');
      for (final feature in result.features) {
        expect(feature.properties['cad.layer.colorIndex'], '1');
      }
    });

    test('invalid True Color with BYLAYER falls back to layer color', () async {
      final result = await parseWithLayers(
        layers: '0\nLAYER\n2\nFALLBACK\n70\n0\n62\n6',
        entities: '0\nPOINT\n8\nFALLBACK\n62\n256\n420\ninvalid\n10\n0\n20\n0',
      );
      final properties = result.features.single.properties;
      expect(properties['cad.trueColor'], 'invalid');
      expect(properties['style.strokeColor'], '#FF00FF');
    });

    test('BYBLOCK does not fall back to layer color', () async {
      final result = await parseWithLayers(
        layers: '0\nLAYER\n2\nBLOCK\n70\n0\n62\n1',
        entities: '0\nPOINT\n8\nBLOCK\n62\n0\n10\n0\n20\n0',
      );
      final properties = result.features.single.properties;
      expect(properties['cad.layer.colorIndex'], '1');
      expect(properties.containsKey('style.strokeColor'), isFalse);
    });

    test('missing group 8 does not default to layer zero', () async {
      final result = await parseWithLayers(
        layers: '0\nLAYER\n2\n0\n70\n0\n62\n1',
        entities: '0\nPOINT\n62\n256\n10\n0\n20\n0',
      );
      final properties = result.features.single.properties;
      expect(properties.containsKey('cadLayer'), isFalse);
      expect(properties.containsKey('cad.layer.colorIndex'), isFalse);
      expect(properties.containsKey('style.strokeColor'), isFalse);
    });

    test('explicit Unicode and zero layer names resolve exactly', () async {
      for (final sample in const [
        (name: '0', aci: '4', color: '#00FFFF'),
        (name: 'Đường – ເສັ້ນ', aci: '6', color: '#FF00FF'),
      ]) {
        final result = await parseWithLayers(
          layers: '0\nLAYER\n2\n${sample.name}\n70\n4\n62\n${sample.aci}',
          entities: '0\nPOINT\n8\n${sample.name}\n62\n256\n10\n0\n20\n0',
        );
        final properties = result.features.single.properties;
        expect(properties['cadLayer'], sample.name);
        expect(properties['cad.layer.flags'], '4');
        expect(properties['style.strokeColor'], sample.color);
      }
    });

    test('unknown duplicate and case-mismatched layers fail soft', () async {
      final result = await parseWithLayers(
        layers: '''
0
LAYER
2
DUP
70
0
62
1
0
LAYER
2
DUP
70
0
62
2
0
LAYER
2
Case
70
0
62
3
''',
        entities: '''
0
POINT
8
DUP
62
256
10
0
20
0
0
POINT
8
UNKNOWN
62
256
10
1
20
1
0
POINT
8
case
62
256
10
2
20
2
''',
      );
      expect(result.features, hasLength(3));
      for (final feature in result.features) {
        expect(feature.properties.containsKey('cad.layer.colorIndex'), isFalse);
        expect(feature.properties.containsKey('style.strokeColor'), isFalse);
      }
    });

    test(
      'malformed missing zero and 256 layer colors do not resolve',
      () async {
        for (final rawColor in const ['invalid', '', '0', '256']) {
          final colorPair = rawColor.isEmpty ? '' : '62\n$rawColor';
          final result = await parseWithLayers(
            layers: '0\nLAYER\n2\nNO-COLOR\n70\ninvalid\n$colorPair',
            entities: '0\nPOINT\n8\nNO-COLOR\n62\n256\n10\n0\n20\n0',
          );
          final properties = result.features.single.properties;
          if (rawColor.isEmpty) {
            expect(properties.containsKey('cad.layer.colorIndex'), isFalse);
          } else {
            expect(properties['cad.layer.colorIndex'], rawColor);
          }
          expect(properties.containsKey('cad.layer.flags'), isFalse);
          expect(properties.containsKey('style.strokeColor'), isFalse);
        }
      },
    );

    test('R12 POLYLINE resolves color from its header layer', () async {
      final result = await parseWithLayers(
        layers: '0\nLAYER\n2\nR12\n70\n0\n62\n5',
        entities: '''
0
POLYLINE
8
R12
62
256
70
0
0
VERTEX
10
0
20
0
70
0
0
VERTEX
10
1
20
1
70
0
0
SEQEND
''',
      );
      final properties = result.features.single.properties;
      expect(properties['entityType'], 'POLYLINE');
      expect(properties['cad.layer.colorIndex'], '5');
      expect(properties['style.strokeColor'], '#0000FF');
    });
  });

  group('DXF R12 POLYLINE / VERTEX / SEQEND', () {
    test('parses open and closed POLYLINE as logical entities', () async {
      final open = await parseRaw(
        _r12PolylineDxf(0, [
          ['100', '200', '0'],
          ['150', '250', '0'],
          ['300', '400', '0'],
        ]),
      );
      final closed = await parseRaw(
        _r12PolylineDxf(1, [
          ['0', '0', '5'],
          ['10', '0', '6'],
          ['0', '10', '7'],
        ]),
      );
      expect(open.features.single.type, MapFeatureType.polyline);
      expect(open.features.single.coordinates, hasLength(3));
      expect(open.features.single.properties['entityType'], 'POLYLINE');
      expect(open.diagnostics.totalEntityCount, 1);
      expect(open.diagnostics.parsedEntityCount, 1);
      expect(closed.features.single.type, MapFeatureType.polygon);
      expect(closed.features.single.coordinates.map((c) => c.z), [5, 6, 7]);
      expect(closed.diagnostics.totalEntityCount, 1);
    });

    test('rejects non-finite VERTEX as one malformed POLYLINE', () async {
      final result = await parseRaw(
        _r12PolylineDxf(0, [
          ['0', '0', '0'],
          ['NaN', '10', '0'],
        ]),
      );
      expect(result.features, isEmpty);
      expect(result.diagnostics.totalEntityCount, 1);
      expect(result.diagnostics.malformedEntityCount, 1);
      expect(
        result.diagnostics.issues.single.code,
        DxfDiagnosticCode.nonFiniteNumber,
      );
      expect(result.diagnostics.issues.single.entityType, 'POLYLINE');
    });

    test('rejects POLYLINE missing SEQEND', () async {
      final result = await parseRaw(
        _r12PolylineDxf(0, [
          ['0', '0', '0'],
          ['10', '10', '0'],
        ], includeSeqend: false),
      );
      expect(result.features, isEmpty);
      expect(result.diagnostics.totalEntityCount, 1);
      expect(result.diagnostics.malformedEntityCount, 1);
      expect(
        result.diagnostics.issues.single.code,
        DxfDiagnosticCode.malformedEntity,
      );
      expect(result.diagnostics.issues.single.reason, contains('SEQEND'));
    });

    test('rejects open and closed POLYLINE with too few vertices', () async {
      final open = await parseRaw(
        _r12PolylineDxf(0, [
          ['0', '0', '0'],
        ]),
      );
      final closed = await parseRaw(
        _r12PolylineDxf(1, [
          ['0', '0', '0'],
          ['10', '0', '0'],
        ]),
      );
      for (final result in [open, closed]) {
        expect(result.features, isEmpty);
        expect(result.diagnostics.totalEntityCount, 1);
        expect(result.diagnostics.malformedEntityCount, 1);
        expect(
          result.diagnostics.issues.single.code,
          DxfDiagnosticCode.invalidGeometry,
        );
      }
    });

    test('rejects VERTEX missing required Y', () async {
      final result = await parseRaw(_r12MissingYVertexDxf);
      expect(result.features, isEmpty);
      expect(result.diagnostics.totalEntityCount, 1);
      expect(result.diagnostics.malformedEntityCount, 1);
      expect(
        result.diagnostics.issues.single.code,
        DxfDiagnosticCode.missingRequiredValue,
      );
    });
  });
}

String _r12PolylineDxf(
  int flags,
  List<List<String>> vertices, {
  bool includeSeqend = true,
  String? headerColorIndex,
  String? headerTrueColor,
}) {
  final b = StringBuffer();
  for (final line in [
    '0',
    'SECTION',
    '2',
    'ENTITIES',
    '0',
    'POLYLINE',
    '8',
    '0',
    '66',
    '1',
    '10',
    '0',
    '20',
    '0',
    '30',
    '0',
    '70',
    '$flags',
  ]) {
    b.writeln(line);
  }
  if (headerColorIndex != null) {
    b
      ..writeln('62')
      ..writeln(headerColorIndex);
  }
  if (headerTrueColor != null) {
    b
      ..writeln('420')
      ..writeln(headerTrueColor);
  }
  for (final v in vertices) {
    for (final line in [
      '0',
      'VERTEX',
      '8',
      '0',
      '10',
      v[0],
      '20',
      v[1],
      '30',
      v[2],
      '70',
      '0',
    ]) {
      b.writeln(line);
    }
  }
  if (includeSeqend) {
    for (final line in ['0', 'SEQEND', '8', '0']) {
      b.writeln(line);
    }
  }
  for (final line in ['0', 'ENDSEC', '0', 'EOF']) {
    b.writeln(line);
  }
  return b.toString();
}

final _r12MissingYVertexDxf = [
  '0',
  'SECTION',
  '2',
  'ENTITIES',
  '0',
  'POLYLINE',
  '8',
  '0',
  '66',
  '1',
  '70',
  '0',
  '0',
  'VERTEX',
  '8',
  '0',
  '10',
  '100',
  '30',
  '0',
  '70',
  '0',
  '0',
  'VERTEX',
  '8',
  '0',
  '10',
  '200',
  '20',
  '200',
  '30',
  '0',
  '70',
  '0',
  '0',
  'SEQEND',
  '8',
  '0',
  '0',
  'ENDSEC',
  '0',
  'EOF',
].join('\n');
