import 'map_feature.dart';

class MapFeatureChange {
  final MapFeature originalFeature;
  final MapFeature updatedFeature;

  const MapFeatureChange({
    required this.originalFeature,
    required this.updatedFeature,
  });
}