import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart' as file_selector;

import '../models/cad_document.dart';
import '../models/coordinate_reference_system.dart';
import '../models/map_feature_change.dart';
import '../models/map_layer.dart';
import '../models/map_project.dart';
import '../services/cad_file_service.dart';
import '../services/dxf_parser_service.dart';
import '../services/dxf_export_service.dart';
import '../services/project_history_service.dart';
import '../services/project_persistence_service.dart';
import '../services/project_dirty_state_service.dart';
import '../services/layer_reprojection_service.dart';
import '../services/layer_georeference_service.dart';
import '../services/kml_parser_service.dart';
import '../services/kml_export_service.dart';
import '../widgets/coordinate_converter_dialog.dart';
import '../widgets/layer_georeference_dialog.dart';
import '../widgets/map_canvas.dart';
import '../widgets/unsaved_changes_dialog.dart';

typedef ProjectSavePathSelector = Future<String?> Function({
  required String suggestedName,
  required List<String> allowedExtensions,
});

class HomeScreen extends StatefulWidget {
  final MapProject? initialProject;
  final Future<bool> Function(MapProject project)? saveProjectOverride;
  final ProjectSavePathSelector? projectSavePathSelectorOverride;
  final Future<GeoCadProjectDocument?> Function()? openProjectOverride;
  final Future<Uri?> Function(Uint8List bytes)? saveDxfOverride;
  final Future<CoordinateReferenceSystem?> Function(MapLayer layer)?
  selectUtmCrsOverride;

