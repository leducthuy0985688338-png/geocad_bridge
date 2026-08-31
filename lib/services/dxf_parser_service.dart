import 'dart:io';
import 'dart:math' as math;

import '../models/map_feature.dart';
import 'cad_color_service.dart';

class DxfParserService {
  static const _cadColorService = CadColorService();
  const DxfParserService();

  /// Đọc file DXF dạng ASCII.
  ///
  /// Hiện hỗ trợ chuyển các entity sau thành MapFeature:
  /// - POINT
  /// - LINE
  /// - LWPOLYLINE
  /// - POLYLINE / VERTEX / SEQEND (DXF R12)
  /// - CIRCLE
  /// - ARC
  /// - TEXT
  /// - MTEXT
  Future<DxfParseResult> parseFile(String filePath) async {
    final file = File(filePath);

    if (!await file.exists()) {
      throw const DxfParserException('Không tìm thấy file DXF.');
    }

    final lines = await file.readAsLines();

    if (lines.isEmpty) {
      throw const DxfParserException('File DXF không có dữ liệu.');
    }

    if (lines.length < 2) {
      throw const DxfParserException('File DXF không đúng cấu trúc.');
    }

    if (lines.length.isOdd) {
      throw const DxfParserException(
        'File DXF có Group Code không đi kèm giá trị.',
      );
    }

    final pairs = _createPairs(lines);

    if (pairs.isEmpty) {
      throw const DxfParserException('Không đọc được dữ liệu DXF.');
    }

    final sections = _findSections(pairs);
    _validateEntitiesSection(pairs);
    final entitiesResult = _parseEntities(pairs);

    return DxfParseResult(
      filePath: filePath,
      lineCount: lines.length,
      pairCount: pairs.length,
      pairs: pairs,
      sections: sections,
      features: entitiesResult.features,
      diagnostics: entitiesResult.diagnostics,
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

      pairs.add(DxfGroupPair(code: code, value: value));
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

  void _validateEntitiesSection(List<DxfGroupPair> pairs) {
    var entitiesStart = -1;
    for (var index = 0; index < pairs.length - 1; index++) {
      if (pairs[index].code == 0 &&
          pairs[index].value.toUpperCase() == 'SECTION' &&
          pairs[index + 1].code == 2 &&
          pairs[index + 1].value.toUpperCase() == 'ENTITIES') {
        entitiesStart = index + 2;
        break;
      }
    }
    if (entitiesStart < 0) return;
    for (var index = entitiesStart; index < pairs.length; index++) {
      final pair = pairs[index];
      if (pair.code != 0) continue;
      final value = pair.value.toUpperCase();
      if (value == 'ENDSEC') return;
      if (value == 'SECTION' || value == 'EOF') break;
    }
    throw const DxfParserException('SECTION ENTITIES không có ENDSEC hợp lệ.');
  }

  _DxfEntitiesParseResult _parseEntities(List<DxfGroupPair> pairs) {
    final entityPairs = _getEntitiesSection(pairs);

    if (entityPairs.isEmpty) {
      return _DxfEntitiesParseResult(
        features: const [],
        diagnostics: const DxfImportDiagnostics.empty(),
      );
    }

    final features = <MapFeature>[];
    final issues = <DxfImportDiagnostic>[];
    final unsupportedCounts = <String, int>{};

    var index = 0;
    var featureIndex = 0;
    var entityIndex = 0;
    var malformedCount = 0;

    while (index < entityPairs.length) {
      final pair = entityPairs[index];

      if (pair.code != 0) {
        index++;
        continue;
      }

      final entityType = pair.value.toUpperCase();
      entityIndex++;

      if (entityType == 'POLYLINE') {
        final polylineResult = _parseR12PolylineEntity(
          entityPairs,
          startIndex: index,
          featureIndex: featureIndex,
          entityIndex: entityIndex,
        );
        issues.addAll(polylineResult.issues);
        if (polylineResult.feature == null) {
          malformedCount++;
        } else {
          features.add(polylineResult.feature!);
          featureIndex++;
        }
        index = polylineResult.nextIndex;
        continue;
      }

      final nextEntityIndex = _findNextEntityIndex(entityPairs, index + 1);

      final entityData = entityPairs.sublist(index + 1, nextEntityIndex);

      MapFeature? feature;

      if (!_supportedEntityTypes.contains(entityType)) {
        unsupportedCounts.update(
          entityType,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
        issues.add(
          DxfImportDiagnostic(
            code: DxfDiagnosticCode.unsupportedEntity,
            severity: DxfDiagnosticSeverity.warning,
            entityType: entityType,
            entityIndex: entityIndex,
            layerName: _readString(entityData, 8),
            reason: 'Entity $entityType chưa được hỗ trợ.',
          ),
        );
        index = nextEntityIndex;
        continue;
      }

      final validation = _validateEntity(entityType, entityData, entityIndex);
      issues.addAll(validation.issues);
      if (!validation.isValid) {
        malformedCount++;
        index = nextEntityIndex;
        continue;
      }

      switch (entityType) {
        case 'POINT':
          feature = _parsePoint(entityData, featureIndex);
          break;

        case 'LINE':
          feature = _parseLine(entityData, featureIndex);
          break;

        case 'LWPOLYLINE':
          feature = _parseLwPolyline(entityData, featureIndex);
          break;

        case 'CIRCLE':
          feature = _parseCircle(entityData, featureIndex);
          break;

        case 'ARC':
          feature = _parseArc(entityData, featureIndex);
          break;

        case 'TEXT':
          feature = _parseText(entityData, featureIndex);
          break;

        case 'MTEXT':
          feature = _parseMText(entityData, featureIndex);
          break;
      }

      if (feature == null ||
          feature.coordinates.any(
            (coordinate) =>
                !coordinate.x.isFinite ||
                !coordinate.y.isFinite ||
                (coordinate.z != null && !coordinate.z!.isFinite),
          )) {
        malformedCount++;
        issues.add(
          DxfImportDiagnostic(
            code: feature == null
                ? DxfDiagnosticCode.malformedEntity
                : DxfDiagnosticCode.nonFiniteNumber,
            severity: DxfDiagnosticSeverity.error,
            entityType: entityType,
            entityIndex: entityIndex,
            layerName: _readString(entityData, 8),
            reason: feature == null
                ? 'Không thể tạo geometry $entityType hợp lệ.'
                : 'Geometry $entityType tạo ra tọa độ không hữu hạn.',
          ),
        );
        index = nextEntityIndex;
        continue;
      }

      features.add(feature);
      featureIndex++;

      index = nextEntityIndex;
    }

    final sortedUnsupported = Map<String, int>.fromEntries(
      unsupportedCounts.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key)),
    );
    return _DxfEntitiesParseResult(
      features: features,
      diagnostics: DxfImportDiagnostics(
        totalEntityCount: entityIndex,
        parsedEntityCount: features.length,
        malformedEntityCount: malformedCount,
        unsupportedEntityCounts: sortedUnsupported,
        issues: issues,
      ),
    );
  }

  static const _supportedEntityTypes = <String>{
    'POINT',
    'LINE',
    'LWPOLYLINE',
    'POLYLINE',
    'CIRCLE',
    'ARC',
    'TEXT',
    'MTEXT',
  };

  _DxfEntityValidation _validateEntity(
    String entityType,
    List<DxfGroupPair> data,
    int entityIndex,
  ) {
    final issues = <DxfImportDiagnostic>[];
    final layerName = _readString(data, 8);

    void malformed(DxfDiagnosticCode code, String reason, {int? groupCode}) {
      if (issues.any(
        (issue) => issue.severity == DxfDiagnosticSeverity.error,
      )) {
        return;
      }
      issues.add(
        DxfImportDiagnostic(
          code: code,
          severity: DxfDiagnosticSeverity.error,
          entityType: entityType,
          entityIndex: entityIndex,
          layerName: layerName,
          groupCode: groupCode,
          reason: reason,
        ),
      );
    }

    void warning(DxfDiagnosticCode code, String reason, {int? groupCode}) {
      issues.add(
        DxfImportDiagnostic(
          code: code,
          severity: DxfDiagnosticSeverity.warning,
          entityType: entityType,
          entityIndex: entityIndex,
          layerName: layerName,
          groupCode: groupCode,
          reason: reason,
        ),
      );
    }

    bool validateNumber(
      int code, {
      required bool required,
      bool positive = false,
    }) {
      final values = data.where((pair) => pair.code == code).toList();
      if (values.isEmpty) {
        if (required) {
          malformed(
            DxfDiagnosticCode.missingRequiredValue,
            'Thiếu Group Code $code bắt buộc của $entityType.',
            groupCode: code,
          );
        }
        return !required;
      }
      for (final pair in values) {
        final value = double.tryParse(pair.value);
        if (value == null) {
          malformed(
            DxfDiagnosticCode.invalidNumber,
            'Group Code $code của $entityType không phải số hợp lệ.',
            groupCode: code,
          );
          return false;
        }
        if (!value.isFinite) {
          malformed(
            DxfDiagnosticCode.nonFiniteNumber,
            'Group Code $code của $entityType phải là số hữu hạn.',
            groupCode: code,
          );
          return false;
        }
        if (positive && value <= 0) {
          malformed(
            DxfDiagnosticCode.invalidGeometry,
            'Group Code $code của $entityType phải lớn hơn 0.',
            groupCode: code,
          );
          return false;
        }
      }
      return true;
    }

    switch (entityType) {
      case 'POINT':
        validateNumber(10, required: true);
        validateNumber(20, required: true);
        validateNumber(30, required: false);
      case 'LINE':
        for (final code in const [10, 20, 11, 21]) {
          validateNumber(code, required: true);
        }
        validateNumber(30, required: false);
        validateNumber(31, required: false);
      case 'LWPOLYLINE':
        _validateLwPolyline(data, malformed: malformed, warning: warning);
      case 'CIRCLE':
        validateNumber(10, required: true);
        validateNumber(20, required: true);
        validateNumber(30, required: false);
        validateNumber(40, required: true, positive: true);
      case 'ARC':
        validateNumber(10, required: true);
        validateNumber(20, required: true);
        validateNumber(30, required: false);
        validateNumber(40, required: true, positive: true);
        final startValid = validateNumber(50, required: true);
        final endValid = validateNumber(51, required: true);
        if (startValid && endValid) {
          final start = _readDouble(data, 50)!;
          final end = _readDouble(data, 51)!;
          if (_normalizeArcSweep(start, end) == null) {
            malformed(
              DxfDiagnosticCode.invalidGeometry,
              'ARC có góc quét không hợp lệ hoặc bằng 0.',
            );
          }
        }
      case 'TEXT':
        validateNumber(10, required: true);
        validateNumber(20, required: true);
        validateNumber(30, required: false);
        validateNumber(40, required: false, positive: true);
        validateNumber(50, required: false);
        final content = _readString(data, 1)?.trim();
        if (content == null || content.isEmpty) {
          malformed(
            DxfDiagnosticCode.missingRequiredValue,
            'TEXT thiếu nội dung Group Code 1 hợp lệ.',
            groupCode: 1,
          );
        }
      case 'MTEXT':
        validateNumber(10, required: true);
        validateNumber(20, required: true);
        validateNumber(30, required: false);
        validateNumber(40, required: false, positive: true);
        validateNumber(50, required: false);
        final chunks = _readStrings(data, 3);
        final finalChunk = _readString(data, 1);
        if (finalChunk != null) chunks.add(finalChunk);
        if (_cleanMText(chunks.join()).trim().isEmpty) {
          malformed(
            DxfDiagnosticCode.missingRequiredValue,
            'MTEXT thiếu nội dung Group Code 1/3 hợp lệ.',
          );
        }
    }

    return _DxfEntityValidation(issues);
  }

  void _validateLwPolyline(
    List<DxfGroupPair> data, {
    required void Function(
      DxfDiagnosticCode code,
      String reason, {
      int? groupCode,
    })
    malformed,
    required void Function(
      DxfDiagnosticCode code,
      String reason, {
      int? groupCode,
    })
    warning,
  }) {
    var pendingX = false;
    var vertexCount = 0;
    for (final pair in data) {
      if (pair.code == 10) {
        if (pendingX) {
          malformed(
            DxfDiagnosticCode.invalidGeometry,
            'LWPOLYLINE có đỉnh X không đi kèm Y.',
            groupCode: 10,
          );
          return;
        }
        final x = double.tryParse(pair.value);
        if (x == null || !x.isFinite) {
          malformed(
            x == null
                ? DxfDiagnosticCode.invalidNumber
                : DxfDiagnosticCode.nonFiniteNumber,
            'Tọa độ X của LWPOLYLINE không hợp lệ hoặc không hữu hạn.',
            groupCode: 10,
          );
          return;
        }
        pendingX = true;
      } else if (pair.code == 20) {
        if (!pendingX) {
          malformed(
            DxfDiagnosticCode.invalidGeometry,
            'LWPOLYLINE có đỉnh Y không đi kèm X.',
            groupCode: 20,
          );
          return;
        }
        final y = double.tryParse(pair.value);
        if (y == null || !y.isFinite) {
          malformed(
            y == null
                ? DxfDiagnosticCode.invalidNumber
                : DxfDiagnosticCode.nonFiniteNumber,
            'Tọa độ Y của LWPOLYLINE không hợp lệ hoặc không hữu hạn.',
            groupCode: 20,
          );
          return;
        }
        pendingX = false;
        vertexCount++;
      }
    }
    if (pendingX) {
      malformed(
        DxfDiagnosticCode.invalidGeometry,
        'LWPOLYLINE có đỉnh X cuối không đi kèm Y.',
        groupCode: 10,
      );
      return;
    }

    final flagsText = _readString(data, 70);
    final flags = flagsText == null ? 0 : int.tryParse(flagsText);
    if (flags == null) {
      malformed(
        DxfDiagnosticCode.invalidNumber,
        'Flags Group Code 70 của LWPOLYLINE không hợp lệ.',
        groupCode: 70,
      );
      return;
    }
    final isClosed = (flags & 1) == 1;
    final minimum = isClosed ? 3 : 2;
    if (vertexCount < minimum) {
      malformed(
        DxfDiagnosticCode.invalidGeometry,
        'LWPOLYLINE ${isClosed ? 'đóng' : 'mở'} cần ít nhất $minimum đỉnh.',
      );
      return;
    }

    final declaredText = _readString(data, 90);
    if (declaredText == null) {
      warning(
        DxfDiagnosticCode.lwPolylineVertexCountMissing,
        'LWPOLYLINE thiếu khai báo số đỉnh Group Code 90.',
        groupCode: 90,
      );
    } else {
      final declared = int.tryParse(declaredText);
      if (declared == null || declared < 0) {
        malformed(
          DxfDiagnosticCode.invalidNumber,
          'Số đỉnh Group Code 90 của LWPOLYLINE không hợp lệ.',
          groupCode: 90,
        );
        return;
      }
      if (declared != vertexCount) {
        malformed(
          DxfDiagnosticCode.lwPolylineVertexCountMismatch,
          'LWPOLYLINE khai báo $declared đỉnh nhưng đọc được $vertexCount.',
          groupCode: 90,
        );
        return;
      }
    }

    final bulges = data.where((pair) => pair.code == 42).toList();
    var hasNonZeroBulge = false;
    for (final pair in bulges) {
      final value = double.tryParse(pair.value);
      if (value == null || !value.isFinite) {
        malformed(
          value == null
              ? DxfDiagnosticCode.invalidNumber
              : DxfDiagnosticCode.nonFiniteNumber,
          'Bulge Group Code 42 của LWPOLYLINE không hợp lệ.',
          groupCode: 42,
        );
        return;
      }
      hasNonZeroBulge |= value != 0;
    }
    if (hasNonZeroBulge) {
      warning(
        DxfDiagnosticCode.lwPolylineBulgeNotPreserved,
        'LWPOLYLINE có bulge; cung được nhập dưới dạng đoạn thẳng.',
        groupCode: 42,
      );
    }

    final elevations = data.where((pair) => pair.code == 38).toList();
    for (final pair in elevations) {
      final value = double.tryParse(pair.value);
      if (value == null || !value.isFinite) {
        malformed(
          value == null
              ? DxfDiagnosticCode.invalidNumber
              : DxfDiagnosticCode.nonFiniteNumber,
          'Elevation Group Code 38 của LWPOLYLINE không hợp lệ.',
          groupCode: 38,
        );
        return;
      }
    }
    if (elevations.isNotEmpty) {
      warning(
        DxfDiagnosticCode.lwPolylineElevationNotPreserved,
        'Elevation của LWPOLYLINE chưa được bảo toàn.',
        groupCode: 38,
      );
    }

    final hasOcs = data.any(
      (pair) => pair.code == 210 || pair.code == 220 || pair.code == 230,
    );
    if (!hasOcs) return;
    final ocsValues = <double>[];
    for (final code in const [210, 220, 230]) {
      final text = _readString(data, code);
      final value = text == null ? null : double.tryParse(text);
      if (value == null || !value.isFinite) {
        malformed(
          value != null
              ? DxfDiagnosticCode.nonFiniteNumber
              : DxfDiagnosticCode.lwPolylineOcsNotSupported,
          'OCS của LWPOLYLINE phải có đủ 210/220/230 hữu hạn.',
          groupCode: code,
        );
        return;
      }
      ocsValues.add(value);
    }
    const tolerance = 1e-12;
    final isDefault =
        ocsValues[0].abs() <= tolerance &&
        ocsValues[1].abs() <= tolerance &&
        (ocsValues[2] - 1).abs() <= tolerance;
    if (!isDefault) {
      malformed(
        DxfDiagnosticCode.lwPolylineOcsNotSupported,
        'LWPOLYLINE dùng OCS phi mặc định chưa được hỗ trợ.',
      );
      return;
    }
    warning(
      DxfDiagnosticCode.lwPolylineDefaultOcs,
      'LWPOLYLINE khai báo OCS mặc định (0,0,1).',
      groupCode: 210,
    );
  }

  _DxfR12PolylineParseResult _parseR12PolylineEntity(
    List<DxfGroupPair> pairs, {
    required int startIndex,
    required int featureIndex,
    required int entityIndex,
  }) {
    final headerEnd = _findNextEntityIndex(pairs, startIndex + 1);
    final headerData = pairs.sublist(startIndex + 1, headerEnd);
    final layerName = _readString(headerData, 8);
    final issues = <DxfImportDiagnostic>[];

    _DxfR12PolylineParseResult malformed(
      DxfDiagnosticCode code,
      String reason, {
      int? groupCode,
      int? nextIndex,
    }) {
      issues.add(
        DxfImportDiagnostic(
          code: code,
          severity: DxfDiagnosticSeverity.error,
          entityType: 'POLYLINE',
          entityIndex: entityIndex,
          layerName: layerName,
          groupCode: groupCode,
          reason: reason,
        ),
      );
      return _DxfR12PolylineParseResult(
        feature: null,
        issues: issues,
        nextIndex: nextIndex ?? _findR12PolylineEnd(pairs, headerEnd),
      );
    }

    final flagsText = _readString(headerData, 70);
    final flags = flagsText == null ? 0 : int.tryParse(flagsText);
    if (flags == null) {
      return malformed(
        DxfDiagnosticCode.invalidNumber,
        'Flags Group Code 70 của POLYLINE không hợp lệ.',
        groupCode: 70,
      );
    }

    final unsupportedFlags = flags & ~1;
    if (unsupportedFlags != 0) {
      return malformed(
        DxfDiagnosticCode.invalidGeometry,
        'POLYLINE dùng flags chưa được hỗ trợ (chỉ hỗ trợ polyline 2D mở/đóng).',
        groupCode: 70,
      );
    }

    final coordinates = <MapCoordinate>[];
    var cursor = headerEnd;
    var foundSeqend = false;

    while (cursor < pairs.length) {
      final marker = pairs[cursor];
      if (marker.code != 0) {
        return malformed(
          DxfDiagnosticCode.malformedEntity,
          'POLYLINE có dữ liệu ngoài VERTEX/SEQEND không hợp lệ.',
          nextIndex: cursor + 1,
        );
      }

      final type = marker.value.toUpperCase();
      if (type == 'SEQEND') {
        foundSeqend = true;
        cursor = _findNextEntityIndex(pairs, cursor + 1);
        break;
      }

      if (type != 'VERTEX') {
        return malformed(
          DxfDiagnosticCode.malformedEntity,
          'POLYLINE thiếu SEQEND trước entity $type.',
          nextIndex: cursor,
        );
      }

      final vertexEnd = _findNextEntityIndex(pairs, cursor + 1);
      final vertexData = pairs.sublist(cursor + 1, vertexEnd);
      final vertexFlagsText = _readString(vertexData, 70);
      final vertexFlags = vertexFlagsText == null
          ? 0
          : int.tryParse(vertexFlagsText);
      if (vertexFlags == null) {
        return malformed(
          DxfDiagnosticCode.invalidNumber,
          'Flags Group Code 70 của VERTEX không hợp lệ.',
          groupCode: 70,
        );
      }
      if (vertexFlags != 0) {
        return malformed(
          DxfDiagnosticCode.invalidGeometry,
          'VERTEX của POLYLINE dùng flags chưa được hỗ trợ.',
          groupCode: 70,
        );
      }

      final xText = _readString(vertexData, 10);
      final yText = _readString(vertexData, 20);
      if (xText == null || yText == null) {
        return malformed(
          DxfDiagnosticCode.missingRequiredValue,
          'VERTEX của POLYLINE thiếu tọa độ X/Y bắt buộc.',
          groupCode: xText == null ? 10 : 20,
        );
      }

      final x = double.tryParse(xText);
      final y = double.tryParse(yText);
      final zText = _readString(vertexData, 30);
      final z = zText == null ? null : double.tryParse(zText);

      if (x == null || y == null || (zText != null && z == null)) {
        return malformed(
          DxfDiagnosticCode.invalidNumber,
          'VERTEX của POLYLINE có tọa độ không phải số hợp lệ.',
        );
      }
      if (!x.isFinite || !y.isFinite || (z != null && !z.isFinite)) {
        return malformed(
          DxfDiagnosticCode.nonFiniteNumber,
          'VERTEX của POLYLINE phải dùng tọa độ hữu hạn.',
        );
      }

      coordinates.add(MapCoordinate(x: x, y: y, z: z));
      cursor = vertexEnd;
    }

    if (!foundSeqend) {
      return malformed(
        DxfDiagnosticCode.malformedEntity,
        'POLYLINE thiếu entity kết thúc SEQEND.',
        nextIndex: cursor,
      );
    }

    final isClosed = (flags & 1) == 1;
    final minimum = isClosed ? 3 : 2;
    if (coordinates.length < minimum) {
      return malformed(
        DxfDiagnosticCode.invalidGeometry,
        'POLYLINE ${isClosed ? 'đóng' : 'mở'} cần ít nhất $minimum đỉnh.',
        nextIndex: cursor,
      );
    }

    final feature = MapFeature(
      id: 'dxf-polyline-$featureIndex',
      type: isClosed ? MapFeatureType.polygon : MapFeatureType.polyline,
      name: isClosed
          ? 'POLYGON ${featureIndex + 1}'
          : 'POLYLINE ${featureIndex + 1}',
      coordinates: coordinates,
      properties: {
        ..._createProperties(
          entityType: 'POLYLINE',
          data: headerData,
          layerName: layerName,
        ),
        'closed': isClosed.toString(),
        'vertexCount': coordinates.length.toString(),
      },
    );

    return _DxfR12PolylineParseResult(
      feature: feature,
      issues: issues,
      nextIndex: cursor,
    );
  }

  int _findR12PolylineEnd(List<DxfGroupPair> pairs, int startIndex) {
    var cursor = startIndex;

    while (cursor < pairs.length) {
      final pair = pairs[cursor];

      if (pair.code == 0 && pair.value.toUpperCase() == 'SEQEND') {
        return _findNextEntityIndex(pairs, cursor + 1);
      }

      cursor++;
    }

    return pairs.length;
  }

  List<DxfGroupPair> _getEntitiesSection(List<DxfGroupPair> pairs) {
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

      if (pair.code == 0 && pair.value.toUpperCase() == 'ENDSEC') {
        entitiesEnd = index;
        break;
      }
    }

    return pairs.sublist(entitiesStart, entitiesEnd);
  }

