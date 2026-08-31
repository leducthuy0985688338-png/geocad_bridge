import 'dart:convert';
import 'dart:typed_data';

import '../models/coordinate_reference_system.dart';
import '../models/map_feature.dart';
import '../models/map_layer.dart';
import 'coordinate_transform_service.dart';

enum DxfExportErrorCode {
  emptyExport,
  unsupportedCrs,
  mixedCrs,
  invalidGeometry,
  nonFiniteCoordinate,
  unsupportedElevation,
  invalidText,
  invalidLayerName,
}

class DxfExportException implements Exception {
  final DxfExportErrorCode code;
  final String message;
  final String? layerId;
  final String? featureId;

  const DxfExportException(
    this.code,
    this.message, {
    this.layerId,
    this.featureId,
  });

  @override
  String toString() => message;
}

class DxfExportOptions {
  final double defaultTextHeight;

  const DxfExportOptions({this.defaultTextHeight = 1.0});
}

class DxfExportResult {
  final String content;
  final int layerCount;
  final int entityCount;
  final List<String> warnings;
  final CoordinateReferenceSystem exportedCrs;

  DxfExportResult({
    required this.content,
    required this.layerCount,
    required this.entityCount,
    required List<String> warnings,
    required this.exportedCrs,
  }) : warnings = List<String>.unmodifiable(warnings);

  Uint8List get bytes => Uint8List.fromList(utf8.encode(content));
}

/// ASCII DXF R12 exporter.
///
/// R12/AC1009 is deliberately used as the interoperability profile. It avoids
/// the handle/owner/LAYOUT/OBJECTS database graph required by newer DXF
/// versions while preserving the basic CAD geometry GeoCAD currently exports.
class DxfExportService {
  static const String acadVersion = 'AC1009';
  static const String lineEnding = '\r\n';
  static const double _minimumTolerance = 1e-9;

  static const CoordinateTransformService _coordinateTransformService =
      CoordinateTransformService();

  const DxfExportService();

  DxfExportResult serialize({
    required String documentName,
    required List<MapLayer> layers,
    DxfExportOptions options = const DxfExportOptions(),
  }) {
    if (!options.defaultTextHeight.isFinite || options.defaultTextHeight <= 0) {
      throw const DxfExportException(
        DxfExportErrorCode.invalidText,
        'Chiều cao TEXT mặc định phải là số hữu hạn lớn hơn 0.',
      );
    }

    final exportLayers = layers
        .where(
          (layer) =>
              layer.visible && layer.features.any((feature) => feature.visible),
        )
        .toList();
    if (exportLayers.isEmpty) {
      throw const DxfExportException(
        DxfExportErrorCode.emptyExport,
        'Không có dữ liệu đang hiển thị để xuất DXF.',
      );
    }

    final exportedCrs = _validateCrs(exportLayers);
    final layerNames = _buildLayerNames(exportLayers);
    final warnings = <String>[];
    final entities = <String>[];

    for (var layerIndex = 0; layerIndex < exportLayers.length; layerIndex++) {
      final layer = exportLayers[layerIndex];
      for (final feature in layer.features.where(
        (feature) => feature.visible,
      )) {
        final rawLayerName = _rawLayerName(layer, feature, layerIndex + 1);
        final layerName = layerNames[rawLayerName]!;
        entities.add(
          _serializeFeature(
            layer: layer,
            feature: feature,
            layerName: layerName,
            options: options,
            warnings: warnings,
          ),
        );
      }
    }

    if (entities.isEmpty) {
      throw const DxfExportException(
        DxfExportErrorCode.emptyExport,
        'Không có đối tượng hợp lệ để xuất DXF.',
      );
    }

    final lines = <String>[];
    _addHeader(lines);
    _addTables(lines, layerNames.values.toList());
    _pair(lines, 0, 'SECTION');
    _pair(lines, 2, 'ENTITIES');
    for (final entity in entities) {
      lines.addAll(entity.split(lineEnding));
    }
    _pair(lines, 0, 'ENDSEC');
    _pair(lines, 0, 'EOF');

    return DxfExportResult(
      content: '${lines.join(lineEnding)}$lineEnding',
      layerCount: layerNames.length,
      entityCount: entities.length,
      warnings: warnings,
      exportedCrs: exportedCrs,
    );
  }