  const HomeScreen({
    super.key,
    this.initialProject,
    this.saveProjectOverride,
    this.projectSavePathSelectorOverride,
    this.openProjectOverride,
    this.saveDxfOverride,
    this.selectUtmCrsOverride,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CadFileService _cadFileService = const CadFileService();
  final DxfParserService _dxfParserService = const DxfParserService();
  final DxfExportService _dxfExportService = const DxfExportService();
  final LayerReprojectionService _layerReprojectionService =
      const LayerReprojectionService();
  final LayerGeoreferenceService _layerGeoreferenceService =
      const LayerGeoreferenceService();
  final KmlParserService _kmlParserService = const KmlParserService();
  final KmlExportService _kmlExportService = const KmlExportService();
  final ProjectPersistenceService _projectPersistenceService =
      const ProjectPersistenceService();

  final ProjectHistoryService _history = ProjectHistoryService(maxHistory: 100);

  late MapProject _project;
  late ProjectDirtyStateService _dirtyState;
  late final AppLifecycleListener _lifecycleListener;

  bool _isImporting = false;
  bool _isExporting = false;
  bool _isProjectBusy = false;
  String? _projectPath;
  DateTime _projectCreatedAt = DateTime.now().toUtc();
  bool _exitRequestActive = false;
  bool _confirmationActive = false;

  bool get _isDirty => _dirtyState.isDirty(_project);
  bool get _hasBlockingProjectOperation =>
      _isProjectBusy || _isImporting || _isExporting;

  @override
  void initState() {
    super.initState();
    _project =
        widget.initialProject ??
        const MapProject(
          id: 'main-project',
          name: 'Dự án AutoCAD ↔ Google Earth',
        );
    _dirtyState = ProjectDirtyStateService(_project);
    _lifecycleListener = AppLifecycleListener(
      onExitRequested: _handleExitRequested,
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  Future<void> _newProject() async {
    if (_hasBlockingProjectOperation) return;
    if (!await _prepareForDestructiveAction() || !mounted) return;
    final now = DateTime.now().toUtc();
    final newProject = MapProject(
      id: 'project-${now.microsecondsSinceEpoch}',
      name: 'Dự án GeoCAD mới',
    );
    _history.clear();
    setState(() {
      _project = newProject;
      _dirtyState.markSaved(newProject);
      _projectPath = null;
      _projectCreatedAt = now;
    });
    _showMessage('Đã tạo project mới.');
  }

  Future<void> _openProject() async {
    if (_hasBlockingProjectOperation) return;
    if (!await _prepareForDestructiveAction() || !mounted) return;
    final override = widget.openProjectOverride;
    if (override != null) {
      setState(() => _isProjectBusy = true);
      try {
        final loaded = await override();
        if (loaded == null || !mounted) return;
        _applyLoadedProject(loaded, path: null);
      } catch (error) {
        _showMessage('Không thể mở project: $error');
      } finally {
        if (mounted) setState(() => _isProjectBusy = false);
      }
      return;
    }
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['geocad'],
      dialogTitle: 'Mở GeoCAD Project',
    );
    if (files.isEmpty || !mounted) return;
    final path = files.single.path;
    if (path == null || path.isEmpty) {
      _showMessage('Không lấy được đường dẫn project.');
      return;
    }

    setState(() => _isProjectBusy = true);
    try {
      final loaded = await _projectPersistenceService.load(path);
      if (!mounted) return;
      _applyLoadedProject(loaded, path: path);
      if (loaded.warnings.isEmpty) {
        _showMessage('Đã mở project "${loaded.project.name}".');
      } else {
        await _showProjectWarnings(loaded.warnings);
      }
    } catch (error) {
      _showMessage('Không thể mở project: $error');
    } finally {
      if (mounted) setState(() => _isProjectBusy = false);
    }
  }

  void _applyLoadedProject(
    GeoCadProjectDocument loaded, {
    required String? path,
  }) {
    _history.clear();
    setState(() {
      _project = loaded.project;
      _dirtyState.markSaved(loaded.project);
      _projectPath = path;
      _projectCreatedAt = loaded.createdAt;
    });
  }

  Future<bool> _saveProject() async {
    if (_hasBlockingProjectOperation) return false;
    final override = widget.saveProjectOverride;
    if (override != null) {
      final projectBeingSaved = _project;
      setState(() => _isProjectBusy = true);
      try {
        final saved = await override(projectBeingSaved);
        if (!saved || !mounted) return false;
        setState(() => _dirtyState.markSaved(projectBeingSaved));
        return true;
      } catch (error) {
        _showMessage('Không thể lưu project: $error');
        return false;
      } finally {
        if (mounted) setState(() => _isProjectBusy = false);
      }
    }
    final path = _projectPath;
    if (path == null) {
      return _saveProjectAs();
    }
    return _saveProjectTo(path, updateCurrentPath: false);
  }

  Future<bool> _saveProjectAs() async {
    if (_hasBlockingProjectOperation) return false;
    final override = widget.saveProjectOverride;
    if (override != null) return _saveProject();
    final pathSelector =
        widget.projectSavePathSelectorOverride ?? _selectProjectSavePath;
    final path = await pathSelector(
      suggestedName: '${_safeFileName(_project.name)}.geocad',
      allowedExtensions: const ['geocad'],
    );
    if (path == null || !mounted) return false;
    return _saveProjectTo(path, updateCurrentPath: true);
  }

  Future<String?> _selectProjectSavePath({
    required String suggestedName,
    required List<String> allowedExtensions,
  }) async {
    final location = await file_selector.getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: [
        file_selector.XTypeGroup(
          label: 'GeoCAD Project',
          extensions: allowedExtensions,
        ),
      ],
    );
    return location?.path;
  }

  Future<bool> _saveProjectTo(
    String path, {
    required bool updateCurrentPath,
  }) async {
    final projectBeingSaved = _project;
    setState(() => _isProjectBusy = true);
    try {
      final document = GeoCadProjectDocument(
        project: projectBeingSaved,
        createdAt: _projectCreatedAt,
        updatedAt: DateTime.now().toUtc(),
      );
      await _projectPersistenceService.save(path, document);
      if (!mounted) return false;
      setState(() {
        if (updateCurrentPath) _projectPath = path;
        _dirtyState.markSaved(projectBeingSaved);
      });
      _showMessage('Đã lưu project: $path');
      return true;
    } catch (error) {
      _showMessage('Không thể lưu project: $error');
      return false;
    } finally {
      if (mounted) setState(() => _isProjectBusy = false);
    }
  }

  Future<bool> _prepareForDestructiveAction() async {
    if (!_isDirty) return true;
    if (_confirmationActive) return false;
    _confirmationActive = true;
    try {
      final decision = await showDialog<UnsavedChangesDecision>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const UnsavedChangesDialog(),
      );
      if (!mounted) return false;
      return switch (decision) {
        UnsavedChangesDecision.discard => true,
        UnsavedChangesDecision.save => await _saveProject(),
        UnsavedChangesDecision.cancel || null => false,
      };
    } finally {
      _confirmationActive = false;
    }
  }

  Future<AppExitResponse> _handleExitRequested() async {
    if (_hasBlockingProjectOperation ||
        _exitRequestActive ||
        _confirmationActive) {
      return AppExitResponse.cancel;
    }
    if (!_isDirty) return AppExitResponse.exit;
    _exitRequestActive = true;
    try {
      return await _prepareForDestructiveAction()
          ? AppExitResponse.exit
          : AppExitResponse.cancel;
    } finally {
      _exitRequestActive = false;
    }
  }

  Future<void> _showProjectWarnings(List<String> warnings) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Project đã mở với cảnh báo'),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Geometry đã được khôi phục. Một số file nguồn không còn tồn tại:',
                ),
                const SizedBox(height: 12),
                for (final warning in warnings)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('• $warning'),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Future<void> _openCadFiles() async {
    if (_isImporting || _isProjectBusy) return;

    final documents = await _cadFileService.pickCadFiles();

    if (documents.isEmpty || !mounted) return;

    setState(() {
      _isImporting = true;
    });

    final newLayers = <MapLayer>[];
    final errors = <String>[];

    try {
      for (final document in documents) {
        if (_projectContainsPath(document.path)) {
          continue;
        }

        try {
          final layer = await _createCadLayer(document);
          newLayers.add(layer);
        } catch (error) {
          errors.add('${document.name}: $error');
        }
      }

      if (!mounted) return;

      if (newLayers.isNotEmpty) {
        _recordHistory();

        setState(() {
          _project = _project.addLayers(newLayers);
        });
      }

      if (newLayers.isEmpty && errors.isEmpty) {
        _showMessage('Các file đã chọn đều đang có trong dự án.');
        return;
      }

      if (errors.isEmpty) {
        _showMessage('Đã thêm ${newLayers.length} bản vẽ vào dự án.');
        return;
      }

      _showImportResult(importedCount: newLayers.length, errors: errors);
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  Future<void> _openGoogleEarthFiles() async {
    if (_isImporting || _isProjectBusy) return;

    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['kml'],
      dialogTitle: 'Chọn dữ liệu Google Earth (KML)',
    );

    if (files.isEmpty || !mounted) {
      return;
    }

    setState(() {
      _isImporting = true;
    });

    final newLayers = <MapLayer>[];
    final errors = <String>[];
    var skippedCount = 0;

    try {
      for (final file in files) {
        final path = file.path;

        if (path == null || path.trim().isEmpty) {
          errors.add('${file.name}: Không lấy được đường dẫn file.');
          continue;
        }

        if (_projectContainsPath(path)) {
          skippedCount++;
          continue;
        }

        try {
          final parsed = await _kmlParserService.parseFile(path);

          if (parsed.features.isEmpty) {
            errors.add(
              '${file.name}: Không tìm thấy Point, '
              'LineString hoặc Polygon hợp lệ.',
            );
            continue;
          }

          newLayers.add(
            MapLayer(
              id: _createLayerId(),
              name: file.name,
              sourcePath: path,
              sourceType: MapLayerSourceType.kml,
              crs: const CoordinateReferenceSystem.wgs84(),
              features: parsed.features,
              properties: {
                'placemarkCount': parsed.placemarkCount.toString(),
                'pointCount': parsed.pointCount.toString(),
                'lineStringCount': parsed.lineStringCount.toString(),
                'polygonCount': parsed.polygonCount.toString(),
                'sourceFormat': 'KML',
                'coordinateOrder': 'longitude,latitude,altitude',
                'epsg': '4326',
              },
            ),
          );
        } catch (error) {
          errors.add('${file.name}: $error');
        }
      }

      if (!mounted) return;

      if (newLayers.isNotEmpty) {
        _recordHistory();

        setState(() {
          _project = _project.addLayers(newLayers);
        });
      }

      if (newLayers.isEmpty && errors.isEmpty && skippedCount > 0) {
        _showMessage('Các file KML đã chọn đều đang có trong dự án.');
        return;
      }

      if (errors.isEmpty) {
        final skippedText = skippedCount > 0
            ? ' • Bỏ qua $skippedCount file đã có.'
            : '';

        _showMessage(
          'Đã thêm ${newLayers.length} file KML '
          'vào dự án.$skippedText',
        );
        return;
      }

      _showGoogleEarthImportResult(
        importedCount: newLayers.length,
        skippedCount: skippedCount,
        errors: errors,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  void _showGoogleEarthImportResult({
    required int importedCount,
    required int skippedCount,
    required List<String> errors,
  }) {
    if (!mounted) return;

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Kết quả nhập Google Earth'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Đã thêm thành công: '
                    '$importedCount file KML',
                  ),
                  if (skippedCount > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Đã bỏ qua: $skippedCount file '
                      'đang có trong dự án',
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    'Các file không đọc được:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...errors.map(
                    (error) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('• $error'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Đóng'),
            ),
          ],
        );
      },
    );
  }

