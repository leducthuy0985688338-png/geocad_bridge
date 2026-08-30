import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../models/map_feature.dart';
import '../models/map_feature_change.dart';
import '../models/map_project.dart';
import '../services/map_selection_service.dart';
import '../services/map_snap_service.dart';
import 'cad_grid_painter.dart';
import 'selection_painter.dart';
import 'snap_painter.dart';

class MapCanvas extends StatefulWidget {
  final MapProject project;
  final ValueChanged<MapFeatureChange>? onFeatureChanged;

  const MapCanvas({super.key, required this.project, this.onFeatureChanged});

  @override
  State<MapCanvas> createState() => _MapCanvasState();
}

class _MapCanvasState extends State<MapCanvas> {
  final MapSelectionService _selectionService = const MapSelectionService();

  final MapSnapService _snapService = const MapSnapService();

  double _zoom = 1.0;
  Offset _pan = Offset.zero;

  bool _isPanning = false;
  bool _pointerMoved = false;
  bool _isEditingVertex = false;
  bool _isMovingFeature = false;

  Offset? _lastPanPosition;
  Offset? _pointerDownPosition;

  MapCoordinate? _mouseCoordinate;

  MapFeature? _selectedFeature;
  MapFeature? _previewFeature;

  MapSnapResult? _snapResult;

  int? _editingCoordinateIndex;
  MapCoordinate? _moveStartCoordinate;

  static const double _minZoom = 0.05;
  static const double _maxZoom = 100.0;

  static const double _selectionTolerancePixels = 10.0;
  static const double _snapTolerancePixels = 12.0;
  static const double _clickMovementTolerance = 4.0;

  List<MapFeature> get _projectFeatures {
    return widget.project.visibleFeatures;
  }

  List<MapFeature> get _displayFeatures {
    final preview = _previewFeature;

    if (preview == null) {
      return _projectFeatures;
    }

    return _projectFeatures.map((feature) {
      if (identical(feature, _selectedFeature)) {
        return preview;
      }

      return feature;
    }).toList();
  }

  MapFeature? get _displaySelectedFeature {
    final preview = _previewFeature;

    if (preview != null && _selectedFeature != null) {
      return preview;
    }

    return _selectedFeature;
  }

  bool _isFeatureLocked(MapFeature feature) {
    for (final layer in widget.project.layers) {
      final containsFeature = layer.features.any(
        (item) => identical(item, feature),
      );

      if (containsFeature) {
        return layer.locked;
      }
    }

    return false;
  }

  @override
  void didUpdateWidget(covariant MapCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);

    final selected = _selectedFeature;

    if (selected != null && !_isEditingVertex && !_isMovingFeature) {
      MapFeature? updatedFeature;

      for (final feature in _projectFeatures) {
        if (identical(feature, selected)) {
          updatedFeature = feature;
          break;
        }
      }

      _selectedFeature = updatedFeature;
    }

    final snap = _snapResult;

