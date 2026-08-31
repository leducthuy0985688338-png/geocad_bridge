// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Lao (`lo`).
class AppLocalizationsLo extends AppLocalizations {
  AppLocalizationsLo([String locale = 'lo']) : super(locale);

  @override
  String get appTitle => 'AutoCAD ↔ Google Earth';

  @override
  String get language => 'ພາສາ';

  @override
  String get selectLanguage => 'ເລືອກພາສາ';

  @override
  String get vietnamese => 'Tiếng Việt';

  @override
  String get lao => 'ລາວ';

  @override
  String get english => 'English';

  @override
  String get projectNew => 'ໂຄງການໃໝ່';

  @override
  String get projectOpen => 'ເປີດໂຄງການ';

  @override
  String get projectSave => 'ບັນທຶກໂຄງການ';

  @override
  String get projectSaveAs => 'ບັນທຶກໂຄງການເປັນ...';

  @override
  String get tools => 'ເຄື່ອງມື';

  @override
  String get importingCad => 'ກຳລັງອ່ານແບບ...';

  @override
  String get addAutoCadDrawing => 'ເພີ່ມແບບ AutoCAD';

  @override
  String get selectMultipleDwgDxf => 'ເລືອກຫຼາຍໄຟລ໌ DWG / DXF';

  @override
  String get importingGoogleEarth => 'ກຳລັງອ່ານຂໍ້ມູນ...';

  @override
  String get addGoogleEarthData => 'ເພີ່ມຂໍ້ມູນ Google Earth';

  @override
  String get kmlWgs84 => 'KML (WGS84 / EPSG:4326)';

  @override
  String get coordinateConverter => 'ແປງພິກັດ';

  @override
  String get utmWgs84 => 'UTM ↔ WGS84';

  @override
  String get editData => 'ແກ້ໄຂຂໍ້ມູນ';

  @override
  String get geometryAndAttributes => 'ເລຂາຄະນິດ / ຄຸນລັກສະນະ';

  @override
  String get exportingKml => 'ກຳລັງສົ່ງອອກ KML...';

  @override
  String get exportGoogleEarth => 'ສົ່ງອອກໄປ Google Earth';

  @override
  String get exportingDxf => 'ກຳລັງສົ່ງອອກ DXF...';

  @override
  String get exportAutoCad => 'ສົ່ງອອກໄປ AutoCAD';

  @override
  String get dxfAscii => 'DXF ASCII';

  @override
  String get exportPdf => 'ສົ່ງອອກເປັນ PDF';

  @override
  String get drawingAndMap => 'ແບບ / ແຜນທີ່';

  @override
  String get dataLayers => 'ຊັ້ນຂໍ້ມູນ';

  @override
  String get noDataLayers => 'ຍັງບໍ່ມີຊັ້ນຂໍ້ມູນ.';

  @override
  String get visible => 'ກຳລັງສະແດງ';

  @override
  String layersVisible(int visibleCount, int totalCount) {
    return 'ກຳລັງສະແດງ $visibleCount/$totalCount ຊັ້ນ';
  }

  @override
  String objectsVisible(int count) {
    return 'ກຳລັງສະແດງ $count ວັດຖຸ';
  }

  @override
  String get addDataHint => 'ເພີ່ມແບບ AutoCAD ຫຼື ຂໍ້ມູນ Google Earth.';

  @override
  String projectContentSummary(int layerCount, int featureCount) {
    return '$layerCount ຊັ້ນ • $featureCount ວັດຖຸ';
  }
}
