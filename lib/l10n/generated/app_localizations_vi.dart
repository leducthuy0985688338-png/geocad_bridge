// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'AutoCAD ↔ Google Earth';

  @override
  String get language => 'Ngôn ngữ';

  @override
  String get selectLanguage => 'Chọn ngôn ngữ';

  @override
  String get vietnamese => 'Tiếng Việt';

  @override
  String get lao => 'ລາວ';

  @override
  String get english => 'English';

  @override
  String get projectNew => 'Project mới';

  @override
  String get projectOpen => 'Mở project';

  @override
  String get projectSave => 'Lưu project';

  @override
  String get projectSaveAs => 'Lưu project thành...';

  @override
  String get tools => 'CÔNG CỤ';

  @override
  String get importingCad => 'Đang đọc bản vẽ...';

  @override
  String get addAutoCadDrawing => 'Thêm bản vẽ AutoCAD';

  @override
  String get selectMultipleDwgDxf => 'Chọn nhiều DWG / DXF';

  @override
  String get importingGoogleEarth => 'Đang đọc dữ liệu...';

  @override
  String get addGoogleEarthData => 'Thêm dữ liệu Google Earth';

  @override
  String get kmlWgs84 => 'KML (WGS84 / EPSG:4326)';

  @override
  String get coordinateConverter => 'Chuyển đổi tọa độ';

  @override
  String get utmWgs84 => 'UTM ↔ WGS84';

  @override
  String get editData => 'Chỉnh sửa dữ liệu';

  @override
  String get geometryAndAttributes => 'Hình học / thuộc tính';

  @override
  String get exportingKml => 'Đang xuất KML...';

  @override
  String get exportGoogleEarth => 'Xuất sang Google Earth';

  @override
  String get exportingDxf => 'Đang xuất DXF...';

  @override
  String get exportAutoCad => 'Xuất sang AutoCAD';

  @override
  String get dxfAscii => 'DXF ASCII';

  @override
  String get exportPdf => 'Xuất sang PDF';

  @override
  String get drawingAndMap => 'Bản vẽ / Bản đồ';

  @override
  String get dataLayers => 'CÁC LỚP DỮ LIỆU';

  @override
  String get noDataLayers => 'Chưa có lớp dữ liệu.';

  @override
  String get visible => 'Đang hiển thị';

  @override
  String layersVisible(int visibleCount, int totalCount) {
    return '$visibleCount/$totalCount layer đang hiển thị';
  }

  @override
  String objectsVisible(int count) {
    return '$count đối tượng hiển thị';
  }

  @override
  String get addDataHint =>
      'Hãy thêm bản vẽ AutoCAD hoặc dữ liệu Google Earth.';

  @override
  String projectContentSummary(int layerCount, int featureCount) {
    return '$layerCount lớp • $featureCount đối tượng';
  }
}
