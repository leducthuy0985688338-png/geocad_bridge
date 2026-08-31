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
}
