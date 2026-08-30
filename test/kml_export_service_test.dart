import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

import 'package:autocad_googleearth/models/coordinate_reference_system.dart';
import 'package:autocad_googleearth/models/map_feature.dart';
import 'package:autocad_googleearth/models/map_layer.dart';
import 'package:autocad_googleearth/services/kml_export_service.dart';

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