    if (snap != null) {
      final stillExists = _projectFeatures.any(
        (feature) => identical(feature, snap.feature),
      );

      if (!stillExists) {
        _snapResult = null;
      }
    }
  }

  void _fitView() {
    if (_isEditingVertex || _isMovingFeature) {
      return;
    }

    setState(() {
      _zoom = 1.0;
      _pan = Offset.zero;
      _snapResult = null;
    });
  }

  void _zoomIn() {
    if (_isEditingVertex || _isMovingFeature) {
      return;
    }

    _changeZoom(_zoom * 1.25);
  }

  void _zoomOut() {
    if (_isEditingVertex || _isMovingFeature) {
      return;
    }

    _changeZoom(_zoom / 1.25);
  }

  void _changeZoom(double newZoom) {
    setState(() {
      _zoom = newZoom.clamp(_minZoom, _maxZoom);

      _snapResult = null;
    });
  }

  void _handlePointerSignal(PointerSignalEvent event, Size canvasSize) {
    if (_isEditingVertex || _isMovingFeature || event is! PointerScrollEvent) {
      return;
    }

    final oldZoom = _zoom;

    final zoomFactor = event.scrollDelta.dy < 0 ? 1.15 : 1 / 1.15;

    final newZoom = (_zoom * zoomFactor).clamp(_minZoom, _maxZoom);

    if (newZoom == oldZoom) {
      return;
    }

    final pointer = event.localPosition;

    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);

    final oldOffsetFromCenter = pointer - center - _pan;

    final scaleRatio = newZoom / oldZoom;

    final newOffsetFromCenter = oldOffsetFromCenter * scaleRatio;

    final newPan = pointer - center - newOffsetFromCenter;

    setState(() {
      _zoom = newZoom;
      _pan = newPan;
      _snapResult = null;
    });

    _updatePointerState(pointer, canvasSize);
  }

  void _handlePointerDown(PointerDownEvent event, Size canvasSize) {
    if (event.buttons == kPrimaryMouseButton) {
      if (_tryStartVertexEdit(event.localPosition, canvasSize)) {
        return;
      }

      if (_tryStartFeatureMove(event.localPosition, canvasSize)) {
        return;
      }
    }

    if (event.buttons != kPrimaryMouseButton &&
        event.buttons != kMiddleMouseButton) {
      return;
    }

    setState(() {
      _isPanning = true;
      _pointerMoved = false;

      _lastPanPosition = event.localPosition;

      _pointerDownPosition = event.localPosition;

      _snapResult = null;
    });
  }

  bool _tryStartVertexEdit(Offset localPosition, Size canvasSize) {
    final selected = _selectedFeature;

    final snap = _findSnapAtPosition(localPosition, canvasSize);

    if (selected == null || snap == null) {
      return false;
    }

    if (!identical(snap.feature, selected)) {
      return false;
    }

    if (_isFeatureLocked(selected)) {
      return false;
    }

    setState(() {
      _isEditingVertex = true;

      _editingCoordinateIndex = snap.coordinateIndex;

      _previewFeature = selected;

      _pointerMoved = false;

      _pointerDownPosition = localPosition;

      _lastPanPosition = null;

      _isPanning = false;

      _snapResult = snap;
    });

    return true;
  }

  bool _tryStartFeatureMove(Offset localPosition, Size canvasSize) {
    final selected = _selectedFeature;

    if (selected == null || _isFeatureLocked(selected)) {
      return false;
    }

    final bounds = _calculateBounds(_projectFeatures);

    if (bounds == null) {
      return false;
    }

    final transform = _MapTransform.create(
      bounds: bounds,
      canvasSize: canvasSize,
    );

    final cadPosition = transform.fromCanvas(
      localPosition,
      zoom: _zoom,
      pan: _pan,
    );

    final effectiveScale = transform.scale * _zoom;

    if (effectiveScale <= 0) {
      return false;
    }

    final toleranceCad = _selectionTolerancePixels / effectiveScale;

    final result = _selectionService.findNearestFeature(
      features: [selected],
      position: cadPosition,
      tolerance: toleranceCad,
    );

    if (result == null) {
      return false;
    }

    setState(() {
      _isMovingFeature = true;
      _moveStartCoordinate = cadPosition;
      _previewFeature = selected;
      _pointerMoved = false;
      _pointerDownPosition = localPosition;
      _lastPanPosition = null;
      _isPanning = false;
      _snapResult = null;
    });

    return true;
  }

  void _handlePointerMove(PointerMoveEvent event, Size canvasSize) {
    if (_isMovingFeature) {
      _updateFeatureMove(event.localPosition, canvasSize);
      return;
    }

    if (_isEditingVertex) {
      _updateVertexEdit(event.localPosition, canvasSize);

      return;
    }

    if (_isPanning && _lastPanPosition != null) {
      final currentPosition = event.localPosition;

      final downPosition = _pointerDownPosition;

      if (downPosition != null) {
        final totalMovement = (currentPosition - downPosition).distance;

        if (totalMovement > _clickMovementTolerance) {
          _pointerMoved = true;
        }
      }

      final delta = currentPosition - _lastPanPosition!;

      setState(() {
        _pan += delta;

        _lastPanPosition = currentPosition;

        _snapResult = null;
      });
    }

    _updatePointerState(event.localPosition, canvasSize);
  }

  void _updateFeatureMove(Offset localPosition, Size canvasSize) {
    final selected = _selectedFeature;
    final start = _moveStartCoordinate;

    if (selected == null || start == null) {
      return;
    }

    final bounds = _calculateBounds(_projectFeatures);

    if (bounds == null) {
      return;
    }

    final transform = _MapTransform.create(
      bounds: bounds,
      canvasSize: canvasSize,
    );

    final current = transform.fromCanvas(localPosition, zoom: _zoom, pan: _pan);

    final downPosition = _pointerDownPosition;

    if (downPosition != null &&
        (localPosition - downPosition).distance > _clickMovementTolerance) {
      _pointerMoved = true;
    }

    final updated = selected.move(
      deltaX: current.x - start.x,
      deltaY: current.y - start.y,
    );

    setState(() {
      _previewFeature = updated;
      _mouseCoordinate = current;
      _snapResult = null;
    });
  }

  void _updateVertexEdit(Offset localPosition, Size canvasSize) {
    final selected = _selectedFeature;

    final coordinateIndex = _editingCoordinateIndex;

    if (selected == null || coordinateIndex == null) {
      return;
    }

    final bounds = _calculateBounds(_projectFeatures);

    if (bounds == null) {
      return;
    }

    final transform = _MapTransform.create(
      bounds: bounds,
      canvasSize: canvasSize,
    );

    final coordinate = transform.fromCanvas(
      localPosition,
      zoom: _zoom,
      pan: _pan,
    );

    final downPosition = _pointerDownPosition;

    if (downPosition != null &&
        (localPosition - downPosition).distance > _clickMovementTolerance) {
      _pointerMoved = true;
    }

    final updated = selected.updateCoordinate(
      index: coordinateIndex,
      coordinate: coordinate,
    );

    setState(() {
      _previewFeature = updated;
      _mouseCoordinate = coordinate;

      _snapResult = MapSnapResult(
        feature: updated,
        coordinate: coordinate,
        type: _snapTypeForCoordinate(updated, coordinateIndex),
        distance: 0,
        coordinateIndex: coordinateIndex,
      );
    });
  }

  MapSnapType _snapTypeForCoordinate(MapFeature feature, int index) {
    switch (feature.type) {
      case MapFeatureType.point:
      case MapFeatureType.line:
      case MapFeatureType.text:
        return MapSnapType.endpoint;

      case MapFeatureType.polyline:
        if (index == 0 || index == feature.coordinates.length - 1) {
          return MapSnapType.endpoint;
        }

        return MapSnapType.vertex;

      case MapFeatureType.polygon:
        return MapSnapType.vertex;
    }
  }

  void _handlePointerUp(PointerUpEvent event, Size canvasSize) {
    if (_isMovingFeature) {
      _finishFeatureMove(event.localPosition, canvasSize);
      return;
    }

    if (_isEditingVertex) {
      _finishVertexEdit(event.localPosition, canvasSize);

      return;
    }

    if (!_isPanning) {
      return;
    }

    final shouldSelect =
        event.kind == PointerDeviceKind.mouse &&
        event.buttons == 0 &&
        !_pointerMoved;

    setState(() {
      _isPanning = false;
      _lastPanPosition = null;
      _pointerDownPosition = null;
    });

    if (shouldSelect) {
      _selectAtPosition(event.localPosition, canvasSize);
    }

    _updatePointerState(event.localPosition, canvasSize);
  }

  void _finishFeatureMove(Offset localPosition, Size canvasSize) {
    final original = _selectedFeature;
    final preview = _previewFeature;
    final changed = _pointerMoved && original != null && preview != null;

    setState(() {
      if (changed) {
        _selectedFeature = preview;
      }

      _isMovingFeature = false;
      _moveStartCoordinate = null;
      _previewFeature = null;
      _pointerDownPosition = null;
      _lastPanPosition = null;
      _pointerMoved = false;
    });

    if (changed) {
      widget.onFeatureChanged?.call(
        MapFeatureChange(originalFeature: original, updatedFeature: preview),
      );
    }

    _updatePointerState(localPosition, canvasSize);
  }

  void _finishVertexEdit(Offset localPosition, Size canvasSize) {
    final original = _selectedFeature;
    final preview = _previewFeature;

    final changed = _pointerMoved && original != null && preview != null;

    setState(() {
      if (changed) {
        _selectedFeature = preview;
      }

      _isEditingVertex = false;
      _editingCoordinateIndex = null;
      _previewFeature = null;
      _pointerDownPosition = null;
      _lastPanPosition = null;
      _pointerMoved = false;
    });

    if (changed) {
      widget.onFeatureChanged?.call(
        MapFeatureChange(originalFeature: original, updatedFeature: preview),
      );
    }

    _updatePointerState(localPosition, canvasSize);
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    setState(() {
      _isPanning = false;
      _isEditingVertex = false;
      _isMovingFeature = false;
      _pointerMoved = false;

      _lastPanPosition = null;
      _pointerDownPosition = null;

      _editingCoordinateIndex = null;
      _moveStartCoordinate = null;

      _previewFeature = null;
      _snapResult = null;
    });
  }

  MapSnapResult? _findSnapAtPosition(Offset localPosition, Size canvasSize) {
    final bounds = _calculateBounds(_displayFeatures);

    if (bounds == null) {
      return null;
    }

    final transform = _MapTransform.create(
      bounds: bounds,
      canvasSize: canvasSize,
    );

    final coordinate = transform.fromCanvas(
      localPosition,
      zoom: _zoom,
      pan: _pan,
    );

    final effectiveScale = transform.scale * _zoom;

    if (effectiveScale <= 0) {
      return null;
    }

    final toleranceCad = _snapTolerancePixels / effectiveScale;

    return _snapService.findNearestSnap(
      features: _displayFeatures,
      position: coordinate,
      tolerance: toleranceCad,
    );
  }

  void _updatePointerState(Offset localPosition, Size canvasSize) {
    if (_isEditingVertex || _isMovingFeature) {
      return;
    }

    final bounds = _calculateBounds(_displayFeatures);

    if (bounds == null) {
      return;
    }

    final transform = _MapTransform.create(
      bounds: bounds,
      canvasSize: canvasSize,
    );

    final coordinate = transform.fromCanvas(
      localPosition,
      zoom: _zoom,
      pan: _pan,
    );

    final effectiveScale = transform.scale * _zoom;

    MapSnapResult? snap;

    if (!_isPanning && effectiveScale > 0) {
      final toleranceCad = _snapTolerancePixels / effectiveScale;

      snap = _snapService.findNearestSnap(
        features: _displayFeatures,
        position: coordinate,
        tolerance: toleranceCad,
      );
    }

    setState(() {
      _mouseCoordinate = coordinate;
      _snapResult = snap;
    });
  }

  void _selectAtPosition(Offset localPosition, Size canvasSize) {
    final bounds = _calculateBounds(_displayFeatures);

    if (bounds == null) {
      return;
    }

    final transform = _MapTransform.create(
      bounds: bounds,
      canvasSize: canvasSize,
    );

    final cadPosition = transform.fromCanvas(
      localPosition,
      zoom: _zoom,
      pan: _pan,
    );

    final effectiveScale = transform.scale * _zoom;

    if (effectiveScale <= 0) {
      return;
    }

    final toleranceCad = _selectionTolerancePixels / effectiveScale;

    final result = _selectionService.findNearestFeature(
      features: _displayFeatures,
      position: cadPosition,
      tolerance: toleranceCad,
    );

    setState(() {
      _selectedFeature = result?.feature;
    });
  }

  bool get _canAddVertex {
    final feature = _selectedFeature;
    if (feature == null || _isFeatureLocked(feature)) {
      return false;
    }

    return feature.type == MapFeatureType.polyline ||
        feature.type == MapFeatureType.polygon;
  }

  bool get _canDeleteVertex {
    final feature = _selectedFeature;
    if (feature == null || _isFeatureLocked(feature)) {
      return false;
    }

    if (feature.type == MapFeatureType.polyline) {
      return feature.coordinates.length > 2;
    }

    if (feature.type == MapFeatureType.polygon) {
      return feature.coordinates.length > 3;
    }

    return false;
  }

  bool get _canEditCoordinate {
    final feature = _selectedFeature;
    return feature != null &&
        feature.coordinates.isNotEmpty &&
        !_isFeatureLocked(feature);
  }

  void _commitFeatureUpdate(MapFeature updatedFeature) {
    final original = _selectedFeature;

    if (original == null || _isFeatureLocked(original)) {
      return;
    }

    setState(() {
      _selectedFeature = updatedFeature;
      _previewFeature = null;
      _snapResult = null;
    });

    widget.onFeatureChanged?.call(
      MapFeatureChange(
        originalFeature: original,
        updatedFeature: updatedFeature,
      ),
    );
  }

  Future<void> _showAddVertexDialog() async {
    final feature = _selectedFeature;

    if (feature == null || !_canAddVertex) {
      return;
    }

    final isPolygon = feature.type == MapFeatureType.polygon;

    final segmentCount = isPolygon
        ? feature.coordinates.length
        : feature.coordinates.length - 1;

    if (segmentCount <= 0) {
      return;
    }

    var segmentIndex = 0;

    final start = feature.coordinates[0];
    final end = feature
        .coordinates[isPolygon && feature.coordinates.length == 1 ? 0 : 1];

    final xController = TextEditingController(
      text: ((start.x + end.x) / 2).toStringAsFixed(4),
    );
    final yController = TextEditingController(
      text: ((start.y + end.y) / 2).toStringAsFixed(4),
    );

    final result = await showDialog<_VertexInsertResult>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void updateMidpoint(int newSegmentIndex) {
              segmentIndex = newSegmentIndex;

              final first = feature.coordinates[segmentIndex];
              final secondIndex =
                  (segmentIndex + 1) % feature.coordinates.length;
              final second = feature.coordinates[secondIndex];

              xController.text = ((first.x + second.x) / 2).toStringAsFixed(4);
              yController.text = ((first.y + second.y) / 2).toStringAsFixed(4);
            }

            return AlertDialog(
              title: const Text('Thêm đỉnh'),
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Chọn đoạn cần chèn đỉnh. '
                      'Tọa độ mặc định là trung điểm của đoạn.',
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      initialValue: segmentIndex,
                      decoration: const InputDecoration(
                        labelText: 'Đoạn',
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(segmentCount, (index) {
                        final nextIndex =
                            (index + 1) % feature.coordinates.length;
                        return DropdownMenuItem(
                          value: index,
                          child: Text(
                            'Đỉnh ${index + 1} → '
                            'Đỉnh ${nextIndex + 1}',
                          ),
                        );
                      }),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          updateMidpoint(value);
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: xController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Tọa độ X',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: yController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Tọa độ Y',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  onPressed: () {
                    final x = double.tryParse(xController.text.trim());
                    final y = double.tryParse(yController.text.trim());

                    if (x == null || y == null) {
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(
                            content: Text('X và Y phải là số hợp lệ.'),
                          ),
                        );
                      return;
                    }

                    Navigator.of(dialogContext).pop(
                      _VertexInsertResult(
                        segmentIndex: segmentIndex,
                        coordinate: MapCoordinate(x: x, y: y),
                      ),
                    );
                  },
                  child: const Text('Thêm đỉnh'),
                ),
              ],
            );
          },
        );
      },
    );

    xController.dispose();
    yController.dispose();

    if (!mounted || result == null) {
      return;
    }

    final originalZ = feature.coordinates[result.segmentIndex].z;

    final coordinate = MapCoordinate(
      x: result.coordinate.x,
      y: result.coordinate.y,
      z: originalZ,
    );

    final updated = feature.insertCoordinate(
      index: result.segmentIndex + 1,
      coordinate: coordinate,
    );

    _commitFeatureUpdate(updated);
  }

  Future<void> _showDeleteVertexDialog() async {
    final feature = _selectedFeature;

    if (feature == null || !_canDeleteVertex) {
      return;
    }

    var coordinateIndex = 0;

    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final coordinate = feature.coordinates[coordinateIndex];

            return AlertDialog(
              title: const Text('Xóa đỉnh'),
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      feature.type == MapFeatureType.polygon
                          ? 'Polygon phải còn ít nhất 3 đỉnh.'
                          : 'Polyline phải còn ít nhất 2 đỉnh.',
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      initialValue: coordinateIndex,
                      decoration: const InputDecoration(
                        labelText: 'Đỉnh cần xóa',
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(
                        feature.coordinates.length,
                        (index) => DropdownMenuItem(
                          value: index,
                          child: Text('Đỉnh ${index + 1}'),
                        ),
                      ),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          coordinateIndex = value;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'X: ${_CoordinateIndicator._formatCoordinate(coordinate.x)}',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Y: ${_CoordinateIndicator._formatCoordinate(coordinate.y)}',
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(coordinateIndex);
                  },
                  child: const Text('Xóa đỉnh'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted || result == null) {
      return;
    }

    final updated = feature.removeCoordinate(result);

    _commitFeatureUpdate(updated);
  }

  Future<void> _showCoordinateEditorDialog() async {
    final feature = _selectedFeature;

    if (feature == null || !_canEditCoordinate) {
      return;
    }

    var coordinateIndex = 0;

    final xController = TextEditingController(
      text: feature.coordinates.first.x.toStringAsFixed(4),
    );
    final yController = TextEditingController(
      text: feature.coordinates.first.y.toStringAsFixed(4),
    );

    final result = await showDialog<_CoordinateEditResult>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void loadCoordinate(int index) {
              coordinateIndex = index;
              final coordinate = feature.coordinates[index];

              xController.text = coordinate.x.toStringAsFixed(4);
              yController.text = coordinate.y.toStringAsFixed(4);
            }

            return AlertDialog(
              title: const Text('Chỉnh tọa độ đỉnh'),
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: coordinateIndex,
                      decoration: const InputDecoration(
                        labelText: 'Đỉnh',
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(
                        feature.coordinates.length,
                        (index) => DropdownMenuItem(
                          value: index,
                          child: Text('Đỉnh ${index + 1}'),
                        ),
                      ),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          loadCoordinate(value);
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: xController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Tọa độ X',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: yController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Tọa độ Y',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  onPressed: () {
                    final x = double.tryParse(xController.text.trim());
                    final y = double.tryParse(yController.text.trim());

                    if (x == null || y == null) {
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(
                            content: Text('X và Y phải là số hợp lệ.'),
                          ),
                        );
                      return;
                    }

                    Navigator.of(dialogContext).pop(
                      _CoordinateEditResult(
                        coordinateIndex: coordinateIndex,
                        x: x,
                        y: y,
                      ),
                    );
                  },
                  child: const Text('Cập nhật'),
                ),
              ],
            );
          },
        );
      },
    );

    xController.dispose();
    yController.dispose();

    if (!mounted || result == null) {
      return;
    }

    final oldCoordinate = feature.coordinates[result.coordinateIndex];

    final updated = feature.updateCoordinate(
      index: result.coordinateIndex,
      coordinate: MapCoordinate(x: result.x, y: result.y, z: oldCoordinate.z),
    );

    _commitFeatureUpdate(updated);
  }

  void _clearPointerState() {
    if (_isEditingVertex || _isMovingFeature) {
      return;
    }

    setState(() {
      _mouseCoordinate = null;
      _snapResult = null;
    });
  }

  _MapBounds? _calculateBounds(List<MapFeature> features) {
    double? minX;
    double? minY;
    double? maxX;
    double? maxY;

    for (final feature in features) {
      for (final coordinate in feature.coordinates) {
        minX = minX == null ? coordinate.x : math.min(minX, coordinate.x);

        minY = minY == null ? coordinate.y : math.min(minY, coordinate.y);

        maxX = maxX == null ? coordinate.x : math.max(maxX, coordinate.x);

        maxY = maxY == null ? coordinate.y : math.max(maxY, coordinate.y);
      }
    }

    if (minX == null || minY == null || maxX == null || maxY == null) {
      return null;
    }

    return _MapBounds(minX: minX, minY: minY, maxX: maxX, maxY: maxY);
  }

  @override
  Widget build(BuildContext context) {
    if (_displayFeatures.isEmpty) {
      return const _EmptyMapCanvas();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);

        final bounds = _calculateBounds(_displayFeatures);

        if (bounds == null) {
          return const _EmptyMapCanvas();
        }

        final transform = _MapTransform.create(
          bounds: bounds,
          canvasSize: canvasSize,
        );

        return Stack(
          children: [
            Positioned.fill(
              child: MouseRegion(
                cursor: _isMovingFeature
                    ? SystemMouseCursors.move
                    : _isEditingVertex
                    ? SystemMouseCursors.precise
                    : _isPanning
                    ? SystemMouseCursors.grabbing
                    : _snapResult != null
                    ? SystemMouseCursors.precise
                    : SystemMouseCursors.grab,
                onHover: (event) {
                  _updatePointerState(event.localPosition, canvasSize);
                },
                onExit: (_) {
                  _clearPointerState();
                },
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerSignal: (event) {
                    _handlePointerSignal(event, canvasSize);
                  },
                  onPointerDown: (event) {
                    _handlePointerDown(event, canvasSize);
                  },
                  onPointerMove: (event) {
                    _handlePointerMove(event, canvasSize);
                  },
                  onPointerUp: (event) {
                    _handlePointerUp(event, canvasSize);
                  },
                  onPointerCancel: _handlePointerCancel,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: CadGridPainter(
                            minX: bounds.minX,
                            minY: bounds.minY,
                            maxX: bounds.maxX,
                            maxY: bounds.maxY,
                            baseScale: transform.scale,
                            offsetX: transform.offsetX,
                            offsetY: transform.offsetY,
                            zoom: _zoom,
                            pan: _pan,
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _MapProjectPainter(
                            features: _displayFeatures,
                            zoom: _zoom,
                            pan: _pan,
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: SelectionPainter(
                              selectedFeature: _displaySelectedFeature,
                              toCanvas: (coordinate) {
                                return transform.toScreen(
                                  coordinate,
                                  zoom: _zoom,
                                  pan: _pan,
                                );
                              },
                              zoom: 1.0,
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: SnapPainter(
                              snapResult: _snapResult,
                              toScreen: (coordinate) {
                                return transform.toScreen(
                                  coordinate,
                                  zoom: _zoom,
                                  pan: _pan,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: _MapToolbar(
                zoom: _zoom,
                editing: _isEditingVertex || _isMovingFeature,
                onZoomIn: _zoomIn,
                onZoomOut: _zoomOut,
                onFit: _fitView,
              ),
            ),
            if (_displaySelectedFeature != null)
              Positioned(
                top: 70,
                right: 12,
                child: _SelectionInfo(
                  feature: _displaySelectedFeature!,
                  locked: _isFeatureLocked(_displaySelectedFeature!),
                  editing: _isEditingVertex,
                  moving: _isMovingFeature,
                ),
              ),
            if (_displaySelectedFeature != null)
              Positioned(
                top: 258,
                right: 12,
                child: _GeometryEditActions(
                  canAddVertex:
                      _canAddVertex && !_isEditingVertex && !_isMovingFeature,
                  canDeleteVertex:
                      _canDeleteVertex &&
                      !_isEditingVertex &&
                      !_isMovingFeature,
                  canEditCoordinate:
                      _canEditCoordinate &&
                      !_isEditingVertex &&
                      !_isMovingFeature,
                  onAddVertex: _showAddVertexDialog,
                  onDeleteVertex: _showDeleteVertexDialog,
                  onEditCoordinate: _showCoordinateEditorDialog,
                ),
              ),
            Positioned(
              left: 12,
              bottom: 12,
              child: _CoordinateIndicator(
                coordinate: _mouseCoordinate,
                snapResult: _snapResult,
                zoom: _zoom,
                editing: _isEditingVertex,
                moving: _isMovingFeature,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MapToolbar extends StatelessWidget {
  final double zoom;
  final bool editing;

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFit;

  const _MapToolbar({
    required this.zoom,
    required this.editing,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFit,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(8),
      color: Colors.white,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Phóng to',
            onPressed: editing ? null : onZoomIn,
            icon: const Icon(Icons.add),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 64),
            alignment: Alignment.center,
            child: Text(
              '${(zoom * 100).round()}%',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            tooltip: 'Thu nhỏ',
            onPressed: editing ? null : onZoomOut,
            icon: const Icon(Icons.remove),
          ),
          Container(width: 1, height: 28, color: const Color(0xFFE0E0E0)),
          IconButton(
            tooltip: 'Fit toàn bộ bản vẽ',
            onPressed: editing ? null : onFit,
            icon: const Icon(Icons.fit_screen),
          ),
        ],
      ),
    );
  }
}

class _GeometryEditActions extends StatelessWidget {
  final bool canAddVertex;
  final bool canDeleteVertex;
  final bool canEditCoordinate;

  final VoidCallback onAddVertex;
  final VoidCallback onDeleteVertex;
  final VoidCallback onEditCoordinate;

  const _GeometryEditActions({
    required this.canAddVertex,
    required this.canDeleteVertex,
    required this.canEditCoordinate,
    required this.onAddVertex,
    required this.onDeleteVertex,
    required this.onEditCoordinate,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(8),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: 'Thêm đỉnh vào Polyline/Polygon',
              child: IconButton(
                onPressed: canAddVertex ? onAddVertex : null,
                icon: const Icon(Icons.add_location_alt_outlined),
              ),
            ),
            Tooltip(
              message: 'Xóa một đỉnh',
              child: IconButton(
                onPressed: canDeleteVertex ? onDeleteVertex : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
            ),
            Tooltip(
              message: 'Nhập tọa độ X/Y chính xác',
              child: IconButton(
                onPressed: canEditCoordinate ? onEditCoordinate : null,
                icon: const Icon(Icons.pin_drop_outlined),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionInfo extends StatelessWidget {
  final MapFeature feature;
  final bool locked;
  final bool editing;
  final bool moving;

  const _SelectionInfo({
    required this.feature,
    required this.locked,
    required this.editing,
    required this.moving,
  });

  @override
  Widget build(BuildContext context) {
    final cadLayer = feature.properties['cadLayer'];

    return IgnorePointer(
      child: Material(
        elevation: 3,
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
        child: Container(
          width: 240,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: editing
                  ? const Color(0xFF00A86B)
                  : const Color(0xFFFFB74D),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    editing ? Icons.edit : Icons.ads_click,
                    size: 17,
                    color: editing
                        ? const Color(0xFF00A86B)
                        : const Color(0xFFFF9800),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    moving
                        ? 'ĐANG DI CHUYỂN'
                        : editing
                        ? 'ĐANG SỬA ĐỈNH'
                        : 'ĐỐI TƯỢNG ĐÃ CHỌN',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _InfoRow(
                label: 'Tên',
                value: feature.name.isEmpty ? feature.id : feature.name,
              ),
              _InfoRow(label: 'Loại', value: _featureTypeLabel(feature.type)),
              _InfoRow(
                label: 'Số đỉnh',
                value: '${feature.coordinates.length}',
              ),
              if (cadLayer != null && cadLayer.isNotEmpty)
                _InfoRow(label: 'CAD Layer', value: cadLayer),
              _InfoRow(
                label: 'Trạng thái',
                value: locked
                    ? 'Layer đã khóa'
                    : moving
                    ? 'Đang di chuyển đối tượng'
                    : editing
                    ? 'Đang kéo đỉnh'
                    : 'Có thể chỉnh sửa',
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _featureTypeLabel(MapFeatureType type) {
    switch (type) {
      case MapFeatureType.point:
        return 'POINT';
      case MapFeatureType.line:
        return 'LINE';
      case MapFeatureType.polyline:
        return 'POLYLINE';
      case MapFeatureType.polygon:
        return 'POLYGON';
      case MapFeatureType.text:
        return 'TEXT';
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              '$label:',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoordinateIndicator extends StatelessWidget {
  final MapCoordinate? coordinate;
  final MapSnapResult? snapResult;
  final double zoom;
  final bool editing;
  final bool moving;

  const _CoordinateIndicator({
    required this.coordinate,
    required this.snapResult,
    required this.zoom,
    required this.editing,
    required this.moving,
  });

  @override
  Widget build(BuildContext context) {
    final displayCoordinate = snapResult?.coordinate ?? coordinate;

    final coordinateText = displayCoordinate == null
        ? 'X: —    Y: —'
        : 'X: ${_formatCoordinate(displayCoordinate.x)}    '
              'Y: ${_formatCoordinate(displayCoordinate.y)}';

    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              moving
                  ? Icons.open_with
                  : editing
                  ? Icons.edit_location_alt
                  : snapResult != null
                  ? Icons.gps_fixed
                  : Icons.my_location,
              size: 14,
              color: moving || editing || snapResult != null
                  ? const Color(0xFF69F0AE)
                  : Colors.white,
            ),
            const SizedBox(width: 8),
            if (moving) ...[
              const Text(
                'MOVE  ',
                style: TextStyle(
                  color: Color(0xFF69F0AE),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ] else if (editing) ...[
              const Text(
                'EDIT VERTEX  ',
                style: TextStyle(
                  color: Color(0xFF69F0AE),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ] else if (snapResult != null) ...[
              Text(
                '${snapResult!.label}  ',
                style: const TextStyle(
                  color: Color(0xFF69F0AE),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            Text(
              coordinateText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 14),
            Container(width: 1, height: 14, color: Colors.white30),
            const SizedBox(width: 14),
            Text(
              'Zoom ${(zoom * 100).round()}%',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatCoordinate(double value) {
    final absoluteValue = value.abs();

    if (absoluteValue >= 1000000) {
      return value.toStringAsFixed(2);
    }

    if (absoluteValue >= 1000) {
      return value.toStringAsFixed(3);
    }

    return value.toStringAsFixed(4);
  }
}

class _EmptyMapCanvas extends StatelessWidget {
  const _EmptyMapCanvas();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.layers_clear, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Chưa có hình học để hiển thị',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 6),
            Text(
              'Hãy mở một file DXF có dữ liệu hình học.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapProjectPainter extends CustomPainter {
  final List<MapFeature> features;
  final double zoom;
  final Offset pan;

  _MapProjectPainter({
    required this.features,
    required this.zoom,
    required this.pan,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (features.isEmpty || size.width <= 0 || size.height <= 0) {
      return;
    }

    final bounds = _calculateBounds();

    if (bounds == null) {
      return;
    }

    final baseTransform = _MapTransform.create(
      bounds: bounds,
      canvasSize: size,
    );

    canvas.save();

    final center = Offset(size.width / 2, size.height / 2);

    canvas.translate(center.dx + pan.dx, center.dy + pan.dy);

    canvas.scale(zoom, zoom);

    canvas.translate(-center.dx, -center.dy);

    final geometryPaint = Paint()
      ..color = const Color(0xFF1565C0)
      ..strokeWidth = 1.5 / zoom
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final pointPaint = Paint()
      ..color = const Color(0xFFD32F2F)
      ..style = PaintingStyle.fill;

    for (final feature in features) {
      switch (feature.type) {
        case MapFeatureType.point:
          _drawPoint(canvas, feature, baseTransform, pointPaint);
          break;

        case MapFeatureType.line:
          _drawLine(canvas, feature, baseTransform, geometryPaint);
          break;

        case MapFeatureType.polyline:
          _drawPolyline(
            canvas,
            feature,
            baseTransform,
            geometryPaint,
            closePath: false,
          );
          break;

        case MapFeatureType.polygon:
          _drawPolyline(
            canvas,
            feature,
            baseTransform,
            geometryPaint,
            closePath: true,
          );
          break;

        case MapFeatureType.text:
          _drawText(canvas, feature, baseTransform);
          break;
      }
    }

    canvas.restore();
  }

  _MapBounds? _calculateBounds() {
    double? minX;
    double? minY;
    double? maxX;
    double? maxY;

    for (final feature in features) {
      for (final coordinate in feature.coordinates) {
        minX = minX == null ? coordinate.x : math.min(minX, coordinate.x);

        minY = minY == null ? coordinate.y : math.min(minY, coordinate.y);

        maxX = maxX == null ? coordinate.x : math.max(maxX, coordinate.x);

        maxY = maxY == null ? coordinate.y : math.max(maxY, coordinate.y);
      }
    }

    if (minX == null || minY == null || maxX == null || maxY == null) {
      return null;
    }

    return _MapBounds(minX: minX, minY: minY, maxX: maxX, maxY: maxY);
  }

  void _drawPoint(
    Canvas canvas,
    MapFeature feature,
    _MapTransform transform,
    Paint paint,
  ) {
    if (feature.coordinates.isEmpty) {
      return;
    }

    final position = transform.toCanvas(feature.coordinates.first);

    canvas.drawCircle(position, 3.5 / zoom, paint);
  }

  void _drawLine(
    Canvas canvas,
    MapFeature feature,
    _MapTransform transform,
    Paint paint,
  ) {
    if (feature.coordinates.length < 2) {
      return;
    }

    final start = transform.toCanvas(feature.coordinates[0]);

    final end = transform.toCanvas(feature.coordinates[1]);

    canvas.drawLine(start, end, paint);
  }

  void _drawPolyline(
    Canvas canvas,
    MapFeature feature,
    _MapTransform transform,
    Paint paint, {
    required bool closePath,
  }) {
    if (feature.coordinates.length < 2) {
      return;
    }

    final path = Path();

    final first = transform.toCanvas(feature.coordinates.first);

    path.moveTo(first.dx, first.dy);

    for (var index = 1; index < feature.coordinates.length; index++) {
      final position = transform.toCanvas(feature.coordinates[index]);

      path.lineTo(position.dx, position.dy);
    }

    if (closePath) {
      path.close();
    }

    canvas.drawPath(path, paint);
  }

  void _drawText(Canvas canvas, MapFeature feature, _MapTransform transform) {
    if (feature.coordinates.isEmpty) {
      return;
    }

    final content = feature.properties['text'] ?? feature.name;

    if (content.isEmpty) {
      return;
    }

    final position = transform.toCanvas(feature.coordinates.first);

    final rotationDegrees =
        double.tryParse(feature.properties['rotationDegrees'] ?? '') ?? 0;

    final textPainter = TextPainter(
      text: TextSpan(
        text: content,
        style: TextStyle(
          color: const Color(0xFF5E35B1),
          fontSize: 13 / zoom,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 320 / zoom);

    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(-rotationDegrees * math.pi / 180);
    textPainter.paint(canvas, Offset(4 / zoom, -textPainter.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MapProjectPainter oldDelegate) {
    return oldDelegate.features != features ||
        oldDelegate.zoom != zoom ||
        oldDelegate.pan != pan;
  }
}

class _VertexInsertResult {
  final int segmentIndex;
  final MapCoordinate coordinate;

  const _VertexInsertResult({
    required this.segmentIndex,
    required this.coordinate,
  });
}

class _CoordinateEditResult {
  final int coordinateIndex;
  final double x;
  final double y;

  const _CoordinateEditResult({
    required this.coordinateIndex,
    required this.x,
    required this.y,
  });
}

class _MapBounds {
  final double minX;
  final double minY;
  final double maxX;
  final double maxY;

  const _MapBounds({
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
  });

  double get width => maxX - minX;

  double get height => maxY - minY;
}

class _MapTransform {
  final _MapBounds bounds;
  final Size canvasSize;

  final double scale;
  final double offsetX;
  final double offsetY;

  const _MapTransform({
    required this.bounds,
    required this.canvasSize,
    required this.scale,
    required this.offsetX,
    required this.offsetY,
  });

  factory _MapTransform.create({
    required _MapBounds bounds,
    required Size canvasSize,
  }) {
    const padding = 40.0;

    final availableWidth = math.max(1.0, canvasSize.width - padding * 2);

    final availableHeight = math.max(1.0, canvasSize.height - padding * 2);

    final geometryWidth = math.max(bounds.width, 0.000001);

    final geometryHeight = math.max(bounds.height, 0.000001);

    final scaleX = availableWidth / geometryWidth;

    final scaleY = availableHeight / geometryHeight;

    final scale = math.min(scaleX, scaleY);

    final drawnWidth = bounds.width * scale;

    final drawnHeight = bounds.height * scale;

    final offsetX = (canvasSize.width - drawnWidth) / 2;

    final offsetY = (canvasSize.height - drawnHeight) / 2;

    return _MapTransform(
      bounds: bounds,
      canvasSize: canvasSize,
      scale: scale,
      offsetX: offsetX,
      offsetY: offsetY,
    );
  }

  Offset toCanvas(MapCoordinate coordinate) {
    final x = offsetX + (coordinate.x - bounds.minX) * scale;

    final y =
        canvasSize.height - offsetY - (coordinate.y - bounds.minY) * scale;

    return Offset(x, y);
  }

  Offset toScreen(
    MapCoordinate coordinate, {
    required double zoom,
    required Offset pan,
  }) {
    final base = toCanvas(coordinate);

    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);

    return Offset(
      center.dx + (base.dx - center.dx) * zoom + pan.dx,
      center.dy + (base.dy - center.dy) * zoom + pan.dy,
    );
  }

  MapCoordinate fromCanvas(
    Offset canvasPosition, {
    required double zoom,
    required Offset pan,
  }) {
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);

    final baseX = center.dx + (canvasPosition.dx - center.dx - pan.dx) / zoom;

    final baseY = center.dy + (canvasPosition.dy - center.dy - pan.dy) / zoom;

    final x = bounds.minX + (baseX - offsetX) / scale;

    final y = bounds.minY + (canvasSize.height - offsetY - baseY) / scale;

    return MapCoordinate(x: x, y: y);
  }
}
