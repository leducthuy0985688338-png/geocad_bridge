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
