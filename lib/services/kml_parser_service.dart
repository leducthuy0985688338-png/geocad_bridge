import 'dart:convert';
import 'dart:io';

import 'package:xml/xml.dart';

import '../models/map_feature.dart';

class KmlParseResult {
  final List<MapFeature> features;
  final int placemarkCount;
  final int pointCount;
  final int lineStringCount;
  final int polygonCount;

  const KmlParseResult({
    required this.features,
    required this.placemarkCount,
    required this.pointCount,
    required this.lineStringCount,
    required this.polygonCount,
  });
}

class KmlParserService {
  const KmlParserService();

  Future<KmlParseResult> parseFile(String path) async {
    final file = File(path);

    if (!await file.exists()) {
      throw ArgumentError('Không tìm thấy file KML: $path');
    }

    final content = await file.readAsString(encoding: utf8);
    return parseString(content);
  }

  KmlParseResult parseString(String content) {
    XmlDocument document;

    try {
      document = XmlDocument.parse(content);
    } on XmlParserException catch (error) {
      throw FormatException('KML không hợp lệ: ${error.message}');
    }

    final features = <MapFeature>[];
    var placemarkCount = 0;
    var pointCount = 0;
    var lineStringCount = 0;
    var polygonCount = 0;
    var featureIndex = 0;

    final placemarks = document.descendants.whereType<XmlElement>().where(
      (element) => element.name.local == 'Placemark',
    );

    for (final placemark in placemarks) {
      placemarkCount++;

      final name = _firstChildText(placemark, 'name') ?? '';
      final description = _firstChildText(placemark, 'description');
      final properties = _readExtendedData(placemark);

      final geometries = placemark.descendants.whereType<XmlElement>().where((
        element,
      ) {
        final name = element.name.local;
        return name == 'Point' || name == 'LineString' || name == 'Polygon';
      });

      for (final geometry in geometries) {
        final localName = geometry.name.local;

        if (localName == 'Point') {
          final coordinates = _coordinatesFromGeometry(
            geometry,
            placemarkName: name,
            geometryType: localName,
          );

          if (coordinates.length != 1) {
            throw _geometryError(name, localName, 'phải có đúng 1 bộ tọa độ');
          }

          featureIndex++;
          pointCount++;

          features.add(
            MapFeature(
              id: 'kml-feature-$featureIndex',
              type: MapFeatureType.point,
              coordinates: [coordinates.first],
              name: name,
              description: description,
              properties: {...properties, 'kmlGeometry': 'Point'},
            ),
          );
        } else if (localName == 'LineString') {
          final coordinates = _coordinatesFromGeometry(
            geometry,
            placemarkName: name,
            geometryType: localName,
          );

          if (coordinates.length < 2) {
            throw _geometryError(
              name,
              localName,
              'phải có ít nhất 2 bộ tọa độ',
            );
          }

          featureIndex++;
          lineStringCount++;

          features.add(
            MapFeature(
              id: 'kml-feature-$featureIndex',
              type: MapFeatureType.polyline,
              coordinates: coordinates,
              name: name,
              description: description,
              properties: {...properties, 'kmlGeometry': 'LineString'},
            ),
          );
        } else if (localName == 'Polygon') {
          final hasInnerBoundary = geometry.descendants
              .whereType<XmlElement>()
              .any((element) => element.name.local == 'innerBoundaryIs');

          if (hasInnerBoundary) {
            throw _geometryError(
              name,
              localName,
              'chưa hỗ trợ innerBoundaryIs (polygon có lỗ)',
            );
          }

          final outerBoundary = _firstDescendant(geometry, 'outerBoundaryIs');

          if (outerBoundary == null) {
            throw _geometryError(name, localName, 'thiếu outerBoundaryIs');
          }

          final linearRing = _firstDescendant(outerBoundary, 'LinearRing');

          if (linearRing == null) {
            throw _geometryError(name, localName, 'thiếu LinearRing');
          }

          final coordinates = _coordinatesFromGeometry(
            linearRing,
            placemarkName: name,
            geometryType: localName,
          );

          if (coordinates.length < 3) {
            throw _geometryError(
              name,
              localName,
              'phải có ít nhất 3 bộ tọa độ',
            );
          }

          featureIndex++;
          polygonCount++;

          features.add(
            MapFeature(
              id: 'kml-feature-$featureIndex',
              type: MapFeatureType.polygon,
              coordinates: coordinates,
              name: name,
              description: description,
              properties: {...properties, 'kmlGeometry': 'Polygon'},
            ),
          );
        }
      }
    }

    return KmlParseResult(
      features: features,
      placemarkCount: placemarkCount,
      pointCount: pointCount,
      lineStringCount: lineStringCount,
      polygonCount: polygonCount,
    );
  }