  int _findNextEntityIndex(List<DxfGroupPair> pairs, int startIndex) {
    for (var index = startIndex; index < pairs.length; index++) {
      if (pairs[index].code == 0) {
        return index;
      }
    }

    return pairs.length;
  }

  MapFeature? _parsePoint(List<DxfGroupPair> data, int featureIndex) {
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
      coordinates: [MapCoordinate(x: x, y: y, z: z)],
      properties: _createProperties(
        entityType: 'POINT',
        data: data,
        layerName: layerName,
      ),
    );
  }

  MapFeature? _parseLine(List<DxfGroupPair> data, int featureIndex) {
    final startX = _readDouble(data, 10);
    final startY = _readDouble(data, 20);

    final endX = _readDouble(data, 11);
    final endY = _readDouble(data, 21);

    if (startX == null || startY == null || endX == null || endY == null) {
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
        MapCoordinate(x: startX, y: startY, z: startZ),
        MapCoordinate(x: endX, y: endY, z: endZ),
      ],
      properties: _createProperties(
        entityType: 'LINE',
        data: data,
        layerName: layerName,
      ),
    );
  }

  MapFeature? _parseLwPolyline(List<DxfGroupPair> data, int featureIndex) {
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
          coordinates.add(MapCoordinate(x: currentX, y: y));
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
      type: isClosed ? MapFeatureType.polygon : MapFeatureType.polyline,
      name: isClosed
          ? 'POLYGON ${featureIndex + 1}'
          : 'LWPOLYLINE ${featureIndex + 1}',
      coordinates: coordinates,
      properties: {
        ..._createProperties(
          entityType: 'LWPOLYLINE',
          data: data,
          layerName: layerName,
        ),
        'closed': isClosed.toString(),
        'vertexCount': coordinates.length.toString(),
      },
    );
  }

  Map<String, String> _createProperties({
    required String entityType,
    required List<DxfGroupPair> data,
    String? layerName,
  }) {
    final properties = <String, String>{
      'source': 'DXF',
      'entityType': entityType,
    };

    if (layerName != null && layerName.isNotEmpty) {
      properties['cadLayer'] = layerName;
    }

    final colorIndex = _readString(data, 62);
    if (colorIndex != null && colorIndex.isNotEmpty) {
      properties['cad.colorIndex'] = colorIndex;
    }

    final trueColor = _readString(data, 420);
    if (trueColor != null && trueColor.isNotEmpty) {
      properties['cad.trueColor'] = trueColor;
    }

    final canonicalColor = _cadColorService.resolveCanonicalColor(
      colorIndex: colorIndex,
      trueColor: trueColor,
    );

    if (canonicalColor != null &&
        !properties.containsKey('style.strokeColor')) {
      properties['style.strokeColor'] = canonicalColor;
    }

    return properties;
  }

  MapFeature? _parseCircle(List<DxfGroupPair> data, int featureIndex) {
    final centerX = _readDouble(data, 10);
    final centerY = _readDouble(data, 20);
    final centerZ = _readDouble(data, 30);
    final radius = _readDouble(data, 40);

    if (centerX == null || centerY == null || radius == null || radius <= 0) {
      return null;
    }

    const segmentCount = 72;
    final coordinates = List.generate(segmentCount, (index) {
      final angle = 2 * math.pi * index / segmentCount;

      return MapCoordinate(
        x: centerX + radius * math.cos(angle),
        y: centerY + radius * math.sin(angle),
        z: centerZ,
      );
    })..add(MapCoordinate(x: centerX + radius, y: centerY, z: centerZ));

    return MapFeature(
      id: 'dxf-circle-$featureIndex',
      type: MapFeatureType.polyline,
      name: 'CIRCLE ${featureIndex + 1}',
      coordinates: coordinates,
      properties: {
        ..._createProperties(
          entityType: 'CIRCLE',
          data: data,
          layerName: _readString(data, 8),
        ),
        'closed': 'true',
        'centerX': centerX.toString(),
        'centerY': centerY.toString(),
        if (centerZ != null) 'centerZ': centerZ.toString(),
        'radius': radius.toString(),
        'approximationSegments': segmentCount.toString(),
      },
    );
  }

  MapFeature? _parseArc(List<DxfGroupPair> data, int featureIndex) {
    final centerX = _readDouble(data, 10);
    final centerY = _readDouble(data, 20);
    final centerZ = _readDouble(data, 30);
    final radius = _readDouble(data, 40);
    final startAngle = _readDouble(data, 50);
    final endAngle = _readDouble(data, 51);

    if (centerX == null ||
        centerY == null ||
        radius == null ||
        radius <= 0 ||
        startAngle == null ||
        endAngle == null) {
      return null;
    }

    final normalizedArc = _normalizeArcSweep(startAngle, endAngle);
    if (normalizedArc == null) return null;

    final sweepAngle = normalizedArc.sweepDegrees;
    final segmentCount = math.max(1, (sweepAngle / 5).ceil());
    final coordinates = List.generate(segmentCount + 1, (index) {
      final angleDegrees =
          normalizedArc.startDegrees + sweepAngle * index / segmentCount;
      final angleRadians = angleDegrees * math.pi / 180;

      return MapCoordinate(
        x: centerX + radius * math.cos(angleRadians),
        y: centerY + radius * math.sin(angleRadians),
        z: centerZ,
      );
    });

    return MapFeature(
      id: 'dxf-arc-$featureIndex',
      type: MapFeatureType.polyline,
      name: 'ARC ${featureIndex + 1}',
      coordinates: coordinates,
      properties: {
        ..._createProperties(
          entityType: 'ARC',
          data: data,
          layerName: _readString(data, 8),
        ),
        'centerX': centerX.toString(),
        'centerY': centerY.toString(),
        if (centerZ != null) 'centerZ': centerZ.toString(),
        'radius': radius.toString(),
        'startAngleDegrees': startAngle.toString(),
        'endAngleDegrees': endAngle.toString(),
        'sweepAngleDegrees': sweepAngle.toString(),
        'approximationSegments': segmentCount.toString(),
      },
    );
  }

  _DxfArcSweep? _normalizeArcSweep(double startAngle, double endAngle) {
    if (!startAngle.isFinite || !endAngle.isFinite) return null;
    final normalizedStart = _normalizeDegrees(startAngle);
    final normalizedEnd = _normalizeDegrees(endAngle);
    var sweep = normalizedEnd - normalizedStart;
    if (sweep < 0) sweep += 360;
    if (!sweep.isFinite || sweep <= 1e-12 || sweep > 360) return null;
    return _DxfArcSweep(startDegrees: normalizedStart, sweepDegrees: sweep);
  }

  double _normalizeDegrees(double angle) {
    final normalized = angle % 360;
    return normalized < 0 ? normalized + 360 : normalized;
  }

  MapFeature? _parseText(List<DxfGroupPair> data, int featureIndex) {
    final content = _readString(data, 1);

    return _createTextFeature(
      data: data,
      featureIndex: featureIndex,
      entityType: 'TEXT',
      content: content,
    );
  }

  MapFeature? _parseMText(List<DxfGroupPair> data, int featureIndex) {
    final chunks = _readStrings(data, 3);
    final finalChunk = _readString(data, 1);

    if (finalChunk != null) {
      chunks.add(finalChunk);
    }

    return _createTextFeature(
      data: data,
      featureIndex: featureIndex,
      entityType: 'MTEXT',
      content: _cleanMText(chunks.join()),
    );
  }

  MapFeature? _createTextFeature({
    required List<DxfGroupPair> data,
    required int featureIndex,
    required String entityType,
    required String? content,
  }) {
    final x = _readDouble(data, 10);
    final y = _readDouble(data, 20);
    final normalizedContent = content?.trim();

    if (x == null ||
        y == null ||
        normalizedContent == null ||
        normalizedContent.isEmpty) {
      return null;
    }

    final z = _readDouble(data, 30);
    final textHeight = _readDouble(data, 40);
    final rotation = _readDouble(data, 50);
    final style = _readString(data, 7);

    return MapFeature(
      id: 'dxf-${entityType.toLowerCase()}-$featureIndex',
      type: MapFeatureType.text,
      name: normalizedContent,
      coordinates: [MapCoordinate(x: x, y: y, z: z)],
      properties: {
        ..._createProperties(
          entityType: entityType,
          data: data,
          layerName: _readString(data, 8),
        ),
        'text': normalizedContent,
        if (textHeight != null) 'textHeight': textHeight.toString(),
        if (rotation != null) 'rotationDegrees': rotation.toString(),
        if (style != null && style.isNotEmpty) 'textStyle': style,
      },
    );
  }

  String _cleanMText(String value) {
    return value
        .replaceAll(r'\P', '\n')
        .replaceAll(r'\~', ' ')
        .replaceAll(RegExp(r'\\[ACFHQTW][^;]*;'), '')
        .replaceAll(RegExp(r'\\[LlOoKk]'), '')
        .replaceAll('{', '')
        .replaceAll('}', '');
  }

  String? _readString(List<DxfGroupPair> data, int code) {
    for (final pair in data) {
      if (pair.code == code) {
        return pair.value;
      }
    }

    return null;
  }

  List<String> _readStrings(List<DxfGroupPair> data, int code) {
    return data
        .where((pair) => pair.code == code)
        .map((pair) => pair.value)
        .toList();
  }

  double? _readDouble(List<DxfGroupPair> data, int code) {
    final value = _readString(data, code);

    if (value == null) {
      return null;
    }

    return double.tryParse(value);
  }

  int? _readInt(List<DxfGroupPair> data, int code) {
    final value = _readString(data, code);

    if (value == null) {
      return null;
    }

    return int.tryParse(value);
  }
}