  Uint8List exportAsBytes({
    required String documentName,
    required List<MapLayer> layers,
    DxfExportOptions options = const DxfExportOptions(),
  }) {
    return serialize(
      documentName: documentName,
      layers: layers,
      options: options,
    ).bytes;
  }

  CoordinateReferenceSystem _validateCrs(List<MapLayer> layers) {
    final first = layers.first.crs;
    if (first.isWgs84) {
      throw const DxfExportException(
        DxfExportErrorCode.unsupportedCrs,
        'DXF không xuất trực tiếp tọa độ WGS84. Hãy tạo layer UTM trước.',
      );
    }
    if (!first.isValid || (first.isUtm && first.epsgCode == null)) {
      throw const DxfExportException(
        DxfExportErrorCode.unsupportedCrs,
        'CRS của layer xuất DXF không hợp lệ.',
      );
    }

    for (final layer in layers.skip(1)) {
      final crs = layer.crs;
      if (crs.isWgs84) {
        throw const DxfExportException(
          DxfExportErrorCode.unsupportedCrs,
          'DXF không xuất trực tiếp tọa độ WGS84. Hãy tạo layer UTM trước.',
        );
      }
      if (!crs.isValid || (crs.isUtm && crs.epsgCode == null)) {
        throw DxfExportException(
          DxfExportErrorCode.unsupportedCrs,
          'CRS của layer "${layer.name}" không hợp lệ.',
          layerId: layer.id,
        );
      }
      if (crs.type != first.type ||
          crs.utmZone != first.utmZone ||
          crs.hemisphere != first.hemisphere) {
        throw const DxfExportException(
          DxfExportErrorCode.mixedCrs,
          'Các layer xuất DXF phải cùng localCad hoặc cùng UTM zone/hemisphere.',
        );
      }
    }

    return first;
  }

  Map<String, String> _buildLayerNames(List<MapLayer> layers) {
    final result = <String, String>{};
    final used = <String>{};
    var fallbackIndex = 0;

    for (var layerIndex = 0; layerIndex < layers.length; layerIndex++) {
      final layer = layers[layerIndex];
      for (final feature in layer.features.where(
        (feature) => feature.visible,
      )) {
        final raw = _rawLayerName(layer, feature, layerIndex + 1);
        if (result.containsKey(raw)) continue;
        fallbackIndex++;
        final base = _sanitizeLayerName(raw, fallbackIndex);
        var candidate = base;
        var suffix = 2;
        while (used.contains(candidate.toLowerCase())) {
          candidate = _withSuffix(base, suffix++);
        }
        if (candidate.isEmpty) {
          throw DxfExportException(
            DxfExportErrorCode.invalidLayerName,
            'Không thể tạo tên DXF layer hợp lệ.',
            layerId: layer.id,
          );
        }
        result[raw] = candidate;
        used.add(candidate.toLowerCase());
      }
    }

    return result;
  }

  String _rawLayerName(MapLayer layer, MapFeature feature, int fallbackIndex) {
    final cadLayer = feature.properties['cadLayer']?.trim();
    if (cadLayer != null && cadLayer.isNotEmpty) return cadLayer;
    final layerName = layer.name.trim();
    return layerName.isEmpty ? 'Layer_$fallbackIndex' : layerName;
  }

