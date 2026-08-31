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

  @override
  String get lockLayer => 'ລັອກຊັ້ນ';

  @override
  String get knownCrsUseCoordinateConversion =>
      'ກຳນົດ CRS ແລ້ວ; ໃຫ້ໃຊ້ການແປງພິກັດ';

  @override
  String get manualLayer => 'ກຳນົດເອງ';

  @override
  String get georeferenceLayer => 'ກຳນົດຕຳແໜ່ງຊັ້ນດ້ວຍຈຸດຄວບຄຸມ';

  @override
  String layerObjectCount(int count) {
    return '$count ວັດຖຸ';
  }

  @override
  String get moveLayerDown => 'ຍ້າຍຊັ້ນລົງ';

  @override
  String get moveLayerUp => 'ຍ້າຍຊັ້ນຂຶ້ນ';

  @override
  String get createUtmLayer => 'ສ້າງຊັ້ນ UTM';

  @override
  String get redo => 'ເຮັດຄືນ (Ctrl+Y)';

  @override
  String get editSourceCrs => 'ແກ້ໄຂ CRS ຕົ້ນທາງ';

  @override
  String get hideLayer => 'ເຊື່ອງຊັ້ນ';

  @override
  String get readingDrawingData => 'ກຳລັງອ່ານຂໍ້ມູນແບບ...';

  @override
  String get showLayer => 'ສະແດງຊັ້ນ';

  @override
  String get undo => 'ຍ້ອນກັບ (Ctrl+Z)';

  @override
  String get removeLayer => 'ລຶບຊັ້ນອອກຈາກໂຄງການ';

  @override
  String get assignSourceCrs => 'ກຳນົດ CRS ຕົ້ນທາງ';

  @override
  String get welcomeTagline => 'ຊ້ອນຂໍ້ມູນ • ແກ້ໄຂ • ແປງ • ສົ່ງອອກ';

  @override
  String get welcomeAddData =>
      'ເພີ່ມແບບ AutoCAD ໜຶ່ງ ຫຼື ຫຼາຍແບບ ເພື່ອເລີ່ມສ້າງໂຄງການ.';

  @override
  String get createWgs84Layer => 'ສ້າງຊັ້ນ WGS84';

  @override
  String get unlockLayer => 'ປົດລັອກຊັ້ນ';

  @override
  String get projectOpenedWithWarnings => 'ເປີດໂຄງການແລ້ວໂດຍມີຄຳເຕືອນ';

  @override
  String get geometryRestoredMissingSources =>
      'ໄດ້ກູ້ຄືນ Geometry ແລ້ວ. ບາງໄຟລ໌ຕົ້ນທາງບໍ່ມີຢູ່ແລ້ວ:';

  @override
  String get close => 'ປິດ';

  @override
  String get googleEarthImportResult => 'ຜົນການນຳເຂົ້າ Google Earth';

  @override
  String googleEarthFilesImported(int count) {
    return 'ເພີ່ມສຳເລັດ: $count ໄຟລ໌ KML';
  }

  @override
  String googleEarthFilesSkipped(int count) {
    return 'ຂ້າມ: $count ໄຟລ໌ທີ່ມີຢູ່ແລ້ວໃນໂຄງການ';
  }

  @override
  String get unreadableFiles => 'ໄຟລ໌ທີ່ບໍ່ສາມາດອ່ານໄດ້:';

  @override
  String get dxfImportResult => 'ຜົນການນຳເຂົ້າ DXF';

  @override
  String dxfLayersImported(int count) {
    return 'ເພີ່ມແລ້ວ: $count ຊັ້ນ DXF';
  }

  @override
  String dxfEntitiesImported(int count) {
    return 'ນຳເຂົ້າແລ້ວ: $count entity';
  }

  @override
  String dxfMalformedSkipped(int count) {
    return 'ຂ້າມ entity ທີ່ບໍ່ສົມບູນ: $count';
  }

  @override
  String dxfUnsupportedEntities(int count) {
    return 'Entity ທີ່ຍັງບໍ່ຮອງຮັບ: $count';
  }

  @override
  String get dxfFidelityWarnings => 'ຄຳເຕືອນ fidelity:';

  @override
  String get cadImportResult => 'ຜົນການນຳເຂົ້າແບບ';

  @override
  String cadFilesImported(int count) {
    return 'ເພີ່ມສຳເລັດ: $count ໄຟລ໌';
  }

  @override
  String get kmlExportUnavailable => 'ຍັງບໍ່ສາມາດສົ່ງອອກ KML';

  @override
  String get kmlRequiresWgs84 =>
      'KML ຕ້ອງໃຊ້ WGS84 (EPSG:4326). ຊັ້ນທີ່ກຳລັງສະແດງຕໍ່ໄປນີ້ຍັງບໍ່ແມ່ນ WGS84:';

  @override
  String get kmlPrepareWgs84Hint =>
      'ກຳນົດ/ອ້າງອີງ CRS, ສ້າງຊັ້ນ WGS84 ແລ້ວເຊື່ອງຊັ້ນຕົ້ນທາງກ່ອນສົ່ງອອກ.';

  @override
  String get understood => 'ເຂົ້າໃຈແລ້ວ';

  @override
  String get kmlExportSucceeded => 'ສົ່ງອອກ KML ສຳເລັດ';

  @override
  String get openWithGoogleEarth => 'ເປີດດ້ວຍ Google Earth';

  @override
  String get utmZone => 'UTM Zone';

  @override
  String get hemisphere => 'ຊີກໂລກ';

  @override
  String get north => 'ເໜືອ';

  @override
  String get south => 'ໃຕ້';

  @override
  String get cancel => 'ຍົກເລີກ';

  @override
  String get createLayer => 'ສ້າງຊັ້ນ';

  @override
  String get coordinateSystem => 'ລະບົບພິກັດ';

  @override
  String get localCadUndefined => 'CAD ທ້ອງຖິ່ນ / ຍັງບໍ່ກຳນົດ';

  @override
  String get sourceCrsDeclarationNote =>
      'ໝາຍເຫດ: ການດຳເນີນການນີ້ພຽງແຕ່ກຳນົດ CRS ຂອງຊັ້ນ ແລະ ບໍ່ໄດ້ປ່ຽນຄ່າພິກັດ X/Y ທີ່ມີຢູ່.';

  @override
  String get apply => 'ນຳໃຊ້';

  @override
  String get sourceCoordinateSystem => 'ລະບົບພິກັດຕົ້ນທາງ';

  @override
  String get targetCoordinateSystem => 'ລະບົບພິກັດປາຍທາງ';

  @override
  String get autoUtmHint =>
      'ເມື່ອແປງ WGS84 → UTM, Zone ແລະ ຊີກໂລກຈະຖືກກຳນົດອັດຕະໂນມັດຈາກ Longitude/Latitude.';

  @override
  String get swapDirection => 'ສະຫຼັບທິດທາງ';

  @override
  String get convert => 'ແປງ';

  @override
  String get coordinateInputRequired => 'ກະລຸນາປ້ອນຄ່າພິກັດທີ່ຖືກຕ້ອງສອງຄ່າ.';

  @override
  String get wgs84Result => 'ຜົນ WGS84';

  @override
  String get utmResult => 'ຜົນ UTM';

  @override
  String get longitudeLatitudeRange =>
      'Longitude ຕ້ອງຢູ່ໃນ [-180, 180] ແລະ Latitude ຢູ່ໃນ [-90, 90].';

  @override
  String get invalidCoordinates => 'ຄ່າພິກັດທີ່ປ້ອນບໍ່ຖືກຕ້ອງ.';

  @override
  String get coordinateConversionFailed =>
      'ບໍ່ສາມາດແປງພິກັດໄດ້. ກະລຸນາກວດສອບຂໍ້ມູນປ້ອນ.';

  @override
  String get cadLocalConversionNote =>
      'ໝາຍເຫດ: ພິກັດ CAD ທ້ອງຖິ່ນຍັງບໍ່ສາມາດແປງໄປ WGS84 ໂດຍກົງ ຈົນກວ່າຈະຮູ້ CRS ຫຼື ການອ້າງອີງຕຳແໜ່ງຂອງແບບ.';

  @override
  String get georeferenceCadDrawing => 'ອ້າງອີງຕຳແໜ່ງແບບ CAD';

  @override
  String get targetCrs => 'CRS ປາຍທາງ';

  @override
  String get addControlPoint => 'ເພີ່ມຈຸດຄວບຄຸມ';

  @override
  String get calculateGeoreferencePreview => 'ຄຳນວນຕົວຢ່າງການອ້າງອີງຕຳແໜ່ງ';

  @override
  String get georeferenceInstructions =>
      'ປ້ອນຢ່າງໜ້ອຍສອງຈຸດ CAD ແລະ ພິກັດ UTM ຈິງທີ່ກົງກັນ. ຖ້າມີຫຼາຍກວ່າສອງຈຸດ ແອັບຈະໃຊ້ການປັບແບບ least-squares.';

  @override
  String get createGeoreferencedLayer => 'ສ້າງຊັ້ນທີ່ອ້າງອີງຕຳແໜ່ງແລ້ວ';

  @override
  String get invalidControlPointData => 'ຂໍ້ມູນຈຸດຄວບຄຸມບໍ່ຖືກຕ້ອງ.';

  @override
  String get georeferenceCalculationFailed =>
      'ບໍ່ສາມາດຄຳນວນການອ້າງອີງຕຳແໜ່ງໄດ້. ກະລຸນາກວດສອບຈຸດຄວບຄຸມ.';

  @override
  String invalidNumber(String label) {
    return '$label ບໍ່ແມ່ນຕົວເລກທີ່ຖືກຕ້ອງ.';
  }

  @override
  String controlPoint(int number) {
    return 'ຈຸດຄວບຄຸມ $number';
  }

  @override
  String get suspectedReview => 'ສົງໄສ — ຕ້ອງກວດສອບ';

  @override
  String get largestError => 'ຄ່າຜິດພາດສູງສຸດ';

  @override
  String removePoint(int number) {
    return 'ລຶບຈຸດ $number';
  }

  @override
  String residualSummary(String deltaX, String deltaY, String error) {
    return 'ΔX: $deltaX m • ΔY: $deltaY m • ຄ່າຜິດພາດ: $error m';
  }

  @override
  String get twoPointTransform => 'ການແປງ 2 ຈຸດ';

  @override
  String leastSquaresAdjustment(int count) {
    return 'ການປັບ least-squares ດ້ວຍ $count ຈຸດ';
  }

  @override
  String maxResidualSummary(String error, int number) {
    return 'ຄ່າຜິດພາດສູງສຸດ: $error m (ຈຸດ $number)';
  }

  @override
  String get outlierNotApplicable => 'ສອງຈຸດ: ບໍ່ສາມາດໃຊ້ການກວດຫາ outlier.';

  @override
  String get outlierInsufficientSample =>
      'ຕົວຢ່າງບໍ່ພຽງພໍສຳລັບປະເມີນ outlier; ຈຸດທີ່ໃຫຍ່ສຸດໃຊ້ເປັນຂໍ້ອ້າງອີງເທົ່ານັ້ນ.';

  @override
  String get outlierNoRelativeAnomaly =>
      'ບໍ່ພົບຄວາມຜິດປົກກະຕິສຳພັນໃນ residual.';

  @override
  String get outlierReviewSuggested =>
      'ພົບຈຸດທີ່ໜ້າສົງໄສ — ກະລຸນາກວດສອບ ຫຼື ແກ້ໄຂດ້ວຍຕົນເອງ.';

  @override
  String get outlierMultipleLargeResiduals =>
      'ມີ residual ຫຼາຍຄ່າທີ່ຕ້ອງກວດສອບໂດຍລວມ.';

  @override
  String get unsavedChangesTitle => 'Project ມີການປ່ຽນແປງທີ່ຍັງບໍ່ໄດ້ບັນທຶກ';

  @override
  String get unsavedChangesMessage =>
      'ຖ້າສືບຕໍ່ ການປ່ຽນແປງທີ່ຍັງບໍ່ໄດ້ບັນທຶກອາດສູນເສຍ. ຕ້ອງການບັນທຶກ project ກ່ອນບໍ?';

  @override
  String get discardChanges => 'ບໍ່ບັນທຶກ';

  @override
  String get save => 'ບັນທຶກ';

  @override
  String get projectCreated => 'ສ້າງ project ໃໝ່ແລ້ວ.';

  @override
  String projectOpenFailed(Object error) {
    return 'ບໍ່ສາມາດເປີດ project: $error';
  }

  @override
  String get openGeoCadProject => 'ເປີດ GeoCAD Project';

  @override
  String get projectPathUnavailable => 'ບໍ່ສາມາດຮັບ path ຂອງ project.';

  @override
  String projectOpened(Object name) {
    return 'ເປີດ project \"$name\" ແລ້ວ.';
  }

  @override
  String projectSaveFailed(Object error) {
    return 'ບໍ່ສາມາດບັນທຶກ project: $error';
  }

  @override
  String get geoCadProject => 'GeoCAD Project';

  @override
  String projectSaved(Object path) {
    return 'ບັນທຶກ project ແລ້ວ: $path';
  }

  @override
  String dxfNoValidEntities(Object fileName) {
    return '$fileName: ບໍ່ພົບ entity DXF ທີ່ຖືກຕ້ອງ.';
  }

  @override
  String get selectedFilesAlreadyInProject =>
      'ໄຟລ໌ທີ່ເລືອກທັງໝົດມີຢູ່ໃນ project ແລ້ວ.';

  @override
  String cadDrawingsAdded(Object count) {
    return 'ເພີ່ມ $count ແບບເຂົ້າ project ແລ້ວ.';
  }

  @override
  String get selectGoogleEarthKml => 'ເລືອກຂໍ້ມູນ Google Earth (KML)';

  @override
  String filePathUnavailable(Object fileName) {
    return '$fileName: ບໍ່ສາມາດຮັບ path ຂອງໄຟລ໌.';
  }

  @override
  String kmlNoValidGeometry(Object fileName) {
    return '$fileName: ບໍ່ພົບ Point, LineString ຫຼື Polygon ທີ່ຖືກຕ້ອງ.';
  }

  @override
  String get selectedKmlAlreadyInProject =>
      'ໄຟລ໌ KML ທີ່ເລືອກທັງໝົດມີຢູ່ໃນ project ແລ້ວ.';

  @override
  String skippedExistingFiles(Object count) {
    return ' • ຂ້າມ $count ໄຟລ໌ທີ່ມີແລ້ວ.';
  }

  @override
  String kmlFilesAdded(Object count, Object skippedText) {
    return 'ເພີ່ມ $count ໄຟລ໌ KML ເຂົ້າ project ແລ້ວ.$skippedText';
  }

  @override
  String get featureOwnerLayerNotFound => 'ບໍ່ພົບ layer ທີ່ມີວັດຖຸນີ້.';

  @override
  String layerLocked(Object name) {
    return 'Layer \"$name\" ຖືກລັອກ.';
  }

  @override
  String get georeferenceLocalCadOnly =>
      'ສາມາດ georeference ໄດ້ສະເພາະ local CAD layer ທີ່ມີ geometry.';

  @override
  String georeferenceSucceeded(
    Object coordinateCount,
    Object crs,
    Object name,
    Object rmse,
  ) {
    return 'Georeference \"$name\" ສຳເລັດ: $coordinateCount ພິກັດ • $crs • RMSE $rmse m.';
  }

  @override
  String georeferenceLayerFailed(Object error) {
    return 'ບໍ່ສາມາດ georeference layer: $error';
  }

  @override
  String layerNeedsValidCrs(Object name) {
    return 'Layer \"$name\" ຍັງບໍ່ມີ CRS ທີ່ຖືກຕ້ອງ. ກຳນົດ CRS ກ່ອນ.';
  }

  @override
  String layerAlreadyWgs84(Object name) {
    return 'Layer \"$name\" ເປັນ WGS84 (EPSG:4326) ແລ້ວ.';
  }

  @override
  String wgs84LayerCreated(Object coordinateCount, Object featureCount) {
    return 'ສ້າງ layer WGS84 ແລ້ວ: $featureCount ວັດຖຸ, $coordinateCount ພິກັດ.';
  }

  @override
  String createWgs84Failed(Object error) {
    return 'ບໍ່ສາມາດສ້າງ layer WGS84: $error';
  }

  @override
  String get createUtmFromWgs84Only =>
      'ສາມາດສ້າງ UTM ໄດ້ສະເພາະຈາກ WGS84 layer ທີ່ມີ geometry.';

  @override
  String get invalidTargetUtmCrs => 'CRS UTM ປາຍທາງບໍ່ຖືກຕ້ອງ.';

  @override
  String utmLayerCreated(
    Object coordinateCount,
    Object crs,
    Object featureCount,
  ) {
    return 'ສ້າງ layer $crs ແລ້ວ: $featureCount ວັດຖຸ, $coordinateCount ພິກັດ.';
  }

  @override
  String createUtmFailed(Object error) {
    return 'ບໍ່ສາມາດສ້າງ layer UTM: $error';
  }

  @override
  String get noVisibleDataForKml => 'ບໍ່ມີຂໍ້ມູນທີ່ກຳລັງສະແດງເພື່ອ export KML.';

  @override
  String get exportGoogleEarthKml => 'Export ຂໍ້ມູນ Google Earth (KML)';

  @override
  String exportKmlFailed(Object error) {
    return 'ບໍ່ສາມາດ export KML: $error';
  }

  @override
  String exportDxfFailed(Object error) {
    return 'ບໍ່ສາມາດ export DXF: $error';
  }

  @override
  String get exportAutoCadDxfAscii => 'Export ແບບ AutoCAD (DXF ASCII)';

  @override
  String exportWarnings(Object count) {
    return ' • $count ຄຳເຕືອນ';
  }

  @override
  String dxfExportSucceeded(
    Object crs,
    Object entityCount,
    Object layerCount,
    Object path,
    Object warnings,
  ) {
    return 'Export $entityCount ວັດຖຸໃນ $layerCount CAD layer • $crs$warnings • $path';
  }

  @override
  String writeDxfFailed(Object error) {
    return 'ບໍ່ສາມາດຂຽນໄຟລ໌ DXF: $error';
  }

  @override
  String get autoOpenKmlWindowsOnly =>
      'ການເປີດ KML ອັດຕະໂນມັດຮອງຮັບສະເພາະ Windows desktop.';

  @override
  String get kmlSentToDefaultApp =>
      'ສົ່ງໄຟລ໌ KML ໄປຫາແອັບຄ່າເລີ່ມຕົ້ນແລ້ວ. ຖ້າບໍ່ໄດ້ຕິດຕັ້ງ Google Earth, Windows ຈະໃຫ້ເລືອກແອັບ.';

  @override
  String windowsOpenKmlFailed(Object error) {
    return 'Windows ບໍ່ສາມາດເປີດໄຟລ໌ KML. ກວດ Google Earth ຫຼືແອັບຄ່າເລີ່ມຕົ້ນ: $error';
  }

  @override
  String openKmlFailed(Object error) {
    return 'ບໍ່ສາມາດເປີດໄຟລ໌ KML: $error';
  }

  @override
  String crsAlreadyDefined(Object name) {
    return 'CRS ຂອງ \"$name\" ຖືກກຳນົດແລ້ວ. ໃຫ້ໃຊ້ການປ່ຽນພິກັດແທນການກຳນົດ metadata ໃໝ່.';
  }

  @override
  String crsAssigned(Object crs, Object name) {
    return 'ກຳນົດ CRS ໃຫ້ \"$name\" ແລ້ວ: $crs';
  }
}
