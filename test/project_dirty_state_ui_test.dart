import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autocad_googleearth/models/coordinate_reference_system.dart';
import 'package:autocad_googleearth/models/map_layer.dart';
import 'package:autocad_googleearth/models/map_project.dart';
import 'package:autocad_googleearth/screens/home_screen.dart';
import 'package:autocad_googleearth/services/project_persistence_service.dart';
import 'package:autocad_googleearth/widgets/map_canvas.dart';

void main() {
  const initialProject = MapProject(
    id: 'initial',
    name: 'Initial',
    layers: [
      MapLayer(
        id: 'layer',
        name: 'Layer',
        sourceType: MapLayerSourceType.manual,
      ),
    ],
  );

  Future<void> pumpHome(
    WidgetTester tester, {
    MapProject project = initialProject,
    Future<bool> Function(MapProject)? save,
    Future<GeoCadProjectDocument?> Function()? open,
  }) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          initialProject: project,
          saveProjectOverride: save,
          openProjectOverride: open,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String title(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('project-title'))).data!;

  Future<void> makeDirty(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Ẩn layer'));
    await tester.pumpAndSettle();
    expect(title(tester), endsWith(' *'));
  }

  testWidgets('persistent layer mutation updates dirty indicator', (
    tester,
  ) async {
    await pumpHome(tester);
    expect(title(tester), isNot(endsWith(' *')));
    await makeDirty(tester);
  });

  testWidgets('known WGS84 and UTM layers cannot be metadata relabeled', (
    tester,
  ) async {
    const knownProject = MapProject(
      id: 'known',
      name: 'Known CRS',
      layers: [
        MapLayer(
          id: 'wgs',
          name: 'WGS Layer',
          sourceType: MapLayerSourceType.kml,
          crs: CoordinateReferenceSystem.wgs84(),
        ),
        MapLayer(
          id: 'utm',
          name: 'UTM Layer',
          sourceType: MapLayerSourceType.dxf,
          crs: CoordinateReferenceSystem.utm(
            utmZone: 48,
            hemisphere: UtmHemisphere.north,
          ),
        ),
      ],
    );

    await pumpHome(tester, project: knownProject);

    expect(find.text('WGS84 (EPSG:4326)'), findsOneWidget);
    expect(find.text('UTM Zone 48N'), findsOneWidget);
    expect(
      find.byTooltip('CRS đã xác định; hãy dùng chuyển đổi tọa độ'),
      findsNWidgets(2),
    );

    await tester.tap(
      find.byTooltip('CRS đã xác định; hãy dùng chuyển đổi tọa độ').first,
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(find.text('Gán hệ tọa độ nguồn'), findsNothing);
    expect(title(tester), isNot(endsWith(' *')));
  });

  testWidgets('local CAD layer exposes source CRS assignment workflow', (
    tester,
  ) async {
    await pumpHome(tester);

    await tester.tap(find.byTooltip('Gán hệ tọa độ nguồn'));
    await tester.pumpAndSettle();

    expect(find.text('Gán hệ tọa độ nguồn'), findsOneWidget);
    expect(find.textContaining('chỉ khai báo CRS của layer'), findsOneWidget);
  });

  testWidgets('transient canvas pan does not mark project dirty', (
    tester,
  ) async {
    await pumpHome(tester);
    await tester.drag(find.byType(MapCanvas), const Offset(80, 40));
    await tester.pumpAndSettle();
    expect(title(tester), isNot(endsWith(' *')));
  });

  testWidgets('Save success cleans and Save failure remains dirty', (
    tester,
  ) async {
    await pumpHome(tester, save: (_) async => true);
    await makeDirty(tester);
    await tester.tap(find.byTooltip('Lưu project'));
    await tester.pumpAndSettle();
    expect(title(tester), isNot(endsWith(' *')));

    await tester.tap(find.byTooltip('Hiện layer'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpHome(tester, save: (_) async => false);
    await makeDirty(tester);
    await tester.tap(find.byTooltip('Lưu project'));
    await tester.pumpAndSettle();
    expect(title(tester), endsWith(' *'));
  });

  testWidgets('dirty New supports Cancel and Discard', (tester) async {
    await pumpHome(tester);
    await makeDirty(tester);
    await tester.tap(find.byTooltip('Project mới'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('unsaved-cancel')));
    await tester.pumpAndSettle();
    expect(title(tester), contains('Initial *'));

    await tester.tap(find.byTooltip('Project mới'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('unsaved-discard')));
    await tester.pumpAndSettle();
    expect(title(tester), contains('Dự án GeoCAD mới'));
    expect(title(tester), isNot(endsWith(' *')));
  });

  testWidgets('dirty New only continues after successful Save', (tester) async {
    await pumpHome(tester, save: (_) async => false);
    await makeDirty(tester);
    await tester.tap(find.byTooltip('Project mới'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('unsaved-save')));
    await tester.pumpAndSettle();
    expect(title(tester), contains('Initial *'));

    await tester.pumpWidget(const SizedBox.shrink());
    await pumpHome(tester, save: (_) async => true);
    await makeDirty(tester);
    await tester.tap(find.byTooltip('Project mới'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('unsaved-save')));
    await tester.pumpAndSettle();
    expect(title(tester), contains('Dự án GeoCAD mới'));
    expect(title(tester), isNot(endsWith(' *')));
  });

  testWidgets('Open success cleans while cancel keeps old dirty project', (
    tester,
  ) async {
    await pumpHome(tester, open: () async => null);
    await makeDirty(tester);
    await tester.tap(find.byTooltip('Mở project'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('unsaved-discard')));
    await tester.pumpAndSettle();
    expect(title(tester), contains('Initial *'));

    final loaded = GeoCadProjectDocument(
      project: const MapProject(id: 'loaded', name: 'Loaded'),
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpHome(tester, open: () async => loaded);
    await makeDirty(tester);
    await tester.tap(find.byTooltip('Mở project'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('unsaved-discard')));
    await tester.pumpAndSettle();
    expect(title(tester), contains('Loaded'));
    expect(title(tester), isNot(endsWith(' *')));
  });

  testWidgets('Open failure keeps the old project and dirty state', (
    tester,
  ) async {
    await pumpHome(
      tester,
      open: () async => throw StateError('corrupted project'),
    );
    await makeDirty(tester);
    await tester.tap(find.byTooltip('Mở project'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('unsaved-discard')));
    await tester.pumpAndSettle();
    expect(title(tester), contains('Initial *'));
  });

  testWidgets('undo and redo recognize the saved project revision', (
    tester,
  ) async {
    await pumpHome(tester, save: (_) async => true);
    await makeDirty(tester);
    await tester.tap(find.byTooltip('Lưu project'));
    await tester.pumpAndSettle();
    expect(title(tester), isNot(endsWith(' *')));

    await tester.tap(find.byTooltip('Hiện layer'));
    await tester.pumpAndSettle();
    expect(title(tester), endsWith(' *'));
    await tester.tap(find.byTooltip('Undo (Ctrl+Z)'));
    await tester.pumpAndSettle();
    expect(title(tester), isNot(endsWith(' *')));
    await tester.tap(find.byTooltip('Undo (Ctrl+Z)'));
    await tester.pumpAndSettle();
    expect(title(tester), endsWith(' *'));
    await tester.tap(find.byTooltip('Redo (Ctrl+Y)'));
    await tester.pumpAndSettle();
    expect(title(tester), isNot(endsWith(' *')));
  });

  testWidgets('exit request handles clean Cancel Discard and Save', (
    tester,
  ) async {
    await pumpHome(tester, save: (_) async => true);
    expect(await tester.binding.handleRequestAppExit(), AppExitResponse.exit);

    await makeDirty(tester);
    var response = tester.binding.handleRequestAppExit();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('unsaved-cancel')));
    await tester.pumpAndSettle();
    expect(await response, AppExitResponse.cancel);

    response = tester.binding.handleRequestAppExit();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('unsaved-discard')));
    await tester.pumpAndSettle();
    expect(await response, AppExitResponse.exit);

    response = tester.binding.handleRequestAppExit();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('unsaved-save')));
    await tester.pumpAndSettle();
    expect(await response, AppExitResponse.exit);
  });

  testWidgets('busy close request is cancelled', (tester) async {
    final saveCompleter = Completer<bool>();
    await pumpHome(tester, save: (_) => saveCompleter.future);
    await makeDirty(tester);
    await tester.tap(find.byTooltip('Lưu project'));
    await tester.pump();

    expect(await tester.binding.handleRequestAppExit(), AppExitResponse.cancel);
    saveCompleter.complete(true);
    await tester.pumpAndSettle();
    expect(title(tester), isNot(endsWith(' *')));
  });
}
