import 'dart:convert';
import 'dart:io';

import '../models/coordinate_reference_system.dart';
import '../models/map_feature.dart';
import '../models/map_layer.dart';
import '../models/map_project.dart';

class GeoCadProjectDocument {
  final MapProject project;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> warnings;

  GeoCadProjectDocument({
    required this.project,
    required this.createdAt,
    required this.updatedAt,
    List<String> warnings = const [],
  }) : warnings = List<String>.unmodifiable(warnings);

  GeoCadProjectDocument copyWith({
    MapProject? project,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? warnings,
  }) {
    return GeoCadProjectDocument(
      project: project ?? this.project,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      warnings: warnings ?? this.warnings,
    );
  }
}

class ProjectPersistenceException implements Exception {
  final String message;

  const ProjectPersistenceException(this.message);

  @override
  String toString() => message;
}

class ProjectPersistenceService {
  static const String formatName = 'GeoCAD Bridge Project';
  static const int currentVersion = 1;

  const ProjectPersistenceService();

  String serialize(GeoCadProjectDocument document) {
    final root = <String, Object?>{
      'format': formatName,
      'version': currentVersion,
      'createdAt': document.createdAt.toUtc().toIso8601String(),
      'updatedAt': document.updatedAt.toUtc().toIso8601String(),
      'project': _encodeProject(document.project),
    };
    try {
      return const JsonEncoder.withIndent('  ').convert(root);
    } on JsonUnsupportedObjectError catch (error) {
      throw ProjectPersistenceException(
        'Dữ liệu project không thể chuyển thành JSON: $error.',
      );
    }
  }

