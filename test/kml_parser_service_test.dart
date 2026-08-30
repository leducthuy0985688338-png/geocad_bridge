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
}