class DxfGroupPair {
  final int code;
  final String value;

  const DxfGroupPair({required this.code, required this.value});

  @override
  String toString() {
    return 'DxfGroupPair(code: $code, value: $value)';
  }
}

enum DxfDiagnosticSeverity { warning, error }

enum DxfDiagnosticCode {
  malformedEntity,
  unsupportedEntity,
  nonFiniteNumber,
  invalidNumber,
  missingRequiredValue,
  invalidGeometry,
  lwPolylineBulgeNotPreserved,
  lwPolylineElevationNotPreserved,
  lwPolylineOcsNotSupported,
  lwPolylineDefaultOcs,
  lwPolylineVertexCountMissing,
  lwPolylineVertexCountMismatch,
}

class DxfImportDiagnostic {
  final DxfDiagnosticCode code;
  final DxfDiagnosticSeverity severity;
  final String entityType;
  final int entityIndex;
  final String? layerName;
  final int? groupCode;
  final String reason;

  const DxfImportDiagnostic({
    required this.code,
    required this.severity,
    required this.entityType,
    required this.entityIndex,
    required this.reason,
    this.layerName,
    this.groupCode,
  });
}

class DxfImportDiagnostics {
  final int totalEntityCount;
  final int parsedEntityCount;
  final int malformedEntityCount;
  final Map<String, int> unsupportedEntityCounts;
  final List<DxfImportDiagnostic> issues;

