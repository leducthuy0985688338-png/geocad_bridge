import 'package:autocad_googleearth/l10n/generated/app_localizations.dart';
import 'package:autocad_googleearth/models/map_feature.dart';
import 'package:autocad_googleearth/models/map_layer.dart';
import 'package:autocad_googleearth/models/map_project.dart';
import 'package:autocad_googleearth/screens/home_screen.dart';
import 'package:autocad_googleearth/widgets/map_canvas.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const originalCoordinate = MapCoordinate(x: 123.4567, y: -45.6789, z: 8);
  const project = MapProject(
    id: 'project',
    name: 'Edit entry',
    layers: [
      MapLayer(
        id: 'layer',
        name: 'POINTS',
        sourceType: MapLayerSourceType.dxf,
        features: [
          MapFeature(
            id: 'point',
            name: 'POINT 1',
            type: MapFeatureType.point,
            coordinates: [originalCoordinate],
            properties: {'cadLayer': 'POINTS'},
          ),
        ],
      ),
    ],
  );

  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(0.8)),
          child: HomeScreen(initialProject: project),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> selectPoint(WidgetTester tester) async {
    final position = tester.getRect(find.byType(MapCanvas)).center;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: position);
    await mouse.down(position);
    await mouse.up();
    await mouse.removePointer();
    await tester.pump();
  }

  testWidgets(
    'Edit Data gives localized guidance when no feature is selected',
    (tester) async {
      await pumpHome(tester);

      await tester.tap(find.text('Chỉnh sửa dữ liệu'));
      await tester.pump();

      expect(
        find.text(
          'Hãy chọn một đối tượng có thể chỉnh sửa trên canvas, '
          'sau đó dùng các công cụ chỉnh sửa bên phải.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('selected POINT opens exact XY editor and updates once', (
    tester,
  ) async {
    await pumpHome(tester);
    await selectPoint(tester);

    await tester.tap(find.text('Chỉnh sửa dữ liệu'));
    await tester.pumpAndSettle();

    expect(find.text('Chỉnh tọa độ đỉnh'), findsOneWidget);
    expect(find.widgetWithText(TextField, '123.4567'), findsOneWidget);
    expect(find.widgetWithText(TextField, '-45.6789'), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '200.25');
    await tester.enterText(fields.at(1), '-100.5');
    await tester.tap(find.widgetWithText(FilledButton, 'Cập nhật'));
    await tester.pumpAndSettle();

    var updated = tester.widget<MapCanvas>(find.byType(MapCanvas)).project;
    expect(updated.layers.single.features.single.coordinates.single.x, 200.25);
    expect(updated.layers.single.features.single.coordinates.single.y, -100.5);
    expect(updated.layers.single.features.single.coordinates.single.z, 8);
    expect(find.textContaining('Edit entry *'), findsOneWidget);

    await tester.tap(find.byTooltip('Undo (Ctrl+Z)'));
    await tester.pumpAndSettle();

    updated = tester.widget<MapCanvas>(find.byType(MapCanvas)).project;
    expect(
      updated.layers.single.features.single.coordinates.single,
      originalCoordinate,
    );
    expect(find.textContaining('Edit entry *'), findsNothing);
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byTooltip('Undo (Ctrl+Z)'),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byTooltip('Redo (Ctrl+Y)'),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNotNull,
    );
  });
}
