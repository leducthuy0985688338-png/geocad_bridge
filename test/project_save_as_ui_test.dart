import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autocad_googleearth/l10n/generated/app_localizations.dart';
import 'package:autocad_googleearth/models/map_layer.dart';
import 'package:autocad_googleearth/models/map_project.dart';
import 'package:autocad_googleearth/screens/home_screen.dart';
import 'package:autocad_googleearth/services/project_persistence_service.dart';

void main() {
  const initialProject = MapProject(
    id: 'save-as-project',
    name: 'Dự án Unicode',
    layers: [
      MapLayer(
        id: 'layer',
        name: 'Layer',
        sourceType: MapLayerSourceType.manual,
      ),
    ],
  );

  Future<void> pumpHome(
    WidgetTester tester,
    ProjectSavePathSelector selector,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HomeScreen(
          initialProject: initialProject,
          projectSavePathSelectorOverride: selector,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String projectTitle(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('project-title'))).data!;

  Future<void> makeDirty(WidgetTester tester) async {
    final toggle = find.byTooltip('Ẩn layer');
    if (toggle.evaluate().isNotEmpty) {
      await tester.tap(toggle);
    } else {
      await tester.tap(find.byTooltip('Hiện layer'));
    }
    await tester.pumpAndSettle();
    expect(projectTitle(tester), endsWith(' *'));
  }

  Future<void> tapAndSettleFileIo(WidgetTester tester, Finder action) async {
    await tester.runAsync(() async {
      await tester.tap(action);
      await Future<void>.delayed(const Duration(milliseconds: 600));
    });
    await tester.pumpAndSettle();
  }

  Future<void> clearMessages(WidgetTester tester) async {
    final context = tester.element(find.byType(HomeScreen));
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    await tester.pumpAndSettle();
  }

  testWidgets('cancel Save As performs no write and remains dirty', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync('geocad-cancel-');
    addTearDown(() => directory.deleteSync(recursive: true));
    var selectorCalls = 0;
    await pumpHome(tester, ({
      required suggestedName,
      required allowedExtensions,
    }) async {
      selectorCalls++;
      return null;
    });
    await makeDirty(tester);

    await tester.tap(find.byTooltip('Lưu project thành...'));
    await tester.pumpAndSettle();

    expect(selectorCalls, 1);
    expect(directory.listSync(), isEmpty);
    expect(projectTitle(tester), endsWith(' *'));
  });

  testWidgets(
    'Save As preserves existing bytes during selection then saves Unicode path',
    (tester) async {
      final root = Directory.systemTemp.createTempSync('geocad-save-as-');
      addTearDown(() => root.deleteSync(recursive: true));
      final directory = Directory(
        '${root.path}${Platform.pathSeparator}Dữ liệu có khoảng trắng',
      );
      directory.createSync();
      final path =
          '${directory.path}${Platform.pathSeparator}Dự án hiện hữu.geocad';
      const original = 'EXISTING PROJECT MUST SURVIVE PATH SELECTION';
      File(path).writeAsStringSync(original);
      var selectorCalls = 0;
      String? receivedName;
      List<String>? receivedExtensions;

      await pumpHome(tester, ({
        required suggestedName,
        required allowedExtensions,
      }) async {
        selectorCalls++;
        receivedName = suggestedName;
        receivedExtensions = List<String>.from(allowedExtensions);
        expect(File(path).readAsStringSync(), original);
        return path;
      });
      await makeDirty(tester);

      await tapAndSettleFileIo(tester, find.byTooltip('Lưu project thành...'));

      expect(selectorCalls, 1);
      expect(receivedName, 'Dự án Unicode.geocad');
      expect(receivedExtensions, ['geocad']);
      expect(projectTitle(tester), isNot(endsWith(' *')));
      final restored = const ProjectPersistenceService().deserialize(
        File(path).readAsStringSync(),
      );
      expect(restored.project.id, initialProject.id);
      expect(restored.project.layers.single.visible, isFalse);

      await clearMessages(tester);
      await makeDirty(tester);
      await tapAndSettleFileIo(tester, find.byTooltip('Lưu project'));

      expect(selectorCalls, 1);
      expect(projectTitle(tester), isNot(endsWith(' *')));
      final savedAgain = const ProjectPersistenceService().deserialize(
        File(path).readAsStringSync(),
      );
      expect(savedAgain.project.layers.single.visible, isTrue);
      await clearMessages(tester);
    },
  );

  testWidgets('persistence failure does not update path or clean dirty state', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync('geocad-fail-');
    addTearDown(() => directory.deleteSync(recursive: true));
    var selectorCalls = 0;
    await pumpHome(tester, ({
      required suggestedName,
      required allowedExtensions,
    }) async {
      selectorCalls++;
      return directory.path;
    });
    await makeDirty(tester);

    await tapAndSettleFileIo(tester, find.byTooltip('Lưu project thành...'));

    expect(selectorCalls, 1);
    expect(projectTitle(tester), endsWith(' *'));

    await clearMessages(tester);
    await tapAndSettleFileIo(tester, find.byTooltip('Lưu project'));

    expect(selectorCalls, 2);
    expect(projectTitle(tester), endsWith(' *'));
    await clearMessages(tester);
  });
}
