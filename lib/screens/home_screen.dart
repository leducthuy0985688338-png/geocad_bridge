import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart' as file_selector;

import '../models/cad_document.dart';
import '../models/coordinate_reference_system.dart';
import '../models/map_feature.dart';
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
import '../l10n/generated/app_localizations.dart';

typedef ProjectSavePathSelector = Future<String?> Function({
  required String suggestedName,
  required List<String> allowedExtensions,
});

typedef CadDocumentsSelector = Future<List<CadDocument>> Function();

class HomeScreen extends StatefulWidget {
  final MapProject? initialProject;
  final Future<bool> Function(MapProject project)? saveProjectOverride;
  final ProjectSavePathSelector? projectSavePathSelectorOverride;
  final Future<GeoCadProjectDocument?> Function()? openProjectOverride;
  final Future<Uri?> Function(Uint8List bytes)? saveDxfOverride;
  final Future<CoordinateReferenceSystem?> Function(MapLayer layer)?
  selectUtmCrsOverride;
  final CadDocumentsSelector? cadDocumentsSelectorOverride;

  const HomeScreen({
    super.key,
    this.initialProject,
    this.saveProjectOverride,
    this.projectSavePathSelectorOverride,
    this.openProjectOverride,
    this.saveDxfOverride,
    this.selectUtmCrsOverride,
    this.cadDocumentsSelectorOverride,
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
    _showMessage(AppLocalizations.of(context).projectCreated);
  }

  Future<void> _openProject() async {
    if (_hasBlockingProjectOperation) return;
    final l10n = AppLocalizations.of(context);
    if (!await _prepareForDestructiveAction() || !mounted) return;
    final override = widget.openProjectOverride;
    if (override != null) {
      setState(() => _isProjectBusy = true);
      try {
        final loaded = await override();
        if (loaded == null || !mounted) return;
        _applyLoadedProject(loaded, path: null);
      } catch (error) {
        _showMessage(l10n.projectOpenFailed(error.toString()));
      } finally {
        if (mounted) setState(() => _isProjectBusy = false);
      }
      return;
    }
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['geocad'],
      dialogTitle: l10n.openGeoCadProject,
    );
    if (files.isEmpty || !mounted) return;
    final path = files.single.path;
    if (path == null || path.isEmpty) {
      _showMessage(l10n.projectPathUnavailable);
      return;
    }

    setState(() => _isProjectBusy = true);
    try {
      final loaded = await _projectPersistenceService.load(path);
      if (!mounted) return;
      _applyLoadedProject(loaded, path: path);
      if (loaded.warnings.isEmpty) {
        _showMessage(l10n.projectOpened(loaded.project.name));
      } else {
        await _showProjectWarnings(loaded.warnings);
      }
    } catch (error) {
      _showMessage(l10n.projectOpenFailed(error.toString()));
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
        _showMessage(
          AppLocalizations.of(context).projectSaveFailed(error.toString()),
        );
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
          label: AppLocalizations.of(context).geoCadProject,
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
      _showMessage(AppLocalizations.of(context).projectSaved(path));
      return true;
    } catch (error) {
      _showMessage(
        AppLocalizations.of(context).projectSaveFailed(error.toString()),
      );
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
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.projectOpenedWithWarnings),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.geometryRestoredMissingSources),
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
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  Future<void> _openCadFiles() async {
    if (_isImporting || _isProjectBusy) return;
    final l10n = AppLocalizations.of(context);

    final selector = widget.cadDocumentsSelectorOverride;
    final documents = selector != null
        ? await selector()
        : await _cadFileService.pickCadFiles();

    if (documents.isEmpty || !mounted) return;

    setState(() {
      _isImporting = true;
    });

    final newLayers = <MapLayer>[];
    final errors = <String>[];
    final dxfSummaries =
        <({String fileName, DxfImportDiagnostics diagnostics})>[];

    try {
      for (final document in documents) {
        if (_projectContainsPath(document.path)) {
          continue;
        }

        try {
          final importResult = await _createCadLayer(document);
          final layer = importResult.layer;
          final diagnostics = importResult.diagnostics;
          if (layer != null) {
            newLayers.add(layer);
          }
          if (diagnostics != null && diagnostics.hasIssues) {
            dxfSummaries.add((
              fileName: document.name,
              diagnostics: diagnostics,
            ));
          } else if (layer == null) {
            errors.add(l10n.dxfNoValidEntities(document.name));
          }
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

      if (dxfSummaries.isNotEmpty) {
        await _showDxfImportSummary(
          summaries: dxfSummaries,
          importedLayerCount: newLayers.length,
          errors: errors,
        );
        return;
      }

      if (newLayers.isEmpty && errors.isEmpty) {
        _showMessage(l10n.selectedFilesAlreadyInProject);
        return;
      }

      if (errors.isEmpty) {
        _showMessage(l10n.cadDrawingsAdded(newLayers.length));
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
    final l10n = AppLocalizations.of(context);

    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['kml'],
      dialogTitle: l10n.selectGoogleEarthKml,
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
          errors.add(l10n.filePathUnavailable(file.name));
          continue;
        }

        if (_projectContainsPath(path)) {
          skippedCount++;
          continue;
        }

        try {
          final parsed = await _kmlParserService.parseFile(path);

          if (parsed.features.isEmpty) {
            errors.add(l10n.kmlNoValidGeometry(file.name));
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
        _showMessage(l10n.selectedKmlAlreadyInProject);
        return;
      }

      if (errors.isEmpty) {
        final skippedText = skippedCount > 0
            ? l10n.skippedExistingFiles(skippedCount)
            : '';

        _showMessage(l10n.kmlFilesAdded(newLayers.length, skippedText));
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
    final l10n = AppLocalizations.of(context);

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.googleEarthImportResult),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.googleEarthFilesImported(importedCount)),
                  if (skippedCount > 0) ...[
                    const SizedBox(height: 6),
                    Text(l10n.googleEarthFilesSkipped(skippedCount)),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    l10n.unreadableFiles,
                    style: const TextStyle(fontWeight: FontWeight.bold),
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
              child: Text(l10n.close),
            ),
          ],
        );
      },
    );
  }

  bool _projectContainsPath(String path) {
    return _project.layers.any((layer) => layer.sourcePath == path);
  }

  Future<void> _showDxfImportSummary({
    required List<({String fileName, DxfImportDiagnostics diagnostics})>
    summaries,
    required int importedLayerCount,
    required List<String> errors,
  }) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.dxfImportResult),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.dxfLayersImported(importedLayerCount)),
                const SizedBox(height: 12),
                for (final summary in summaries) ...[
                  Text(
                    summary.fileName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    l10n.dxfEntitiesImported(
                      summary.diagnostics.parsedEntityCount,
                    ),
                  ),
                  Text(
                    l10n.dxfMalformedSkipped(
                      summary.diagnostics.malformedEntityCount,
                    ),
                  ),
                  Text(
                    l10n.dxfUnsupportedEntities(
                      summary.diagnostics.unsupportedEntityCount,
                    ),
                  ),
                  for (final entry
                      in summary.diagnostics.unsupportedEntityCounts.entries)
                    Text('  • ${entry.key}: ${entry.value}'),
                  if (summary.diagnostics.hasFidelityWarnings) ...[
                    const SizedBox(height: 4),
                    Text(l10n.dxfFidelityWarnings),
                    for (final entry in _aggregateDxfWarnings(
                      summary.diagnostics,
                    ).entries)
                      Text('  • ${entry.value}× ${entry.key}'),
                  ],
                  const SizedBox(height: 12),
                ],
                if (errors.isNotEmpty) ...[
                  Text(
                    l10n.unreadableFiles,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  for (final error in errors) Text('• $error'),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  Map<String, int> _aggregateDxfWarnings(DxfImportDiagnostics diagnostics) {
    final result = <String, int>{};
    for (final issue in diagnostics.issues.where(
      (issue) =>
          issue.severity == DxfDiagnosticSeverity.warning &&
          issue.code != DxfDiagnosticCode.unsupportedEntity,
    )) {
      result.update(issue.reason, (count) => count + 1, ifAbsent: () => 1);
    }
    return result;
  }

  Future<({MapLayer? layer, DxfImportDiagnostics? diagnostics})>
  _createCadLayer(CadDocument document) async {
    switch (document.fileType) {
      case CadFileType.dxf:
        return _createDxfLayer(document);

      case CadFileType.dwg:
        return (
          layer: MapLayer(
            id: _createLayerId(),
            name: document.name,
            sourcePath: document.path,
            sourceType: MapLayerSourceType.dwg,
            properties: const {
              'geometryStatus': 'Chưa hỗ trợ đọc hình học DWG',
            },
          ),
          diagnostics: null,
        );

      case CadFileType.unknown:
        return (
          layer: MapLayer(
            id: _createLayerId(),
            name: document.name,
            sourcePath: document.path,
            sourceType: MapLayerSourceType.manual,
          ),
          diagnostics: null,
        );
    }
  }

  Future<({MapLayer? layer, DxfImportDiagnostics diagnostics})> _createDxfLayer(
    CadDocument document,
  ) async {
    final result = await _dxfParserService.parseFile(document.path);

    return (
      layer: result.features.isEmpty
          ? null
          : MapLayer(
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
            ),
      diagnostics: result.diagnostics,
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
      _showMessage(AppLocalizations.of(context).featureOwnerLayerNotFound);
      return;
    }

    if (ownerLayer.locked) {
      _showMessage(AppLocalizations.of(context).layerLocked(ownerLayer.name));
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

  void _applyFeatureCreation(MapFeature feature) {
    if (_isProjectBusy) return;

    MapLayer? drawingLayer;
    for (final layer in _project.layers) {
      if (layer.sourceType == MapLayerSourceType.manual &&
          layer.name == 'Manual Drawing' &&
          layer.sourcePath == null &&
          !layer.locked) {
        drawingLayer = layer;
        break;
      }
    }

    _recordHistory();

    setState(() {
      if (drawingLayer == null) {
        final layer = MapLayer(
          id: _createLayerId(),
          name: 'Manual Drawing',
          sourceType: MapLayerSourceType.manual,
          sourcePath: null,
          features: [feature],
        );
        _project = _project.addLayer(layer);
      } else {
        _project = _project.updateLayer(drawingLayer.addFeature(feature));
      }
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
    final l10n = AppLocalizations.of(context);

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.cadImportResult),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.cadFilesImported(importedCount)),
                  const SizedBox(height: 16),
                  Text(
                    l10n.unreadableFiles,
                    style: const TextStyle(fontWeight: FontWeight.bold),
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
              child: Text(l10n.close),
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
      _showMessage(AppLocalizations.of(context).georeferenceLocalCadOnly);
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
        AppLocalizations.of(context).georeferenceSucceeded(
          sourceLayer.name,
          result.transformedCoordinateCount,
          request.targetCrs.displayName,
          result.rmse.toStringAsFixed(4),
        ),
      );
    } catch (error) {
      _showMessage(
        AppLocalizations.of(context).georeferenceLayerFailed(error.toString()),
      );
    }
  }

  void _createWgs84Layer(MapLayer sourceLayer) {
    if (_isProjectBusy) return;
    if (!sourceLayer.canTransformToWgs84) {
      _showMessage(
        AppLocalizations.of(context).layerNeedsValidCrs(sourceLayer.name),
      );
      return;
    }

    if (sourceLayer.crs.isWgs84) {
      _showMessage(
        AppLocalizations.of(context).layerAlreadyWgs84(sourceLayer.name),
      );
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
        AppLocalizations.of(context).wgs84LayerCreated(
          result.transformedFeatureCount,
          result.transformedCoordinateCount,
        ),
      );
    } catch (error) {
      _showMessage(
        AppLocalizations.of(context).createWgs84Failed(error.toString()),
      );
    }
  }

  Future<void> _createUtmLayer(MapLayer sourceLayer) async {
    if (_isProjectBusy || _isImporting || _isExporting) return;
    if (!sourceLayer.crs.isWgs84 || sourceLayer.features.isEmpty) {
      _showMessage(AppLocalizations.of(context).createUtmFromWgs84Only);
      return;
    }

    final targetCrs = widget.selectUtmCrsOverride != null
        ? await widget.selectUtmCrsOverride!(sourceLayer)
        : mounted
        ? await _showUtmTargetDialog(context)
        : null;
    if (targetCrs == null || !mounted) return;
    if (!targetCrs.isUtm || !targetCrs.isValid) {
      _showMessage(AppLocalizations.of(context).invalidTargetUtmCrs);
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
        AppLocalizations.of(context).utmLayerCreated(
          targetCrs.displayName,
          result.transformedFeatureCount,
          result.transformedCoordinateCount,
        ),
      );
    } catch (error) {
      _showMessage(
        AppLocalizations.of(context).createUtmFailed(error.toString()),
      );
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
    final l10n = AppLocalizations.of(context);

    final exportLayers = _project.visibleLayers
        .where(
          (layer) => layer.features.any(
            (feature) => feature.visible && feature.coordinates.isNotEmpty,
          ),
        )
        .toList();

    if (exportLayers.isEmpty) {
      _showMessage(l10n.noVisibleDataForKml);
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
        dialogTitle: l10n.exportGoogleEarthKml,
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
      _showMessage(l10n.exportKmlFailed(error.toString()));
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
      _showMessage(
        AppLocalizations.of(context).exportDxfFailed(error.toString()),
      );
      return;
    }

    setState(() {
      _isExporting = true;
    });
    try {
      final outputUri = widget.saveDxfOverride != null
          ? await widget.saveDxfOverride!(result.bytes)
          : await FilePicker.saveFile(
              dialogTitle: AppLocalizations.of(context).exportAutoCadDxfAscii,
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
          : AppLocalizations.of(context).exportWarnings(result.warnings.length);
      _showMessage(
        AppLocalizations.of(context).dxfExportSucceeded(
          result.entityCount,
          result.layerCount,
          result.exportedCrs.displayName,
          warnings,
          path,
        ),
      );
    } catch (error) {
      _showMessage(
        AppLocalizations.of(context).writeDxfFailed(error.toString()),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _showInvalidKmlCrsDialog(List<MapLayer> invalidLayers) async {
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.kmlExportUnavailable),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.kmlRequiresWgs84),
                  const SizedBox(height: 12),
                  ...invalidLayers.map(
                    (layer) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('• ${layer.name} — ${layer.crs.displayName}'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(l10n.kmlPrepareWgs84Hint),
                ],
              ),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.understood),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showKmlExportSuccessDialog(Uri outputUri) async {
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (context) {
        final displayPath = outputUri.scheme == 'file'
            ? outputUri.toFilePath(windows: Platform.isWindows)
            : outputUri.toString();

        return AlertDialog(
          title: Text(l10n.kmlExportSucceeded),
          content: SizedBox(width: 520, child: SelectableText(displayPath)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.close),
            ),
            FilledButton.icon(
              onPressed: outputUri.scheme == 'file' && Platform.isWindows
                  ? () {
                      Navigator.of(context).pop();
                      _openKmlInGoogleEarth(outputUri);
                    }
                  : null,
              icon: const Icon(Icons.public),
              label: Text(l10n.openWithGoogleEarth),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openKmlInGoogleEarth(Uri outputUri) async {
    final l10n = AppLocalizations.of(context);
    if (!Platform.isWindows || outputUri.scheme != 'file') {
      _showMessage(l10n.autoOpenKmlWindowsOnly);
      return;
    }

    try {
      final path = outputUri.toFilePath(windows: true);

      await Process.start('explorer.exe', [
        path,
      ], mode: ProcessStartMode.detached);

      _showMessage(l10n.kmlSentToDefaultApp);
    } on ProcessException catch (error) {
      _showMessage(l10n.windowsOpenKmlFailed(error.message));
    } catch (error) {
      _showMessage(l10n.openKmlFailed(error.toString()));
    }
  }

  String _safeFileName(String value) {
    final sanitized = value.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();

    return sanitized.isEmpty ? 'geocad_bridge' : sanitized;
  }

  void _updateLayerCrs(MapLayer layer, CoordinateReferenceSystem crs) {
    if (_isProjectBusy) return;
    if (!layer.crs.isLocalCad) {
      _showMessage(AppLocalizations.of(context).crsAlreadyDefined(layer.name));
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

    _showMessage(
      AppLocalizations.of(context).crsAssigned(layer.name, crs.displayName),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

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
                  tooltip: l10n.projectNew,
                  onPressed: _hasBlockingProjectOperation ? null : _newProject,
                  icon: const Icon(Icons.note_add_outlined),
                ),
                IconButton(
                  tooltip: l10n.projectOpen,
                  onPressed: _hasBlockingProjectOperation ? null : _openProject,
                  icon: const Icon(Icons.folder_open),
                ),
                IconButton(
                  tooltip: l10n.projectSave,
                  onPressed: _hasBlockingProjectOperation ? null : _saveProject,
                  icon: const Icon(Icons.save_outlined),
                ),
                IconButton(
                  tooltip: l10n.projectSaveAs,
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
                  tooltip: l10n.undo,
                  onPressed: !_isProjectBusy && _history.canUndo ? _undo : null,
                  icon: const Icon(Icons.undo),
                ),
                IconButton(
                  tooltip: l10n.redo,
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
                      onFeatureCreated: _applyFeatureCreation,
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
    final l10n = AppLocalizations.of(context);

    return Container(
      color: const Color(0xFFF4F6F8),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  l10n.tools,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                _ToolButton(
                  icon: Icons.folder_open,
                  title: isImporting
                      ? l10n.importingCad
                      : l10n.addAutoCadDrawing,
                  subtitle: l10n.selectMultipleDwgDxf,
                  onPressed: isImporting ? null : onOpenCadFiles,
                ),
                const SizedBox(height: 10),
                _ToolButton(
                  icon: Icons.public,
                  title: isImporting
                      ? l10n.importingGoogleEarth
                      : l10n.addGoogleEarthData,
                  subtitle: l10n.kmlWgs84,
                  onPressed: isImporting ? null : onOpenGoogleEarthFiles,
                ),
                const SizedBox(height: 10),
                _ToolButton(
                  icon: Icons.sync_alt,
                  title: l10n.coordinateConverter,
                  subtitle: l10n.utmWgs84,
                  onPressed: onOpenCoordinateConverter,
                ),
                const SizedBox(height: 10),
                _ToolButton(
                  icon: Icons.edit_location_alt,
                  title: l10n.editData,
                  subtitle: l10n.geometryAndAttributes,
                  onPressed: () {},
                ),
                const SizedBox(height: 10),
                _ToolButton(
                  icon: Icons.map,
                  title: isExporting
                      ? l10n.exportingKml
                      : l10n.exportGoogleEarth,
                  subtitle: l10n.kmlWgs84,
                  onPressed: isImporting || isExporting ? null : onExportKml,
                ),
                const SizedBox(height: 10),
                _ToolButton(
                  icon: Icons.architecture,
                  title: isExporting ? l10n.exportingDxf : l10n.exportAutoCad,
                  subtitle: l10n.dxfAscii,
                  onPressed: isImporting || isExporting ? null : onExportDxf,
                ),
                const SizedBox(height: 10),
                _ToolButton(
                  icon: Icons.picture_as_pdf,
                  title: l10n.exportPdf,
                  subtitle: l10n.drawingAndMap,
                  onPressed: () {},
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.dataLayers,
                        style: const TextStyle(
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
              l10n.projectContentSummary(
                project.layerCount,
                project.featureCount,
              ),
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
  final l10n = AppLocalizations.of(context);
  var zone = 48;
  var hemisphere = UtmHemisphere.north;

  return showDialog<CoordinateReferenceSystem>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(l10n.createUtmLayer),
            content: SizedBox(
              width: 480,
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: zone,
                      decoration: InputDecoration(
                        labelText: l10n.utmZone,
                        border: const OutlineInputBorder(),
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
                      decoration: InputDecoration(
                        labelText: l10n.hemisphere,
                        border: const OutlineInputBorder(),
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
                child: Text(l10n.cancel),
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
                child: Text(l10n.createLayer),
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
  final l10n = AppLocalizations.of(context);
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
            title: Text(l10n.assignSourceCrs),
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
                      decoration: InputDecoration(
                        labelText: l10n.coordinateSystem,
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: CoordinateReferenceSystemType.localCad,
                          child: Text(l10n.localCadUndefined),
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
                              decoration: InputDecoration(
                                labelText: l10n.utmZone,
                                border: const OutlineInputBorder(),
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
                              decoration: InputDecoration(
                                labelText: l10n.hemisphere,
                                border: const OutlineInputBorder(),
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
                    Text(
                      l10n.sourceCrsDeclarationNote,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
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
                child: Text(l10n.cancel),
              ),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop(preview);
                },
                icon: const Icon(Icons.check),
                label: Text(l10n.apply),
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
    final l10n = AppLocalizations.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Text(
        '${l10n.noDataLayers}\n${l10n.addDataHint}',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
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
    final l10n = AppLocalizations.of(context);
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
                  tooltip: layer.visible ? l10n.hideLayer : l10n.showLayer,
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
                        '${_layerTypeLabel(layer.sourceType, l10n)}'
                        ' • ${l10n.layerObjectCount(layer.featureCount)}',
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
                  tooltip: layer.locked ? l10n.unlockLayer : l10n.lockLayer,
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
                tooltip: l10n.moveLayerUp,
                onPressed: isFirst ? null : onMoveUp,
                icon: const Icon(Icons.keyboard_arrow_up),
              ),
              IconButton(
                tooltip: l10n.moveLayerDown,
                onPressed: isLast ? null : onMoveDown,
                icon: const Icon(Icons.keyboard_arrow_down),
              ),
              IconButton(
                tooltip: l10n.georeferenceLayer,
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
                  tooltip: l10n.createUtmLayer,
                  onPressed: layer.features.isEmpty ? null : onCreateUtm,
                  icon: const Icon(Icons.grid_on),
                )
              else
                IconButton(
                  tooltip: l10n.createWgs84Layer,
                  onPressed: layer.canTransformToWgs84 ? onCreateWgs84 : null,
                  icon: const Icon(Icons.public),
                ),
              IconButton(
                tooltip: layer.crs.isLocalCad
                    ? l10n.assignSourceCrs
                    : l10n.knownCrsUseCoordinateConversion,
                onPressed: layer.crs.isLocalCad ? onEditCrs : null,
                icon: const Icon(Icons.language),
              ),
              IconButton(
                tooltip: l10n.removeLayer,
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _layerTypeLabel(MapLayerSourceType type, AppLocalizations l10n) {
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
        return l10n.manualLayer;
    }
  }
}

class _Workspace extends StatelessWidget {
  final MapProject project;
  final bool isImporting;
  final ValueChanged<MapFeatureChange> onFeatureChanged;
  final ValueChanged<MapFeature> onFeatureCreated;

  const _Workspace({
    required this.project,
    required this.isImporting,
    required this.onFeatureChanged,
    required this.onFeatureCreated,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (isImporting) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(l10n.readingDrawingData),
          ],
        ),
      );
    }

    if (project.layers.isEmpty) {
      return Stack(
        children: [
          Positioned.fill(
            child: MapCanvas(
              project: project,
              onFeatureChanged: onFeatureChanged,
              onFeatureCreated: onFeatureCreated,
            ),
          ),
          const Positioned.fill(child: IgnorePointer(child: _EmptyWorkspace())),
        ],
      );
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
                  onFeatureCreated: onFeatureCreated,
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
    final l10n = AppLocalizations.of(context);
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
                  l10n.projectContentSummary(
                    project.layerCount,
                    project.featureCount,
                  ),
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
            label: l10n.visible,
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
    final l10n = AppLocalizations.of(context);
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
              l10n.layersVisible(visibleLayerCount, project.layerCount),
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ),
          Text(
            l10n.objectsVisible(project.visibleFeatures.length),
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
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.satellite_alt, size: 90, color: Colors.blue.shade700),
          const SizedBox(height: 24),
          const Text(
            'AutoCAD ↔ Google Earth',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.welcomeTagline,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 32),
          Text(l10n.welcomeAddData, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
