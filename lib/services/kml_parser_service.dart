import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:xml/xml.dart';

import '../models/map_feature.dart';

enum KmlDiagnosticSeverity { warning, error }

enum KmlDiagnosticCode {
  unsupportedGeometry,
  malformedGeometry,
  fidelityWarning,
}

class KmlImportDiagnostic {
  final KmlDiagnosticSeverity severity;
  final KmlDiagnosticCode code;
  final int placemarkIndex;
  final String placemarkName;
  final String geometryType;
  final String message;

  const KmlImportDiagnostic({
    required this.severity,
    required this.code,
    required this.placemarkIndex,
    required this.placemarkName,
    required this.geometryType,
    required this.message,
  });
}

class KmlImportDiagnostics {
  final int totalGeometryCount;
  final int parsedGeometryCount;
  final int malformedGeometryCount;
  final Map<String, int> unsupportedGeometryCounts;
  final List<KmlImportDiagnostic> issues;

  KmlImportDiagnostics({
    required this.totalGeometryCount,
    required this.parsedGeometryCount,
    required this.malformedGeometryCount,
    required Map<String, int> unsupportedGeometryCounts,
    required List<KmlImportDiagnostic> issues,
  }) : unsupportedGeometryCounts = UnmodifiableMapView(
         Map<String, int>.fromEntries(
           unsupportedGeometryCounts.entries.toList()
             ..sort((a, b) => a.key.compareTo(b.key)),
         ),
       ),
       issues = List.unmodifiable(issues);

  int get unsupportedGeometryCount =>
      unsupportedGeometryCounts.values.fold(0, (sum, count) => sum + count);

  int get skippedGeometryCount =>
      malformedGeometryCount + unsupportedGeometryCount;

  bool get hasIssues => issues.isNotEmpty;

  bool get hasFidelityWarnings =>
      issues.any((issue) => issue.code == KmlDiagnosticCode.fidelityWarning);
}

class KmlParseResult {
  final List<MapFeature> features;
  final int placemarkCount;
  final int pointCount;
  final int lineStringCount;
  final int polygonCount;
  final KmlImportDiagnostics diagnostics;

  KmlParseResult({
    required List<MapFeature> features,
    required this.placemarkCount,
    required this.pointCount,
    required this.lineStringCount,
    required this.polygonCount,
    required this.diagnostics,
  }) : features = List.unmodifiable(features);
}

class KmlParserService {
  const KmlParserService();

  static const _supportedGeometryTypes = {'Point', 'LineString', 'Polygon'};
  static const _knownUnsupportedGeometryTypes = {
    'Model',
    'LinearRing',
    'Track',
    'MultiTrack',
  };
  static const _standardAltitudeModes = {
    'clampToGround',
    'relativeToGround',
    'absolute',
  };

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
    final issues = <KmlImportDiagnostic>[];
    final unsupportedGeometryCounts = <String, int>{};
    var placemarkCount = 0;
    var pointCount = 0;
    var lineStringCount = 0;
    var polygonCount = 0;
    var totalGeometryCount = 0;
    var malformedGeometryCount = 0;
    var featureIndex = 0;

    final placemarks = document.descendants.whereType<XmlElement>().where(
      (element) => element.name.local == 'Placemark',
    );

