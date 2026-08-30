import 'package:flutter_test/flutter_test.dart';

import 'package:autocad_googleearth/models/map_feature.dart';
import 'package:autocad_googleearth/services/kml_parser_service.dart';

void main() {
  const service = KmlParserService();

  test('parses KML Point', () {
    const kml = '''
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <Placemark>
      <name>Điểm A</name>
      <description>Điểm thử</description>
      <Point>
        <coordinates>106.0,16.0,25.5</coordinates>
      </Point>
    </Placemark>
  </Document>
</kml>
''';

    final result = service.parseString(kml);

    expect(result.placemarkCount, 1);
    expect(result.pointCount, 1);
    expect(result.features.length, 1);

    final feature = result.features.single;

    expect(feature.type, MapFeatureType.point);
    expect(feature.name, 'Điểm A');
    expect(feature.description, 'Điểm thử');
    expect(feature.coordinates.single.x, 106.0);
    expect(feature.coordinates.single.y, 16.0);
    expect(feature.coordinates.single.z, 25.5);
  });

  test('parses LineString and ExtendedData', () {
    const kml = '''
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <Placemark>
      <name>Tuyến 1</name>
      <ExtendedData>
        <Data name="code"><value>L01</value></Data>
      </ExtendedData>
      <LineString>
        <coordinates>
          106.0,16.0,0
          106.1,16.1,10
          106.2,16.2,20
        </coordinates>
      </LineString>
    </Placemark>
  </Document>
</kml>
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
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <Placemark>
      <name>Thửa đất</name>
      <Polygon>
        <outerBoundaryIs>
          <LinearRing>
            <coordinates>
              106.0,16.0,0
              106.1,16.0,0
              106.1,16.1,0
              106.0,16.1,0
              106.0,16.0,0
            </coordinates>
          </LinearRing>
        </outerBoundaryIs>
      </Polygon>
    </Placemark>
  </Document>
</kml>
''';

    final result = service.parseString(kml);
    final feature = result.features.single;

    expect(result.polygonCount, 1);
    expect(feature.type, MapFeatureType.polygon);
    expect(feature.coordinates.length, 5);
  });

  test('parses MultiGeometry into separate features', () {
    const kml = '''
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <Placemark>
      <name>Nhóm đối tượng</name>
      <MultiGeometry>
        <Point>
          <coordinates>106.0,16.0,0</coordinates>
        </Point>
        <LineString>
          <coordinates>
            106.0,16.0,0
            106.2,16.2,0
          </coordinates>
        </LineString>
      </MultiGeometry>
    </Placemark>
  </Document>
</kml>
''';

    final result = service.parseString(kml);

    expect(result.placemarkCount, 1);
    expect(result.pointCount, 1);
    expect(result.lineStringCount, 1);
    expect(result.features.length, 2);
  });

  group('strict coordinate validation', () {
    test('rejects malformed tuple without partially importing geometry', () {
      const kml = '''
<kml><Placemark><name>Tuyến lỗi</name><LineString><coordinates>
106,16,0 invalid 106.2,16.2,0
</coordinates></LineString></Placemark></kml>
''';

      expect(
        () => service.parseString(kml),
        throwsA(
          isA<FormatException>()
              .having(
                (error) => error.message,
                'message',
                contains('Tuyến lỗi'),
              )
              .having((error) => error.message, 'message', contains('#2')),
        ),
      );
    });

    test('rejects non-finite longitude, latitude, and altitude', () {
      for (final tuple in const [
        'NaN,16',
        '106,Infinity',
        '106,16,-Infinity',
      ]) {
        final kml =
            '<kml><Placemark><Point><coordinates>$tuple</coordinates>'
            '</Point></Placemark></kml>';

        expect(() => service.parseString(kml), throwsFormatException);
      }
    });

    test('rejects coordinates outside WGS84 bounds', () {
      for (final tuple in const [
        '180.1,16',
        '-180.1,16',
        '106,90.1',
        '106,-90.1',
      ]) {
        final kml =
            '<kml><Placemark><Point><coordinates>$tuple</coordinates>'
            '</Point></Placemark></kml>';

        expect(() => service.parseString(kml), throwsFormatException);
      }
    });

    test('rejects Point and LineString with insufficient coordinates', () {
      const point =
          '<kml><Placemark><Point><coordinates>106,16 107,17</coordinates>'
          '</Point></Placemark></kml>';
      const line =
          '<kml><Placemark><LineString><coordinates>106,16</coordinates>'
          '</LineString></Placemark></kml>';

      expect(() => service.parseString(point), throwsFormatException);
      expect(() => service.parseString(line), throwsFormatException);
    });

    test('rejects Polygon with incomplete outer ring', () {
      const kml = '''
<kml><Placemark><Polygon><outerBoundaryIs><LinearRing><coordinates>
106,16 107,17
</coordinates></LinearRing></outerBoundaryIs></Polygon></Placemark></kml>
''';

      expect(() => service.parseString(kml), throwsFormatException);
    });

    test('rejects Polygon inner boundary instead of silently dropping it', () {
      const kml = '''
<kml><Placemark><name>Có lỗ</name><Polygon>
<outerBoundaryIs><LinearRing><coordinates>
106,16 107,16 107,17 106,16
</coordinates></LinearRing></outerBoundaryIs>
<innerBoundaryIs><LinearRing><coordinates>
106.2,16.2 106.3,16.2 106.2,16.3 106.2,16.2
</coordinates></LinearRing></innerBoundaryIs>
</Polygon></Placemark></kml>
''';

      expect(
        () => service.parseString(kml),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('innerBoundaryIs'),
          ),
        ),
      );
    });
  });
}