  String _sanitizeLayerName(String value, int fallbackIndex) {
    var result = value
        .replaceAll(RegExp(r'[<>/\\":;?*|=,]'), '_')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '_')
        .trim();
    if (result.isEmpty) result = 'Layer_$fallbackIndex';
    return String.fromCharCodes(result.runes.take(255));
  }

  String _withSuffix(String base, int suffix) {
    final tail = '_$suffix';
    final maxBaseLength = 255 - tail.length;
    return '${String.fromCharCodes(base.runes.take(maxBaseLength))}$tail';
  }

  String _serializeFeature({
    required MapLayer layer,
    required MapFeature feature,
    required String layerName,
    required DxfExportOptions options,
    required List<String> warnings,
  }) {
    for (final coordinate in feature.coordinates) {
      _validateCoordinate(layer, feature, coordinate);
    }

    final lines = <String>[];
    switch (feature.type) {
      case MapFeatureType.point:
        _requireCount(layer, feature, exactly: 1);
        _entityStart(lines, 'POINT', layerName, feature: feature);
        _coordinate(
          lines,
          feature.coordinates.single,
          xCode: 10,
          yCode: 20,
          zCode: 30,
          writeZeroZ: true,
        );
      case MapFeatureType.line:
        _requireCount(layer, feature, exactly: 2);
        _entityStart(lines, 'LINE', layerName, feature: feature);
        _coordinate(
          lines,
          feature.coordinates[0],
          xCode: 10,
          yCode: 20,
          zCode: 30,
          writeZeroZ: true,
        );
        _coordinate(
          lines,
          feature.coordinates[1],
          xCode: 11,
          yCode: 21,
          zCode: 31,
          writeZeroZ: true,
        );
      case MapFeatureType.polyline:
        _requireCount(layer, feature, minimum: 2);
        _rejectPolylineElevation(layer, feature);
        _polyline(
          lines,
          feature,
          feature.coordinates,
          layerName,
          closed: false,
        );
      case MapFeatureType.polygon:
        _requireCount(layer, feature, minimum: 3);
        _rejectPolylineElevation(layer, feature);
        _polyline(
          lines,
          feature,
          _canonicalPolygon(layer, feature),
          layerName,
          closed: true,
        );
      case MapFeatureType.text:
        _requireCount(layer, feature, exactly: 1);
        _text(
          lines,
          layer: layer,
          feature: feature,
          layerName: layerName,
          options: options,
          warnings: warnings,
        );
    }

    return lines.join(lineEnding);
  }

  void _entityStart(
    List<String> lines,
    String entity,
    String layerName, {
    MapFeature? feature,
  }) {
    _pair(lines, 0, entity);
    _pair(lines, 8, layerName);
    if (feature != null) {
      _writeEntityColor(lines, feature);
    }
  }

  void _writeEntityColor(List<String> lines, MapFeature feature) {
    final rawColorIndex = feature.properties['cad.colorIndex']?.trim();
    if (rawColorIndex == null || rawColorIndex.isEmpty) return;

    final colorIndex = int.tryParse(rawColorIndex);
    if (colorIndex == null || colorIndex < -255 || colorIndex > 255) return;

    _pair(lines, 62, colorIndex);
  }

  void _polyline(
    List<String> lines,
    MapFeature feature,
    List<MapCoordinate> coordinates,
    String layerName, {
    required bool closed,
  }) {
    _entityStart(lines, 'POLYLINE', layerName, feature: feature);
    _pair(lines, 66, 1);
    _pair(lines, 10, '0');
    _pair(lines, 20, '0');
    _pair(lines, 30, '0');
    _pair(lines, 70, closed ? 1 : 0);

    for (final coordinate in coordinates) {
      _entityStart(lines, 'VERTEX', layerName);
      _pair(lines, 10, _number(coordinate.x));
      _pair(lines, 20, _number(coordinate.y));
      _pair(lines, 30, '0');
      _pair(lines, 70, 0);
    }

    _entityStart(lines, 'SEQEND', layerName);
  }

  void _text(
    List<String> lines, {
    required MapLayer layer,
    required MapFeature feature,
    required String layerName,
    required DxfExportOptions options,
    required List<String> warnings,
  }) {
    final suppliedText = feature.properties['text'];
    var content = suppliedText != null && suppliedText.trim().isNotEmpty
        ? suppliedText.trim()
        : feature.name.trim();
    if (content.isEmpty) {
      throw _featureError(
        DxfExportErrorCode.invalidText,
        'TEXT phải có properties["text"] hoặc name không rỗng.',
        layer,
        feature,
      );
    }
    if (RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]').hasMatch(content)) {
      throw _featureError(
        DxfExportErrorCode.invalidText,
        'TEXT chứa ký tự điều khiển không an toàn.',
        layer,
        feature,
      );
    }

    final normalized = content.replaceAll(RegExp(r'\r\n?|\n'), ' ');
    if (normalized != content) {
      warnings.add('TEXT "${feature.id}" đã được chuyển thành một dòng.');
      content = normalized;
    }

    final height = _textNumber(
      layer,
      feature,
      key: 'textHeight',
      fallback: options.defaultTextHeight,
      positive: true,
    );
    final rotation = _textNumber(
      layer,
      feature,
      key: 'rotationDegrees',
      fallback: 0,
    );

    _entityStart(lines, 'TEXT', layerName, feature: feature);
    _coordinate(
      lines,
      feature.coordinates.single,
      xCode: 10,
      yCode: 20,
      zCode: 30,
      writeZeroZ: true,
    );
    _pair(lines, 40, _number(height));
    _pair(lines, 1, content);
    _pair(lines, 50, _number(rotation));
    _pair(lines, 7, 'STANDARD');
  }

  double _textNumber(
    MapLayer layer,
    MapFeature feature, {
    required String key,
    required double fallback,
    bool positive = false,
  }) {
    final raw = feature.properties[key];
    if (raw == null) return fallback;
    final value = double.tryParse(raw);
    if (value == null || !value.isFinite || (positive && value <= 0)) {
      throw _featureError(
        DxfExportErrorCode.invalidText,
        'Thuộc tính $key của TEXT không hợp lệ.',
        layer,
        feature,
      );
    }
    return value;
  }

  List<MapCoordinate> _canonicalPolygon(MapLayer layer, MapFeature feature) {
    final coordinates = List<MapCoordinate>.from(feature.coordinates);
    final tolerance = _coordinateTolerance(coordinates);
    if (_samePoint(coordinates.first, coordinates.last, tolerance)) {
      coordinates.removeLast();
    }

    final distinct = <MapCoordinate>[];
    for (final coordinate in coordinates) {
      if (!distinct.any((item) => _samePoint(item, coordinate, tolerance))) {
        distinct.add(coordinate);
      }
    }

    if (distinct.length < 3 || coordinates.length < 3) {
      throw _featureError(
        DxfExportErrorCode.invalidGeometry,
        'POLYGON phải có ít nhất 3 đỉnh phân biệt.',
        layer,
        feature,
      );
    }

    var twiceArea = 0.0;
    for (var index = 0; index < coordinates.length; index++) {
      final current = coordinates[index];
      final next = coordinates[(index + 1) % coordinates.length];
      twiceArea += current.x * next.y - next.x * current.y;
    }

    if (!twiceArea.isFinite || twiceArea.abs() <= tolerance * tolerance) {
      throw _featureError(
        DxfExportErrorCode.invalidGeometry,
        'POLYGON bị suy biến hoặc có diện tích quá nhỏ.',
        layer,
        feature,
      );
    }

    return coordinates;
  }

  double _coordinateTolerance(List<MapCoordinate> coordinates) {
    var minX = coordinates.first.x;
    var maxX = minX;
    var minY = coordinates.first.y;
    var maxY = minY;
    for (final coordinate in coordinates.skip(1)) {
      if (coordinate.x < minX) minX = coordinate.x;
      if (coordinate.x > maxX) maxX = coordinate.x;
      if (coordinate.y < minY) minY = coordinate.y;
      if (coordinate.y > maxY) maxY = coordinate.y;
    }
    final extent = (maxX - minX).abs() > (maxY - minY).abs()
        ? (maxX - minX).abs()
        : (maxY - minY).abs();
    return extent * 1e-12 > _minimumTolerance
        ? extent * 1e-12
        : _minimumTolerance;
  }

  bool _samePoint(MapCoordinate a, MapCoordinate b, double tolerance) {
    return (a.x - b.x).abs() <= tolerance && (a.y - b.y).abs() <= tolerance;
  }

  void _rejectPolylineElevation(MapLayer layer, MapFeature feature) {
    if (feature.coordinates.any((coordinate) => coordinate.z != null)) {
      throw _featureError(
        DxfExportErrorCode.unsupportedElevation,
        'DXF R12 hiện chưa hỗ trợ Z cho POLYLINE/POLYGON.',
        layer,
        feature,
      );
    }
  }

  void _requireCount(
    MapLayer layer,
    MapFeature feature, {
    int? exactly,
    int? minimum,
  }) {
    final valid = exactly != null
        ? feature.coordinates.length == exactly
        : feature.coordinates.length >= minimum!;
    if (!valid) {
      throw _featureError(
        DxfExportErrorCode.invalidGeometry,
        'Số tọa độ của ${feature.type.name} không hợp lệ.',
        layer,
        feature,
      );
    }
  }

  void _validateCoordinate(
    MapLayer layer,
    MapFeature feature,
    MapCoordinate coordinate,
  ) {
    if (!coordinate.x.isFinite ||
        !coordinate.y.isFinite ||
        (coordinate.z != null && !coordinate.z!.isFinite)) {
      throw _featureError(
        DxfExportErrorCode.nonFiniteCoordinate,
        'DXF không chấp nhận tọa độ NaN hoặc infinity.',
        layer,
        feature,
      );
    }

    final zone = layer.crs.utmZone;
    if (layer.crs.isUtm &&
        (zone == null ||
            !_coordinateTransformService.isValidUtm(
              easting: coordinate.x,
              northing: coordinate.y,
              zone: zone,
            ))) {
      throw _featureError(
        DxfExportErrorCode.invalidGeometry,
        'Tọa độ UTM nằm ngoài phạm vi hợp lệ.',
        layer,
        feature,
      );
    }
  }

  DxfExportException _featureError(
    DxfExportErrorCode code,
    String message,
    MapLayer layer,
    MapFeature feature,
  ) {
    return DxfExportException(
      code,
      message,
      layerId: layer.id,
      featureId: feature.id,
    );
  }

  void _coordinate(
    List<String> lines,
    MapCoordinate coordinate, {
    required int xCode,
    required int yCode,
    required int zCode,
    bool writeZeroZ = false,
  }) {
    _pair(lines, xCode, _number(coordinate.x));
    _pair(lines, yCode, _number(coordinate.y));
    if (coordinate.z != null || writeZeroZ) {
      _pair(lines, zCode, _number(coordinate.z ?? 0));
    }
  }

  String _number(double value) {
    if (value == 0) return '0';
    final text = value.toStringAsPrecision(15);
    if (text.contains('e') || text.contains('E') || !text.contains('.')) {
      return text;
    }
    return text
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  void _addHeader(List<String> lines) {
    _pair(lines, 0, 'SECTION');
    _pair(lines, 2, 'HEADER');
    _pair(lines, 9, r'$ACADVER');
    _pair(lines, 1, acadVersion);
    _pair(lines, 0, 'ENDSEC');
  }

  void _addTables(List<String> lines, List<String> layerNames) {
    _pair(lines, 0, 'SECTION');
    _pair(lines, 2, 'TABLES');

    _pair(lines, 0, 'TABLE');
    _pair(lines, 2, 'LTYPE');
    _pair(lines, 70, 1);
    _pair(lines, 0, 'LTYPE');
    _pair(lines, 2, 'CONTINUOUS');
    _pair(lines, 70, 64);
    _pair(lines, 3, 'Solid line');
    _pair(lines, 72, 65);
    _pair(lines, 73, 0);
    _pair(lines, 40, '0');
    _pair(lines, 0, 'ENDTAB');

    _pair(lines, 0, 'TABLE');
    _pair(lines, 2, 'LAYER');
    _pair(lines, 70, layerNames.length);
    for (final layerName in layerNames) {
      _pair(lines, 0, 'LAYER');
      _pair(lines, 2, layerName);
      _pair(lines, 70, 0);
      _pair(lines, 62, 7);
      _pair(lines, 6, 'CONTINUOUS');
    }
    _pair(lines, 0, 'ENDTAB');

    _pair(lines, 0, 'TABLE');
    _pair(lines, 2, 'STYLE');
    _pair(lines, 70, 1);
    _pair(lines, 0, 'STYLE');
    _pair(lines, 2, 'STANDARD');
    _pair(lines, 70, 0);
    _pair(lines, 40, '0');
    _pair(lines, 41, '1');
    _pair(lines, 50, '0');
    _pair(lines, 71, 0);
    _pair(lines, 42, '1');
    _pair(lines, 3, 'txt');
    _pair(lines, 4, '');
    _pair(lines, 0, 'ENDTAB');

    _pair(lines, 0, 'ENDSEC');
  }

  void _pair(List<String> lines, int code, Object value) {
    lines.add(code.toString());
    lines.add(value.toString());
  }
}