  const DxfImportDiagnostics.empty()
    : totalEntityCount = 0,
      parsedEntityCount = 0,
      malformedEntityCount = 0,
      unsupportedEntityCounts = const {},
      issues = const [];

  DxfImportDiagnostics({
    required this.totalEntityCount,
    required this.parsedEntityCount,
    required this.malformedEntityCount,
    required Map<String, int> unsupportedEntityCounts,
    required List<DxfImportDiagnostic> issues,
  }) : unsupportedEntityCounts = Map.unmodifiable(unsupportedEntityCounts),
       issues = List.unmodifiable(issues) {
    if (totalEntityCount !=
        parsedEntityCount + malformedEntityCount + unsupportedEntityCount) {
      throw ArgumentError('DXF diagnostics counts are inconsistent.');
    }
  }

  int get unsupportedEntityCount =>
      unsupportedEntityCounts.values.fold(0, (total, count) => total + count);

  int get skippedEntityCount => malformedEntityCount + unsupportedEntityCount;

  bool get hasIssues => issues.isNotEmpty;

  bool get hasFidelityWarnings => issues.any(
    (issue) => const {
      DxfDiagnosticCode.lwPolylineBulgeNotPreserved,
      DxfDiagnosticCode.lwPolylineElevationNotPreserved,
      DxfDiagnosticCode.lwPolylineDefaultOcs,
      DxfDiagnosticCode.lwPolylineVertexCountMissing,
    }.contains(issue.code),
  );
}

