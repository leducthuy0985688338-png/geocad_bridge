import 'package:flutter/material.dart';

import '../models/coordinate_reference_system.dart';
import '../models/map_feature.dart';
import '../models/map_layer.dart';
import '../services/layer_georeference_service.dart';

class LayerGeoreferenceDialog extends StatefulWidget {
  final MapLayer layer;

  const LayerGeoreferenceDialog({super.key, required this.layer});

  @override
  State<LayerGeoreferenceDialog> createState() =>
      _LayerGeoreferenceDialogState();
}

class _LayerGeoreferenceDialogState extends State<LayerGeoreferenceDialog> {
  final LayerGeoreferenceService _service = const LayerGeoreferenceService();
  final List<_ControlPointEntry> _entries = [];

  int _utmZone = 48;
  UtmHemisphere _hemisphere = UtmHemisphere.north;
  GeoreferenceFitResult? _preview;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final defaults = _defaultLocalPoints(widget.layer);
    _entries.addAll([
      _ControlPointEntry.fromLocal(defaults.$1, _format),
      _ControlPointEntry.fromLocal(defaults.$2, _format),
    ]);
  }

  @override
  void dispose() {
    for (final entry in _entries) {
      entry.dispose();
    }
    super.dispose();
  }

  CoordinateReferenceSystem get _targetCrs =>
      CoordinateReferenceSystem.utm(utmZone: _utmZone, hemisphere: _hemisphere);

  (MapCoordinate, MapCoordinate) _defaultLocalPoints(MapLayer layer) {
    final coordinates = layer.features
        .expand((feature) => feature.coordinates)
        .toList();

    if (coordinates.length >= 2) {
      final first = coordinates.first;
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
      return (first, MapCoordinate(x: first.x + 1, y: first.y, z: first.z));
    }

    return (const MapCoordinate(x: 0, y: 0), const MapCoordinate(x: 1, y: 0));
  }

  String _format(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(6);
  }

  double _read(TextEditingController controller, String label) {
    final value = double.tryParse(controller.text.trim().replaceAll(',', '.'));
    if (value == null) {
      throw ArgumentError('$label không phải là số hợp lệ.');
    }
    return value;
  }

  List<GeoreferenceControlPoint> _readControlPoints() {
    return List.generate(_entries.length, (index) {
      final entry = _entries[index];
      final number = index + 1;
      return GeoreferenceControlPoint(
        local: MapCoordinate(
          x: _read(entry.localX, 'CAD X$number'),
          y: _read(entry.localY, 'CAD Y$number'),
        ),
        target: MapCoordinate(
          x: _read(entry.targetX, 'UTM Easting $number'),
          y: _read(entry.targetY, 'UTM Northing $number'),
        ),
      );
    });
  }

  void _invalidatePreview() {
    if (_preview == null && _errorMessage == null) return;
    setState(() {
      _preview = null;
      _errorMessage = null;
    });
  }

  void _addControlPoint() {
    setState(() {
      _entries.add(_ControlPointEntry.empty());
      _preview = null;
      _errorMessage = null;
    });
  }

  void _removeControlPoint(int index) {
    if (_entries.length <= 2) return;
    final removed = _entries.removeAt(index);
    removed.dispose();
    setState(() {
      _preview = null;
      _errorMessage = null;
    });
  }

  void _calculatePreview() {
    try {
      final fit = _service.fitControlPoints(
        controlPoints: _readControlPoints(),
        targetCrs: _targetCrs,
      );
      setState(() {
        _preview = fit;
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
      final points = _readControlPoints();
      _service.fitControlPoints(controlPoints: points, targetCrs: _targetCrs);
      Navigator.of(context).pop(
        LayerGeoreferenceRequest(controlPoints: points, targetCrs: _targetCrs),
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
    if (error is StateError) return error.message;
    return 'Không thể tính phép định vị. Hãy kiểm tra lại các điểm khống chế.';
  }

  @override
  Widget build(BuildContext context) {
    final targetCrs = _targetCrs;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 860),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'CRS đích',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      key: const Key('georeference-zone'),
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
                          _errorMessage = null;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<UtmHemisphere>(
                      key: const Key('georeference-hemisphere'),
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
                          _errorMessage = null;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${targetCrs.displayName} • EPSG:${targetCrs.epsgCode}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF1565C0),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 22),
              ...List.generate(_entries.length, (index) {
                final residual = _preview == null
                    ? null
                    : _preview!.residuals[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _ControlPointEditor(
                    index: index,
                    entry: _entries[index],
                    residual: residual,
                    canRemove: _entries.length > 2,
                    onChanged: _invalidatePreview,
                    onRemove: () => _removeControlPoint(index),
                  ),
                );
              }),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: const Key('add-control-point'),
                  onPressed: _addControlPoint,
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm điểm khống chế'),
                ),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                key: const Key('calculate-georeference-preview'),
                onPressed: _calculatePreview,
                icon: const Icon(Icons.calculate_outlined),
                label: const Text('Tính thử phép định vị'),
              ),
              if (_preview != null) ...[
                const SizedBox(height: 14),
                _FitSummary(fit: _preview!),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                Container(
                  key: const Key('georeference-error'),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              const Text(
                'Nhập ít nhất hai điểm CAD và tọa độ UTM thực tương ứng. '
                'Với nhiều hơn hai điểm, ứng dụng dùng bình sai least-squares.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Hủy'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    key: const Key('apply-georeference'),
                    onPressed: _apply,
                    icon: const Icon(Icons.add_location_alt),
                    label: const Text('Tạo layer đã định vị'),
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
  final List<GeoreferenceControlPoint> controlPoints;
  final CoordinateReferenceSystem targetCrs;

  LayerGeoreferenceRequest({
    required List<GeoreferenceControlPoint> controlPoints,
    required this.targetCrs,
  }) : controlPoints = List<GeoreferenceControlPoint>.unmodifiable(
         controlPoints,
       );

  GeoreferenceControlPoint get point1 => controlPoints[0];
  GeoreferenceControlPoint get point2 => controlPoints[1];
}

class _ControlPointEntry {
  final TextEditingController localX;
  final TextEditingController localY;
  final TextEditingController targetX;
  final TextEditingController targetY;

  _ControlPointEntry({
    required this.localX,
    required this.localY,
    required this.targetX,
    required this.targetY,
  });

  factory _ControlPointEntry.fromLocal(
    MapCoordinate coordinate,
    String Function(double) formatter,
  ) {
    return _ControlPointEntry(
      localX: TextEditingController(text: formatter(coordinate.x)),
      localY: TextEditingController(text: formatter(coordinate.y)),
      targetX: TextEditingController(),
      targetY: TextEditingController(),
    );
  }

  factory _ControlPointEntry.empty() {
    return _ControlPointEntry(
      localX: TextEditingController(),
      localY: TextEditingController(),
      targetX: TextEditingController(),
      targetY: TextEditingController(),
    );
  }

  void dispose() {
    localX.dispose();
    localY.dispose();
    targetX.dispose();
    targetY.dispose();
  }
}

class _ControlPointEditor extends StatelessWidget {
  final int index;
  final _ControlPointEntry entry;
  final GeoreferenceResidual? residual;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _ControlPointEditor({
    required this.index,
    required this.entry,
    required this.residual,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final number = index + 1;
    return Container(
      key: Key('control-point-$index'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDE3E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Điểm khống chế $number',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (canRemove)
                IconButton(
                  key: Key('remove-control-point-$index'),
                  tooltip: 'Xóa điểm $number',
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _NumberField(
                  fieldKey: Key('local-x-$index'),
                  controller: entry.localX,
                  label: 'CAD X',
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _NumberField(
                  fieldKey: Key('local-y-$index'),
                  controller: entry.localY,
                  label: 'CAD Y',
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _NumberField(
                  fieldKey: Key('target-x-$index'),
                  controller: entry.targetX,
                  label: 'UTM Easting',
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _NumberField(
                  fieldKey: Key('target-y-$index'),
                  controller: entry.targetY,
                  label: 'UTM Northing',
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
          if (residual != null) ...[
            const SizedBox(height: 10),
            Text(
              'ΔX: ${residual!.deltaX.toStringAsFixed(4)} m • '
              'ΔY: ${residual!.deltaY.toStringAsFixed(4)} m • '
              'Sai số: ${residual!.planarError.toStringAsFixed(4)} m',
              key: Key('residual-$index'),
              style: const TextStyle(fontSize: 12, color: Color(0xFF455A64)),
            ),
          ],
        ],
      ),
    );
  }
}

class _FitSummary extends StatelessWidget {
  final GeoreferenceFitResult fit;

  const _FitSummary({required this.fit});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('georeference-fit-summary'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFA5D6A7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fit.controlPointCount == 2
                ? 'Phép biến đổi 2 điểm'
                : 'Bình sai ${fit.controlPointCount} điểm',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E7D32),
            ),
          ),
          const SizedBox(height: 8),
          Text('Scale: ${fit.transform.scale.toStringAsFixed(9)}'),
          Text(
            'Rotation: ${fit.transform.rotationDegrees.toStringAsFixed(6)}°',
          ),
          Text(
            'Translation X: ${fit.transform.translationX.toStringAsFixed(3)}',
          ),
          Text(
            'Translation Y: ${fit.transform.translationY.toStringAsFixed(3)}',
          ),
          Text('RMSE: ${fit.rmse.toStringAsFixed(4)} m'),
          Text(
            'Sai số lớn nhất: ${fit.maxResidual.planarError.toStringAsFixed(4)} m '
            '(điểm ${fit.maxResidualIndex + 1})',
          ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final Key fieldKey;
  final TextEditingController controller;
  final String label;
  final VoidCallback onChanged;

  const _NumberField({
    required this.fieldKey,
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: fieldKey,
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: (_) => onChanged(),
    );
  }
}
