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