    for (final placemark in placemarks) {
      placemarkCount++;

      final name = _firstChildText(placemark, 'name') ?? '';
      final description = _firstChildText(placemark, 'description');
      final baseProperties = _readExtendedData(placemark);
      _readPlacemarkStyle(placemark, baseProperties);
      final geometryEntries = _geometryEntries(placemark);

      for (final entry in geometryEntries) {
        final geometry = entry.element;
        final localName = geometry.name.local;
        totalGeometryCount++;

        if (!_supportedGeometryTypes.contains(localName)) {
          unsupportedGeometryCounts.update(
            localName,
            (count) => count + 1,
            ifAbsent: () => 1,
          );
          issues.add(
            KmlImportDiagnostic(
              severity: KmlDiagnosticSeverity.warning,
              code: KmlDiagnosticCode.unsupportedGeometry,
              placemarkIndex: placemarkCount,
              placemarkName: name,
              geometryType: localName,
              message: 'Geometry $localName chưa được GeoCAD hỗ trợ.',
            ),
          );
          continue;
        }

        if (localName == 'Polygon' &&
            _hasDirectChild(geometry, 'innerBoundaryIs')) {
          unsupportedGeometryCounts.update(
            localName,
            (count) => count + 1,
            ifAbsent: () => 1,
          );
          issues.add(
            KmlImportDiagnostic(
              severity: KmlDiagnosticSeverity.warning,
              code: KmlDiagnosticCode.fidelityWarning,
              placemarkIndex: placemarkCount,
              placemarkName: name,
              geometryType: localName,
              message: 'Polygon có innerBoundaryIs (polygon có lỗ) chưa được model GeoCAD hỗ trợ; geometry đã bị bỏ qua để tránh mất fidelity.',
            ),
          );
          continue;
        }

        try {
          final geometryProperties = <String, String>{...baseProperties};
          geometryProperties['kmlGeometry'] = localName;
          if (entry.fromMultiGeometry) {
            geometryProperties['kmlFromMultiGeometry'] = 'true';
          }
          if (localName == 'Point') {
            final coordinates = _coordinatesFromGeometry(
              geometry,
              placemarkName: name,
              geometryType: localName,
            );

            if (coordinates.length != 1) {
              throw _geometryError(name, localName, 'phải có đúng 1 bộ tọa độ');
            }

            _preserveAltitudeMode(
              geometry,
              properties: geometryProperties,
              placemarkIndex: placemarkCount,
              placemarkName: name,
              geometryType: localName,
              issues: issues,
            );

            featureIndex++;
            pointCount++;
            features.add(
              MapFeature(
                id: 'kml-feature-$featureIndex',
                type: MapFeatureType.point,
                coordinates: [coordinates.first],
                name: name,
                description: description,
                properties: geometryProperties,
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

            _preserveAltitudeMode(
              geometry,
              properties: geometryProperties,
              placemarkIndex: placemarkCount,
              placemarkName: name,
              geometryType: localName,
              issues: issues,
            );

            featureIndex++;
            lineStringCount++;
            features.add(
              MapFeature(
                id: 'kml-feature-$featureIndex',
                type: MapFeatureType.polyline,
                coordinates: coordinates,
                name: name,
                description: description,
                properties: geometryProperties,
              ),
            );
          } else if (localName == 'Polygon') {
            final outerBoundary = _firstDirectChild(
              geometry,
              'outerBoundaryIs',
            );
            if (outerBoundary == null) {
              throw _geometryError(name, localName, 'thiếu outerBoundaryIs');
            }

            final linearRing = _firstDirectChild(outerBoundary, 'LinearRing');
            if (linearRing == null) {
              throw _geometryError(name, localName, 'thiếu LinearRing');
            }

            final coordinates = _coordinatesFromGeometry(
              linearRing,
              placemarkName: name,
              geometryType: localName,
            );
            _validateOuterRing(coordinates, name, localName);

            _preserveAltitudeMode(
              geometry,
              properties: geometryProperties,
              placemarkIndex: placemarkCount,
              placemarkName: name,
              geometryType: localName,
              issues: issues,
            );

            featureIndex++;
            polygonCount++;
            features.add(
              MapFeature(
                id: 'kml-feature-$featureIndex',
                type: MapFeatureType.polygon,
                coordinates: coordinates,
                name: name,
                description: description,
                properties: geometryProperties,
              ),
            );
          }
        } on FormatException catch (error) {
          malformedGeometryCount++;
          issues.add(
            KmlImportDiagnostic(
              severity: KmlDiagnosticSeverity.error,
              code: KmlDiagnosticCode.malformedGeometry,
              placemarkIndex: placemarkCount,
              placemarkName: name,
              geometryType: localName,
              message: error.message,
            ),
          );
        }
      }
    }

    final diagnostics = KmlImportDiagnostics(
      totalGeometryCount: totalGeometryCount,
      parsedGeometryCount: features.length,
      malformedGeometryCount: malformedGeometryCount,
      unsupportedGeometryCounts: unsupportedGeometryCounts,
      issues: issues,
    );

    assert(
      diagnostics.totalGeometryCount ==
          diagnostics.parsedGeometryCount +
              diagnostics.malformedGeometryCount +
              diagnostics.unsupportedGeometryCount,
    );

    return KmlParseResult(
      features: features,
      placemarkCount: placemarkCount,
      pointCount: pointCount,
      lineStringCount: lineStringCount,
      polygonCount: polygonCount,
      diagnostics: diagnostics,
    );
  }

  List<_KmlGeometryEntry> _geometryEntries(XmlElement placemark) {
    final result = <_KmlGeometryEntry>[];

    void collect(XmlElement parent, {required bool insideMultiGeometry}) {
      for (final child in parent.children.whereType<XmlElement>()) {
        final localName = child.name.local;
        if (localName == 'MultiGeometry') {
          collect(child, insideMultiGeometry: true);
        } else if (_supportedGeometryTypes.contains(localName) ||
            _knownUnsupportedGeometryTypes.contains(localName)) {
          result.add(
            _KmlGeometryEntry(
              element: child,
              fromMultiGeometry: insideMultiGeometry,
            ),
          );
        }
      }
    }

    collect(placemark, insideMultiGeometry: false);
    return result;
  }

  void _preserveAltitudeMode(
    XmlElement geometry, {
    required Map<String, String> properties,
    required int placemarkIndex,
    required String placemarkName,
    required String geometryType,
    required List<KmlImportDiagnostic> issues,
  }) {
    final altitudeModeElement = _firstDirectChild(geometry, 'altitudeMode');
    if (altitudeModeElement == null) return;

    final altitudeMode = altitudeModeElement.innerText.trim();
    if (altitudeMode.isEmpty) return;

    properties['kmlAltitudeMode'] = altitudeMode;
    if (!_standardAltitudeModes.contains(altitudeMode)) {
      issues.add(
        KmlImportDiagnostic(
          severity: KmlDiagnosticSeverity.warning,
          code: KmlDiagnosticCode.fidelityWarning,
          placemarkIndex: placemarkIndex,
          placemarkName: placemarkName,
          geometryType: geometryType,
          message:
              'altitudeMode "$altitudeMode" được giữ nguyên nhưng semantics chưa được GeoCAD xác nhận hỗ trợ.',
        ),
      );
    }
  }

  void _validateOuterRing(
    List<MapCoordinate> coordinates,
    String placemarkName,
    String geometryType,
  ) {
    if (coordinates.length < 4) {
      throw _geometryError(
        placemarkName,
        geometryType,
        'outer LinearRing phải có ít nhất 4 bộ tọa độ',
      );
    }

    final first = coordinates.first;
    final last = coordinates.last;
    if (first.x != last.x || first.y != last.y || first.z != last.z) {
      throw _geometryError(
        placemarkName,
        geometryType,
        'outer LinearRing phải khép kín (tọa độ đầu và cuối phải trùng nhau)',
      );
    }

    final uniqueVertices = coordinates
        .take(coordinates.length - 1)
        .map((coordinate) => '${coordinate.x},${coordinate.y},${coordinate.z}')
        .toSet();
    if (uniqueVertices.length < 3) {
      throw _geometryError(
        placemarkName,
        geometryType,
        'outer LinearRing phải có ít nhất 3 đỉnh phân biệt',
      );
    }
  }

  List<MapCoordinate> _coordinatesFromGeometry(
    XmlElement geometry, {
    required String placemarkName,
    required String geometryType,
  }) {
    final element = _firstDirectChild(geometry, 'coordinates');

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
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return result;

    final tuples = trimmed
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
      if (parts.length == 3 && parts[2].trim().isNotEmpty) {
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

  void _readPlacemarkStyle(
    XmlElement placemark,
    Map<String, String> properties,
  ) {
    final styleUrl = _firstChildText(placemark, 'styleUrl');
    if (styleUrl != null) {
      properties['kml.styleUrl'] = styleUrl;
    }

    final style = _firstDirectChild(placemark, 'Style');
    if (style == null) return;

    final lineStyle = _firstDirectChild(style, 'LineStyle');
    if (lineStyle != null) {
      final color = _firstChildText(lineStyle, 'color');
      if (color != null) {
        _readKmlColor(
          color,
          properties: properties,
          colorKey: 'style.strokeColor',
          opacityKey: 'style.strokeOpacity',
        );
      }

      final width = _firstChildText(lineStyle, 'width');
      if (width != null) {
        final parsedWidth = double.tryParse(width);
        if (parsedWidth != null && parsedWidth.isFinite && parsedWidth >= 0) {
          properties['style.strokeWidth'] = _formatStyleNumber(parsedWidth);
        }
      }
    }

    final polyStyle = _firstDirectChild(style, 'PolyStyle');
    if (polyStyle != null) {
      final color = _firstChildText(polyStyle, 'color');
      if (color != null) {
        _readKmlColor(
          color,
          properties: properties,
          colorKey: 'style.fillColor',
          opacityKey: 'style.fillOpacity',
        );
      }

      final fill = _firstChildText(polyStyle, 'fill');
      if (fill == '0' || fill == '1') {
        properties['style.fill'] = fill!;
      }

      final outline = _firstChildText(polyStyle, 'outline');
      if (outline == '0' || outline == '1') {
        properties['style.outline'] = outline!;
      }
    }
  }

  void _readKmlColor(
    String raw, {
    required Map<String, String> properties,
    required String colorKey,
    required String opacityKey,
  }) {
    final value = raw.trim();
    if (!RegExp(r'^[0-9A-Fa-f]{8}$').hasMatch(value)) return;

    final alpha = int.parse(value.substring(0, 2), radix: 16);
    final blue = value.substring(2, 4);
    final green = value.substring(4, 6);
    final red = value.substring(6, 8);

    properties[colorKey] =
        '#${red.toUpperCase()}${green.toUpperCase()}${blue.toUpperCase()}';
    properties[opacityKey] = _formatStyleNumber(alpha / 255);
  }

  String _formatStyleNumber(double value) {
    if (value == 0) return '0';
    if (value == 1) return '1';
    return value
        .toStringAsFixed(6)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
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

  bool _hasDirectChild(XmlElement parent, String localName) =>
      _firstDirectChild(parent, localName) != null;

  XmlElement? _firstDirectChild(XmlElement parent, String localName) {
    for (final child in parent.children.whereType<XmlElement>()) {
      if (child.name.local == localName) return child;
    }
    return null;
  }

  String? _firstChildText(XmlElement parent, String localName) {
    final child = _firstDirectChild(parent, localName);
    if (child == null) return null;
    final value = child.innerText.trim();
    return value.isEmpty ? null : value;
  }

  XmlElement? _firstDescendant(XmlElement parent, String localName) {
    for (final element in parent.descendants.whereType<XmlElement>()) {
      if (element.name.local == localName) return element;
    }
    return null;
  }
}

class _KmlGeometryEntry {
  final XmlElement element;
  final bool fromMultiGeometry;

  const _KmlGeometryEntry({
    required this.element,
    required this.fromMultiGeometry,
  });
}
