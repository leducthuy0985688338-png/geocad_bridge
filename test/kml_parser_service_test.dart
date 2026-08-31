import 'package:flutter_test/flutter_test.dart';

import 'package:autocad_googleearth/models/map_feature.dart';
import 'package:autocad_googleearth/services/kml_parser_service.dart';

void main() {
  const service = KmlParserService();

  test('parses KML Point', () {
    const kml = '''
<kml xmlns="http://www.opengis.net/kml/2.2"><Document><Placemark>
<name>Điểm A</name><description>Điểm thử</description>
<Point><coordinates>106.0,16.0,25.5</coordinates></Point>
</Placemark></Document></kml>
''';

    final result = service.parseString(kml);
    final feature = result.features.single;

    expect(result.placemarkCount, 1);
    expect(result.pointCount, 1);
    expect(feature.type, MapFeatureType.point);
    expect(feature.name, 'Điểm A');
    expect(feature.description, 'Điểm thử');
    expect(feature.coordinates.single.x, 106.0);
    expect(feature.coordinates.single.y, 16.0);
    expect(feature.coordinates.single.z, 25.5);
    expect(result.diagnostics.totalGeometryCount, 1);
    expect(result.diagnostics.parsedGeometryCount, 1);
    expect(result.diagnostics.hasIssues, isFalse);
  });

  test('parses LineString and ExtendedData', () {
    const kml = '''
<kml><Placemark><name>Tuyến 1</name><ExtendedData>
<Data name="code"><value>L01</value></Data></ExtendedData>
<LineString><coordinates>106,16,0 106.1,16.1,10 106.2,16.2,20</coordinates></LineString>
</Placemark></kml>
''';

    final result = service.parseString(kml);
    final feature = result.features.single;

    expect(result.lineStringCount, 1);
    expect(feature.type, MapFeatureType.polyline);
    expect(feature.coordinates.length, 3);
    expect(feature.properties['code'], 'L01');
    expect(feature.properties['kmlGeometry'], 'LineString');
  });

  test('parses Polygon outer boundary', () {
    const kml = '''
<kml><Placemark><name>Thửa đất</name><Polygon><outerBoundaryIs><LinearRing>
<coordinates>106,16,0 106.1,16,0 106.1,16.1,0 106,16.1,0 106,16,0</coordinates>
</LinearRing></outerBoundaryIs></Polygon></Placemark></kml>
''';

    final result = service.parseString(kml);
    final feature = result.features.single;

    expect(result.polygonCount, 1);
    expect(feature.type, MapFeatureType.polygon);
    expect(feature.coordinates.length, 5);
  });

  test('isolates malformed geometry and preserves valid geometries', () {
    const kml = '''
<kml><Document>
<Placemark><name>A</name><Point><coordinates>106,16</coordinates></Point></Placemark>
<Placemark><name>B</name><LineString><coordinates>106,16 invalid</coordinates></LineString></Placemark>
<Placemark><name>C</name><Polygon><outerBoundaryIs><LinearRing>
<coordinates>106,16 107,16 107,17 106,16</coordinates>
</LinearRing></outerBoundaryIs></Polygon></Placemark>
</Document></kml>
''';

    final result = service.parseString(kml);

    expect(result.features.map((feature) => feature.name), ['A', 'C']);
    expect(result.diagnostics.totalGeometryCount, 3);
    expect(result.diagnostics.parsedGeometryCount, 2);
    expect(result.diagnostics.malformedGeometryCount, 1);
    expect(result.diagnostics.unsupportedGeometryCount, 0);
    expect(
      result.diagnostics.issues.single.code,
      KmlDiagnosticCode.malformedGeometry,
    );
    expect(result.diagnostics.issues.single.geometryType, 'LineString');
  });

  test('skips unsupported Model with explicit diagnostic', () {
    const kml = '''
<kml><Placemark><name>Model A</name><Model><Location/></Model></Placemark></kml>
''';

    final result = service.parseString(kml);

    expect(result.features, isEmpty);
    expect(result.diagnostics.totalGeometryCount, 1);
    expect(result.diagnostics.unsupportedGeometryCount, 1);
    expect(result.diagnostics.unsupportedGeometryCounts, {'Model': 1});
    expect(
      result.diagnostics.issues.single.code,
      KmlDiagnosticCode.unsupportedGeometry,
    );
  });

  test('flattens MultiGeometry in document order without double counting', () {
    const kml = '''
<kml><Placemark><name>Nhóm</name><MultiGeometry>
<Point><coordinates>106,16</coordinates></Point>
<LineString><coordinates>106,16 107,17</coordinates></LineString>
<Polygon><outerBoundaryIs><LinearRing><coordinates>
106,16 107,16 107,17 106,16
</coordinates></LinearRing></outerBoundaryIs></Polygon>
</MultiGeometry></Placemark></kml>
''';

    final result = service.parseString(kml);

    expect(result.features.length, 3);
    expect(result.features.map((feature) => feature.type), [
      MapFeatureType.point,
      MapFeatureType.polyline,
      MapFeatureType.polygon,
    ]);
    expect(
      result.features.every(
        (feature) => feature.properties['kmlFromMultiGeometry'] == 'true',
      ),
      isTrue,
    );
    expect(result.diagnostics.totalGeometryCount, 3);
    expect(result.diagnostics.parsedGeometryCount, 3);
  });

  test('MultiGeometry preserves valid children around malformed and unsupported children', () {
    const kml = '''
<kml><Placemark><name>Mixed</name><MultiGeometry>
<Point><coordinates>106,16</coordinates></Point>
<LineString><coordinates>106,16 bad</coordinates></LineString>
<Model><Location/></Model>
<Point><coordinates>107,17</coordinates></Point>
</MultiGeometry></Placemark></kml>
''';

    final result = service.parseString(kml);

    expect(result.features.length, 2);
    expect(result.features.map((feature) => feature.coordinates.single.x), [
      106,
      107,
    ]);
    expect(result.diagnostics.totalGeometryCount, 4);
    expect(result.diagnostics.parsedGeometryCount, 2);
    expect(result.diagnostics.malformedGeometryCount, 1);
    expect(result.diagnostics.unsupportedGeometryCount, 1);
    expect(result.diagnostics.issues.map((issue) => issue.code), [
      KmlDiagnosticCode.malformedGeometry,
      KmlDiagnosticCode.unsupportedGeometry,
    ]);
  });

  test('skips polygon holes as unsupported fidelity without aborting file', () {
    const kml = '''
<kml><Document>
<Placemark><name>Có lỗ</name><Polygon>
<outerBoundaryIs><LinearRing><coordinates>106,16 107,16 107,17 106,16</coordinates></LinearRing></outerBoundaryIs>
<innerBoundaryIs><LinearRing><coordinates>106.2,16.2 106.3,16.2 106.2,16.3 106.2,16.2</coordinates></LinearRing></innerBoundaryIs>
</Polygon></Placemark>
<Placemark><name>Điểm còn lại</name><Point><coordinates>106,16</coordinates></Point></Placemark>
</Document></kml>
''';

    final result = service.parseString(kml);

    expect(result.features.single.name, 'Điểm còn lại');
    expect(result.diagnostics.totalGeometryCount, 2);
    expect(result.diagnostics.parsedGeometryCount, 1);
    expect(result.diagnostics.unsupportedGeometryCount, 1);
    expect(result.diagnostics.unsupportedGeometryCounts, {'Polygon': 1});
    expect(
      result.diagnostics.issues.single.code,
      KmlDiagnosticCode.fidelityWarning,
    );
    expect(result.diagnostics.hasFidelityWarnings, isTrue);
  });

  group('strict coordinate validation with geometry isolation', () {
    test('diagnoses malformed tuple without partially importing geometry', () {
      const kml = '''
<kml><Placemark><name>Tuyến lỗi</name><LineString><coordinates>
106,16,0 invalid 106.2,16.2,0
</coordinates></LineString></Placemark></kml>
''';

      final result = service.parseString(kml);
      expect(result.features, isEmpty);
      expect(result.diagnostics.malformedGeometryCount, 1);
      expect(result.diagnostics.issues.single.message, contains('Tuyến lỗi'));
      expect(result.diagnostics.issues.single.message, contains('#2'));
    });

    test('diagnoses non-finite longitude, latitude, and altitude', () {
      for (final tuple in const [
        'NaN,16',
        '106,Infinity',
        '106,16,-Infinity',
      ]) {
        final result = service.parseString(
          '<kml><Placemark><Point><coordinates>$tuple</coordinates></Point></Placemark></kml>',
        );
        expect(result.features, isEmpty);
        expect(result.diagnostics.malformedGeometryCount, 1);
      }
    });

    test('diagnoses coordinates outside WGS84 bounds', () {
      for (final tuple in const [
        '180.1,16',
        '-180.1,16',
        '106,90.1',
        '106,-90.1',
      ]) {
        final result = service.parseString(
          '<kml><Placemark><Point><coordinates>$tuple</coordinates></Point></Placemark></kml>',
        );
        expect(result.features, isEmpty);
        expect(result.diagnostics.malformedGeometryCount, 1);
      }
    });

    test('diagnoses insufficient Point and LineString coordinates', () {
      for (final geometry in const [
        '<Point><coordinates>106,16 107,17</coordinates></Point>',
        '<LineString><coordinates>106,16</coordinates></LineString>',
      ]) {
        final result = service.parseString(
          '<kml><Placemark>$geometry</Placemark></kml>',
        );
        expect(result.features, isEmpty);
        expect(result.diagnostics.malformedGeometryCount, 1);
      }
    });

    test('diagnoses degenerate or open Polygon outer rings', () {
      for (final coordinates in const [
        '106,16 107,17',
        '106,16 107,16 107,17 106,17',
        '106,16 107,16 106,16 106,16',
      ]) {
        final result = service.parseString('''
<kml><Placemark><Polygon><outerBoundaryIs><LinearRing>
<coordinates>$coordinates</coordinates>
</LinearRing></outerBoundaryIs></Polygon></Placemark></kml>
''');
        expect(result.features, isEmpty);
        expect(result.diagnostics.malformedGeometryCount, 1);
      }
    });
  });

  test('preserves standard altitudeMode in feature properties', () {
    for (final mode in const [
      'clampToGround',
      'relativeToGround',
      'absolute',
    ]) {
      final result = service.parseString('''
<kml><Placemark><Point><altitudeMode>$mode</altitudeMode>
<coordinates>106,16,25</coordinates></Point></Placemark></kml>
''');
      expect(result.features.single.properties['kmlAltitudeMode'], mode);
      expect(result.diagnostics.hasFidelityWarnings, isFalse);
    }
  });

  test('preserves unknown altitudeMode and emits fidelity warning', () {
    const kml = '''
<kml><Placemark><Point><altitudeMode>clampToSeaFloor</altitudeMode>
<coordinates>106,16,25</coordinates></Point></Placemark></kml>
''';

    final result = service.parseString(kml);

    expect(
      result.features.single.properties['kmlAltitudeMode'],
      'clampToSeaFloor',
    );
    expect(result.diagnostics.parsedGeometryCount, 1);
    expect(
      result.diagnostics.issues.single.code,
      KmlDiagnosticCode.fidelityWarning,
    );
  });

  test('does not emit altitude fidelity warning for malformed geometry', () {
    const kml = '''
<kml><Placemark><Point>
<altitudeMode>clampToSeaFloor</altitudeMode>
<coordinates>bad</coordinates>
</Point></Placemark></kml>
''';

    final result = service.parseString(kml);

    expect(result.features, isEmpty);
    expect(result.diagnostics.totalGeometryCount, 1);
    expect(result.diagnostics.parsedGeometryCount, 0);
    expect(result.diagnostics.malformedGeometryCount, 1);
    expect(result.diagnostics.unsupportedGeometryCount, 0);
    expect(result.diagnostics.hasFidelityWarnings, isFalse);
    expect(result.diagnostics.issues.length, 1);
    expect(
      result.diagnostics.issues.single.code,
      KmlDiagnosticCode.malformedGeometry,
    );
  });

  test('diagnostics invariant holds for parsed malformed and unsupported geometries', () {
    const kml = '''
<kml><Placemark><MultiGeometry>
<Point><coordinates>106,16</coordinates></Point>
<LineString><coordinates>bad</coordinates></LineString>
<Model/>
</MultiGeometry></Placemark></kml>
''';

    final diagnostics = service.parseString(kml).diagnostics;
    expect(
      diagnostics.totalGeometryCount,
      diagnostics.parsedGeometryCount +
          diagnostics.malformedGeometryCount +
          diagnostics.unsupportedGeometryCount,
    );
  });

  test('result and diagnostics collections are unmodifiable', () {
    const kml = '''
<kml><Placemark><Point><coordinates>106,16</coordinates></Point><Model/></Placemark></kml>
''';
    final result = service.parseString(kml);

    expect(
      () => result.features.add(result.features.single),
      throwsUnsupportedError,
    );
    expect(() => result.diagnostics.issues.clear(), throwsUnsupportedError);
    expect(
      () => result.diagnostics.unsupportedGeometryCounts['Other'] = 1,
      throwsUnsupportedError,
    );
  });

  test('preserves Vietnamese Lao and English Unicode metadata', () {
    const kml = '''
<kml><Document>
<Placemark>
<name>Tiếng Việt – Đường thử nghiệm</name>
<description>Mô tả tiếng Việt</description>
<ExtendedData><Data name="label"><value>Tiếng Việt – Đường thử nghiệm</value></Data></ExtendedData>
<Point><coordinates>106,16</coordinates></Point>
</Placemark>
<Placemark>
<name>ພາສາລາວ – ທົດສອບ</name>
<description>ຄຳອະທິບາຍພາສາລາວ</description>
<ExtendedData><Data name="label"><value>ພາສາລາວ – ທົດສອບ</value></Data></ExtendedData>
<Point><coordinates>107,17</coordinates></Point>
</Placemark>
<Placemark>
<name>English – Test feature</name>
<description>English description</description>
<ExtendedData><Data name="label"><value>English – Test feature</value></Data></ExtendedData>
<Point><coordinates>108,18</coordinates></Point>
</Placemark>
</Document></kml>
''';

    final result = service.parseString(kml);

    expect(result.features.map((feature) => feature.name), [
      'Tiếng Việt – Đường thử nghiệm',
      'ພາສາລາວ – ທົດສອບ',
      'English – Test feature',
    ]);
    expect(result.features.map((feature) => feature.description), [
      'Mô tả tiếng Việt',
      'ຄຳອະທິບາຍພາສາລາວ',
      'English description',
    ]);
    expect(result.features.map((feature) => feature.properties['label']), [
      'Tiếng Việt – Đường thử nghiệm',
      'ພາສາລາວ – ທົດສອບ',
      'English – Test feature',
    ]);
    expect(result.diagnostics.parsedGeometryCount, 3);
    expect(result.diagnostics.hasIssues, isFalse);
  });

  group('KML inline style parsing', () {
    test('parses LineStyle color opacity width and styleUrl', () {
      const kml = '''
<kml><Placemark>
<name>Tuyến style</name>
<styleUrl>#shared-line</styleUrl>
<Style><LineStyle><color>800000ff</color><width>2.5</width></LineStyle></Style>
<LineString><coordinates>106,16 107,17</coordinates></LineString>
</Placemark></kml>
''';

      final feature = service.parseString(kml).features.single;

      expect(feature.properties['kml.styleUrl'], '#shared-line');
      expect(feature.properties['style.strokeColor'], '#FF0000');
      expect(feature.properties['style.strokeOpacity'], '0.501961');
      expect(feature.properties['style.strokeWidth'], '2.5');
    });

    test('parses PolyStyle color alpha fill and outline', () {
      const kml = '''
<kml><Placemark>
<Style><PolyStyle><color>4000ff00</color><fill>0</fill><outline>1</outline></PolyStyle></Style>
<Polygon><outerBoundaryIs><LinearRing>
<coordinates>106,16 107,16 107,17 106,16</coordinates>
</LinearRing></outerBoundaryIs></Polygon>
</Placemark></kml>
''';

      final feature = service.parseString(kml).features.single;

      expect(feature.properties['style.fillColor'], '#00FF00');
      expect(feature.properties['style.fillOpacity'], '0.25098');
      expect(feature.properties['style.fill'], '0');
      expect(feature.properties['style.outline'], '1');
    });

    test('keeps inline style and Unicode user metadata separate', () {
      const kml = '''
<kml><Placemark>
<name>Việt Nam – ລາວ – English</name>
<ExtendedData><Data name="owner"><value>Đội khảo sát – ທີມສຳຫຼວດ – Survey Team</value></Data></ExtendedData>
<Style><LineStyle><color>ff332211</color><width>3</width></LineStyle></Style>
<LineString><coordinates>106,16 107,17</coordinates></LineString>
</Placemark></kml>
''';

      final feature = service.parseString(kml).features.single;

      expect(
        feature.properties['owner'],
        'Đội khảo sát – ທີມສຳຫຼວດ – Survey Team',
      );
      expect(feature.properties['style.strokeColor'], '#112233');
      expect(feature.properties['style.strokeOpacity'], '1');
      expect(feature.properties['style.strokeWidth'], '3');
    });
  });

  test('structurally invalid XML remains a whole-document failure', () {
    expect(
      () => service.parseString('<kml><Placemark>'),
      throwsFormatException,
    );
  });
}