  List<MapCoordinate> _coordinatesFromGeometry(
    XmlElement geometry, {
    required String placemarkName,
    required String geometryType,
  }) {
    final element = _firstDescendant(geometry, 'coordinates');

    if (element == null) {
      throw _geometryError(placemarkName, geometryType, 'thiếu coordinates');
    }

    return _parseCoordinates(
      element.innerText,
      placemarkName: placemarkName,
      geometryType: geometryType,
    );
  }

  List<MapCoordinate> _parseCoordinates(
    String raw, {
    required String placemarkName,
    required String geometryType,
  }) {
    final result = <MapCoordinate>[];

    final tuples = raw
        .trim()
        .split(RegExp(r'\s+'))
        .where((item) => item.trim().isNotEmpty);

    var tupleIndex = 0;
    for (final tuple in tuples) {
      tupleIndex++;
      final parts = tuple.split(',');

      if (parts.length < 2 || parts.length > 3) {
        throw _coordinateError(
          placemarkName,
          geometryType,
          tupleIndex,
          tuple,
          'phải có dạng longitude,latitude[,altitude]',
        );
      }

      final longitude = double.tryParse(parts[0].trim());
      final latitude = double.tryParse(parts[1].trim());

      if (longitude == null ||
          latitude == null ||
          !longitude.isFinite ||
          !latitude.isFinite) {
        throw _coordinateError(
          placemarkName,
          geometryType,
          tupleIndex,
          tuple,
          'longitude/latitude phải là số hữu hạn',
        );
      }

      if (longitude < -180 || longitude > 180) {
        throw _coordinateError(
          placemarkName,
          geometryType,
          tupleIndex,
          tuple,
          'longitude phải nằm trong [-180, 180]',
        );
      }

      if (latitude < -90 || latitude > 90) {
        throw _coordinateError(
          placemarkName,
          geometryType,
          tupleIndex,
          tuple,
          'latitude phải nằm trong [-90, 90]',
        );
      }

      double? altitude;

      if (parts.length >= 3 && parts[2].trim().isNotEmpty) {
        altitude = double.tryParse(parts[2].trim());
        if (altitude == null || !altitude.isFinite) {
          throw _coordinateError(
            placemarkName,
            geometryType,
            tupleIndex,
            tuple,
            'altitude phải là số hữu hạn',
          );
        }
      }

      result.add(MapCoordinate(x: longitude, y: latitude, z: altitude));
    }

    return result;
  }

  FormatException _geometryError(
    String placemarkName,
    String geometryType,
    String message,
  ) {
    final displayName = placemarkName.isEmpty ? '(không tên)' : placemarkName;
    return FormatException(
      'Placemark "$displayName", $geometryType: $message.',
    );
  }

  FormatException _coordinateError(
    String placemarkName,
    String geometryType,
    int tupleIndex,
    String tuple,
    String message,
  ) {
    return _geometryError(
      placemarkName,
      geometryType,
      'tọa độ #$tupleIndex "$tuple" không hợp lệ: $message',
    );
  }

  Map<String, String> _readExtendedData(XmlElement placemark) {
    final result = <String, String>{};

    for (final data in placemark.descendants.whereType<XmlElement>().where(
      (element) => element.name.local == 'Data',
    )) {
      final key = data.getAttribute('name');

      if (key == null || key.isEmpty) continue;

      final valueElement = _firstDescendant(data, 'value');

      if (valueElement != null) {
        result[key] = valueElement.innerText.trim();
      }
    }

    for (final simpleData
        in placemark.descendants.whereType<XmlElement>().where(
          (element) => element.name.local == 'SimpleData',
        )) {
      final key = simpleData.getAttribute('name');

      if (key == null || key.isEmpty) continue;

      result[key] = simpleData.innerText.trim();
    }

    return result;
  }

  String? _firstChildText(XmlElement parent, String localName) {
    for (final child in parent.children.whereType<XmlElement>()) {
      if (child.name.local == localName) {
        final value = child.innerText.trim();
        return value.isEmpty ? null : value;
      }
    }

    return null;
  }

  XmlElement? _firstDescendant(XmlElement parent, String localName) {
    for (final element in parent.descendants.whereType<XmlElement>()) {
      if (element.name.local == localName) {
        return element;
      }
    }

    return null;
  }
}
