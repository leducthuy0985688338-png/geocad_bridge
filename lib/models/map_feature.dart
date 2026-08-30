enum MapFeatureType {
  point,
  line,
  polyline,
  polygon,
  text,
}

class MapCoordinate {
  final double x;
  final double y;
  final double? z;

  const MapCoordinate({
    required this.x,
    required this.y,
    this.z,
  });

  MapCoordinate copyWith({
    double? x,
    double? y,
    double? z,
  }) {
    return MapCoordinate(
      x: x ?? this.x,
      y: y ?? this.y,
      z: z ?? this.z,
    );
  }

  MapCoordinate move({
    required double deltaX,
    required double deltaY,
    double deltaZ = 0,
  }) {
    return MapCoordinate(
      x: x + deltaX,
      y: y + deltaY,
      z: z == null ? null : z! + deltaZ,
    );
  }

  @override
  String toString() {
    if (z != null) {
      return '($x, $y, $z)';
    }

    return '($x, $y)';
  }
}

class MapFeature {
  final String id;
  final MapFeatureType type;
  final List<MapCoordinate> coordinates;

  final String name;
  final String? description;

  final Map<String, String> properties;

  final bool visible;

  const MapFeature({
    required this.id,
    required this.type,
    required this.coordinates,
    this.name = '',
    this.description,
    this.properties = const {},
    this.visible = true,
  });

  bool get isPoint =>
      type == MapFeatureType.point;

  bool get isLine =>
      type == MapFeatureType.line;

  bool get isPolyline =>
      type == MapFeatureType.polyline;

  bool get isPolygon =>
      type == MapFeatureType.polygon;

  bool get isText =>
      type == MapFeatureType.text;

  int get coordinateCount =>
      coordinates.length;

  bool get hasCoordinates =>
      coordinates.isNotEmpty;

  MapCoordinate? coordinateAt(
    int index,
  ) {
    if (index < 0 ||
        index >= coordinates.length) {
      return null;
    }

    return coordinates[index];
  }

  MapFeature copyWith({
    String? id,
    MapFeatureType? type,
    List<MapCoordinate>? coordinates,
    String? name,
    String? description,
    Map<String, String>? properties,
    bool? visible,
  }) {
    return MapFeature(
      id: id ?? this.id,
      type: type ?? this.type,
      coordinates:
          coordinates ?? this.coordinates,
      name: name ?? this.name,
      description:
          description ?? this.description,
      properties:
          properties ?? this.properties,
      visible: visible ?? this.visible,
    );
  }

  /// Thay một đỉnh bằng tọa độ mới.
  ///
  /// Nếu index không hợp lệ, giữ nguyên feature.
  MapFeature updateCoordinate({
    required int index,
    required MapCoordinate coordinate,
  }) {
    if (index < 0 ||
        index >= coordinates.length) {
      return this;
    }

    final updatedCoordinates =
        List<MapCoordinate>.from(
      coordinates,
    );

    updatedCoordinates[index] =
        coordinate;

    return copyWith(
      coordinates: updatedCoordinates,
    );
  }

  /// Di chuyển một đỉnh theo delta.
  MapFeature moveCoordinate({
    required int index,
    required double deltaX,
    required double deltaY,
    double deltaZ = 0,
  }) {
    final current =
        coordinateAt(index);

    if (current == null) {
      return this;
    }

    return updateCoordinate(
      index: index,
      coordinate: current.move(
        deltaX: deltaX,
        deltaY: deltaY,
        deltaZ: deltaZ,
      ),
    );
  }

  /// Thêm một đỉnh vào cuối danh sách.
  MapFeature addCoordinate(
    MapCoordinate coordinate,
  ) {
    final updatedCoordinates =
        List<MapCoordinate>.from(
      coordinates,
    )..add(coordinate);

    return copyWith(
      coordinates: updatedCoordinates,
    );
  }

  /// Chèn một đỉnh vào vị trí xác định.
  MapFeature insertCoordinate({
    required int index,
    required MapCoordinate coordinate,
  }) {
    if (index < 0 ||
        index > coordinates.length) {
      return this;
    }

    final updatedCoordinates =
        List<MapCoordinate>.from(
      coordinates,
    );

    updatedCoordinates.insert(
      index,
      coordinate,
    );

    return copyWith(
      coordinates: updatedCoordinates,
    );
  }

  /// Xóa một đỉnh.
  ///
  /// Hiện tại model chỉ xử lý dữ liệu.
  /// Quy tắc số đỉnh tối thiểu của LINE/POLYGON
  /// sẽ được kiểm soát ở Edit Service.
  MapFeature removeCoordinate(
    int index,
  ) {
    if (index < 0 ||
        index >= coordinates.length) {
      return this;
    }

    final updatedCoordinates =
        List<MapCoordinate>.from(
      coordinates,
    );

    updatedCoordinates.removeAt(index);

    return copyWith(
      coordinates: updatedCoordinates,
    );
  }

  /// Di chuyển toàn bộ đối tượng.
  MapFeature move({
    required double deltaX,
    required double deltaY,
    double deltaZ = 0,
  }) {
    final movedCoordinates =
        coordinates.map(
      (coordinate) {
        return coordinate.move(
          deltaX: deltaX,
          deltaY: deltaY,
          deltaZ: deltaZ,
        );
      },
    ).toList();

    return copyWith(
      coordinates: movedCoordinates,
    );
  }

  MapFeature setProperty(
    String key,
    String value,
  ) {
    final updatedProperties =
        Map<String, String>.from(
      properties,
    );

    updatedProperties[key] = value;

    return copyWith(
      properties: updatedProperties,
    );
  }

  MapFeature setProperties(
    Map<String, String> newProperties,
  ) {
    final updatedProperties =
        Map<String, String>.from(
      properties,
    );

    updatedProperties.addAll(
      newProperties,
    );

    return copyWith(
      properties: updatedProperties,
    );
  }

  MapFeature removeProperty(
    String key,
  ) {
    final updatedProperties =
        Map<String, String>.from(
      properties,
    );

    updatedProperties.remove(key);

    return copyWith(
      properties: updatedProperties,
    );
  }

  @override
  String toString() {
    return 'MapFeature('
        'id: $id, '
        'type: $type, '
        'name: $name, '
        'coordinates: ${coordinates.length}, '
        'properties: ${properties.length}'
        ')';
  }
}