import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

import 'package:autocad_googleearth/models/coordinate_reference_system.dart';
import 'package:autocad_googleearth/models/map_feature.dart';
import 'package:autocad_googleearth/models/map_layer.dart';
import 'package:autocad_googleearth/services/kml_export_service.dart';
import 'package:autocad_googleearth/services/kml_parser_service.dart';

void main() {
  const service = KmlExportService();

  MapLayer wgs84Layer({
    String name = 'Layer kiểm tra',
    required List<MapFeature> features,
  }) {
    return MapLayer(
      id: 'layer-1',
      name: name,
      sourceType: MapLayerSourceType.dxf,
      crs: const CoordinateReferenceSystem.wgs84(),
      features: features,
    );
  }

  XmlDocument exportFeature(MapFeature feature) {
    final content = service.exportLayers(
      documentName: 'GeoCAD Bridge',
      layers: [
        wgs84Layer(features: [feature]),
      ],
    );

    return XmlDocument.parse(content);
  }

  test('exports Point with longitude latitude order and altitude', () {
    final document = exportFeature(
      const MapFeature(
        id: 'point-1',
        type: MapFeatureType.point,
        name: 'Điểm A',
        coordinates: [MapCoordinate(x: 106.25, y: 16.5, z: 25.75)],
      ),
    );

    final point = document.findAllElements('Point').single;

    expect(
      point.findElements('coordinates').single.innerText,
      '106.250000000000,16.5000000000000,25.7500000000000',
    );
    expect(point.findElements('altitudeMode').single.innerText, 'absolute');
  });

  test('exports Polyline as KML LineString', () {
    final document = exportFeature(
      const MapFeature(
        id: 'polyline-1',
        type: MapFeatureType.polyline,
        name: 'Tuyến 1',
        coordinates: [
          MapCoordinate(x: 106, y: 16),
          MapCoordinate(x: 106.1, y: 16.1),
          MapCoordinate(x: 106.2, y: 16.2),
        ],
      ),
    );

    final lineString = document.findAllElements('LineString').single;
    final tuples = lineString
        .findElements('coordinates')
        .single
        .innerText
        .split(' ');

    expect(tuples, hasLength(3));
    expect(tuples.first, '106.000000000000,16.0000000000000,0');
    expect(tuples.last, '106.200000000000,16.2000000000000,0');
  });

  test('exports Polygon and closes its outer ring', () {
    final document = exportFeature(
      const MapFeature(
        id: 'polygon-1',
        type: MapFeatureType.polygon,
        name: 'Thửa đất',
        coordinates: [
          MapCoordinate(x: 106, y: 16),
          MapCoordinate(x: 106.1, y: 16),
          MapCoordinate(x: 106.1, y: 16.1),
        ],
      ),
    );

    final coordinates = document
        .findAllElements('LinearRing')
        .single
        .findElements('coordinates')
        .single
        .innerText
        .split(' ');

    expect(coordinates, hasLength(4));
    expect(coordinates.last, coordinates.first);
  });

  test('escapes XML in names descriptions and properties', () {
    const feature = MapFeature(
      id: 'point-escape',
      type: MapFeatureType.point,
      name: 'A & B <C>',
      description: 'Mô tả "đặc biệt" & kiểm tra',
      properties: {'code&name': '<P&1>'},
      coordinates: [MapCoordinate(x: 106, y: 16)],
    );

    final content = service.exportLayers(
      documentName: 'Dự án & bản đồ',
      layers: [
        wgs84Layer(features: const [feature]),
      ],
    );
    final document = XmlDocument.parse(content);
    final placemark = document.findAllElements('Placemark').single;

    expect(content, contains('A &amp; B &lt;C>'));
    expect(placemark.findElements('name').single.innerText, feature.name);
    expect(
      placemark.findElements('description').single.innerText,
      feature.description,
    );
    expect(placemark.findAllElements('value').single.innerText, '<P&1>');
  });

  test('exports each layer as a named Folder', () {
    final content = service.exportLayers(
      documentName: 'GeoCAD Bridge',
      layers: [
        wgs84Layer(
          name: 'CAD Layer A',
          features: const [
            MapFeature(
              id: 'point-folder',
              type: MapFeatureType.point,
              coordinates: [MapCoordinate(x: 106, y: 16)],
            ),
          ],
        ),
      ],
    );
    final document = XmlDocument.parse(content);
    final folder = document.findAllElements('Folder').single;

    expect(folder.findElements('name').single.innerText, 'CAD Layer A');
  });

  test('exports Text feature as a named Point Placemark', () {
    final document = exportFeature(
      const MapFeature(
        id: 'text-1',
        type: MapFeatureType.text,
        name: 'Ghi chú hiện trường',
        coordinates: [MapCoordinate(x: 106, y: 16, z: 2)],
      ),
    );

    final placemark = document.findAllElements('Placemark').single;

    expect(
      placemark.findElements('name').single.innerText,
      'Ghi chú hiện trường',
    );
    expect(placemark.findElements('Point'), hasLength(1));
  });

  test('preserves imported KML altitudeMode when exporting', () {
    const modes = ['clampToGround', 'relativeToGround', 'absolute'];

    for (final mode in modes) {
      final document = exportFeature(
        MapFeature(
          id: 'altitude-$mode',
          type: MapFeatureType.point,
          name: 'Altitude $mode',
          properties: {'kmlAltitudeMode': mode},
          coordinates: const [MapCoordinate(x: 106, y: 16, z: 25)],
        ),
      );

      final point = document.findAllElements('Point').single;

      expect(
        point.findElements('altitudeMode').single.innerText,
        mode,
        reason: 'KML altitudeMode phải được bảo toàn khi round-trip.',
      );
    }
  });

  test('round trips altitudeMode through parser exporter and parser', () {
    const source = '''
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <Placemark>
      <name>Điểm độ cao</name>
      <description>Kiểm tra round-trip</description>
      <ExtendedData>
        <Data name="code"><value>P01</value></Data>
      </ExtendedData>
      <Point>
        <altitudeMode>relativeToGround</altitudeMode>
        <coordinates>106.25,16.5,25.75</coordinates>
      </Point>
    </Placemark>
  </Document>
</kml>
''';

    const parser = KmlParserService();
    final imported = parser.parseString(source);

    final layer = wgs84Layer(features: imported.features);

    final exported = service.exportLayers(
      documentName: 'Round-trip',
      layers: [layer],
    );

    final reparsed = parser.parseString(exported);
    final feature = reparsed.features.single;

    expect(feature.name, 'Điểm độ cao');
    expect(feature.description, 'Kiểm tra round-trip');
    expect(feature.properties['code'], 'P01');
    expect(feature.properties['kmlAltitudeMode'], 'relativeToGround');
    expect(feature.coordinates.single.x, 106.25);
    expect(feature.coordinates.single.y, 16.5);
    expect(feature.coordinates.single.z, 25.75);
    expect(reparsed.diagnostics.hasIssues, isFalse);
  });
  test('does not expose GeoCAD internal KML metadata as ExtendedData', () {
    const feature = MapFeature(
      id: 'internal-metadata',
      type: MapFeatureType.point,
      name: 'Điểm metadata',
      properties: {
        'code': 'P01',
        'owner': 'Người dùng',
        'kmlGeometry': 'Point',
        'kmlFromMultiGeometry': 'true',
        'kmlAltitudeMode': 'relativeToGround',
      },
      coordinates: [MapCoordinate(x: 106.25, y: 16.5, z: 25)],
    );

    final document = exportFeature(feature);
    final placemark = document.findAllElements('Placemark').single;

    final data = placemark
        .findAllElements('Data')
        .map((element) => element.getAttribute('name'))
        .toList();

    expect(data, containsAll(['code', 'owner']));
    expect(data, isNot(contains('kmlGeometry')));
    expect(data, isNot(contains('kmlFromMultiGeometry')));
    expect(data, isNot(contains('kmlAltitudeMode')));

    expect(
      placemark.findAllElements('altitudeMode').single.innerText,
      'relativeToGround',
    );
  });
  test('round trips Vietnamese Lao and English Unicode metadata', () {
    const features = [
      MapFeature(
        id: 'vi',
        type: MapFeatureType.point,
        name: 'Tiếng Việt – Đường thử nghiệm',
        description: 'Mô tả tiếng Việt',
        properties: {'label': 'Nhãn tiếng Việt – Đắk Lắk'},
        coordinates: [MapCoordinate(x: 106, y: 16)],
      ),
      MapFeature(
        id: 'lo',
        type: MapFeatureType.point,
        name: 'ພາສາລາວ – ທົດສອບ',
        description: 'ຄຳອະທິບາຍພາສາລາວ',
        properties: {'label': 'ຂໍ້ມູນພາສາລາວ'},
        coordinates: [MapCoordinate(x: 107, y: 17)],
      ),
      MapFeature(
        id: 'en',
        type: MapFeatureType.point,
        name: 'English – Test feature',
        description: 'English description',
        properties: {'label': 'English metadata'},
        coordinates: [MapCoordinate(x: 108, y: 18)],
      ),
    ];

    final bytes = service.exportLayersAsBytes(
      documentName: 'Việt Nam – ລາວ – English',
      layers: [wgs84Layer(features: features)],
    );

    final exported = utf8.decode(bytes);
    const parser = KmlParserService();
    final reparsed = parser.parseString(exported);

    expect(reparsed.features.map((feature) => feature.name), [
      'Tiếng Việt – Đường thử nghiệm',
      'ພາສາລາວ – ທົດສອບ',
      'English – Test feature',
    ]);

    expect(reparsed.features.map((feature) => feature.description), [
      'Mô tả tiếng Việt',
      'ຄຳອະທິບາຍພາສາລາວ',
      'English description',
    ]);

    expect(reparsed.features.map((feature) => feature.properties['label']), [
      'Nhãn tiếng Việt – Đắk Lắk',
      'ຂໍ້ມູນພາສາລາວ',
      'English metadata',
    ]);

    expect(reparsed.diagnostics.parsedGeometryCount, 3);
    expect(reparsed.diagnostics.hasIssues, isFalse);
  });
  group('KML inline style export and round-trip', () {
    test('exports LineStyle and reparses canonical stroke style', () {
      const feature = MapFeature(
        id: 'styled-line',
        type: MapFeatureType.polyline,
        name: 'Tuyến màu',
        properties: {
          'style.strokeColor': '#112233',
          'style.strokeOpacity': '0.5',
          'style.strokeWidth': '2.5',
        },
        coordinates: [
          MapCoordinate(x: 106, y: 16),
          MapCoordinate(x: 107, y: 17),
        ],
      );

      final document = exportFeature(feature);
      final lineStyle = document.findAllElements('LineStyle').single;

      expect(lineStyle.findElements('color').single.innerText, '80332211');
      expect(lineStyle.findElements('width').single.innerText, '2.5');

      final exported = document.toXmlString();
      final reparsed = const KmlParserService().parseString(exported);
      final properties = reparsed.features.single.properties;

      expect(properties['style.strokeColor'], '#112233');
      expect(properties['style.strokeOpacity'], '0.501961');
      expect(properties['style.strokeWidth'], '2.5');
    });

    test('exports PolyStyle alpha fill outline and reparses it', () {
      const feature = MapFeature(
        id: 'styled-polygon',
        type: MapFeatureType.polygon,
        name: 'Vùng màu',
        properties: {
          'style.fillColor': '#00FF00',
          'style.fillOpacity': '0.25',
          'style.fill': '0',
          'style.outline': '1',
        },
        coordinates: [
          MapCoordinate(x: 106, y: 16),
          MapCoordinate(x: 107, y: 16),
          MapCoordinate(x: 107, y: 17),
        ],
      );

      final document = exportFeature(feature);
      final polyStyle = document.findAllElements('PolyStyle').single;

      expect(polyStyle.findElements('color').single.innerText, '4000ff00');
      expect(polyStyle.findElements('fill').single.innerText, '0');
      expect(polyStyle.findElements('outline').single.innerText, '1');

      final reparsed = const KmlParserService().parseString(
        document.toXmlString(),
      );
      final properties = reparsed.features.single.properties;

      expect(properties['style.fillColor'], '#00FF00');
      expect(properties['style.fillOpacity'], '0.25098');
      expect(properties['style.fill'], '0');
      expect(properties['style.outline'], '1');
    });

    test('preserves styleUrl without resolving shared styles', () {
      const feature = MapFeature(
        id: 'style-url',
        type: MapFeatureType.point,
        name: 'Điểm styleUrl',
        properties: {'kml.styleUrl': '#shared-style'},
        coordinates: [MapCoordinate(x: 106, y: 16)],
      );

      final document = exportFeature(feature);
      final placemark = document.findAllElements('Placemark').single;

      expect(
        placemark.findElements('styleUrl').single.innerText,
        '#shared-style',
      );

      final reparsed = const KmlParserService().parseString(
        document.toXmlString(),
      );
      expect(
        reparsed.features.single.properties['kml.styleUrl'],
        '#shared-style',
      );
    });

    test('shared-style import exports resolved visual style inline', () {
      const source = '''
<kml><Document>
<Style id="road"><LineStyle><color>800000ff</color><width>2</width></LineStyle></Style>
<Placemark><styleUrl>#road</styleUrl><LineString><coordinates>106,16 107,17</coordinates></LineString></Placemark>
</Document></kml>
''';
      final imported = const KmlParserService().parseString(source);

      final document = exportFeature(imported.features.single);
      final placemark = document.findAllElements('Placemark').single;
      final lineStyle = placemark.findAllElements('LineStyle').single;

      expect(placemark.findElements('styleUrl').single.innerText, '#road');
      expect(lineStyle.findElements('color').single.innerText, '800000ff');
      expect(lineStyle.findElements('width').single.innerText, '2');
      expect(document.findAllElements('Style').length, 1);
      expect(
        document.findAllElements('Style').single.getAttribute('id'),
        isNull,
      );
    });

    test('does not expose style keys as ExtendedData and preserves Unicode metadata', () {
      const feature = MapFeature(
        id: 'style-metadata',
        type: MapFeatureType.polyline,
        name: 'Việt Nam – ລາວ – English',
        properties: {
          'owner': 'Đội khảo sát – ທີມສຳຫຼວດ – Survey Team',
          'style.strokeColor': '#FF0000',
          'style.strokeOpacity': '1',
          'style.strokeWidth': '3',
          'kml.styleUrl': '#line-style',
        },
        coordinates: [
          MapCoordinate(x: 106, y: 16),
          MapCoordinate(x: 107, y: 17),
        ],
      );

      final document = exportFeature(feature);
      final placemark = document.findAllElements('Placemark').single;
      final dataNames = placemark
          .findAllElements('Data')
          .map((element) => element.getAttribute('name'))
          .toList();

      expect(dataNames, ['owner']);
      expect(
        placemark.findAllElements('value').single.innerText,
        'Đội khảo sát – ທີມສຳຫຼວດ – Survey Team',
      );

      final reparsed = const KmlParserService().parseString(
        document.toXmlString(),
      );
      final properties = reparsed.features.single.properties;

      expect(properties['owner'], 'Đội khảo sát – ທີມສຳຫຼວດ – Survey Team');
      expect(properties['style.strokeColor'], '#FF0000');
      expect(properties['style.strokeOpacity'], '1');
      expect(properties['style.strokeWidth'], '3');
      expect(properties['kml.styleUrl'], '#line-style');
    });
  });

  test('rejects layers that are not WGS84', () {
    const localLayer = MapLayer(
      id: 'local-layer',
      name: 'DXF cục bộ',
      sourceType: MapLayerSourceType.dxf,
      features: [
        MapFeature(
          id: 'point-local',
          type: MapFeatureType.point,
          coordinates: [MapCoordinate(x: 500000, y: 1800000)],
        ),
      ],
    );

    expect(
      () => service.exportLayers(
        documentName: 'GeoCAD Bridge',
        layers: const [localLayer],
      ),
      throwsA(
        isA<KmlExportException>().having(
          (error) => error.message,
          'message',
          contains('DXF cục bộ'),
        ),
      ),
    );
  });
}
