import 'dart:convert';
import 'dart:typed_data';

import 'package:xml/xml.dart';

import '../models/map_feature.dart';
import '../models/map_layer.dart';

class KmlExportService {
  const KmlExportService();

  static const _internalKmlPropertyKeys = {
    'kmlGeometry',
    'kmlFromMultiGeometry',
    'kmlAltitudeMode',
  };

  String exportLayers({
    required String documentName,
    required List<MapLayer> layers,
  }) {
    if (layers.isEmpty) {
      throw const KmlExportException('Không có layer để xuất KML.');
    }

    final invalidLayers = layers
        .where((layer) => !layer.crs.isWgs84)
        .map((layer) => layer.name)
        .toList();

    if (invalidLayers.isNotEmpty) {
      throw KmlExportException(
        'KML chỉ nhận dữ liệu WGS84 (EPSG:4326). '
        'Layer chưa phải WGS84: ${invalidLayers.join(', ')}.',
      );
    }

    final builder = XmlBuilder();

    builder.processing('xml', 'version="1.0" encoding="UTF-8"');

    builder.element(
      'kml',
      attributes: {'xmlns': 'http://www.opengis.net/kml/2.2'},
      nest: () {
        builder.element(
          'Document',
          nest: () {
            builder.element('name', nest: documentName);

            for (final layer in layers) {
              _writeLayer(builder, layer);
            }
          },
        );
      },
    );

    return builder.buildDocument().toXmlString(pretty: true, indent: '  ');
  }

  Uint8List exportLayersAsBytes({
    required String documentName,
    required List<MapLayer> layers,
  }) {
    return Uint8List.fromList(
      utf8.encode(exportLayers(documentName: documentName, layers: layers)),
    );
  }

  void _writeLayer(XmlBuilder builder, MapLayer layer) {
    builder.element(
      'Folder',
      nest: () {
        builder.element('name', nest: layer.name);

        for (final feature in layer.features) {
          if (!feature.visible || feature.coordinates.isEmpty) {
            continue;
          }

          _validateCoordinates(feature, layer);
          _writeFeature(builder, feature);
        }
      },
    );
  }

  void _validateCoordinates(MapFeature feature, MapLayer layer) {
    for (final coordinate in feature.coordinates) {
      final valid =
          coordinate.x.isFinite &&
          coordinate.y.isFinite &&
          coordinate.x >= -180 &&
          coordinate.x <= 180 &&
          coordinate.y >= -90 &&
          coordinate.y <= 90 &&
          (coordinate.z == null || coordinate.z!.isFinite);

      if (!valid) {
        throw KmlExportException(
          'Tọa độ không hợp lệ trong feature "${feature.name.isEmpty ? feature.id : feature.name}" '
          'của layer "${layer.name}".',
        );
      }
    }
  }

  void _writeFeature(XmlBuilder builder, MapFeature feature) {
    builder.element(
      'Placemark',
      nest: () {
        builder.element(
          'name',
          nest: feature.name.isEmpty ? feature.id : feature.name,
        );

        final description = feature.description;
        if (description != null && description.isNotEmpty) {
          builder.element('description', nest: description);
        }

        final exportProperties = feature.properties.entries
            .where((entry) => !_internalKmlPropertyKeys.contains(entry.key))
            .toList();

        if (exportProperties.isNotEmpty) {
          builder.element(
            'ExtendedData',
            nest: () {
              for (final entry in exportProperties) {
                builder.element(
                  'Data',
                  attributes: {'name': entry.key},
                  nest: () {
                    builder.element('value', nest: entry.value);
                  },
                );
              }
            },
          );
        }

        switch (feature.type) {
          case MapFeatureType.point:
          case MapFeatureType.text:
            _writePoint(builder, feature);
            return;

          case MapFeatureType.line:
          case MapFeatureType.polyline:
            if (feature.coordinates.length < 2) {
              throw KmlExportException(
                'Line/Polyline "${feature.name.isEmpty ? feature.id : feature.name}" '
                'phải có ít nhất 2 tọa độ.',
              );
            }
            _writeLineString(builder, feature);
            return;

          case MapFeatureType.polygon:
            if (feature.coordinates.length < 3) {
              throw KmlExportException(
                'Polygon "${feature.name.isEmpty ? feature.id : feature.name}" '
                'phải có ít nhất 3 tọa độ.',
              );
            }
            _writePolygon(builder, feature);
            return;
        }
      },
    );
  }

  void _writePoint(XmlBuilder builder, MapFeature feature) {
    final coordinate = feature.coordinates.first;

    builder.element(
      'Point',
      nest: () {
        _writeAltitudeMode(builder, feature);
        builder.element('coordinates', nest: _coordinateTuple(coordinate));
      },
    );
  }

  void _writeLineString(XmlBuilder builder, MapFeature feature) {
    final coordinates = feature.coordinates;

    builder.element(
      'LineString',
      nest: () {
        builder.element('tessellate', nest: '1');
        _writeAltitudeMode(builder, feature);
        builder.element(
          'coordinates',
          nest: coordinates.map(_coordinateTuple).join(' '),
        );
      },
    );
  }

  void _writePolygon(XmlBuilder builder, MapFeature feature) {
    final ring = List<MapCoordinate>.from(feature.coordinates);
    final first = ring.first;
    final last = ring.last;

    if (first.x != last.x || first.y != last.y || first.z != last.z) {
      ring.add(first);
    }

    builder.element(
      'Polygon',
      nest: () {
        _writeAltitudeMode(builder, feature);
        builder.element(
          'outerBoundaryIs',
          nest: () {
            builder.element(
              'LinearRing',
              nest: () {
                builder.element(
                  'coordinates',
                  nest: ring.map(_coordinateTuple).join(' '),
                );
              },
            );
          },
        );
      },
    );
  }

  void _writeAltitudeMode(XmlBuilder builder, MapFeature feature) {
    final preservedMode = feature.properties['kmlAltitudeMode']?.trim();

    final altitudeMode = preservedMode != null && preservedMode.isNotEmpty
        ? preservedMode
        : feature.coordinates.any((coordinate) => coordinate.z != null)
        ? 'absolute'
        : 'clampToGround';

    builder.element('altitudeMode', nest: altitudeMode);
  }

  String _coordinateTuple(MapCoordinate coordinate) {
    return '${_formatNumber(coordinate.x)},'
        '${_formatNumber(coordinate.y)},'
        '${_formatNumber(coordinate.z ?? 0)}';
  }

  String _formatNumber(double value) {
    if (value == 0) return '0';
    return value.toStringAsPrecision(15);
  }
}

class KmlExportException implements Exception {
  final String message;

  const KmlExportException(this.message);

  @override
  String toString() => message;
}
