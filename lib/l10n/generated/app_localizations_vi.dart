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

  @override
  String get unsavedChangesTitle => 'Project có thay đổi chưa lưu';

  @override
  String get unsavedChangesMessage =>
      'Nếu tiếp tục, các thay đổi chưa lưu có thể bị mất. Bạn muốn lưu project trước không?';

  @override
  String get discardChanges => 'Không lưu';

  @override
  String get save => 'Lưu';

  @override
  String get projectCreated => 'Đã tạo project mới.';

  @override
  String projectOpenFailed(Object error) {
    return 'Không thể mở project: $error';
  }

  @override
  String get openGeoCadProject => 'Mở GeoCAD Project';

  @override
  String get projectPathUnavailable => 'Không lấy được đường dẫn project.';

  @override
  String projectOpened(Object name) {
    return 'Đã mở project \"$name\".';
  }

  @override
  String projectSaveFailed(Object error) {
    return 'Không thể lưu project: $error';
  }

  @override
  String get geoCadProject => 'GeoCAD Project';

  @override
  String projectSaved(Object path) {
    return 'Đã lưu project: $path';
  }

  @override
  String dxfNoValidEntities(Object fileName) {
    return '$fileName: Không có entity DXF hợp lệ.';
  }

  @override
  String get selectedFilesAlreadyInProject =>
      'Các file đã chọn đều đang có trong dự án.';

  @override
  String cadDrawingsAdded(Object count) {
    return 'Đã thêm $count bản vẽ vào dự án.';
  }

  @override
  String get selectGoogleEarthKml => 'Chọn dữ liệu Google Earth (KML)';

  @override
  String filePathUnavailable(Object fileName) {
    return '$fileName: Không lấy được đường dẫn file.';
  }

  @override
  String kmlNoValidGeometry(Object fileName) {
    return '$fileName: Không tìm thấy Point, LineString hoặc Polygon hợp lệ.';
  }

  @override
  String get selectedKmlAlreadyInProject =>
      'Các file KML đã chọn đều đang có trong dự án.';

  @override
  String skippedExistingFiles(Object count) {
    return ' • Bỏ qua $count file đã có.';
  }

  @override
  String kmlFilesAdded(Object count, Object skippedText) {
    return 'Đã thêm $count file KML vào dự án.$skippedText';
  }

  @override
  String get featureOwnerLayerNotFound =>
      'Không tìm thấy layer chứa đối tượng.';

  @override
  String layerLocked(Object name) {
    return 'Layer \"$name\" đang bị khóa.';
  }

  @override
  String get georeferenceLocalCadOnly =>
      'Chỉ có thể định vị layer CAD cục bộ có dữ liệu hình học.';

  @override
  String georeferenceSucceeded(
    Object coordinateCount,
    Object crs,
    Object name,
    Object rmse,
  ) {
    return 'Đã định vị \"$name\": $coordinateCount tọa độ • $crs • RMSE $rmse m.';
  }

  @override
  String georeferenceLayerFailed(Object error) {
    return 'Không thể định vị layer: $error';
  }

  @override
  String layerNeedsValidCrs(Object name) {
    return 'Layer \"$name\" chưa có CRS hợp lệ. Hãy thiết lập CRS trước.';
  }

  @override
  String layerAlreadyWgs84(Object name) {
    return 'Layer \"$name\" đã là WGS84 (EPSG:4326).';
  }

  @override
  String wgs84LayerCreated(Object coordinateCount, Object featureCount) {
    return 'Đã tạo layer WGS84: $featureCount đối tượng, $coordinateCount tọa độ.';
  }

  @override
  String createWgs84Failed(Object error) {
    return 'Không thể tạo layer WGS84: $error';
  }

  @override
  String get createUtmFromWgs84Only =>
      'Chỉ có thể tạo UTM từ layer WGS84 có dữ liệu hình học.';

  @override
  String get invalidTargetUtmCrs => 'CRS UTM đích không hợp lệ.';

  @override
  String utmLayerCreated(
    Object coordinateCount,
    Object crs,
    Object featureCount,
  ) {
    return 'Đã tạo layer $crs: $featureCount đối tượng, $coordinateCount tọa độ.';
  }

  @override
  String createUtmFailed(Object error) {
    return 'Không thể tạo layer UTM: $error';
  }

  @override
  String get noVisibleDataForKml =>
      'Không có dữ liệu đang hiển thị để xuất KML.';

  @override
  String get exportGoogleEarthKml => 'Xuất dữ liệu Google Earth (KML)';

  @override
  String exportKmlFailed(Object error) {
    return 'Không thể xuất KML: $error';
  }

  @override
  String exportDxfFailed(Object error) {
    return 'Không thể xuất DXF: $error';
  }

  @override
  String get exportAutoCadDxfAscii => 'Xuất bản vẽ AutoCAD (DXF ASCII)';

  @override
  String exportWarnings(Object count) {
    return ' • $count cảnh báo';
  }

  @override
  String dxfExportSucceeded(
    Object crs,
    Object entityCount,
    Object layerCount,
    Object path,
    Object warnings,
  ) {
    return 'Đã xuất $entityCount đối tượng trên $layerCount CAD layer • $crs$warnings • $path';
  }

  @override
  String writeDxfFailed(Object error) {
    return 'Không thể ghi file DXF: $error';
  }

  @override
  String get autoOpenKmlWindowsOnly =>
      'Chỉ hỗ trợ mở KML tự động trên Windows desktop.';

  @override
  String get kmlSentToDefaultApp =>
      'Đã gửi file KML tới ứng dụng mặc định. Nếu Google Earth chưa được cài đặt, Windows sẽ yêu cầu chọn ứng dụng.';

  @override
  String windowsOpenKmlFailed(Object error) {
    return 'Windows không thể mở file KML. Hãy kiểm tra Google Earth hoặc ứng dụng mặc định: $error';
  }

  @override
  String openKmlFailed(Object error) {
    return 'Không thể mở file KML: $error';
  }

  @override
  String crsAlreadyDefined(Object name) {
    return 'CRS của \"$name\" đã được xác định. Hãy dùng chức năng chuyển đổi tọa độ thay vì gán lại metadata.';
  }

  @override
  String crsAssigned(Object crs, Object name) {
    return 'Đã đặt CRS cho \"$name\": $crs';
  }
}
