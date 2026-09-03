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
    'kml.styleUrl',
    'style.strokeColor',
    'style.strokeOpacity',
    'style.strokeWidth',
    'style.fillColor',
    'style.fillOpacity',
    'style.fill',
    'style.outline',
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

        final styleUrl = feature.properties['kml.styleUrl']?.trim();
        if (styleUrl != null && styleUrl.isNotEmpty) {
          builder.element('styleUrl', nest: styleUrl);
        }

        _writeInlineStyle(builder, feature);

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

  void _writeInlineStyle(XmlBuilder builder, MapFeature feature) {
    final strokeColor = _canonicalColor(
      feature.properties['style.strokeColor'],
    );
    final strokeOpacity = _canonicalOpacity(
      feature.properties['style.strokeOpacity'],
    );
    final strokeWidth = _canonicalWidth(
      feature.properties['style.strokeWidth'],
    );
    final fillColor = _canonicalColor(feature.properties['style.fillColor']);
    final fillOpacity = _canonicalOpacity(
      feature.properties['style.fillOpacity'],
    );
    final fill = _binaryFlag(feature.properties['style.fill']);
    final outline = _binaryFlag(feature.properties['style.outline']);

    final hasLineStyle =
        strokeColor != null || strokeOpacity != null || strokeWidth != null;
    final hasPolyStyle =
        fillColor != null ||
        fillOpacity != null ||
        fill != null ||
        outline != null;

    if (!hasLineStyle && !hasPolyStyle) return;

    builder.element(
      'Style',
      nest: () {
        if (hasLineStyle) {
          builder.element(
            'LineStyle',
            nest: () {
              if (strokeColor != null || strokeOpacity != null) {
                builder.element(
                  'color',
                  nest: _toKmlColor(
                    strokeColor ?? '#FFFFFF',
                    strokeOpacity ?? 1,
                  ),
                );
              }
              if (strokeWidth != null) {
                builder.element('width', nest: _formatStyleNumber(strokeWidth));
              }
            },
          );
        }

        if (hasPolyStyle) {
          builder.element(
            'PolyStyle',
            nest: () {
              if (fillColor != null || fillOpacity != null) {
                builder.element(
                  'color',
                  nest: _toKmlColor(fillColor ?? '#FFFFFF', fillOpacity ?? 1),
                );
              }
              if (fill != null) {
                builder.element('fill', nest: fill);
              }
              if (outline != null) {
                builder.element('outline', nest: outline);
              }
            },
          );
        }
      },
    );
  }

  String? _canonicalColor(String? raw) {
    if (raw == null) return null;
    final value = raw.trim();
    if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value)) return null;
    return value.toUpperCase();
  }

  double? _canonicalOpacity(String? raw) {
    if (raw == null) return null;
    final value = double.tryParse(raw.trim());
    if (value == null || !value.isFinite || value < 0 || value > 1) return null;
    return value;
  }

  double? _canonicalWidth(String? raw) {
    if (raw == null) return null;
    final value = double.tryParse(raw.trim());
    if (value == null || !value.isFinite || value < 0) return null;
    return value;
  }

  String? _binaryFlag(String? raw) {
    final value = raw?.trim();
    return value == '0' || value == '1' ? value : null;
  }

  String _toKmlColor(String rgb, double opacity) {
    final red = rgb.substring(1, 3);
    final green = rgb.substring(3, 5);
    final blue = rgb.substring(5, 7);
    final alpha = (opacity * 255).round().clamp(0, 255);
    final alphaHex = alpha.toRadixString(16).padLeft(2, '0').toUpperCase();
    return '$alphaHex$blue$green$red'.toLowerCase();
  }

  String _formatStyleNumber(double value) {
    if (value == 0) return '0';
    if (value == 1) return '1';
    return value
        .toStringAsFixed(6)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
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
    final horizontal =
        '${_formatNumber(coordinate.x)},'
        '${_formatNumber(coordinate.y)}';
    final z = coordinate.z;
    return z == null ? horizontal : '$horizontal,${_formatNumber(z)}';
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
