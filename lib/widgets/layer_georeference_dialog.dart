import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';

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
      throw ArgumentError(AppLocalizations.of(context).invalidNumber(label));
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
          AppLocalizations.of(context).invalidControlPointData;
    }
    if (error is StateError) return error.message;
    return AppLocalizations.of(context).georeferenceCalculationFailed;
  }

  @override
  Widget build(BuildContext context) {
    final targetCrs = _targetCrs;
    final l10n = AppLocalizations.of(context);

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
                        Text(
                          l10n.georeferenceCadDrawing,
                          style: const TextStyle(
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
                    tooltip: l10n.close,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                l10n.targetCrs,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      key: const Key('georeference-zone'),
                      initialValue: _utmZone,
                      decoration: InputDecoration(
                        labelText: l10n.utmZone,
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
                      decoration: InputDecoration(
                        labelText: l10n.hemisphere,
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: UtmHemisphere.north,
                          child: Text(l10n.north),
                        ),
                        DropdownMenuItem(
                          value: UtmHemisphere.south,
                          child: Text(l10n.south),
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
                    isSuspected:
                        _preview?.assessment.isSuspected(index) ?? false,
                    isUniqueWorst: _preview?.uniqueWorstPointIndex == index,
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
                  label: Text(l10n.addControlPoint),
                ),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                key: const Key('calculate-georeference-preview'),
                onPressed: _calculatePreview,
                icon: const Icon(Icons.calculate_outlined),
                label: Text(l10n.calculateGeoreferencePreview),
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
              Text(
                l10n.georeferenceInstructions,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.cancel),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    key: const Key('apply-georeference'),
                    onPressed: _apply,
                    icon: const Icon(Icons.add_location_alt),
                    label: Text(l10n.createGeoreferencedLayer),
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
  final bool isSuspected;
  final bool isUniqueWorst;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _ControlPointEditor({
    required this.index,
    required this.entry,
    required this.residual,
    required this.isSuspected,
    required this.isUniqueWorst,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final number = index + 1;
    final l10n = AppLocalizations.of(context);
    final highlightColor = isSuspected
        ? const Color(0xFFD84315)
        : isUniqueWorst
        ? const Color(0xFFF9A825)
        : const Color(0xFFDDE3E8);
    return Container(
      key: Key('control-point-$index'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isSuspected
            ? const Color(0xFFFFF3E0)
            : isUniqueWorst
            ? const Color(0xFFFFFDE7)
            : const Color(0xFFF7F9FB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: highlightColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.controlPoint(number),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (isSuspected)
                Text(
                  l10n.suspectedReview,
                  key: Key('suspected-point-label'),
                  style: const TextStyle(
                    color: Color(0xFFD84315),
                    fontWeight: FontWeight.bold,
                  ),
                )
              else if (isUniqueWorst)
                Text(
                  l10n.largestError,
                  key: Key('worst-point-label'),
                  style: const TextStyle(
                    color: Color(0xFFF57F17),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (isSuspected || isUniqueWorst) const SizedBox(width: 8),
              if (canRemove)
                IconButton(
                  key: Key('remove-control-point-$index'),
                  tooltip: l10n.removePoint(number),
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
              l10n.residualSummary(
                residual!.deltaX.toStringAsFixed(4),
                residual!.deltaY.toStringAsFixed(4),
                residual!.planarError.toStringAsFixed(4),
              ),
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
    final assessment = fit.assessment;
    final l10n = AppLocalizations.of(context);
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
                ? l10n.twoPointTransform
                : l10n.leastSquaresAdjustment(fit.controlPointCount),
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
            l10n.maxResidualSummary(
              fit.maxResidual.planarError.toStringAsFixed(4),
              fit.maxResidualIndex + 1,
            ),
          ),
          const SizedBox(height: 8),
          _QualityMessage(assessment: assessment),
        ],
      ),
    );
  }
}

class _QualityMessage extends StatelessWidget {
  final GeoreferenceOutlierAssessment assessment;

  const _QualityMessage({required this.assessment});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (text, color) = switch (assessment.status) {
      GeoreferenceReviewStatus.notApplicable => (
        l10n.outlierNotApplicable,
        const Color(0xFF455A64),
      ),
      GeoreferenceReviewStatus.insufficientSample => (
        l10n.outlierInsufficientSample,
        const Color(0xFFF57F17),
      ),
      GeoreferenceReviewStatus.noRelativeAnomaly => (
        l10n.outlierNoRelativeAnomaly,
        const Color(0xFF2E7D32),
      ),
      GeoreferenceReviewStatus.reviewSuggested => (
        l10n.outlierReviewSuggested,
        const Color(0xFFD84315),
      ),
      GeoreferenceReviewStatus.multipleLargeResiduals => (
        l10n.outlierMultipleLargeResiduals,
        const Color(0xFFD84315),
      ),
    };
    return Text(
      text,
      key: const Key('georeference-quality-message'),
      style: TextStyle(color: color, fontWeight: FontWeight.w600),
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
