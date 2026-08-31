// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'AutoCAD ↔ Google Earth';

  @override
  String get language => 'Language';

  @override
  String get selectLanguage => 'Select language';

  @override
  String get vietnamese => 'Tiếng Việt';

  @override
  String get lao => 'ລາວ';

  @override
  String get english => 'English';

  @override
  String get projectNew => 'New project';

  @override
  String get projectOpen => 'Open project';

  @override
  String get projectSave => 'Save project';

  @override
  String get projectSaveAs => 'Save project as...';

  @override
  String get tools => 'TOOLS';

  @override
  String get importingCad => 'Reading drawing...';

  @override
  String get addAutoCadDrawing => 'Add AutoCAD drawing';

  @override
  String get selectMultipleDwgDxf => 'Select multiple DWG / DXF files';

  @override
  String get importingGoogleEarth => 'Reading data...';

  @override
  String get addGoogleEarthData => 'Add Google Earth data';

  @override
  String get kmlWgs84 => 'KML (WGS84 / EPSG:4326)';

  @override
  String get coordinateConverter => 'Coordinate converter';

  @override
  String get utmWgs84 => 'UTM ↔ WGS84';

  @override
  String get editData => 'Edit data';

  @override
  String get geometryAndAttributes => 'Geometry / attributes';

  @override
  String get exportingKml => 'Exporting KML...';

  @override
  String get exportGoogleEarth => 'Export to Google Earth';

  @override
  String get exportingDxf => 'Exporting DXF...';

  @override
  String get exportAutoCad => 'Export to AutoCAD';

  @override
  String get dxfAscii => 'DXF ASCII';

  @override
  String get exportPdf => 'Export to PDF';

  @override
  String get drawingAndMap => 'Drawing / Map';

  @override
  String get dataLayers => 'DATA LAYERS';

  @override
  String get noDataLayers => 'No data layers.';

  @override
  String get visible => 'Visible';

  @override
  String layersVisible(int visibleCount, int totalCount) {
    return '$visibleCount/$totalCount layers visible';
  }

  @override
  String objectsVisible(int count) {
    return '$count objects visible';
  }

  @override
  String get addDataHint => 'Add an AutoCAD drawing or Google Earth data.';

  @override
  String projectContentSummary(int layerCount, int featureCount) {
    return '$layerCount layers • $featureCount objects';
  }

  @override
  String get lockLayer => 'Lock layer';

  @override
  String get knownCrsUseCoordinateConversion =>
      'CRS is defined; use coordinate conversion';

  @override
  String get manualLayer => 'MANUAL';

  @override
  String get georeferenceLayer => 'Georeference layer using control points';

  @override
  String layerObjectCount(int count) {
    return '$count objects';
  }

  @override
  String get moveLayerDown => 'Move layer down';

  @override
  String get moveLayerUp => 'Move layer up';

  @override
  String get createUtmLayer => 'Create UTM layer';

  @override
  String get redo => 'Redo (Ctrl+Y)';

  @override
  String get editSourceCrs => 'Edit source CRS';

  @override
  String get hideLayer => 'Hide layer';

  @override
  String get readingDrawingData => 'Reading drawing data...';

  @override
  String get showLayer => 'Show layer';

  @override
  String get undo => 'Undo (Ctrl+Z)';

  @override
  String get removeLayer => 'Remove layer from project';

  @override
  String get assignSourceCrs => 'Assign source CRS';

  @override
  String get welcomeTagline => 'Overlay • Edit • Convert • Export';

  @override
  String get welcomeAddData =>
      'Add one or more AutoCAD drawings to start creating a project.';

  @override
  String get createWgs84Layer => 'Create WGS84 layer';

  @override
  String get unlockLayer => 'Unlock layer';
}
