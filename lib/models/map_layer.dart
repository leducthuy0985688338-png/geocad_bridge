import 'coordinate_reference_system.dart';
import 'map_feature.dart';

enum MapLayerSourceType {
  dwg,
  dxf,
  kml,
  kmz,
  manual,
}

class MapLayer {
  final String id;
  final String name;

  /// File nguồn của layer.
  /// Có thể null nếu layer được tạo trực tiếp trong ứng dụng.
  final String? sourcePath;

  final MapLayerSourceType sourceType;

  /// Hệ tọa độ của layer.
  ///
  /// Mặc định là CAD cục bộ / chưa xác định để bảo đảm các
  /// DWG/DXF cũ vẫn hoạt động an toàn cho đến khi người dùng
  /// khai báo CRS chính xác.
  final CoordinateReferenceSystem crs;

  /// Danh sách toàn bộ đối tượng hình học thuộc layer.
  final List<MapFeature> features;

  /// Cho phép bật/tắt layer trên bản đồ.
  final bool visible;

  /// Cho phép khóa layer để tránh chỉnh sửa nhầm.
  final bool locked;

  /// Thông tin bổ sung của layer.
  final Map<String, String> properties;

  const MapLayer({
    required this.id,
    required this.name,
    required this.sourceType,
    this.sourcePath,
    this.crs = const CoordinateReferenceSystem.localCad(),
    this.features = const [],
    this.visible = true,
    this.locked = false,
    this.properties = const {},
  });

  int get featureCount => features.length;

  bool get isEmpty => features.isEmpty;

  bool get isNotEmpty => features.isNotEmpty;

  bool get isCad =>
      sourceType == MapLayerSourceType.dwg ||
      sourceType == MapLayerSourceType.dxf;

  bool get isGoogleEarth =>
      sourceType == MapLayerSourceType.kml ||
      sourceType == MapLayerSourceType.kmz;

  bool get hasKnownCrs => !crs.isLocalCad;

  bool get canTransformToWgs84 =>
      crs.isWgs84 || (crs.isUtm && crs.isValid);

  String get crsLabel => crs.displayName;

  int? get epsgCode => crs.epsgCode;

  MapLayer copyWith({
    String? id,
    String? name,
    String? sourcePath,
    MapLayerSourceType? sourceType,
    CoordinateReferenceSystem? crs,
    List<MapFeature>? features,
    bool? visible,
    bool? locked,
    Map<String, String>? properties,
  }) {
    return MapLayer(
      id: id ?? this.id,
      name: name ?? this.name,
      sourcePath: sourcePath ?? this.sourcePath,
      sourceType: sourceType ?? this.sourceType,
      crs: crs ?? this.crs,
      features: features ?? this.features,
      visible: visible ?? this.visible,
      locked: locked ?? this.locked,
      properties: properties ?? this.properties,
    );
  }

  MapLayer withCrs(
    CoordinateReferenceSystem newCrs,
  ) {
    return copyWith(
      crs: newCrs,
    );
  }

  MapLayer addFeature(MapFeature feature) {
    final updatedFeatures = List<MapFeature>.from(features)
      ..add(feature);

    return copyWith(
      features: updatedFeatures,
    );
  }

  MapLayer addFeatures(Iterable<MapFeature> newFeatures) {
    final updatedFeatures = List<MapFeature>.from(features)
      ..addAll(newFeatures);

    return copyWith(
      features: updatedFeatures,
    );
  }

  MapLayer updateFeature(MapFeature feature) {
    final index = features.indexWhere(
      (item) => item.id == feature.id,
    );

    if (index == -1) {
      return this;
    }

    final updatedFeatures = List<MapFeature>.from(features);

    updatedFeatures[index] = feature;

    return copyWith(
      features: updatedFeatures,
    );
  }

  MapLayer removeFeature(String featureId) {
    final updatedFeatures = features
        .where(
          (feature) => feature.id != featureId,
        )
        .toList();

    return copyWith(
      features: updatedFeatures,
    );
  }

  MapLayer clearFeatures() {
    return copyWith(
      features: const [],
    );
  }

  MapLayer setProperty(
    String key,
    String value,
  ) {
    final updatedProperties =
        Map<String, String>.from(properties);

    updatedProperties[key] = value;

    return copyWith(
      properties: updatedProperties,
    );
  }

  MapLayer removeProperty(String key) {
    final updatedProperties =
        Map<String, String>.from(properties);

    updatedProperties.remove(key);

    return copyWith(
      properties: updatedProperties,
    );
  }

  @override
  String toString() {
    return 'MapLayer('
        'id: $id, '
        'name: $name, '
        'sourceType: $sourceType, '
        'crs: ${crs.displayName}, '
        'features: $featureCount, '
        'visible: $visible, '
        'locked: $locked'
        ')';
  }
}