  GeoCadProjectDocument deserialize(String source) {
    Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw ProjectPersistenceException(
        'JSON project không hợp lệ: ${error.message}',
      );
    }
    final root = _object(decoded, 'root');
    if (_requiredString(root, 'format') != formatName) {
      throw const ProjectPersistenceException(
        'Định dạng project không được hỗ trợ.',
      );
    }
    final version = root['version'];
    if (version is! int) {
      throw const ProjectPersistenceException(
        'Version project bị thiếu hoặc không hợp lệ.',
      );
    }
    if (version != currentVersion) {
      throw ProjectPersistenceException(
        version > currentVersion
            ? 'Project dùng version mới hơn chưa được hỗ trợ: $version.'
            : 'Project version $version không được hỗ trợ.',
      );
    }
    final createdAt = _date(root, 'createdAt');
    final updatedAt = _date(root, 'updatedAt');
    final project = _decodeProject(_requiredObject(root, 'project'));
    final warnings = <String>[];
    for (final layer in project.layers) {
      final path = layer.sourcePath;
      if (path != null && path.isNotEmpty && !File(path).existsSync()) {
        warnings.add(
          'Không tìm thấy file nguồn của layer "${layer.name}": $path',
        );
      }
    }
    return GeoCadProjectDocument(
      project: project,
      createdAt: createdAt,
      updatedAt: updatedAt,
      warnings: warnings,
    );
  }

  Future<void> save(String path, GeoCadProjectDocument document) async {
    final target = File(path);
    final parent = target.parent;
    if (!await parent.exists()) {
      throw ProjectPersistenceException(
        'Thư mục lưu project không tồn tại: ${parent.path}',
      );
    }
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final temporary = File('${target.path}.tmp-$stamp');
    final backup = File('${target.path}.bak-$stamp');
    var targetMoved = false;
    try {
      final sink = temporary.openWrite(encoding: utf8);
      sink.write(serialize(document));
      await sink.flush();
      await sink.close();

      if (await target.exists()) {
        await target.rename(backup.path);
        targetMoved = true;
      }
      await temporary.rename(target.path);
      if (targetMoved && await backup.exists()) {
        await backup.delete();
      }
    } catch (error) {
      if (targetMoved && !await target.exists() && await backup.exists()) {
        await backup.rename(target.path);
      }
      throw ProjectPersistenceException('Không thể lưu project: $error');
    } finally {
      if (await temporary.exists()) {
        await temporary.delete();
      }
    }
  }

  Future<GeoCadProjectDocument> load(String path) async {
    try {
      return deserialize(await File(path).readAsString(encoding: utf8));
    } on ProjectPersistenceException {
      rethrow;
    } catch (error) {
      throw ProjectPersistenceException('Không thể mở project: $error');
    }
  }

  Map<String, Object?> _encodeProject(MapProject project) => {
    'id': project.id,
    'name': project.name,
    'description': project.description,
    'properties': _sortedProperties(project.properties),
    'layers': project.layers.map(_encodeLayer).toList(),
  };

  Map<String, Object?> _encodeLayer(MapLayer layer) => {
    'id': layer.id,
    'name': layer.name,
    'sourceType': layer.sourceType.name,
    'sourcePath': layer.sourcePath,
    'crs': _encodeCrs(layer.crs),
    'visible': layer.visible,
    'locked': layer.locked,
    'properties': _sortedProperties(layer.properties),
    'features': layer.features.map(_encodeFeature).toList(),
  };

  Map<String, Object?> _encodeFeature(MapFeature feature) => {
    'id': feature.id,
    'type': feature.type.name,
    'name': feature.name,
    'description': feature.description,
    'visible': feature.visible,
    'properties': _sortedProperties(feature.properties),
    'coordinates': feature.coordinates.map(_encodeCoordinate).toList(),
  };

  Map<String, Object?> _encodeCoordinate(MapCoordinate coordinate) {
    _finite(coordinate.x, 'coordinate.x');
    _finite(coordinate.y, 'coordinate.y');
    if (coordinate.z != null) _finite(coordinate.z!, 'coordinate.z');
    return {
      'x': coordinate.x,
      'y': coordinate.y,
      if (coordinate.z != null) 'z': coordinate.z,
    };
  }

  Map<String, Object?> _encodeCrs(CoordinateReferenceSystem crs) => {
    'type': crs.type.name,
    'name': crs.name,
    if (crs.utmZone != null) 'utmZone': crs.utmZone,
    if (crs.hemisphere != null) 'hemisphere': crs.hemisphere!.name,
  };

  Map<String, String> _sortedProperties(Map<String, String> properties) {
    final keys = properties.keys.toList()..sort();
    return {for (final key in keys) key: properties[key]!};
  }

  MapProject _decodeProject(Map<String, Object?> json) {
    final layersJson = _requiredList(json, 'layers');
    final layers = <MapLayer>[];
    final ids = <String>{};
    for (var index = 0; index < layersJson.length; index++) {
      final layer = _decodeLayer(_object(layersJson[index], 'layers[$index]'));
      if (!ids.add(layer.id)) {
        throw ProjectPersistenceException('Layer ID bị trùng: ${layer.id}.');
      }
      layers.add(layer);
    }
    return MapProject(
      id: _requiredNonEmptyString(json, 'id'),
      name: _requiredNonEmptyString(json, 'name'),
      description: _optionalString(json, 'description'),
      properties: _properties(json, 'properties'),
      layers: layers,
    );
  }

  MapLayer _decodeLayer(Map<String, Object?> json) {
    final sourceType = _enumByName(
      MapLayerSourceType.values,
      _requiredString(json, 'sourceType'),
      'sourceType',
    );
    final featuresJson = _requiredList(json, 'features');
    final features = <MapFeature>[];
    final ids = <String>{};
    for (var index = 0; index < featuresJson.length; index++) {
      final feature = _decodeFeature(
        _object(featuresJson[index], 'features[$index]'),
      );
      if (!ids.add(feature.id)) {
        throw ProjectPersistenceException(
          'Feature ID bị trùng trong layer: ${feature.id}.',
        );
      }
      features.add(feature);
    }
    return MapLayer(
      id: _requiredNonEmptyString(json, 'id'),
      name: _requiredNonEmptyString(json, 'name'),
      sourceType: sourceType,
      sourcePath: _optionalString(json, 'sourcePath'),
      crs: _decodeCrs(_requiredObject(json, 'crs')),
      features: features,
      visible: _requiredBool(json, 'visible'),
      locked: _requiredBool(json, 'locked'),
      properties: _properties(json, 'properties'),
    );
  }

  MapFeature _decodeFeature(Map<String, Object?> json) {
    final type = _enumByName(
      MapFeatureType.values,
      _requiredString(json, 'type'),
      'feature.type',
    );
    final coordinateJson = _requiredList(json, 'coordinates');
    final coordinates = [
      for (var index = 0; index < coordinateJson.length; index++)
        _decodeCoordinate(
          _object(coordinateJson[index], 'coordinates[$index]'),
        ),
    ];
    final minimum = switch (type) {
      MapFeatureType.point || MapFeatureType.text => 1,
      MapFeatureType.line || MapFeatureType.polyline => 2,
      MapFeatureType.polygon => 3,
    };
    final exactOne =
        type == MapFeatureType.point || type == MapFeatureType.text;
    if (coordinates.length < minimum || (exactOne && coordinates.length != 1)) {
      throw ProjectPersistenceException(
        'Geometry ${type.name} có số tọa độ không hợp lệ.',
      );
    }
    return MapFeature(
      id: _requiredNonEmptyString(json, 'id'),
      type: type,
      coordinates: coordinates,
      name: _requiredString(json, 'name'),
      description: _optionalString(json, 'description'),
      properties: _properties(json, 'properties'),
      visible: _requiredBool(json, 'visible'),
    );
  }

  MapCoordinate _decodeCoordinate(Map<String, Object?> json) {
    final x = _number(json, 'x');
    final y = _number(json, 'y');
    final zValue = json['z'];
    final z = zValue == null ? null : _finiteNumber(zValue, 'z');
    return MapCoordinate(x: x, y: y, z: z);
  }

  CoordinateReferenceSystem _decodeCrs(Map<String, Object?> json) {
    final type = _enumByName(
      CoordinateReferenceSystemType.values,
      _requiredString(json, 'type'),
      'crs.type',
    );
    final name = _requiredNonEmptyString(json, 'name');
    switch (type) {
      case CoordinateReferenceSystemType.localCad:
        if (json['utmZone'] != null || json['hemisphere'] != null) {
          throw const ProjectPersistenceException(
            'CRS localCad có metadata UTM không hợp lệ.',
          );
        }
        return CoordinateReferenceSystem.localCad(name: name);
      case CoordinateReferenceSystemType.wgs84:
        if (json['utmZone'] != null || json['hemisphere'] != null) {
          throw const ProjectPersistenceException(
            'CRS WGS84 có metadata UTM không hợp lệ.',
          );
        }
        return CoordinateReferenceSystem.wgs84(name: name);
      case CoordinateReferenceSystemType.utm:
        final zone = json['utmZone'];
        if (zone is! int || zone < 1 || zone > 60) {
          throw const ProjectPersistenceException(
            'UTM zone phải nằm trong 1–60.',
          );
        }
        final hemisphere = _enumByName(
          UtmHemisphere.values,
          _requiredString(json, 'hemisphere'),
          'crs.hemisphere',
        );
        return CoordinateReferenceSystem.utm(
          utmZone: zone,
          hemisphere: hemisphere,
          name: name,
        );
    }
  }

  Map<String, Object?> _requiredObject(Map<String, Object?> json, String key) =>
      _object(json[key], key);

  Map<String, Object?> _object(Object? value, String label) {
    if (value is! Map) {
      throw ProjectPersistenceException('$label phải là JSON object.');
    }
    if (value.keys.any((key) => key is! String)) {
      throw ProjectPersistenceException('$label chứa key không hợp lệ.');
    }
    return value.cast<String, Object?>();
  }

  List<Object?> _requiredList(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! List) {
      throw ProjectPersistenceException('$key phải là JSON array.');
    }
    return value.cast<Object?>();
  }

  String _requiredString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String) {
      throw ProjectPersistenceException('$key phải là chuỗi.');
    }
    return value;
  }

  String _requiredNonEmptyString(Map<String, Object?> json, String key) {
    final value = _requiredString(json, key);
    if (value.trim().isEmpty) {
      throw ProjectPersistenceException('$key không được để trống.');
    }
    return value;
  }

  String? _optionalString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is! String) {
      throw ProjectPersistenceException('$key phải là chuỗi hoặc null.');
    }
    return value;
  }

  bool _requiredBool(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! bool) {
      throw ProjectPersistenceException('$key phải là boolean.');
    }
    return value;
  }

  double _number(Map<String, Object?> json, String key) =>
      _finiteNumber(json[key], key);

  double _finiteNumber(Object? value, String label) {
    if (value is! num) {
      throw ProjectPersistenceException('$label phải là số.');
    }
    return _finite(value.toDouble(), label);
  }

  double _finite(double value, String label) {
    if (!value.isFinite) {
      throw ProjectPersistenceException('$label phải là số hữu hạn.');
    }
    return value;
  }

  Map<String, String> _properties(Map<String, Object?> json, String key) {
    final object = _requiredObject(json, key);
    final result = <String, String>{};
    for (final entry in object.entries) {
      if (entry.value is! String) {
        throw ProjectPersistenceException('$key chỉ được chứa giá trị chuỗi.');
      }
      result[entry.key] = entry.value! as String;
    }
    return result;
  }

  DateTime _date(Map<String, Object?> json, String key) {
    final value = _requiredString(json, key);
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw ProjectPersistenceException('$key không phải timestamp hợp lệ.');
    }
    return parsed.toUtc();
  }

  T _enumByName<T extends Enum>(List<T> values, String name, String label) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    throw ProjectPersistenceException('$label không hợp lệ: $name.');
  }
}
