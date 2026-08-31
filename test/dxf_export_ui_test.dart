import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autocad_googleearth/l10n/generated/app_localizations.dart';
import 'package:autocad_googleearth/models/coordinate_reference_system.dart';
import 'package:autocad_googleearth/models/map_feature.dart';
import 'package:autocad_googleearth/models/map_layer.dart';
import 'package:autocad_googleearth/models/map_project.dart';
import 'package:autocad_googleearth/screens/home_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void prepareView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  MapFeature point({double x = 106, double y = 16}) {
    return MapFeature(
      id: 'point',
      type: MapFeatureType.point,
      coordinates: [MapCoordinate(x: x, y: y, z: 12)],
      name: 'Point',
    );
  }

  MapProject projectWith(CoordinateReferenceSystem crs) {
    return MapProject(
      id: 'project',
      name: 'DXF UI',
      layers: [
        MapLayer(
          id: 'source',
          name: 'Source',
          sourceType: MapLayerSourceType.kml,
          crs: crs,
          features: [point()],
        ),
      ],
    );
  }

  testWidgets(
    'WGS84 to UTM creates a real dirty layer and Undo restores source',
    (tester) async {
      prepareView(tester);
      final source = projectWith(const CoordinateReferenceSystem.wgs84());
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomeScreen(
            initialProject: source,
            selectUtmCrsOverride: (_) async =>
                const CoordinateReferenceSystem.utm(
                  utmZone: 48,
                  hemisphere: UtmHemisphere.north,
                ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Tạo layer UTM'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Source - UTM Zone 48N'), findsOneWidget);
      expect(find.textContaining('UTM Zone 48N'), findsWidgets);
      expect(find.byKey(const Key('project-title')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('project-title'))).data,
        endsWith(' *'),
      );
      expect(source.layers.single.crs.isWgs84, isTrue);
      expect(source.layers.single.features.single.coordinates.single.x, 106);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(find.textContaining('Source - UTM Zone 48N'), findsNothing);
      expect(
        tester.widget<Text>(find.byKey(const Key('project-title'))).data,
        isNot(endsWith(' *')),
      );
    },
  );

  testWidgets('DXF export cancel is read-only and does not dirty project', (
    tester,
  ) async {
    prepareView(tester);
    var saveCalls = 0;
    Uint8List? receivedBytes;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HomeScreen(
          initialProject: projectWith(
            const CoordinateReferenceSystem.localCad(),
          ),
          saveDxfOverride: (bytes) async {
            saveCalls++;
            receivedBytes = bytes;
            return null;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Xuất sang AutoCAD'));
    await tester.pumpAndSettle();

    expect(saveCalls, 1);
    expect(receivedBytes, isNotNull);
    expect(
      tester.widget<Text>(find.byKey(const Key('project-title'))).data,
      isNot(endsWith(' *')),
    );
    expect(find.text('Source'), findsOneWidget);
  });

  testWidgets(
    'invalid WGS84 export fails before writer and keeps state clean',
    (tester) async {
      prepareView(tester);
      var saveCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomeScreen(
            initialProject: projectWith(
              const CoordinateReferenceSystem.wgs84(),
            ),
            saveDxfOverride: (_) async {
              saveCalls++;
              return Uri.file('ignored.dxf');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Xuất sang AutoCAD'));
      await tester.pump();

      expect(saveCalls, 0);
      expect(
        find.textContaining('không xuất trực tiếp tọa độ WGS84'),
        findsOneWidget,
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('project-title'))).data,
        isNot(endsWith(' *')),
      );
    },
  );
}
