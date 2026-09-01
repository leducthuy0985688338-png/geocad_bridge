import 'coordinate_reference_system.dart';
import 'map_feature.dart';
import 'map_layer.dart';

class MapProject {
  final String id;
  final String name;

  /// Hệ tọa độ chuẩn dùng cho canvas, drawing và các tương tác không gian.
  final CoordinateReferenceSystem canvasCrs;

  /// Danh sách tất cả layer trong project.
  final List<MapLayer> layers;

  /// Thông tin mô tả dự án.
  final String? description;

  /// Thuộc tính mở rộng của dự án.
  final Map<String, String> properties;

  const MapProject({
    required this.id,
    required this.name,
    this.canvasCrs = const CoordinateReferenceSystem.localCad(),
    this.layers = const [],
    this.description,
    this.properties = const {},
  });

  int get layerCount => layers.length;

  int get featureCount {
    return layers.fold(0, (total, layer) => total + layer.featureCount);
  }

  bool get isEmpty => layers.isEmpty;

  bool get isNotEmpty => layers.isNotEmpty;

  List<MapLayer> get visibleLayers {
    return layers.where((layer) => layer.visible).toList();
  }

  List<MapLayer> get cadLayers {
    return layers.where((layer) => layer.isCad).toList();
  }

  List<MapLayer> get googleEarthLayers {
    return layers.where((layer) => layer.isGoogleEarth).toList();
  }

  List<MapFeature> get allFeatures {
    return layers.expand((layer) => layer.features).toList();
  }

  List<MapFeature> get visibleFeatures {
    return visibleLayers
        .expand((layer) => layer.features.where((feature) => feature.visible))
        .toList();
  }

  MapProject copyWith({
    String? id,
    String? name,
    CoordinateReferenceSystem? canvasCrs,
    List<MapLayer>? layers,
    String? description,
    Map<String, String>? properties,
  }) {
    return MapProject(
      id: id ?? this.id,
      name: name ?? this.name,
      canvasCrs: canvasCrs ?? this.canvasCrs,
      layers: layers ?? this.layers,
      description: description ?? this.description,
      properties: properties ?? this.properties,
    );
  }

  MapProject addLayer(MapLayer layer) {
    final updatedLayers = List<MapLayer>.from(layers)..add(layer);

    return copyWith(layers: updatedLayers);
  }

  MapProject addLayers(Iterable<MapLayer> newLayers) {
    final updatedLayers = List<MapLayer>.from(layers)..addAll(newLayers);

    return copyWith(layers: updatedLayers);
  }

  MapProject updateLayer(MapLayer layer) {
    final index = layers.indexWhere((item) => item.id == layer.id);

    if (index == -1) {
      return this;
    }

    final updatedLayers = List<MapLayer>.from(layers);

    updatedLayers[index] = layer;

    return copyWith(layers: updatedLayers);
  }

  MapProject removeLayer(String layerId) {
    final updatedLayers = layers.where((layer) => layer.id != layerId).toList();

    return copyWith(layers: updatedLayers);
  }

  MapProject clearLayers() {
    return copyWith(layers: const []);
  }

  MapProject moveLayerUp(String layerId) {
    final index = layers.indexWhere((layer) => layer.id == layerId);

    if (index <= 0) {
      return this;
    }

    final updatedLayers = List<MapLayer>.from(layers);

    final layer = updatedLayers.removeAt(index);
    updatedLayers.insert(index - 1, layer);

    return copyWith(layers: updatedLayers);
  }

  MapProject moveLayerDown(String layerId) {
    final index = layers.indexWhere((layer) => layer.id == layerId);

    if (index == -1 || index >= layers.length - 1) {
      return this;
    }

    final updatedLayers = List<MapLayer>.from(layers);

    final layer = updatedLayers.removeAt(index);
    updatedLayers.insert(index + 1, layer);

    return copyWith(layers: updatedLayers);
  }

  MapProject setProperty(String key, String value) {
    final updatedProperties = Map<String, String>.from(properties);

    updatedProperties[key] = value;

    return copyWith(properties: updatedProperties);
  }

  MapProject removeProperty(String key) {
    final updatedProperties = Map<String, String>.from(properties);

    updatedProperties.remove(key);

    return copyWith(properties: updatedProperties);
  }

  @override
  String toString() {
    return 'MapProject('
        'id: $id, '
        'name: $name, '
        'canvasCrs: ${canvasCrs.displayName}, '
        'layers: $layerCount, '
        'features: $featureCount'
        ')';
  }
}
