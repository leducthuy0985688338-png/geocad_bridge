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
}
