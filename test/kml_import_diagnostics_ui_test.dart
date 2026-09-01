import 'dart:io';
import 'dart:typed_data';

// ignore: depend_on_referenced_packages
import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autocad_googleearth/l10n/generated/app_localizations.dart';
import 'package:autocad_googleearth/models/map_project.dart';
import 'package:autocad_googleearth/screens/home_screen.dart';
import 'package:autocad_googleearth/widgets/map_canvas.dart';

void main() {
  late Directory tempDirectory;

  setUp(() {
    tempDirectory = Directory.systemTemp.createTempSync('geocad-kml-ui-');
  });

  tearDown(() {
    if (tempDirectory.existsSync()) {
      tempDirectory.deleteSync(recursive: true);
    }
  });

  Future<PlatformFile> fixture(String name, String content) {
    final file = File('${tempDirectory.path}${Platform.pathSeparator}$name');
    file.writeAsStringSync(content);
    return Future.value(_TestPlatformFile(file));
  }

  Future<void> pumpHome(
    WidgetTester tester, {
    required Locale locale,
    required String importLabel,
    required List<PlatformFile> files,
  }) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HomeScreen(
          initialProject: const MapProject(id: 'kml-ui', name: 'KML UI'),
          kmlFilesSelectorOverride: () async => files,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text(importLabel));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    for (var attempt = 0; attempt < 200; attempt++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.byType(SnackBar).evaluate().isNotEmpty ||
          find.byType(AlertDialog).evaluate().isNotEmpty) {
        return;
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
    throw TestFailure('KML import did not present a result.');
  }

  MapCanvas canvas(WidgetTester tester) =>
      tester.widget<MapCanvas>(find.byType(MapCanvas));

  String projectTitle(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('project-title'))).data!;

  testWidgets('valid KML uses normal success and imports its layer', (
    tester,
  ) async {
    final file = await fixture(
      'valid.kml',
      '<kml><Placemark><Point><coordinates>106,16</coordinates></Point></Placemark></kml>',
    );

    await pumpHome(
      tester,
      locale: const Locale('en'),
      importLabel: 'Add Google Earth data',
      files: [file],
    );

    expect(find.text('Added 1 KML file(s) to the project.'), findsOneWidget);
    expect(find.text('KML import completed with warnings'), findsNothing);
    expect(canvas(tester).project.layers, hasLength(1));
  });

  testWidgets(
    'malformed sibling produces partial warning and keeps valid feature',
    (tester) async {
      final file = await fixture(
        'survey-&-raw.kml',
        '<kml><Placemark><name>Điểm gốc</name><Point><coordinates>106,16</coordinates></Point></Placemark>'
            '<Placemark><name>Không dịch tôi</name><LineString><coordinates>bad</coordinates></LineString></Placemark></kml>',
      );

      await pumpHome(
        tester,
        locale: const Locale('en'),
        importLabel: 'Add Google Earth data',
        files: [file],
      );

      expect(find.text('KML import completed with warnings'), findsOneWidget);
      expect(find.text('Imported geometry: 1'), findsNWidgets(2));
      expect(find.text('Malformed geometry skipped: 1'), findsNWidgets(2));
      expect(find.text('File: survey-&-raw.kml'), findsOneWidget);
      expect(canvas(tester).project.layers.single.features, hasLength(1));
    },
  );

  testWidgets('unsupported sibling is reported with verbatim geometry type', (
    tester,
  ) async {
    final file = await fixture(
      'model-source.kml',
      '<kml><Placemark><Point><coordinates>106,16</coordinates></Point><Model/></Placemark></kml>',
    );

    await pumpHome(
      tester,
      locale: const Locale('en'),
      importLabel: 'Add Google Earth data',
      files: [file],
    );

    expect(find.text('Unsupported geometry skipped: 1'), findsNWidgets(2));
    expect(find.text('  • Model: 1'), findsOneWidget);
    expect(canvas(tester).project.layers.single.features, hasLength(1));
  });

  testWidgets(
    'polygon hole plus valid sibling reports fidelity partial import',
    (tester) async {
      final file = await fixture(
        'hole.kml',
        '<kml><Placemark><Point><coordinates>106,16</coordinates></Point></Placemark>'
            '<Placemark><Polygon><outerBoundaryIs><LinearRing><coordinates>0,0 1,0 1,1 0,0</coordinates></LinearRing></outerBoundaryIs>'
            '<innerBoundaryIs><LinearRing><coordinates>.2,.2 .3,.2 .3,.3 .2,.2</coordinates></LinearRing></innerBoundaryIs></Polygon></Placemark></kml>',
      );

      await pumpHome(
        tester,
        locale: const Locale('en'),
        importLabel: 'Add Google Earth data',
        files: [file],
      );

      expect(find.text('KML import completed with warnings'), findsOneWidget);
      expect(find.text('Fidelity warnings: 1'), findsNWidgets(2));
      expect(find.text('  • Polygon: 1'), findsOneWidget);
    },
  );

  testWidgets('all invalid KML does not mutate or dirty project', (
    tester,
  ) async {
    final file = await fixture(
      'invalid-only.kml',
      '<kml><Placemark><Model/></Placemark><Placemark><Point><coordinates>bad</coordinates></Point></Placemark></kml>',
    );

    await pumpHome(
      tester,
      locale: const Locale('en'),
      importLabel: 'Add Google Earth data',
      files: [file],
    );

    expect(find.text('No KML layer was added.'), findsOneWidget);
    expect(find.text('Imported geometry: 0'), findsNWidgets(2));
    expect(canvas(tester).project.layers, isEmpty);
    expect(projectTitle(tester), isNot(endsWith(' *')));
  });

  testWidgets('fatal XML uses generic localized text without raw exception', (
    tester,
  ) async {
    final file = await fixture('secret-file.kml', '<kml><Placemark>');

    await pumpHome(
      tester,
      locale: const Locale('en'),
      importLabel: 'Add Google Earth data',
      files: [file],
    );

    expect(
      find.text('secret-file.kml: The KML file could not be read.'),
      findsOneWidget,
    );
    expect(find.textContaining('FormatException'), findsNothing);
    expect(find.textContaining('KML không hợp lệ'), findsNothing);
    expect(canvas(tester).project.layers, isEmpty);
  });

  testWidgets('many file summaries retain aggregate counts and are bounded', (
    tester,
  ) async {
    final files = <PlatformFile>[];
    for (var index = 0; index < 11; index++) {
      files.add(
        await fixture(
          'unsupported-$index.kml',
          '<kml><Placemark><Model/></Placemark></kml>',
        ),
      );
    }

    await pumpHome(
      tester,
      locale: const Locale('en'),
      importLabel: 'Add Google Earth data',
      files: files,
    );

    expect(find.text('Unsupported geometry skipped: 11'), findsOneWidget);
    expect(find.text('File: unsupported-0.kml'), findsOneWidget);
    expect(find.text('File: unsupported-9.kml'), findsOneWidget);
    expect(find.text('File: unsupported-10.kml'), findsNothing);
    expect(find.text('and 1 more'), findsOneWidget);
  });

  testWidgets('Vietnamese and Lao partial summaries are localized', (
    tester,
  ) async {
    final viFile = await fixture(
      'nguon-Model.kml',
      '<kml><Placemark><Point><coordinates>106,16</coordinates></Point><Model/></Placemark></kml>',
    );
    await pumpHome(
      tester,
      locale: const Locale('vi'),
      importLabel: 'Thêm dữ liệu Google Earth',
      files: [viFile],
    );
    expect(find.text('Nhập KML hoàn tất với cảnh báo'), findsOneWidget);
    expect(find.text('File: nguon-Model.kml'), findsOneWidget);
    expect(find.text('  • Model: 1'), findsOneWidget);

    await tester.tap(find.text('Đóng'));
    await tester.pump(const Duration(milliseconds: 300));

    final loFile = await fixture(
      'ແຫຼ່ງ-Model.kml',
      '<kml><Placemark><Point><coordinates>106,16</coordinates></Point><Model/></Placemark></kml>',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpHome(
      tester,
      locale: const Locale('lo'),
      importLabel: 'ເພີ່ມຂໍ້ມູນ Google Earth',
      files: [loFile],
    );
    expect(find.text('ນຳເຂົ້າ KML ສຳເລັດໂດຍມີຄຳເຕືອນ'), findsOneWidget);
    expect(find.text('ໄຟລ໌: ແຫຼ່ງ-Model.kml'), findsOneWidget);
    expect(find.text('  • Model: 1'), findsOneWidget);
  });

  testWidgets('partial batch is one history operation', (tester) async {
    final warned = await fixture(
      'warned.kml',
      '<kml><Placemark><Point><coordinates>106,16</coordinates></Point><Model/></Placemark></kml>',
    );
    final clean = await fixture(
      'clean.kml',
      '<kml><Placemark><Point><coordinates>107,17</coordinates></Point></Placemark></kml>',
    );

    await pumpHome(
      tester,
      locale: const Locale('en'),
      importLabel: 'Add Google Earth data',
      files: [warned, clean],
    );
    expect(canvas(tester).project.layers, hasLength(2));

    await tester.tap(find.text('Close'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byIcon(Icons.undo));
    await tester.pump(const Duration(milliseconds: 300));

    expect(canvas(tester).project.layers, isEmpty);
    expect(projectTitle(tester), isNot(endsWith(' *')));
  });
}

final class _TestPlatformFile extends PlatformFile {
  final File file;

  _TestPlatformFile(this.file);

  @override
  String get name => file.uri.pathSegments.last;

  @override
  Uri get uri => file.uri;

  @override
  XFile get xFile => XFile(file.path);

  @override
  Future<int> length() => file.length();

  @override
  Future<Uint8List> readAsBytes() => file.readAsBytes();

  @override
  Stream<Uint8List> readAsByteStream() =>
      file.openRead().map(Uint8List.fromList);
}
