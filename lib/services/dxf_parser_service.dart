import 'dart:io';

import '../models/map_feature.dart';

class DxfParserService {
  const DxfParserService();

  /// Đọc file DXF dạng ASCII.
  ///
  /// Hiện hỗ trợ chuyển các entity sau thành MapFeature:
  /// - POINT
  /// - LINE
  /// - LWPOLYLINE
  Future<DxfParseResult> parseFile(String filePath) async {
    final file = File(filePath);

    if (!await file.exists()) {
      throw const DxfParserException(
        'Không tìm thấy file DXF.',
      );
    }

    final lines = await file.readAsLines();

    if (lines.isEmpty) {
      throw const DxfParserException(
        'File DXF không có dữ liệu.',
      );
    }

    if (lines.length < 2) {
      throw const DxfParserException(
        'File DXF không đúng cấu trúc.',
      );
    }

    final pairs = _createPairs(lines);

    if (pairs.isEmpty) {
      throw const DxfParserException(
        'Không đọc được dữ liệu DXF.',
      );
    }

    final sections = _findSections(pairs);
    final features = _parseEntities(pairs);

    return DxfParseResult(
      filePath: filePath,
      lineCount: lines.length,
      pairCount: pairs.length,
      pairs: pairs,
      sections: sections,
      features: features,
    );
  }

  List<DxfGroupPair> _createPairs(List<String> lines) {
    final pairs = <DxfGroupPair>[];

    for (var index = 0; index + 1 < lines.length; index += 2) {
      final codeText = lines[index].trim();
      final value = lines[index + 1].trim();

      final code = int.tryParse(codeText);

      if (code == null) {
        throw DxfParserException(
          'Group Code không hợp lệ tại dòng ${index + 1}: '
          '$codeText',
        );
      }

      pairs.add(
        DxfGroupPair(
          code: code,
          value: value,
        ),
      );
    }

    return pairs;
  }

  List<String> _findSections(List<DxfGroupPair> pairs) {
    final sections = <String>[];

    for (var index = 0; index < pairs.length - 1; index++) {
      final current = pairs[index];
      final next = pairs[index + 1];

      if (current.code == 0 &&
          current.value.toUpperCase() == 'SECTION' &&
          next.code == 2) {
        final sectionName = next.value.toUpperCase();

        if (!sections.contains(sectionName)) {
          sections.add(sectionName);
        }
      }
    }

    return sections;
  }

  List<MapFeature> _parseEntities(
    List<DxfGroupPair> pairs,
  ) {
    final entityPairs = _getEntitiesSection(pairs);

    if (entityPairs.isEmpty) {
      return const [];
    }

    final features = <MapFeature>[];

    var index = 0;
    var featureIndex = 0;

    while (index < entityPairs.length) {
      final pair = entityPairs[index];

      if (pair.code != 0) {
        index++;
        continue;
      }

      final entityType = pair.value.toUpperCase();

      final nextEntityIndex = _findNextEntityIndex(
        entityPairs,
        index + 1,
      );

      final entityData = entityPairs.sublist(
        index + 1,
        nextEntityIndex,
      );

      MapFeature? feature;

      switch (entityType) {
        case 'POINT':
          feature = _parsePoint(
            entityData,
            featureIndex,
          );
          break;

        case 'LINE':
          feature = _parseLine(
            entityData,
            featureIndex,
          );
          break;

        case 'LWPOLYLINE':
          feature = _parseLwPolyline(
            entityData,
            featureIndex,
          );
          break;
      }

      if (feature != null) {
        features.add(feature);
        featureIndex++;
      }

      index = nextEntityIndex;
    }

    return features;
  }

  List<DxfGroupPair> _getEntitiesSection(
    List<DxfGroupPair> pairs,
  ) {
    var entitiesStart = -1;

    for (var index = 0; index < pairs.length - 1; index++) {
      final current = pairs[index];
      final next = pairs[index + 1];

      if (current.code == 0 &&
          current.value.toUpperCase() == 'SECTION' &&
          next.code == 2 &&
          next.value.toUpperCase() == 'ENTITIES') {
        entitiesStart = index + 2;
        break;
      }
    }

    if (entitiesStart == -1) {
      return const [];
    }

    var entitiesEnd = pairs.length;

    for (var index = entitiesStart; index < pairs.length; index++) {
      final pair = pairs[index];

      if (pair.code == 0 &&
          pair.value.toUpperCase() == 'ENDSEC') {
        entitiesEnd = index;
        break;
      }
    }

    return pairs.sublist(
      entitiesStart,
      entitiesEnd,
    );
  }

  int _findNextEntityIndex(
    List<DxfGroupPair> pairs,
    int startIndex,
  ) {
    for (var index = startIndex; index < pairs.length; index++) {
      if (pairs[index].code == 0) {
        return index;
      }
    }

    return pairs.length;
  }

  MapFeature? _parsePoint(
    List<DxfGroupPair> data,
    int featureIndex,
  ) {
    final x = _readDouble(data, 10);
    final y = _readDouble(data, 20);

    if (x == null || y == null) {
      return null;
    }

    final z = _readDouble(data, 30);
    final layerName = _readString(data, 8);

    return MapFeature(
      id: 'dxf-point-$featureIndex',
      type: MapFeatureType.point,
      name: 'POINT ${featureIndex + 1}',
      coordinates: [
        MapCoordinate(
          x: x,
          y: y,
          z: z,
        ),
      ],
      properties: _createProperties(
        entityType: 'POINT',
        layerName: layerName,
      ),
    );
  }

