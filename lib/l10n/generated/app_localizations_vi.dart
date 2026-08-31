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

  @override
  String get lockLayer => 'Khóa layer';

  @override
  String get knownCrsUseCoordinateConversion =>
      'CRS đã xác định; hãy dùng chuyển đổi tọa độ';

  @override
  String get manualLayer => 'THỦ CÔNG';

  @override
  String get georeferenceLayer => 'Định vị layer bằng các điểm khống chế';

  @override
  String layerObjectCount(int count) {
    return '$count đối tượng';
  }

  @override
  String get moveLayerDown => 'Đưa layer xuống';

  @override
  String get moveLayerUp => 'Đưa layer lên';

  @override
  String get createUtmLayer => 'Tạo layer UTM';

  @override
  String get redo => 'Redo (Ctrl+Y)';

  @override
  String get editSourceCrs => 'Chỉnh sửa hệ tọa độ nguồn';

  @override
  String get hideLayer => 'Ẩn layer';

  @override
  String get readingDrawingData => 'Đang đọc dữ liệu bản vẽ...';

  @override
  String get showLayer => 'Hiện layer';

  @override
  String get undo => 'Undo (Ctrl+Z)';

  @override
  String get removeLayer => 'Xóa layer khỏi dự án';

  @override
  String get assignSourceCrs => 'Gán hệ tọa độ nguồn';

  @override
  String get welcomeTagline => 'Lồng ghép • Chỉnh sửa • Chuyển đổi • Xuất bản';

  @override
  String get welcomeAddData =>
      'Hãy thêm một hoặc nhiều bản vẽ AutoCAD để bắt đầu tạo project.';

  @override
  String get createWgs84Layer => 'Tạo layer WGS84';

  @override
  String get unlockLayer => 'Mở khóa layer';

  @override
  String get projectOpenedWithWarnings => 'Project đã mở với cảnh báo';

  @override
  String get geometryRestoredMissingSources =>
      'Geometry đã được khôi phục. Một số file nguồn không còn tồn tại:';

  @override
  String get close => 'Đóng';

  @override
  String get googleEarthImportResult => 'Kết quả nhập Google Earth';

  @override
  String googleEarthFilesImported(int count) {
    return 'Đã thêm thành công: $count file KML';
  }

  @override
  String googleEarthFilesSkipped(int count) {
    return 'Đã bỏ qua: $count file đang có trong dự án';
  }

  @override
  String get unreadableFiles => 'Các file không đọc được:';

  @override
  String get dxfImportResult => 'Kết quả nhập DXF';

  @override
  String dxfLayersImported(int count) {
    return 'Đã thêm: $count layer DXF';
  }

  @override
  String dxfEntitiesImported(int count) {
    return 'Đã nhập: $count entity';
  }

  @override
  String dxfMalformedSkipped(int count) {
    return 'Malformed đã bỏ qua: $count';
  }

  @override
  String dxfUnsupportedEntities(int count) {
    return 'Entity chưa hỗ trợ: $count';
  }

  @override
  String get dxfFidelityWarnings => 'Cảnh báo fidelity:';

  @override
  String get cadImportResult => 'Kết quả nhập bản vẽ';

  @override
  String cadFilesImported(int count) {
    return 'Đã thêm thành công: $count file';
  }

  @override
  String get kmlExportUnavailable => 'Chưa thể xuất KML';

  @override
  String get kmlRequiresWgs84 =>
      'KML yêu cầu WGS84 (EPSG:4326). Các layer đang hiển thị sau chưa phải WGS84:';

  @override
  String get kmlPrepareWgs84Hint =>
      'Hãy gán/định vị CRS, tạo layer WGS84, sau đó ẩn layer nguồn trước khi xuất.';

  @override
  String get understood => 'Đã hiểu';

  @override
  String get kmlExportSucceeded => 'Xuất KML thành công';

  @override
  String get openWithGoogleEarth => 'Mở bằng Google Earth';

  @override
  String get utmZone => 'UTM Zone';

  @override
  String get hemisphere => 'Bán cầu';

  @override
  String get north => 'Bắc (North)';

  @override
  String get south => 'Nam (South)';

  @override
  String get cancel => 'Hủy';

  @override
  String get createLayer => 'Tạo layer';

  @override
  String get coordinateSystem => 'Hệ tọa độ';

  @override
  String get localCadUndefined => 'CAD cục bộ / chưa xác định';

  @override
  String get sourceCrsDeclarationNote =>
      'Lưu ý: thao tác này chỉ khai báo CRS của layer, không tự thay đổi các giá trị tọa độ X/Y đang có.';

  @override
  String get apply => 'Áp dụng';

  @override
  String get sourceCoordinateSystem => 'Hệ tọa độ nguồn';

  @override
  String get targetCoordinateSystem => 'Hệ tọa độ đích';

  @override
  String get autoUtmHint =>
      'Khi chuyển WGS84 → UTM, Zone và bán cầu được tự động xác định từ Longitude/Latitude.';

  @override
  String get swapDirection => 'Đổi chiều';

  @override
  String get convert => 'Chuyển đổi';

  @override
  String get coordinateInputRequired =>
      'Vui lòng nhập đủ hai giá trị tọa độ hợp lệ.';

  @override
  String get wgs84Result => 'Kết quả WGS84';

  @override
  String get utmResult => 'Kết quả UTM';

  @override
  String get longitudeLatitudeRange =>
      'Longitude phải trong [-180, 180] và Latitude trong [-90, 90].';

  @override
  String get invalidCoordinates => 'Tọa độ nhập vào không hợp lệ.';

  @override
  String get coordinateConversionFailed =>
      'Không thể chuyển đổi tọa độ. Hãy kiểm tra lại dữ liệu đầu vào.';

  @override
  String get cadLocalConversionNote =>
      'Lưu ý: CAD cục bộ chưa thể chuyển trực tiếp sang WGS84 nếu chưa biết CRS hoặc phép định vị của bản vẽ.';

  @override
  String get georeferenceCadDrawing => 'Định vị bản vẽ CAD';

  @override
  String get targetCrs => 'CRS đích';

  @override
  String get addControlPoint => 'Thêm điểm khống chế';

  @override
  String get calculateGeoreferencePreview => 'Tính thử phép định vị';

  @override
  String get georeferenceInstructions =>
      'Nhập ít nhất hai điểm CAD và tọa độ UTM thực tương ứng. Với nhiều hơn hai điểm, ứng dụng dùng bình sai least-squares.';

  @override
  String get createGeoreferencedLayer => 'Tạo layer đã định vị';

  @override
  String get invalidControlPointData => 'Dữ liệu điểm khống chế không hợp lệ.';

  @override
  String get georeferenceCalculationFailed =>
      'Không thể tính phép định vị. Hãy kiểm tra lại các điểm khống chế.';

  @override
  String invalidNumber(String label) {
    return '$label không phải là số hợp lệ.';
  }

  @override
  String controlPoint(int number) {
    return 'Điểm khống chế $number';
  }

  @override
  String get suspectedReview => 'Nghi ngờ — cần kiểm tra';

  @override
  String get largestError => 'Sai số lớn nhất';

  @override
  String removePoint(int number) {
    return 'Xóa điểm $number';
  }

  @override
  String residualSummary(String deltaX, String deltaY, String error) {
    return 'ΔX: $deltaX m • ΔY: $deltaY m • Sai số: $error m';
  }

  @override
  String get twoPointTransform => 'Phép biến đổi 2 điểm';

  @override
  String leastSquaresAdjustment(int count) {
    return 'Bình sai $count điểm';
  }

  @override
  String maxResidualSummary(String error, int number) {
    return 'Sai số lớn nhất: $error m (điểm $number)';
  }

  @override
  String get outlierNotApplicable =>
      'Hai điểm: không áp dụng phát hiện outlier.';

  @override
  String get outlierInsufficientSample =>
      'Chưa đủ mẫu để đánh giá outlier; điểm lớn nhất chỉ mang tính tham khảo.';

  @override
  String get outlierNoRelativeAnomaly =>
      'Không phát hiện bất thường tương đối trong các residual.';

  @override
  String get outlierReviewSuggested =>
      'Có điểm nghi ngờ — hãy kiểm tra hoặc chỉnh sửa thủ công.';

  @override
  String get outlierMultipleLargeResiduals =>
      'Nhiều residual cần được kiểm tra tổng thể.';
}