class _DxfR12PolylineParseResult {
  final MapFeature? feature;
  final List<DxfImportDiagnostic> issues;
  final int nextIndex;

  _DxfR12PolylineParseResult({
    required this.feature,
    required List<DxfImportDiagnostic> issues,
    required this.nextIndex,
  }) : issues = List.unmodifiable(issues);
}

class _DxfEntityValidation {
  final List<DxfImportDiagnostic> issues;

  _DxfEntityValidation(List<DxfImportDiagnostic> issues)
    : issues = List.unmodifiable(issues);

  bool get isValid =>
      !issues.any((issue) => issue.severity == DxfDiagnosticSeverity.error);
}

class _DxfArcSweep {
  final double startDegrees;
  final double sweepDegrees;

  const _DxfArcSweep({required this.startDegrees, required this.sweepDegrees});
}

class _DxfEntitiesParseResult {
  final List<MapFeature> features;
  final DxfImportDiagnostics diagnostics;

  _DxfEntitiesParseResult({
    required List<MapFeature> features,
    required this.diagnostics,
  }) : features = List.unmodifiable(features);
}

class DxfParseResult {
  final String filePath;
  final int lineCount;
  final int pairCount;

  final List<DxfGroupPair> pairs;
  final List<String> sections;

  /// Các đối tượng hình học DXF đã đọc thành công.
  final List<MapFeature> features;

  final DxfImportDiagnostics diagnostics;

  const DxfParseResult({
    required this.filePath,
    required this.lineCount,
    required this.pairCount,
    required this.pairs,
    required this.sections,
    required this.features,
    this.diagnostics = const DxfImportDiagnostics.empty(),
  });

  bool get hasHeader => sections.contains('HEADER');

  bool get hasTables => sections.contains('TABLES');

  bool get hasBlocks => sections.contains('BLOCKS');

  bool get hasEntities => sections.contains('ENTITIES');

  int get featureCount => features.length;

  int get pointCount {
    return features
        .where((feature) => feature.type == MapFeatureType.point)
        .length;
  }

  int get lineCountEntity {
    return features
        .where((feature) => feature.type == MapFeatureType.line)
        .length;
  }

  int get polylineCount {
    return features
        .where((feature) => feature.type == MapFeatureType.polyline)
        .length;
  }

  int get polygonCount {
    return features
        .where((feature) => feature.type == MapFeatureType.polygon)
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