  bool _projectContainsPath(String path) {
    return _project.layers.any((layer) => layer.sourcePath == path);
  }

  Future<MapLayer> _createCadLayer(CadDocument document) async {
    switch (document.fileType) {
      case CadFileType.dxf:
        return _createDxfLayer(document);

      case CadFileType.dwg:
        return MapLayer(
          id: _createLayerId(),
          name: document.name,
          sourcePath: document.path,
          sourceType: MapLayerSourceType.dwg,
          properties: const {'geometryStatus': 'Chưa hỗ trợ đọc hình học DWG'},
        );

      case CadFileType.unknown:
        return MapLayer(
          id: _createLayerId(),
          name: document.name,
          sourcePath: document.path,
          sourceType: MapLayerSourceType.manual,
        );
    }
  }

  Future<MapLayer> _createDxfLayer(CadDocument document) async {
    final result = await _dxfParserService.parseFile(document.path);

    return MapLayer(
      id: _createLayerId(),
      name: document.name,
      sourcePath: document.path,
      sourceType: MapLayerSourceType.dxf,
      features: result.features,
      properties: {
        'lineCount': result.lineCount.toString(),
        'pairCount': result.pairCount.toString(),
        'sectionCount': result.sections.length.toString(),
        'sections': result.sections.join(', '),
        'pointCount': result.pointCount.toString(),
        'lineEntityCount': result.lineCountEntity.toString(),
        'polylineCount': result.polylineCount.toString(),
        'polygonCount': result.polygonCount.toString(),
      },
    );
  }

  String _createLayerId() {
    return 'layer-${DateTime.now().microsecondsSinceEpoch}';
  }

  void _recordHistory() {
    _history.record(_project);
  }

  void _undo() {
    if (_isProjectBusy) return;
    final previous = _history.undo(_project);

    if (previous == null) return;

    setState(() {
      _project = previous;
    });
  }

  void _redo() {
    if (_isProjectBusy) return;
    final next = _history.redo(_project);

    if (next == null) return;

    setState(() {
      _project = next;
    });
  }

  void _applyFeatureChange(MapFeatureChange change) {
    if (_isProjectBusy) return;
    MapLayer? ownerLayer;

    for (final layer in _project.layers) {
      for (final feature in layer.features) {
        if (identical(feature, change.originalFeature)) {
          ownerLayer = layer;
          break;
        }
      }

      if (ownerLayer != null) break;
    }

    if (ownerLayer == null) {
      _showMessage('Không tìm thấy layer chứa đối tượng.');
      return;
    }

    if (ownerLayer.locked) {
      _showMessage('Layer "${ownerLayer.name}" đang bị khóa.');
      return;
    }

    final index = ownerLayer.features.indexWhere(
      (feature) => identical(feature, change.originalFeature),
    );

    if (index < 0) return;

    final features = List.of(ownerLayer.features);

    features[index] = change.updatedFeature;

    final updatedLayer = ownerLayer.copyWith(features: features);

    _recordHistory();

    setState(() {
      _project = _project.updateLayer(updatedLayer);
    });
  }

  void _removeLayer(String layerId) {
    if (_isProjectBusy) return;
    _recordHistory();

    setState(() {
      _project = _project.removeLayer(layerId);
    });
  }

  void _toggleLayerVisibility(MapLayer layer) {
    if (_isProjectBusy) return;
    _recordHistory();

    setState(() {
      _project = _project.updateLayer(layer.copyWith(visible: !layer.visible));
    });
  }

  void _toggleLayerLock(MapLayer layer) {
    if (_isProjectBusy) return;
    _recordHistory();

    setState(() {
      _project = _project.updateLayer(layer.copyWith(locked: !layer.locked));
    });
  }

  void _moveLayerUp(String layerId) {
    if (_isProjectBusy) return;
    final index = _project.layers.indexWhere((layer) => layer.id == layerId);

    if (index <= 0) return;

    _recordHistory();

    setState(() {
      _project = _project.moveLayerUp(layerId);
    });
  }

