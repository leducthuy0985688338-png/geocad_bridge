import 'package:flutter/material.dart';

import '../models/coordinate_reference_system.dart';
import '../models/map_feature.dart';
import '../models/map_layer.dart';
import '../services/layer_georeference_service.dart';

class LayerGeoreferenceDialog extends StatefulWidget {
  final MapLayer layer;

  const LayerGeoreferenceDialog({
    super.key,
    required this.layer,
  });

  @override
  State<LayerGeoreferenceDialog> createState() =>
      _LayerGeoreferenceDialogState();
}

class _LayerGeoreferenceDialogState
    extends State<LayerGeoreferenceDialog> {
  final LayerGeoreferenceService _service =
      const LayerGeoreferenceService();

  late final TextEditingController _local1X;
  late final TextEditingController _local1Y;
  late final TextEditingController _target1X;
  late final TextEditingController _target1Y;

  late final TextEditingController _local2X;
  late final TextEditingController _local2Y;
  late final TextEditingController _target2X;
  late final TextEditingController _target2Y;

  int _utmZone = 48;
  UtmHemisphere _hemisphere = UtmHemisphere.north;

  GeoreferenceTransform? _preview;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    final defaults = _defaultLocalPoints(widget.layer);

    _local1X = TextEditingController(
      text: _format(defaults.$1.x),
    );
    _local1Y = TextEditingController(
      text: _format(defaults.$1.y),
    );
    _target1X = TextEditingController();

    _target1Y = TextEditingController();

    _local2X = TextEditingController(
      text: _format(defaults.$2.x),
    );
    _local2Y = TextEditingController(
      text: _format(defaults.$2.y),
    );
    _target2X = TextEditingController();
    _target2Y = TextEditingController();
  }

  @override
  void dispose() {
    _local1X.dispose();
    _local1Y.dispose();
    _target1X.dispose();
    _target1Y.dispose();
    _local2X.dispose();
    _local2Y.dispose();
    _target2X.dispose();
    _target2Y.dispose();
    super.dispose();
  }

  (MapCoordinate, MapCoordinate) _defaultLocalPoints(
    MapLayer layer,
  ) {
    final coordinates = layer.features
        .expand((feature) => feature.coordinates)
        .toList();

    if (coordinates.length >= 2) {
      var first = coordinates.first;
      var second = coordinates[1];
      var bestDistanceSquared = -1.0;

      for (final candidate in coordinates.skip(1)) {
        final dx = candidate.x - first.x;
        final dy = candidate.y - first.y;
        final distanceSquared = dx * dx + dy * dy;

        if (distanceSquared > bestDistanceSquared) {
          bestDistanceSquared = distanceSquared;
          second = candidate;
        }
      }

      return (first, second);
    }

    if (coordinates.length == 1) {
      final first = coordinates.first;
      return (
        first,
        MapCoordinate(
          x: first.x + 1,
          y: first.y,
          z: first.z,
        ),
      );
    }

    return (
      const MapCoordinate(x: 0, y: 0),
      const MapCoordinate(x: 1, y: 0),
    );
  }

  String _format(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(6);
  }

  double _read(
    TextEditingController controller,
    String label,
  ) {
    final value = double.tryParse(
      controller.text.trim().replaceAll(',', '.'),
    );

    if (value == null) {
      throw ArgumentError(
        '$label không phải là số hợp lệ.',
      );
    }

    return value;
  }

  GeoreferenceControlPoint _readPoint1() {
    return GeoreferenceControlPoint(
      local: MapCoordinate(
        x: _read(_local1X, 'CAD X1'),
        y: _read(_local1Y, 'CAD Y1'),
      ),
      target: MapCoordinate(
        x: _read(_target1X, 'UTM Easting 1'),
        y: _read(_target1Y, 'UTM Northing 1'),
      ),
    );
  }

  GeoreferenceControlPoint _readPoint2() {
    return GeoreferenceControlPoint(
      local: MapCoordinate(
        x: _read(_local2X, 'CAD X2'),
        y: _read(_local2Y, 'CAD Y2'),
      ),
      target: MapCoordinate(
        x: _read(_target2X, 'UTM Easting 2'),
        y: _read(_target2Y, 'UTM Northing 2'),
      ),
    );
  }

  CoordinateReferenceSystem get _targetCrs =>
      CoordinateReferenceSystem.utm(
        utmZone: _utmZone,
        hemisphere: _hemisphere,
      );

  void _calculatePreview() {
    try {
      final transform = _service.calculateTransform(
        point1: _readPoint1(),
        point2: _readPoint2(),
      );

      setState(() {
        _preview = transform;
        _errorMessage = null;
      });
    } catch (error) {
      setState(() {
        _preview = null;
        _errorMessage = _friendlyError(error);
      });
    }
  }

  void _apply() {
    try {
      final point1 = _readPoint1();
      final point2 = _readPoint2();

      _service.calculateTransform(
        point1: point1,
        point2: point2,
      );

      Navigator.of(context).pop(
        LayerGeoreferenceRequest(
          point1: point1,
          point2: point2,
          targetCrs: _targetCrs,
        ),
      );
    } catch (error) {
      setState(() {
        _preview = null;
        _errorMessage = _friendlyError(error);
      });
    }
  }

  String _friendlyError(Object error) {
    if (error is ArgumentError) {
      return error.message?.toString() ??
          'Dữ liệu điểm khống chế không hợp lệ.';
    }

    return 'Không thể tính phép định vị. '
        'Hãy kiểm tra lại các điểm khống chế.';
  }

  @override
  Widget build(BuildContext context) {
    final targetCrs = _targetCrs;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 820,
          maxHeight: 820,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.add_location_alt_outlined,
                    color: Color(0xFF1565C0),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Định vị bản vẽ CAD',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.layer.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'CRS đích',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _utmZone,
                      decoration: const InputDecoration(
                        labelText: 'UTM Zone',
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(
                        60,
                        (index) => DropdownMenuItem(
                          value: index + 1,
                          child: Text('Zone ${index + 1}'),
                        ),
                      ),
                      onChanged: (value) {
                        if (value == null) return;

                        setState(() {
                          _utmZone = value;
                          _preview = null;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child:
                        DropdownButtonFormField<UtmHemisphere>(
                      initialValue: _hemisphere,
                      decoration: const InputDecoration(
                        labelText: 'Bán cầu',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: UtmHemisphere.north,
                          child: Text('Bắc (North)'),
                        ),
                        DropdownMenuItem(
                          value: UtmHemisphere.south,
                          child: Text('Nam (South)'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;

                        setState(() {
                          _hemisphere = value;
                          _preview = null;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${targetCrs.displayName} • '
                'EPSG:${targetCrs.epsgCode}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF1565C0),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 22),
              _ControlPointEditor(
                title: 'Điểm khống chế 1',
                localX: _local1X,
                localY: _local1Y,
                targetX: _target1X,
                targetY: _target1Y,
              ),
              const SizedBox(height: 16),
              _ControlPointEditor(
                title: 'Điểm khống chế 2',
                localX: _local2X,
                localY: _local2Y,
                targetX: _target2X,
                targetY: _target2Y,
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: _calculatePreview,
                icon: const Icon(Icons.calculate_outlined),
                label: const Text(
                  'Tính thử phép định vị',
                ),
              ),
              if (_preview != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFA5D6A7),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Phép biến đổi 2 điểm',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Scale: '
                        '${_preview!.scale.toStringAsFixed(9)}',
                      ),
                      Text(
                        'Rotation: '
                        '${_preview!.rotationDegrees.toStringAsFixed(6)}°',
                      ),
                      Text(
                        'Translation X: '
                        '${_preview!.translationX.toStringAsFixed(3)}',
                      ),
                      Text(
                        'Translation Y: '
                        '${_preview!.translationY.toStringAsFixed(3)}',
                      ),
                    ],
                  ),
                ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onErrorContainer,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              const Text(
                'Hai điểm CAD phải là hai vị trí khác nhau '
                'trên bản vẽ. Hai tọa độ UTM tương ứng phải là '
                'tọa độ thực của đúng hai vị trí đó.',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Hủy'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _apply,
                    icon: const Icon(Icons.add_location_alt),
                    label: const Text(
                      'Tạo layer đã định vị',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LayerGeoreferenceRequest {
  final GeoreferenceControlPoint point1;
  final GeoreferenceControlPoint point2;
  final CoordinateReferenceSystem targetCrs;

  const LayerGeoreferenceRequest({
    required this.point1,
    required this.point2,
    required this.targetCrs,
  });
}

class _ControlPointEditor extends StatelessWidget {
  final String title;
  final TextEditingController localX;
  final TextEditingController localY;
  final TextEditingController targetX;
  final TextEditingController targetY;

  const _ControlPointEditor({
    required this.title,
    required this.localX,
    required this.localY,
    required this.targetX,
    required this.targetY,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFDDE3E8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Tọa độ CAD cục bộ',
            style: TextStyle(
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _NumberField(
                  controller: localX,
                  label: 'CAD X',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _NumberField(
                  controller: localY,
                  label: 'CAD Y',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Tọa độ UTM thực tương ứng',
            style: TextStyle(
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _NumberField(
                  controller: targetX,
                  label: 'Easting',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _NumberField(
                  controller: targetY,
                  label: 'Northing',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _NumberField({
    required this.controller,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType:
          const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}
