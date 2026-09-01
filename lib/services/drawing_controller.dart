import '../models/map_feature.dart';

enum DrawingMode { none, point, polyline, polygon }

class DrawingController {
  DrawingMode _mode = DrawingMode.none;
  final List<MapCoordinate> _coordinates = [];
  MapCoordinate? _hoverCoordinate;

  DrawingMode get mode => _mode;

  List<MapCoordinate> get coordinates =>
      List<MapCoordinate>.unmodifiable(_coordinates);

  MapCoordinate? get hoverCoordinate => _hoverCoordinate;

  bool get isDrawing => _mode != DrawingMode.none;

  bool get canFinish {
    switch (_mode) {
      case DrawingMode.none:
        return false;
      case DrawingMode.point:
        return _coordinates.length == 1;
      case DrawingMode.polyline:
        return _coordinates.length >= 2;
      case DrawingMode.polygon:
        return _coordinates.length >= 3;
    }
  }

  void start(DrawingMode mode) {
    _reset();

    if (mode == DrawingMode.none) {
      return;
    }

    _mode = mode;
  }

  void addCoordinate(MapCoordinate coordinate) {
    if (!isDrawing) {
      return;
    }

    if (_mode == DrawingMode.point) {
      if (_coordinates.isEmpty) {
        _coordinates.add(coordinate);
      }
      return;
    }

    _coordinates.add(coordinate);
  }

  void updateHoverCoordinate(MapCoordinate? coordinate) {
    if (!isDrawing) {
      _hoverCoordinate = null;
      return;
    }

    _hoverCoordinate = coordinate;
  }

  MapFeature? finish({
    required String id,
    String name = '',
    String description = '',
    Map<String, String> properties = const {},
    bool visible = true,
  }) {
    if (!canFinish) {
      return null;
    }

    final feature = MapFeature(
      id: id,
      type: _featureTypeForMode(_mode),
      coordinates: List<MapCoordinate>.from(_coordinates),
      name: name,
      description: description,
      properties: Map<String, String>.from(properties),
      visible: visible,
    );

    _reset();

    return feature;
  }

  void cancel() {
    _reset();
  }

  MapFeatureType _featureTypeForMode(DrawingMode mode) {
    switch (mode) {
      case DrawingMode.point:
        return MapFeatureType.point;
      case DrawingMode.polyline:
        return MapFeatureType.polyline;
      case DrawingMode.polygon:
        return MapFeatureType.polygon;
      case DrawingMode.none:
        throw StateError(
          'DrawingMode.none cannot be converted to a MapFeatureType.',
        );
    }
  }

  void _reset() {
    _mode = DrawingMode.none;
    _coordinates.clear();
    _hoverCoordinate = null;
  }
}