  void _moveLayerDown(String layerId) {
    if (_isProjectBusy) return;
    final index = _project.layers.indexWhere((layer) => layer.id == layerId);

    if (index < 0 || index >= _project.layers.length - 1) {
      return;
    }

    _recordHistory();

    setState(() {
      _project = _project.moveLayerDown(layerId);
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _showImportResult({
    required int importedCount,
    required List<String> errors,
  }) {
    if (!mounted) return;

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Kết quả nhập bản vẽ'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Đã thêm thành công: $importedCount file'),
                  const SizedBox(height: 16),
                  const Text(
                    'Các file không đọc được:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...errors.map(
                    (error) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('• $error'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Đóng'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _georeferenceLayer(MapLayer sourceLayer) async {
    if (_isProjectBusy) return;
    if (!sourceLayer.isCad ||
        !sourceLayer.crs.isLocalCad ||
        sourceLayer.features.isEmpty) {
      _showMessage('Chỉ có thể định vị layer CAD cục bộ có dữ liệu hình học.');
      return;
    }

    final request = await showDialog<LayerGeoreferenceRequest>(
      context: context,
      builder: (context) {
        return LayerGeoreferenceDialog(layer: sourceLayer);
      },
    );

    if (request == null || !mounted) {
      return;
    }

    try {
      final result = _layerGeoreferenceService
          .georeferenceLayerWithControlPoints(
            sourceLayer: sourceLayer,
            controlPoints: request.controlPoints,
            targetCrs: request.targetCrs,
            newLayerId: _createLayerId(),
            newLayerName: '${sourceLayer.name} - Georeferenced',
          );

      _recordHistory();

      setState(() {
        _project = _project.addLayer(result.layer);
      });

      _showMessage(
        'Đã định vị "${sourceLayer.name}": '
        '${result.transformedCoordinateCount} tọa độ • '
        '${request.targetCrs.displayName} • '
        'RMSE ${result.rmse.toStringAsFixed(4)} m.',
      );
    } catch (error) {
      _showMessage('Không thể định vị layer: $error');
    }
  }

  void _createWgs84Layer(MapLayer sourceLayer) {
    if (_isProjectBusy) return;
    if (!sourceLayer.canTransformToWgs84) {
      _showMessage(
        'Layer "${sourceLayer.name}" chưa có CRS hợp lệ. '
        'Hãy thiết lập CRS trước.',
      );
      return;
    }

    if (sourceLayer.crs.isWgs84) {
      _showMessage('Layer "${sourceLayer.name}" đã là WGS84 (EPSG:4326).');
      return;
    }

    try {
      final result = _layerReprojectionService.reprojectLayer(
        sourceLayer: sourceLayer,
        targetCrs: const CoordinateReferenceSystem.wgs84(),
        newLayerId: _createLayerId(),
        newLayerName: '${sourceLayer.name} - WGS84',
      );

      _recordHistory();

      setState(() {
        _project = _project.addLayer(result.layer);
      });

      _showMessage(
        'Đã tạo layer WGS84: '
        '${result.transformedFeatureCount} đối tượng, '
        '${result.transformedCoordinateCount} tọa độ.',
      );
    } catch (error) {
      _showMessage('Không thể tạo layer WGS84: $error');
    }
  }

  Future<void> _createUtmLayer(MapLayer sourceLayer) async {
    if (_isProjectBusy || _isImporting || _isExporting) return;
    if (!sourceLayer.crs.isWgs84 || sourceLayer.features.isEmpty) {
      _showMessage('Chỉ có thể tạo UTM từ layer WGS84 có dữ liệu hình học.');
      return;
    }

    final targetCrs = widget.selectUtmCrsOverride != null
        ? await widget.selectUtmCrsOverride!(sourceLayer)
        : mounted
        ? await _showUtmTargetDialog(context)
        : null;
    if (targetCrs == null || !mounted) return;
    if (!targetCrs.isUtm || !targetCrs.isValid) {
      _showMessage('CRS UTM đích không hợp lệ.');
      return;
    }

    try {
      final result = _layerReprojectionService.reprojectLayer(
        sourceLayer: sourceLayer,
        targetCrs: targetCrs,
        newLayerId: _createLayerId(),
        newLayerName: '${sourceLayer.name} - ${targetCrs.displayName}',
      );
      _recordHistory();
      setState(() {
        _project = _project.addLayer(result.layer);
      });
      _showMessage(
        'Đã tạo layer ${targetCrs.displayName}: '
        '${result.transformedFeatureCount} đối tượng, '
        '${result.transformedCoordinateCount} tọa độ.',
      );
    } catch (error) {
      _showMessage('Không thể tạo layer UTM: $error');
    }
  }

  Future<void> _openCoordinateConverter() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return const CoordinateConverterDialog();
      },
    );
  }

  Future<void> _exportKml() async {
    if (_isExporting || _isImporting) return;

    final exportLayers = _project.visibleLayers
        .where(
          (layer) => layer.features.any(
            (feature) => feature.visible && feature.coordinates.isNotEmpty,
          ),
        )
        .toList();

    if (exportLayers.isEmpty) {
      _showMessage('Không có dữ liệu đang hiển thị để xuất KML.');
      return;
    }

    final invalidLayers = exportLayers
        .where((layer) => !layer.crs.isWgs84)
        .toList();

    if (invalidLayers.isNotEmpty) {
      await _showInvalidKmlCrsDialog(invalidLayers);
      return;
    }

    setState(() {
      _isExporting = true;
    });

    try {
      final bytes = _kmlExportService.exportLayersAsBytes(
        documentName: _project.name,
        layers: exportLayers,
      );

      final outputUri = await FilePicker.saveFile(
        dialogTitle: 'Xuất dữ liệu Google Earth (KML)',
        fileName: '${_safeFileName(_project.name)}.kml',
        bytes: bytes,
        mimeType: 'application/vnd.google-earth.kml+xml',
        type: FileType.custom,
        allowedExtensions: const ['kml'],
      );

      if (outputUri == null || !mounted) {
        return;
      }

      await _showKmlExportSuccessDialog(outputUri);
    } catch (error) {
      _showMessage('Không thể xuất KML: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _exportDxf() async {
    if (_isExporting || _isImporting || _isProjectBusy) return;

    DxfExportResult result;
    try {
      result = _dxfExportService.serialize(
        documentName: _project.name,
        layers: _project.layers,
      );
    } catch (error) {
      _showMessage('Không thể xuất DXF: $error');
      return;
    }

    setState(() {
      _isExporting = true;
    });
    try {
      final outputUri = widget.saveDxfOverride != null
          ? await widget.saveDxfOverride!(result.bytes)
          : await FilePicker.saveFile(
              dialogTitle: 'Xuất bản vẽ AutoCAD (DXF ASCII)',
              fileName: '${_safeFileName(_project.name)}.dxf',
              bytes: result.bytes,
              mimeType: 'application/dxf',
              type: FileType.custom,
              allowedExtensions: const ['dxf'],
            );
      if (outputUri == null || !mounted) return;
      final path = outputUri.scheme == 'file'
          ? outputUri.toFilePath(windows: Platform.isWindows)
          : outputUri.toString();
      final warnings = result.warnings.isEmpty
          ? ''
          : ' • ${result.warnings.length} cảnh báo';
      _showMessage(
        'Đã xuất ${result.entityCount} đối tượng trên '
        '${result.layerCount} CAD layer • '
        '${result.exportedCrs.displayName}$warnings • $path',
      );
    } catch (error) {
      _showMessage('Không thể ghi file DXF: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _showInvalidKmlCrsDialog(List<MapLayer> invalidLayers) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Chưa thể xuất KML'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'KML yêu cầu WGS84 (EPSG:4326). '
                    'Các layer đang hiển thị sau chưa phải WGS84:',
                  ),
                  const SizedBox(height: 12),
                  ...invalidLayers.map(
                    (layer) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('• ${layer.name} — ${layer.crs.displayName}'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Hãy gán/định vị CRS, tạo layer WGS84, '
                    'sau đó ẩn layer nguồn trước khi xuất.',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Đã hiểu'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showKmlExportSuccessDialog(Uri outputUri) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        final displayPath = outputUri.scheme == 'file'
            ? outputUri.toFilePath(windows: Platform.isWindows)
            : outputUri.toString();

        return AlertDialog(
          title: const Text('Xuất KML thành công'),
          content: SizedBox(width: 520, child: SelectableText(displayPath)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Đóng'),
            ),
            FilledButton.icon(
              onPressed: outputUri.scheme == 'file' && Platform.isWindows
                  ? () {
                      Navigator.of(context).pop();
                      _openKmlInGoogleEarth(outputUri);
                    }
                  : null,
              icon: const Icon(Icons.public),
              label: const Text('Mở bằng Google Earth'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openKmlInGoogleEarth(Uri outputUri) async {
    if (!Platform.isWindows || outputUri.scheme != 'file') {
      _showMessage('Chỉ hỗ trợ mở KML tự động trên Windows desktop.');
      return;
    }

    try {
      final path = outputUri.toFilePath(windows: true);

      await Process.start('explorer.exe', [
        path,
      ], mode: ProcessStartMode.detached);

      _showMessage(
        'Đã gửi file KML tới ứng dụng mặc định. '
        'Nếu Google Earth chưa được cài đặt, '
        'Windows sẽ yêu cầu chọn ứng dụng.',
      );
    } on ProcessException catch (error) {
      _showMessage(
        'Windows không thể mở file KML. '
        'Hãy kiểm tra Google Earth hoặc ứng dụng mặc định: '
        '${error.message}',
      );
    } catch (error) {
      _showMessage('Không thể mở file KML: $error');
    }
  }

  String _safeFileName(String value) {
    final sanitized = value.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();

    return sanitized.isEmpty ? 'geocad_bridge' : sanitized;
  }

  void _updateLayerCrs(MapLayer layer, CoordinateReferenceSystem crs) {
    if (_isProjectBusy) return;
    if (!layer.crs.isLocalCad) {
      _showMessage(
        'CRS của "${layer.name}" đã được xác định. '
        'Hãy dùng chức năng chuyển đổi tọa độ thay vì gán lại metadata.',
      );
      return;
    }
    if (layer.crs.type == crs.type &&
        layer.crs.utmZone == crs.utmZone &&
        layer.crs.hemisphere == crs.hemisphere) {
      return;
    }

    _recordHistory();

    setState(() {
      _project = _project.updateLayer(layer.withCrs(crs));
    });

    _showMessage('Đã đặt CRS cho "${layer.name}": ${crs.displayName}');
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.keyZ, control: true): _UndoIntent(),
        SingleActivator(LogicalKeyboardKey.keyY, control: true): _RedoIntent(),
      },
      child: Actions(
        actions: {
          _UndoIntent: CallbackAction<_UndoIntent>(
            onInvoke: (_) {
              _undo();
              return null;
            },
          ),
          _RedoIntent: CallbackAction<_RedoIntent>(
            onInvoke: (_) {
              _redo();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            appBar: AppBar(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              title: Text(
                'AutoCAD ↔ Google Earth — ${_project.name}${_isDirty ? ' *' : ''}',
                key: const Key('project-title'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              actions: [
                IconButton(
                  tooltip: 'Project mới',
                  onPressed: _hasBlockingProjectOperation ? null : _newProject,
                  icon: const Icon(Icons.note_add_outlined),
                ),
                IconButton(
                  tooltip: 'Mở project',
                  onPressed: _hasBlockingProjectOperation ? null : _openProject,
                  icon: const Icon(Icons.folder_open),
                ),
                IconButton(
                  tooltip: 'Lưu project',
                  onPressed: _hasBlockingProjectOperation ? null : _saveProject,
                  icon: const Icon(Icons.save_outlined),
                ),
                IconButton(
                  tooltip: 'Lưu project thành...',
                  onPressed: _hasBlockingProjectOperation
                      ? null
                      : _saveProjectAs,
                  icon: const Icon(Icons.save_as_outlined),
                ),
                const VerticalDivider(
                  width: 20,
                  indent: 12,
                  endIndent: 12,
                  color: Colors.white38,
                ),
                IconButton(
                  tooltip: 'Undo (Ctrl+Z)',
                  onPressed: !_isProjectBusy && _history.canUndo ? _undo : null,
                  icon: const Icon(Icons.undo),
                ),
                IconButton(
                  tooltip: 'Redo (Ctrl+Y)',
                  onPressed: !_isProjectBusy && _history.canRedo ? _redo : null,
                  icon: const Icon(Icons.redo),
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: AbsorbPointer(
              absorbing: _isProjectBusy,
              child: Row(
                children: [
                  SizedBox(
                    width: 340,
                    child: _LeftPanel(
                      project: _project,
                      isImporting: _isImporting,
                      isExporting: _isExporting,
                      onOpenCadFiles: _openCadFiles,
                      onOpenGoogleEarthFiles: _openGoogleEarthFiles,
                      onOpenCoordinateConverter: _openCoordinateConverter,
                      onExportKml: _exportKml,
                      onExportDxf: _exportDxf,
                      onUpdateLayerCrs: _updateLayerCrs,
                      onCreateWgs84Layer: _createWgs84Layer,
                      onCreateUtmLayer: _createUtmLayer,
                      onGeoreferenceLayer: _georeferenceLayer,
                      onToggleVisibility: _toggleLayerVisibility,
                      onToggleLock: _toggleLayerLock,
                      onRemoveLayer: _removeLayer,
                      onMoveLayerUp: _moveLayerUp,
                      onMoveLayerDown: _moveLayerDown,
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: _Workspace(
                      project: _project,
                      isImporting: _isImporting,
                      onFeatureChanged: _applyFeatureChange,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UndoIntent extends Intent {
  const _UndoIntent();
}

class _RedoIntent extends Intent {
  const _RedoIntent();
}

class _LeftPanel extends StatelessWidget {
  final MapProject project;
  final bool isImporting;
  final bool isExporting;

  final VoidCallback onOpenCadFiles;
  final VoidCallback onOpenGoogleEarthFiles;
  final VoidCallback onOpenCoordinateConverter;
  final VoidCallback onExportKml;
  final VoidCallback onExportDxf;
  final void Function(MapLayer layer, CoordinateReferenceSystem crs)
  onUpdateLayerCrs;
  final ValueChanged<MapLayer> onCreateWgs84Layer;
  final ValueChanged<MapLayer> onCreateUtmLayer;
  final ValueChanged<MapLayer> onGeoreferenceLayer;
  final ValueChanged<MapLayer> onToggleVisibility;
  final ValueChanged<MapLayer> onToggleLock;
  final ValueChanged<String> onRemoveLayer;
  final ValueChanged<String> onMoveLayerUp;
  final ValueChanged<String> onMoveLayerDown;

  const _LeftPanel({
    required this.project,
    required this.isImporting,
    required this.isExporting,
    required this.onOpenCadFiles,
    required this.onOpenGoogleEarthFiles,
    required this.onOpenCoordinateConverter,
    required this.onExportKml,
    required this.onExportDxf,
    required this.onUpdateLayerCrs,
    required this.onCreateWgs84Layer,
    required this.onCreateUtmLayer,
    required this.onGeoreferenceLayer,
    required this.onToggleVisibility,
    required this.onToggleLock,
    required this.onRemoveLayer,
    required this.onMoveLayerUp,
    required this.onMoveLayerDown,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF4F6F8),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'CÔNG CỤ',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                _ToolButton(
                  icon: Icons.folder_open,
                  title: isImporting
                      ? 'Đang đọc bản vẽ...'
                      : 'Thêm bản vẽ AutoCAD',
                  subtitle: 'Chọn nhiều DWG / DXF',
                  onPressed: isImporting ? null : onOpenCadFiles,
                ),
                const SizedBox(height: 10),
                _ToolButton(
                  icon: Icons.public,
                  title: isImporting
                      ? 'Đang đọc dữ liệu...'
                      : 'Thêm dữ liệu Google Earth',
                  subtitle: 'KML (WGS84 / EPSG:4326)',
                  onPressed: isImporting ? null : onOpenGoogleEarthFiles,
                ),
                const SizedBox(height: 10),
                _ToolButton(
                  icon: Icons.sync_alt,
                  title: 'Chuyển đổi tọa độ',
                  subtitle: 'UTM ↔ WGS84',
                  onPressed: onOpenCoordinateConverter,
                ),
                const SizedBox(height: 10),
                _ToolButton(
                  icon: Icons.edit_location_alt,
                  title: 'Chỉnh sửa dữ liệu',
                  subtitle: 'Hình học / thuộc tính',
                  onPressed: () {},
                ),
                const SizedBox(height: 10),
                _ToolButton(
                  icon: Icons.map,
                  title: isExporting
                      ? 'Đang xuất KML...'
                      : 'Xuất sang Google Earth',
                  subtitle: 'KML (WGS84 / EPSG:4326)',
                  onPressed: isImporting || isExporting ? null : onExportKml,
                ),
                const SizedBox(height: 10),
                _ToolButton(
                  icon: Icons.architecture,
                  title: isExporting ? 'Đang xuất DXF...' : 'Xuất sang AutoCAD',
                  subtitle: 'DXF ASCII',
                  onPressed: isImporting || isExporting ? null : onExportDxf,
                ),
                const SizedBox(height: 10),
                _ToolButton(
                  icon: Icons.picture_as_pdf,
                  title: 'Xuất sang PDF',
                  subtitle: 'Bản vẽ / Bản đồ',
                  onPressed: () {},
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'CÁC LỚP DỮ LIỆU',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    Text(
                      '${project.layerCount}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (project.layers.isEmpty)
                  const _EmptyLayerPanel()
                else
                  ...List.generate(project.layers.length, (index) {
                    final layer = project.layers[index];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _LayerCard(
                        layer: layer,
                        isFirst: index == 0,
                        isLast: index == project.layers.length - 1,
                        onToggleVisibility: () {
                          onToggleVisibility(layer);
                        },
                        onToggleLock: () {
                          onToggleLock(layer);
                        },
                        onRemove: () {
                          onRemoveLayer(layer.id);
                        },
                        onEditCrs: () async {
                          final crs = await _showLayerCrsDialog(context, layer);

                          if (crs != null) {
                            onUpdateLayerCrs(layer, crs);
                          }
                        },
                        onCreateWgs84: () {
                          onCreateWgs84Layer(layer);
                        },
                        onCreateUtm: () {
                          onCreateUtmLayer(layer);
                        },
                        onGeoreference: () {
                          onGeoreferenceLayer(layer);
                        },
                        onMoveUp: () {
                          onMoveLayerUp(layer.id);
                        },
                        onMoveDown: () {
                          onMoveLayerDown(layer.id);
                        },
                      ),
                    );
                  }),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              '${project.layerCount} lớp • '
              '${project.featureCount} đối tượng',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}

Future<CoordinateReferenceSystem?> _showUtmTargetDialog(
  BuildContext context,
) async {
  var zone = 48;
  var hemisphere = UtmHemisphere.north;

  return showDialog<CoordinateReferenceSystem>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Tạo layer UTM'),
            content: SizedBox(
              width: 480,
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: zone,
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
                        if (value != null) {
                          setDialogState(() => zone = value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<UtmHemisphere>(
                      initialValue: hemisphere,
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
                        if (value != null) {
                          setDialogState(() => hemisphere = value);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop(
                    CoordinateReferenceSystem.utm(
                      utmZone: zone,
                      hemisphere: hemisphere,
                    ),
                  );
                },
                child: const Text('Tạo layer'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<CoordinateReferenceSystem?> _showLayerCrsDialog(
  BuildContext context,
  MapLayer layer,
) async {
  var type = layer.crs.type;
  var zone = layer.crs.utmZone ?? 48;
  var hemisphere = layer.crs.hemisphere ?? UtmHemisphere.north;

  return showDialog<CoordinateReferenceSystem>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          CoordinateReferenceSystem preview;

          switch (type) {
            case CoordinateReferenceSystemType.localCad:
              preview = const CoordinateReferenceSystem.localCad();
            case CoordinateReferenceSystemType.wgs84:
              preview = const CoordinateReferenceSystem.wgs84();
            case CoordinateReferenceSystemType.utm:
              preview = CoordinateReferenceSystem.utm(
                utmZone: zone,
                hemisphere: hemisphere,
              );
          }

          return AlertDialog(
            title: const Text('Gán hệ tọa độ nguồn'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      layer.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 18),
                    DropdownButtonFormField<CoordinateReferenceSystemType>(
                      initialValue: type,
                      decoration: const InputDecoration(
                        labelText: 'Hệ tọa độ',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: CoordinateReferenceSystemType.localCad,
                          child: Text('CAD cục bộ / chưa xác định'),
                        ),
                        DropdownMenuItem(
                          value: CoordinateReferenceSystemType.wgs84,
                          child: Text('WGS84 (EPSG:4326)'),
                        ),
                        DropdownMenuItem(
                          value: CoordinateReferenceSystemType.utm,
                          child: Text('UTM'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;

                        setDialogState(() {
                          type = value;
                        });
                      },
                    ),
                    if (type == CoordinateReferenceSystemType.utm) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: zone,
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

                                setDialogState(() {
                                  zone = value;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<UtmHemisphere>(
                              initialValue: hemisphere,
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

                                setDialogState(() {
                                  hemisphere = value;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F6F8),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFDDE3E8)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: Color(0xFF1565C0),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  preview.displayName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (preview.epsgCode != null)
                                  Text(
                                    'EPSG:${preview.epsgCode}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Lưu ý: thao tác này chỉ khai báo CRS '
                      'của layer, không tự thay đổi các giá trị '
                      'tọa độ X/Y đang có.',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Hủy'),
              ),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop(preview);
                },
                icon: const Icon(Icons.check),
                label: const Text('Áp dụng'),
              ),
            ],
          );
        },
      );
    },
  );
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onPressed;

  const _ToolButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.tonal(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSecondaryContainer
                          .withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyLayerPanel extends StatelessWidget {
  const _EmptyLayerPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: const Text(
        'Chưa có lớp dữ liệu.\n'
        'Hãy thêm bản vẽ AutoCAD hoặc dữ liệu Google Earth.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: Colors.grey),
      ),
    );
  }
}

class _LayerCard extends StatelessWidget {
  final MapLayer layer;
  final bool isFirst;
  final bool isLast;

  final VoidCallback onToggleVisibility;
  final VoidCallback onToggleLock;
  final VoidCallback onRemove;
  final VoidCallback onEditCrs;
  final VoidCallback onCreateWgs84;
  final VoidCallback onCreateUtm;
  final VoidCallback onGeoreference;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  const _LayerCard({
    required this.layer,
    required this.isFirst,
    required this.isLast,
    required this.onToggleVisibility,
    required this.onToggleLock,
    required this.onRemove,
    required this.onEditCrs,
    required this.onCreateWgs84,
    required this.onCreateUtm,
    required this.onGeoreference,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 6, 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  tooltip: layer.visible ? 'Ẩn layer' : 'Hiện layer',
                  onPressed: onToggleVisibility,
                  icon: Icon(
                    layer.visible ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        layer.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: layer.visible ? null : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_layerTypeLabel(layer.sourceType)}'
                        ' • ${layer.featureCount} đối tượng',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 5),
                      InkWell(
                        onTap: layer.crs.isLocalCad ? onEditCrs : null,
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                layer.hasKnownCrs
                                    ? Icons.language
                                    : Icons.help_outline,
                                size: 14,
                                color: layer.hasKnownCrs
                                    ? const Color(0xFF1565C0)
                                    : Colors.orange.shade700,
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  layer.crsLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: layer.hasKnownCrs
                                        ? const Color(0xFF1565C0)
                                        : Colors.orange.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: layer.locked ? 'Mở khóa layer' : 'Khóa layer',
                  onPressed: onToggleLock,
                  icon: Icon(layer.locked ? Icons.lock : Icons.lock_open),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Đưa layer lên',
                onPressed: isFirst ? null : onMoveUp,
                icon: const Icon(Icons.keyboard_arrow_up),
              ),
              IconButton(
                tooltip: 'Đưa layer xuống',
                onPressed: isLast ? null : onMoveDown,
                icon: const Icon(Icons.keyboard_arrow_down),
              ),
              IconButton(
                tooltip: 'Định vị layer bằng các điểm khống chế',
                onPressed:
                    layer.isCad &&
                        layer.crs.isLocalCad &&
                        layer.features.isNotEmpty
                    ? onGeoreference
                    : null,
                icon: const Icon(Icons.add_location_alt_outlined),
              ),
              if (layer.crs.isWgs84)
                IconButton(
                  tooltip: 'Tạo layer UTM',
                  onPressed: layer.features.isEmpty ? null : onCreateUtm,
                  icon: const Icon(Icons.grid_on),
                )
              else
                IconButton(
                  tooltip: 'Tạo layer WGS84',
                  onPressed: layer.canTransformToWgs84 ? onCreateWgs84 : null,
                  icon: const Icon(Icons.public),
                ),
              IconButton(
                tooltip: layer.crs.isLocalCad
                    ? 'Gán hệ tọa độ nguồn'
                    : 'CRS đã xác định; hãy dùng chuyển đổi tọa độ',
                onPressed: layer.crs.isLocalCad ? onEditCrs : null,
                icon: const Icon(Icons.language),
              ),
              IconButton(
                tooltip: 'Xóa layer khỏi dự án',
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _layerTypeLabel(MapLayerSourceType type) {
    switch (type) {
      case MapLayerSourceType.dwg:
        return 'DWG';
      case MapLayerSourceType.dxf:
        return 'DXF';
      case MapLayerSourceType.kml:
        return 'KML';
      case MapLayerSourceType.kmz:
        return 'KMZ';
      case MapLayerSourceType.manual:
        return 'THỦ CÔNG';
    }
  }
}

class _Workspace extends StatelessWidget {
  final MapProject project;
  final bool isImporting;
  final ValueChanged<MapFeatureChange> onFeatureChanged;

  const _Workspace({
    required this.project,
    required this.isImporting,
    required this.onFeatureChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (isImporting) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Đang đọc dữ liệu bản vẽ...'),
          ],
        ),
      );
    }

    if (project.layers.isEmpty) {
      return const _EmptyWorkspace();
    }

    return Column(
      children: [
        _WorkspaceHeader(project: project),
        const Divider(height: 1),
        Expanded(
          child: Container(
            color: const Color(0xFFE9EDF1),
            padding: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFD0D5DA)),
                ),
                child: MapCanvas(
                  project: project,
                  onFeatureChanged: onFeatureChanged,
                ),
              ),
            ),
          ),
        ),
        _WorkspaceStatusBar(project: project),
      ],
    );
  }
}

class _WorkspaceHeader extends StatelessWidget {
  final MapProject project;

  const _WorkspaceHeader({required this.project});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.layers, color: Color(0xFF1565C0)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${project.layerCount} lớp • '
                  '${project.featureCount} đối tượng',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          _HeaderInfo(
            icon: Icons.architecture,
            label: 'CAD',
            value: '${project.cadLayers.length}',
          ),
          const SizedBox(width: 20),
          _HeaderInfo(
            icon: Icons.public,
            label: 'Google Earth',
            value: '${project.googleEarthLayers.length}',
          ),
          const SizedBox(width: 20),
          _HeaderInfo(
            icon: Icons.visibility,
            label: 'Đang hiển thị',
            value: '${project.visibleFeatures.length}',
          ),
        ],
      ),
    );
  }
}

class _HeaderInfo extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _HeaderInfo({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade700),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }
}

class _WorkspaceStatusBar extends StatelessWidget {
  final MapProject project;

  const _WorkspaceStatusBar({required this.project});

  @override
  Widget build(BuildContext context) {
    final visibleLayerCount = project.visibleLayers.length;

    return Container(
      color: const Color(0xFFF4F6F8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$visibleLayerCount/${project.layerCount} layer đang hiển thị',
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ),
          Text(
            '${project.visibleFeatures.length} đối tượng hiển thị',
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _EmptyWorkspace extends StatelessWidget {
  const _EmptyWorkspace();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.satellite_alt, size: 90, color: Colors.blue.shade700),
            const SizedBox(height: 24),
            const Text(
              'AutoCAD ↔ Google Earth',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Lồng ghép • Chỉnh sửa • Chuyển đổi • Xuất bản',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            const Text(
              'Hãy thêm một hoặc nhiều bản vẽ AutoCAD '
              'để bắt đầu tạo project.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
