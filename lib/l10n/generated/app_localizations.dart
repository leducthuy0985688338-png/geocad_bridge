import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_lo.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('lo'),
    Locale('vi'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In vi, this message translates to:
  /// **'AutoCAD ↔ Google Earth'**
  String get appTitle;

  /// No description provided for @language.
  ///
  /// In vi, this message translates to:
  /// **'Ngôn ngữ'**
  String get language;

  /// No description provided for @selectLanguage.
  ///
  /// In vi, this message translates to:
  /// **'Chọn ngôn ngữ'**
  String get selectLanguage;

  /// No description provided for @vietnamese.
  ///
  /// In vi, this message translates to:
  /// **'Tiếng Việt'**
  String get vietnamese;

  /// No description provided for @lao.
  ///
  /// In vi, this message translates to:
  /// **'ລາວ'**
  String get lao;

  /// No description provided for @english.
  ///
  /// In vi, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @projectNew.
  ///
  /// In vi, this message translates to:
  /// **'Project mới'**
  String get projectNew;

  /// No description provided for @projectOpen.
  ///
  /// In vi, this message translates to:
  /// **'Mở project'**
  String get projectOpen;

  /// No description provided for @projectSave.
  ///
  /// In vi, this message translates to:
  /// **'Lưu project'**
  String get projectSave;

  /// No description provided for @projectSaveAs.
  ///
  /// In vi, this message translates to:
  /// **'Lưu project thành...'**
  String get projectSaveAs;

  /// No description provided for @tools.
  ///
  /// In vi, this message translates to:
  /// **'CÔNG CỤ'**
  String get tools;

  /// No description provided for @importingCad.
  ///
  /// In vi, this message translates to:
  /// **'Đang đọc bản vẽ...'**
  String get importingCad;

  /// No description provided for @addAutoCadDrawing.
  ///
  /// In vi, this message translates to:
  /// **'Thêm bản vẽ AutoCAD'**
  String get addAutoCadDrawing;

  /// No description provided for @selectMultipleDwgDxf.
  ///
  /// In vi, this message translates to:
  /// **'Chọn nhiều DWG / DXF'**
  String get selectMultipleDwgDxf;

  /// No description provided for @importingGoogleEarth.
  ///
  /// In vi, this message translates to:
  /// **'Đang đọc dữ liệu...'**
  String get importingGoogleEarth;

  /// No description provided for @addGoogleEarthData.
  ///
  /// In vi, this message translates to:
  /// **'Thêm dữ liệu Google Earth'**
  String get addGoogleEarthData;

  /// No description provided for @kmlWgs84.
  ///
  /// In vi, this message translates to:
  /// **'KML (WGS84 / EPSG:4326)'**
  String get kmlWgs84;

  /// No description provided for @coordinateConverter.
  ///
  /// In vi, this message translates to:
  /// **'Chuyển đổi tọa độ'**
  String get coordinateConverter;

  /// No description provided for @utmWgs84.
  ///
  /// In vi, this message translates to:
  /// **'UTM ↔ WGS84'**
  String get utmWgs84;

  /// No description provided for @editData.
  ///
  /// In vi, this message translates to:
  /// **'Chỉnh sửa dữ liệu'**
  String get editData;

  /// No description provided for @geometryAndAttributes.
  ///
  /// In vi, this message translates to:
  /// **'Hình học / thuộc tính'**
  String get geometryAndAttributes;

  /// No description provided for @selectFeatureToEdit.
  ///
  /// In vi, this message translates to:
  /// **'Hãy chọn một đối tượng có thể chỉnh sửa trên canvas, sau đó dùng các công cụ chỉnh sửa bên phải.'**
  String get selectFeatureToEdit;

  /// No description provided for @exportingKml.
  ///
  /// In vi, this message translates to:
  /// **'Đang xuất KML...'**
  String get exportingKml;

  /// No description provided for @exportGoogleEarth.
  ///
  /// In vi, this message translates to:
  /// **'Xuất sang Google Earth'**
  String get exportGoogleEarth;

  /// No description provided for @exportingDxf.
  ///
  /// In vi, this message translates to:
  /// **'Đang xuất DXF...'**
  String get exportingDxf;

  /// No description provided for @exportAutoCad.
  ///
  /// In vi, this message translates to:
  /// **'Xuất sang AutoCAD'**
  String get exportAutoCad;

  /// No description provided for @dxfAscii.
  ///
  /// In vi, this message translates to:
  /// **'DXF ASCII'**
  String get dxfAscii;

  /// No description provided for @exportPdf.
  ///
  /// In vi, this message translates to:
  /// **'Xuất sang PDF'**
  String get exportPdf;

  /// No description provided for @drawingAndMap.
  ///
  /// In vi, this message translates to:
  /// **'Bản vẽ / Bản đồ'**
  String get drawingAndMap;

  /// No description provided for @dataLayers.
  ///
  /// In vi, this message translates to:
  /// **'CÁC LỚP DỮ LIỆU'**
  String get dataLayers;

  /// No description provided for @noDataLayers.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có lớp dữ liệu.'**
  String get noDataLayers;

  /// No description provided for @visible.
  ///
  /// In vi, this message translates to:
  /// **'Đang hiển thị'**
  String get visible;

  /// No description provided for @layersVisible.
  ///
  /// In vi, this message translates to:
  /// **'{visibleCount}/{totalCount} layer đang hiển thị'**
  String layersVisible(int visibleCount, int totalCount);

  /// No description provided for @objectsVisible.
  ///
  /// In vi, this message translates to:
  /// **'{count} đối tượng hiển thị'**
  String objectsVisible(int count);

  /// No description provided for @addDataHint.
  ///
  /// In vi, this message translates to:
  /// **'Hãy thêm bản vẽ AutoCAD hoặc dữ liệu Google Earth.'**
  String get addDataHint;

  /// No description provided for @projectContentSummary.
  ///
  /// In vi, this message translates to:
  /// **'{layerCount} lớp • {featureCount} đối tượng'**
  String projectContentSummary(int layerCount, int featureCount);

  /// No description provided for @lockLayer.
  ///
  /// In vi, this message translates to:
  /// **'Khóa layer'**
  String get lockLayer;

  /// No description provided for @knownCrsUseCoordinateConversion.
  ///
  /// In vi, this message translates to:
  /// **'CRS đã xác định; hãy dùng chuyển đổi tọa độ'**
  String get knownCrsUseCoordinateConversion;

  /// No description provided for @manualLayer.
  ///
  /// In vi, this message translates to:
  /// **'THỦ CÔNG'**
  String get manualLayer;

  /// No description provided for @georeferenceLayer.
  ///
  /// In vi, this message translates to:
  /// **'Định vị layer bằng các điểm khống chế'**
  String get georeferenceLayer;

  /// No description provided for @layerObjectCount.
  ///
  /// In vi, this message translates to:
  /// **'{count} đối tượng'**
  String layerObjectCount(int count);

  /// No description provided for @moveLayerDown.
  ///
  /// In vi, this message translates to:
  /// **'Đưa layer xuống'**
  String get moveLayerDown;

  /// No description provided for @moveLayerUp.
  ///
  /// In vi, this message translates to:
  /// **'Đưa layer lên'**
  String get moveLayerUp;

  /// No description provided for @createUtmLayer.
  ///
  /// In vi, this message translates to:
  /// **'Tạo layer UTM'**
  String get createUtmLayer;

  /// No description provided for @redo.
  ///
  /// In vi, this message translates to:
  /// **'Redo (Ctrl+Y)'**
  String get redo;

  /// No description provided for @editSourceCrs.
  ///
  /// In vi, this message translates to:
  /// **'Chỉnh sửa hệ tọa độ nguồn'**
  String get editSourceCrs;

  /// No description provided for @hideLayer.
  ///
  /// In vi, this message translates to:
  /// **'Ẩn layer'**
  String get hideLayer;

  /// No description provided for @readingDrawingData.
  ///
  /// In vi, this message translates to:
  /// **'Đang đọc dữ liệu bản vẽ...'**
  String get readingDrawingData;

  /// No description provided for @showLayer.
  ///
  /// In vi, this message translates to:
  /// **'Hiện layer'**
  String get showLayer;

  /// No description provided for @undo.
  ///
  /// In vi, this message translates to:
  /// **'Undo (Ctrl+Z)'**
  String get undo;

  /// No description provided for @removeLayer.
  ///
  /// In vi, this message translates to:
  /// **'Xóa layer khỏi dự án'**
  String get removeLayer;

  /// No description provided for @assignSourceCrs.
  ///
  /// In vi, this message translates to:
  /// **'Gán hệ tọa độ nguồn'**
  String get assignSourceCrs;

  /// No description provided for @welcomeTagline.
  ///
  /// In vi, this message translates to:
  /// **'Lồng ghép • Chỉnh sửa • Chuyển đổi • Xuất bản'**
  String get welcomeTagline;

  /// No description provided for @welcomeAddData.
  ///
  /// In vi, this message translates to:
  /// **'Hãy thêm một hoặc nhiều bản vẽ AutoCAD để bắt đầu tạo project.'**
  String get welcomeAddData;

  /// No description provided for @createWgs84Layer.
  ///
  /// In vi, this message translates to:
  /// **'Tạo layer WGS84'**
  String get createWgs84Layer;

  /// No description provided for @unlockLayer.
  ///
  /// In vi, this message translates to:
  /// **'Mở khóa layer'**
  String get unlockLayer;

  /// No description provided for @projectOpenedWithWarnings.
  ///
  /// In vi, this message translates to:
  /// **'Project đã mở với cảnh báo'**
  String get projectOpenedWithWarnings;

  /// No description provided for @geometryRestoredMissingSources.
  ///
  /// In vi, this message translates to:
  /// **'Geometry đã được khôi phục. Một số file nguồn không còn tồn tại:'**
  String get geometryRestoredMissingSources;

  /// No description provided for @close.
  ///
  /// In vi, this message translates to:
  /// **'Đóng'**
  String get close;

  /// No description provided for @googleEarthImportResult.
  ///
  /// In vi, this message translates to:
  /// **'Kết quả nhập Google Earth'**
  String get googleEarthImportResult;

  /// No description provided for @googleEarthFilesImported.
  ///
  /// In vi, this message translates to:
  /// **'Đã thêm thành công: {count} file KML'**
  String googleEarthFilesImported(int count);

  /// No description provided for @googleEarthFilesSkipped.
  ///
  /// In vi, this message translates to:
  /// **'Đã bỏ qua: {count} file đang có trong dự án'**
  String googleEarthFilesSkipped(int count);

  /// No description provided for @unreadableFiles.
  ///
  /// In vi, this message translates to:
  /// **'Các file không đọc được:'**
  String get unreadableFiles;

  /// No description provided for @dxfImportResult.
  ///
  /// In vi, this message translates to:
  /// **'Kết quả nhập DXF'**
  String get dxfImportResult;

  /// No description provided for @dxfLayersImported.
  ///
  /// In vi, this message translates to:
  /// **'Đã thêm: {count} layer DXF'**
  String dxfLayersImported(int count);

  /// No description provided for @dxfEntitiesImported.
  ///
  /// In vi, this message translates to:
  /// **'Đã nhập: {count} entity'**
  String dxfEntitiesImported(int count);

  /// No description provided for @dxfMalformedSkipped.
  ///
  /// In vi, this message translates to:
  /// **'Malformed đã bỏ qua: {count}'**
  String dxfMalformedSkipped(int count);

  /// No description provided for @dxfUnsupportedEntities.
  ///
  /// In vi, this message translates to:
  /// **'Entity chưa hỗ trợ: {count}'**
  String dxfUnsupportedEntities(int count);

  /// No description provided for @dxfFidelityWarnings.
  ///
  /// In vi, this message translates to:
  /// **'Cảnh báo fidelity:'**
  String get dxfFidelityWarnings;

  /// No description provided for @cadImportResult.
  ///
  /// In vi, this message translates to:
  /// **'Kết quả nhập bản vẽ'**
  String get cadImportResult;

  /// No description provided for @cadFilesImported.
  ///
  /// In vi, this message translates to:
  /// **'Đã thêm thành công: {count} file'**
  String cadFilesImported(int count);

  /// No description provided for @kmlExportUnavailable.
  ///
  /// In vi, this message translates to:
  /// **'Chưa thể xuất KML'**
  String get kmlExportUnavailable;

  /// No description provided for @kmlRequiresWgs84.
  ///
  /// In vi, this message translates to:
  /// **'KML yêu cầu WGS84 (EPSG:4326). Các layer đang hiển thị sau chưa phải WGS84:'**
  String get kmlRequiresWgs84;

  /// No description provided for @kmlPrepareWgs84Hint.
  ///
  /// In vi, this message translates to:
  /// **'Hãy gán/định vị CRS, tạo layer WGS84, sau đó ẩn layer nguồn trước khi xuất.'**
  String get kmlPrepareWgs84Hint;

  /// No description provided for @understood.
  ///
  /// In vi, this message translates to:
  /// **'Đã hiểu'**
  String get understood;

  /// No description provided for @kmlExportSucceeded.
  ///
  /// In vi, this message translates to:
  /// **'Xuất KML thành công'**
  String get kmlExportSucceeded;

  /// No description provided for @openWithGoogleEarth.
  ///
  /// In vi, this message translates to:
  /// **'Mở bằng Google Earth'**
  String get openWithGoogleEarth;

  /// No description provided for @utmZone.
  ///
  /// In vi, this message translates to:
  /// **'UTM Zone'**
  String get utmZone;

  /// No description provided for @hemisphere.
  ///
  /// In vi, this message translates to:
  /// **'Bán cầu'**
  String get hemisphere;

  /// No description provided for @north.
  ///
  /// In vi, this message translates to:
  /// **'Bắc (North)'**
  String get north;

  /// No description provided for @south.
  ///
  /// In vi, this message translates to:
  /// **'Nam (South)'**
  String get south;

  /// No description provided for @cancel.
  ///
  /// In vi, this message translates to:
  /// **'Hủy'**
  String get cancel;

  /// No description provided for @createLayer.
  ///
  /// In vi, this message translates to:
  /// **'Tạo layer'**
  String get createLayer;

  /// No description provided for @coordinateSystem.
  ///
  /// In vi, this message translates to:
  /// **'Hệ tọa độ'**
  String get coordinateSystem;

  /// No description provided for @localCadUndefined.
  ///
  /// In vi, this message translates to:
  /// **'CAD cục bộ / chưa xác định'**
  String get localCadUndefined;

  /// No description provided for @sourceCrsDeclarationNote.
  ///
  /// In vi, this message translates to:
  /// **'Lưu ý: thao tác này chỉ khai báo CRS của layer, không tự thay đổi các giá trị tọa độ X/Y đang có.'**
  String get sourceCrsDeclarationNote;

  /// No description provided for @apply.
  ///
  /// In vi, this message translates to:
  /// **'Áp dụng'**
  String get apply;

  /// No description provided for @sourceCoordinateSystem.
  ///
  /// In vi, this message translates to:
  /// **'Hệ tọa độ nguồn'**
  String get sourceCoordinateSystem;

  /// No description provided for @targetCoordinateSystem.
  ///
  /// In vi, this message translates to:
  /// **'Hệ tọa độ đích'**
  String get targetCoordinateSystem;

  /// No description provided for @autoUtmHint.
  ///
  /// In vi, this message translates to:
  /// **'Khi chuyển WGS84 → UTM, Zone và bán cầu được tự động xác định từ Longitude/Latitude.'**
  String get autoUtmHint;

  /// No description provided for @swapDirection.
  ///
  /// In vi, this message translates to:
  /// **'Đổi chiều'**
  String get swapDirection;

  /// No description provided for @convert.
  ///
  /// In vi, this message translates to:
  /// **'Chuyển đổi'**
  String get convert;

  /// No description provided for @coordinateInputRequired.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng nhập đủ hai giá trị tọa độ hợp lệ.'**
  String get coordinateInputRequired;

  /// No description provided for @wgs84Result.
  ///
  /// In vi, this message translates to:
  /// **'Kết quả WGS84'**
  String get wgs84Result;

  /// No description provided for @utmResult.
  ///
  /// In vi, this message translates to:
  /// **'Kết quả UTM'**
  String get utmResult;

  /// No description provided for @longitudeLatitudeRange.
  ///
  /// In vi, this message translates to:
  /// **'Longitude phải trong [-180, 180] và Latitude trong [-90, 90].'**
  String get longitudeLatitudeRange;

  /// No description provided for @invalidCoordinates.
  ///
  /// In vi, this message translates to:
  /// **'Tọa độ nhập vào không hợp lệ.'**
  String get invalidCoordinates;

  /// No description provided for @coordinateConversionFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không thể chuyển đổi tọa độ. Hãy kiểm tra lại dữ liệu đầu vào.'**
  String get coordinateConversionFailed;

  /// No description provided for @cadLocalConversionNote.
  ///
  /// In vi, this message translates to:
  /// **'Lưu ý: CAD cục bộ chưa thể chuyển trực tiếp sang WGS84 nếu chưa biết CRS hoặc phép định vị của bản vẽ.'**
  String get cadLocalConversionNote;

  /// No description provided for @georeferenceCadDrawing.
  ///
  /// In vi, this message translates to:
  /// **'Định vị bản vẽ CAD'**
  String get georeferenceCadDrawing;

  /// No description provided for @targetCrs.
  ///
  /// In vi, this message translates to:
  /// **'CRS đích'**
  String get targetCrs;

  /// No description provided for @addControlPoint.
  ///
  /// In vi, this message translates to:
  /// **'Thêm điểm khống chế'**
  String get addControlPoint;

  /// No description provided for @calculateGeoreferencePreview.
  ///
  /// In vi, this message translates to:
  /// **'Tính thử phép định vị'**
  String get calculateGeoreferencePreview;

  /// No description provided for @georeferenceInstructions.
  ///
  /// In vi, this message translates to:
  /// **'Nhập ít nhất hai điểm CAD và tọa độ UTM thực tương ứng. Với nhiều hơn hai điểm, ứng dụng dùng bình sai least-squares.'**
  String get georeferenceInstructions;

  /// No description provided for @createGeoreferencedLayer.
  ///
  /// In vi, this message translates to:
  /// **'Tạo layer đã định vị'**
  String get createGeoreferencedLayer;

  /// No description provided for @invalidControlPointData.
  ///
  /// In vi, this message translates to:
  /// **'Dữ liệu điểm khống chế không hợp lệ.'**
  String get invalidControlPointData;

  /// No description provided for @georeferenceCalculationFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không thể tính phép định vị. Hãy kiểm tra lại các điểm khống chế.'**
  String get georeferenceCalculationFailed;

  /// No description provided for @invalidNumber.
  ///
  /// In vi, this message translates to:
  /// **'{label} không phải là số hợp lệ.'**
  String invalidNumber(String label);

  /// No description provided for @controlPoint.
  ///
  /// In vi, this message translates to:
  /// **'Điểm khống chế {number}'**
  String controlPoint(int number);

  /// No description provided for @suspectedReview.
  ///
  /// In vi, this message translates to:
  /// **'Nghi ngờ — cần kiểm tra'**
  String get suspectedReview;

  /// No description provided for @largestError.
  ///
  /// In vi, this message translates to:
  /// **'Sai số lớn nhất'**
  String get largestError;

  /// No description provided for @removePoint.
  ///
  /// In vi, this message translates to:
  /// **'Xóa điểm {number}'**
  String removePoint(int number);

  /// No description provided for @residualSummary.
  ///
  /// In vi, this message translates to:
  /// **'ΔX: {deltaX} m • ΔY: {deltaY} m • Sai số: {error} m'**
  String residualSummary(String deltaX, String deltaY, String error);

  /// No description provided for @twoPointTransform.
  ///
  /// In vi, this message translates to:
  /// **'Phép biến đổi 2 điểm'**
  String get twoPointTransform;

  /// No description provided for @leastSquaresAdjustment.
  ///
  /// In vi, this message translates to:
  /// **'Bình sai {count} điểm'**
  String leastSquaresAdjustment(int count);

  /// No description provided for @maxResidualSummary.
  ///
  /// In vi, this message translates to:
  /// **'Sai số lớn nhất: {error} m (điểm {number})'**
  String maxResidualSummary(String error, int number);

  /// No description provided for @outlierNotApplicable.
  ///
  /// In vi, this message translates to:
  /// **'Hai điểm: không áp dụng phát hiện outlier.'**
  String get outlierNotApplicable;

  /// No description provided for @outlierInsufficientSample.
  ///
  /// In vi, this message translates to:
  /// **'Chưa đủ mẫu để đánh giá outlier; điểm lớn nhất chỉ mang tính tham khảo.'**
  String get outlierInsufficientSample;

  /// No description provided for @outlierNoRelativeAnomaly.
  ///
  /// In vi, this message translates to:
  /// **'Không phát hiện bất thường tương đối trong các residual.'**
  String get outlierNoRelativeAnomaly;

  /// No description provided for @outlierReviewSuggested.
  ///
  /// In vi, this message translates to:
  /// **'Có điểm nghi ngờ — hãy kiểm tra hoặc chỉnh sửa thủ công.'**
  String get outlierReviewSuggested;

  /// No description provided for @outlierMultipleLargeResiduals.
  ///
  /// In vi, this message translates to:
  /// **'Nhiều residual cần được kiểm tra tổng thể.'**
  String get outlierMultipleLargeResiduals;

  /// No description provided for @unsavedChangesTitle.
  ///
  /// In vi, this message translates to:
  /// **'Project có thay đổi chưa lưu'**
  String get unsavedChangesTitle;

  /// No description provided for @unsavedChangesMessage.
  ///
  /// In vi, this message translates to:
  /// **'Nếu tiếp tục, các thay đổi chưa lưu có thể bị mất. Bạn muốn lưu project trước không?'**
  String get unsavedChangesMessage;

  /// No description provided for @discardChanges.
  ///
  /// In vi, this message translates to:
  /// **'Không lưu'**
  String get discardChanges;

  /// No description provided for @save.
  ///
  /// In vi, this message translates to:
  /// **'Lưu'**
  String get save;

  /// No description provided for @projectCreated.
  ///
  /// In vi, this message translates to:
  /// **'Đã tạo project mới.'**
  String get projectCreated;

  /// No description provided for @projectOpenFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không thể mở project: {error}'**
  String projectOpenFailed(Object error);

  /// No description provided for @openGeoCadProject.
  ///
  /// In vi, this message translates to:
  /// **'Mở GeoCAD Project'**
  String get openGeoCadProject;

  /// No description provided for @projectPathUnavailable.
  ///
  /// In vi, this message translates to:
  /// **'Không lấy được đường dẫn project.'**
  String get projectPathUnavailable;

  /// No description provided for @projectOpened.
  ///
  /// In vi, this message translates to:
  /// **'Đã mở project \"{name}\".'**
  String projectOpened(Object name);

  /// No description provided for @projectSaveFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không thể lưu project: {error}'**
  String projectSaveFailed(Object error);

  /// No description provided for @geoCadProject.
  ///
  /// In vi, this message translates to:
  /// **'GeoCAD Project'**
  String get geoCadProject;

  /// No description provided for @projectSaved.
  ///
  /// In vi, this message translates to:
  /// **'Đã lưu project: {path}'**
  String projectSaved(Object path);

  /// No description provided for @dxfNoValidEntities.
  ///
  /// In vi, this message translates to:
  /// **'{fileName}: Không có entity DXF hợp lệ.'**
  String dxfNoValidEntities(Object fileName);

  /// No description provided for @selectedFilesAlreadyInProject.
  ///
  /// In vi, this message translates to:
  /// **'Các file đã chọn đều đang có trong dự án.'**
  String get selectedFilesAlreadyInProject;

  /// No description provided for @cadDrawingsAdded.
  ///
  /// In vi, this message translates to:
  /// **'Đã thêm {count} bản vẽ vào dự án.'**
  String cadDrawingsAdded(Object count);

  /// No description provided for @selectGoogleEarthKml.
  ///
  /// In vi, this message translates to:
  /// **'Chọn dữ liệu Google Earth (KML)'**
  String get selectGoogleEarthKml;

  /// No description provided for @filePathUnavailable.
  ///
  /// In vi, this message translates to:
  /// **'{fileName}: Không lấy được đường dẫn file.'**
  String filePathUnavailable(Object fileName);

  /// No description provided for @kmlNoValidGeometry.
  ///
  /// In vi, this message translates to:
  /// **'{fileName}: Không tìm thấy Point, LineString hoặc Polygon hợp lệ.'**
  String kmlNoValidGeometry(Object fileName);

  /// No description provided for @selectedKmlAlreadyInProject.
  ///
  /// In vi, this message translates to:
  /// **'Các file KML đã chọn đều đang có trong dự án.'**
  String get selectedKmlAlreadyInProject;

  /// No description provided for @skippedExistingFiles.
  ///
  /// In vi, this message translates to:
  /// **' • Bỏ qua {count} file đã có.'**
  String skippedExistingFiles(Object count);

  /// No description provided for @kmlFilesAdded.
  ///
  /// In vi, this message translates to:
  /// **'Đã thêm {count} file KML vào dự án.{skippedText}'**
  String kmlFilesAdded(Object count, Object skippedText);

  /// No description provided for @kmlImportPartialTitle.
  ///
  /// In vi, this message translates to:
  /// **'Nhập KML hoàn tất với cảnh báo'**
  String get kmlImportPartialTitle;

  /// No description provided for @kmlImportPartialNotice.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ hình học hợp lệ được nhập. Một phần dữ liệu KML đã bị bỏ qua hoặc không đọc được.'**
  String get kmlImportPartialNotice;

  /// No description provided for @kmlImportedGeometryCount.
  ///
  /// In vi, this message translates to:
  /// **'Hình học đã nhập: {count}'**
  String kmlImportedGeometryCount(int count);

  /// No description provided for @kmlMalformedGeometryCount.
  ///
  /// In vi, this message translates to:
  /// **'Hình học lỗi đã bỏ qua: {count}'**
  String kmlMalformedGeometryCount(int count);

  /// No description provided for @kmlUnsupportedGeometryCount.
  ///
  /// In vi, this message translates to:
  /// **'Hình học chưa hỗ trợ đã bỏ qua: {count}'**
  String kmlUnsupportedGeometryCount(int count);

  /// No description provided for @kmlFidelityWarningCount.
  ///
  /// In vi, this message translates to:
  /// **'Cảnh báo fidelity: {count}'**
  String kmlFidelityWarningCount(int count);

  /// No description provided for @kmlUnsupportedGeometryTypeCount.
  ///
  /// In vi, this message translates to:
  /// **'  • {geometryType}: {count}'**
  String kmlUnsupportedGeometryTypeCount(String geometryType, int count);

  /// No description provided for @kmlNoLayersAdded.
  ///
  /// In vi, this message translates to:
  /// **'Không có layer KML nào được thêm.'**
  String get kmlNoLayersAdded;

  /// No description provided for @kmlFatalImportFailure.
  ///
  /// In vi, this message translates to:
  /// **'{fileName}: Không thể đọc file KML.'**
  String kmlFatalImportFailure(String fileName);

  /// No description provided for @kmlAdditionalSummaryItems.
  ///
  /// In vi, this message translates to:
  /// **'và {count} mục khác'**
  String kmlAdditionalSummaryItems(int count);

  /// No description provided for @kmlDiagnosticFileHeading.
  ///
  /// In vi, this message translates to:
  /// **'File: {fileName}'**
  String kmlDiagnosticFileHeading(String fileName);

  /// No description provided for @kmlImportWarningsHeading.
  ///
  /// In vi, this message translates to:
  /// **'Chi tiết nhập dữ liệu'**
  String get kmlImportWarningsHeading;

  /// No description provided for @featureOwnerLayerNotFound.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy layer chứa đối tượng.'**
  String get featureOwnerLayerNotFound;

  /// No description provided for @layerLocked.
  ///
  /// In vi, this message translates to:
  /// **'Layer \"{name}\" đang bị khóa.'**
  String layerLocked(Object name);

  /// No description provided for @georeferenceLocalCadOnly.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ có thể định vị layer CAD cục bộ có dữ liệu hình học.'**
  String get georeferenceLocalCadOnly;

  /// No description provided for @georeferenceSucceeded.
  ///
  /// In vi, this message translates to:
  /// **'Đã định vị \"{name}\": {coordinateCount} tọa độ • {crs} • RMSE {rmse} m.'**
  String georeferenceSucceeded(
    Object coordinateCount,
    Object crs,
    Object name,
    Object rmse,
  );

  /// No description provided for @georeferenceLayerFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không thể định vị layer: {error}'**
  String georeferenceLayerFailed(Object error);

  /// No description provided for @layerNeedsValidCrs.
  ///
  /// In vi, this message translates to:
  /// **'Layer \"{name}\" chưa có CRS hợp lệ. Hãy thiết lập CRS trước.'**
  String layerNeedsValidCrs(Object name);

  /// No description provided for @layerAlreadyWgs84.
  ///
  /// In vi, this message translates to:
  /// **'Layer \"{name}\" đã là WGS84 (EPSG:4326).'**
  String layerAlreadyWgs84(Object name);

  /// No description provided for @wgs84LayerCreated.
  ///
  /// In vi, this message translates to:
  /// **'Đã tạo layer WGS84: {featureCount} đối tượng, {coordinateCount} tọa độ.'**
  String wgs84LayerCreated(Object coordinateCount, Object featureCount);

  /// No description provided for @createWgs84Failed.
  ///
  /// In vi, this message translates to:
  /// **'Không thể tạo layer WGS84: {error}'**
  String createWgs84Failed(Object error);

  /// No description provided for @createUtmFromWgs84Only.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ có thể tạo UTM từ layer WGS84 có dữ liệu hình học.'**
  String get createUtmFromWgs84Only;

  /// No description provided for @invalidTargetUtmCrs.
  ///
  /// In vi, this message translates to:
  /// **'CRS UTM đích không hợp lệ.'**
  String get invalidTargetUtmCrs;

  /// No description provided for @utmLayerCreated.
  ///
  /// In vi, this message translates to:
  /// **'Đã tạo layer {crs}: {featureCount} đối tượng, {coordinateCount} tọa độ.'**
  String utmLayerCreated(
    Object coordinateCount,
    Object crs,
    Object featureCount,
  );

  /// No description provided for @createUtmFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không thể tạo layer UTM: {error}'**
  String createUtmFailed(Object error);

  /// No description provided for @noVisibleDataForKml.
  ///
  /// In vi, this message translates to:
  /// **'Không có dữ liệu đang hiển thị để xuất KML.'**
  String get noVisibleDataForKml;

  /// No description provided for @exportGoogleEarthKml.
  ///
  /// In vi, this message translates to:
  /// **'Xuất dữ liệu Google Earth (KML)'**
  String get exportGoogleEarthKml;

  /// No description provided for @exportKmlFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không thể xuất KML: {error}'**
  String exportKmlFailed(Object error);

  /// No description provided for @exportDxfFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không thể xuất DXF: {error}'**
  String exportDxfFailed(Object error);

  /// No description provided for @exportAutoCadDxfAscii.
  ///
  /// In vi, this message translates to:
  /// **'Xuất bản vẽ AutoCAD (DXF ASCII)'**
  String get exportAutoCadDxfAscii;

  /// No description provided for @exportWarnings.
  ///
  /// In vi, this message translates to:
  /// **' • {count} cảnh báo'**
  String exportWarnings(Object count);

  /// No description provided for @dxfExportSucceeded.
  ///
  /// In vi, this message translates to:
  /// **'Đã xuất {entityCount} đối tượng trên {layerCount} CAD layer • {crs}{warnings} • {path}'**
  String dxfExportSucceeded(
    Object crs,
    Object entityCount,
    Object layerCount,
    Object path,
    Object warnings,
  );

  /// No description provided for @writeDxfFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không thể ghi file DXF: {error}'**
  String writeDxfFailed(Object error);

  /// No description provided for @autoOpenKmlWindowsOnly.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ hỗ trợ mở KML tự động trên Windows desktop.'**
  String get autoOpenKmlWindowsOnly;

  /// No description provided for @kmlSentToDefaultApp.
  ///
  /// In vi, this message translates to:
  /// **'Đã gửi file KML tới ứng dụng mặc định. Nếu Google Earth chưa được cài đặt, Windows sẽ yêu cầu chọn ứng dụng.'**
  String get kmlSentToDefaultApp;

  /// No description provided for @windowsOpenKmlFailed.
  ///
  /// In vi, this message translates to:
  /// **'Windows không thể mở file KML. Hãy kiểm tra Google Earth hoặc ứng dụng mặc định: {error}'**
  String windowsOpenKmlFailed(Object error);

  /// No description provided for @openKmlFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không thể mở file KML: {error}'**
  String openKmlFailed(Object error);

  /// No description provided for @crsAlreadyDefined.
  ///
  /// In vi, this message translates to:
  /// **'CRS của \"{name}\" đã được xác định. Hãy dùng chức năng chuyển đổi tọa độ thay vì gán lại metadata.'**
  String crsAlreadyDefined(Object name);

  /// No description provided for @crsAssigned.
  ///
  /// In vi, this message translates to:
  /// **'Đã đặt CRS cho \"{name}\": {crs}'**
  String crsAssigned(Object crs, Object name);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'lo', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'lo':
      return AppLocalizationsLo();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