  MapFeature? _parseLine(
    List<DxfGroupPair> data,
    int featureIndex,
  ) {
    final startX = _readDouble(data, 10);
    final startY = _readDouble(data, 20);

    final endX = _readDouble(data, 11);
    final endY = _readDouble(data, 21);

    if (startX == null ||
        startY == null ||
        endX == null ||
        endY == null) {
      return null;
    }

    final startZ = _readDouble(data, 30);
    final endZ = _readDouble(data, 31);

    final layerName = _readString(data, 8);

    return MapFeature(
      id: 'dxf-line-$featureIndex',
      type: MapFeatureType.line,
      name: 'LINE ${featureIndex + 1}',
      coordinates: [
        MapCoordinate(
          x: startX,
          y: startY,
          z: startZ,
        ),
        MapCoordinate(
          x: endX,
          y: endY,
          z: endZ,
        ),
      ],
      properties: _createProperties(
        entityType: 'LINE',
        layerName: layerName,
      ),
    );
  }

  MapFeature? _parseLwPolyline(
    List<DxfGroupPair> data,
    int featureIndex,
  ) {
    final coordinates = <MapCoordinate>[];

    double? currentX;

    for (final pair in data) {
      if (pair.code == 10) {
        currentX = double.tryParse(pair.value);
        continue;
      }

      if (pair.code == 20 && currentX != null) {
        final y = double.tryParse(pair.value);

        if (y != null) {
          coordinates.add(
            MapCoordinate(
              x: currentX,
              y: y,
            ),
          );
        }

        currentX = null;
      }
    }

    if (coordinates.isEmpty) {
      return null;
    }

    final layerName = _readString(data, 8);

    final flags = _readInt(data, 70) ?? 0;

    final isClosed = (flags & 1) == 1;

    return MapFeature(
      id: 'dxf-lwpolyline-$featureIndex',
      type: isClosed
          ? MapFeatureType.polygon
          : MapFeatureType.polyline,
      name: isClosed
          ? 'POLYGON ${featureIndex + 1}'
          : 'LWPOLYLINE ${featureIndex + 1}',
      coordinates: coordinates,
      properties: {
        ..._createProperties(
          entityType: 'LWPOLYLINE',
          layerName: layerName,
        ),
        'closed': isClosed.toString(),
        'vertexCount': coordinates.length.toString(),
      },
    );
  }

  Map<String, String> _createProperties({
    required String entityType,
    String? layerName,
  }) {
    final properties = <String, String>{
      'source': 'DXF',
      'entityType': entityType,
    };

    if (layerName != null && layerName.isNotEmpty) {
      properties['cadLayer'] = layerName;
    }

    return properties;
  }

  String? _readString(
    List<DxfGroupPair> data,
    int code,
  ) {
    for (final pair in data) {
      if (pair.code == code) {
        return pair.value;
      }
    }

    return null;
  }

  double? _readDouble(
    List<DxfGroupPair> data,
    int code,
  ) {
    final value = _readString(
      data,
      code,
    );

    if (value == null) {
      return null;
    }

    return double.tryParse(value);
  }

  int? _readInt(
    List<DxfGroupPair> data,
    int code,
  ) {
    final value = _readString(
      data,
      code,
    );

    if (value == null) {
      return null;
    }

    return int.tryParse(value);
  }
}

class DxfGroupPair {
  final int code;
  final String value;

  const DxfGroupPair({
    required this.code,
    required this.value,
  });

  @override
  String toString() {
    return 'DxfGroupPair(code: $code, value: $value)';
  }
}

class DxfParseResult {
  final String filePath;
  final int lineCount;
  final int pairCount;

  final List<DxfGroupPair> pairs;
  final List<String> sections;

  /// Các đối tượng hình học DXF đã đọc thành công.
  final List<MapFeature> features;

  const DxfParseResult({
    required this.filePath,
    required this.lineCount,
    required this.pairCount,
    required this.pairs,
    required this.sections,
    required this.features,
  });

  bool get hasHeader => sections.contains('HEADER');

  bool get hasTables => sections.contains('TABLES');

  bool get hasBlocks => sections.contains('BLOCKS');

  bool get hasEntities => sections.contains('ENTITIES');

  int get featureCount => features.length;

  int get pointCount {
    return features
        .where(
          (feature) => feature.type == MapFeatureType.point,
        )
        .length;
  }

  int get lineCountEntity {
    return features
        .where(
          (feature) => feature.type == MapFeatureType.line,
        )
        .length;
  }

  int get polylineCount {
    return features
        .where(
          (feature) =>
              feature.type == MapFeatureType.polyline,
        )
        .length;
  }

  int get polygonCount {
    return features
        .where(
          (feature) =>
              feature.type == MapFeatureType.polygon,
        )
        .length;
  }

  @override
  String toString() {
    return 'DxfParseResult('
        'lineCount: $lineCount, '
        'pairCount: $pairCount, '
        'sections: $sections, '
        'features: $featureCount'
        ')';
  }
}

class DxfParserException implements Exception {
  final String message;

  const DxfParserException(this.message);

  @override
  String toString() {
    return message;
  }
}