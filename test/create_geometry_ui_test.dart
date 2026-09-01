import 'package:autocad_googleearth/models/map_feature.dart';
import 'package:autocad_googleearth/models/map_feature_change.dart';
import 'package:autocad_googleearth/models/map_layer.dart';
import 'package:autocad_googleearth/models/map_project.dart';
import 'package:autocad_googleearth/screens/home_screen.dart';
import 'package:autocad_googleearth/widgets/map_canvas.dart';
import 'package:autocad_googleearth/l10n/generated/app_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpCanvas(
    WidgetTester tester, {
    MapProject project = const MapProject(id: 'project', name: 'Project'),
    ValueChanged<MapFeature>? onCreated,
    ValueChanged<MapFeatureChange>? onChanged,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1000, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapCanvas(
            project: project,
            onFeatureCreated: onCreated,
            onFeatureChanged: onChanged,
          ),
        ),
      ),
    );
  }

  Offset canvasPosition(WidgetTester tester, double dx, double dy) {
    final box = tester.renderObject<RenderBox>(find.byType(MapCanvas));
    return box.localToGlobal(Offset(dx, dy));
  }

  testWidgets('empty project renders a drawing-capable canvas', (tester) async {
    await pumpCanvas(tester);

    expect(find.byKey(const Key('draw-point')), findsOneWidget);
    expect(find.byKey(const Key('draw-polyline')), findsOneWidget);
    expect(find.byKey(const Key('draw-polygon')), findsOneWidget);
  });

  testWidgets('Point creates exactly one coordinate and auto-finishes', (
    tester,
  ) async {
    final created = <MapFeature>[];
    await pumpCanvas(tester, onCreated: created.add);

    await tester.tap(find.byKey(const Key('draw-point')));
    await tester.tapAt(canvasPosition(tester, 400, 300));
    await tester.pump();

    expect(created, hasLength(1));
    expect(created.single.type, MapFeatureType.point);
    expect(created.single.coordinates, hasLength(1));
  });

  testWidgets('Polyline preserves committed order and ignores hover', (
    tester,
  ) async {
    final created = <MapFeature>[];
    await pumpCanvas(tester, onCreated: created.add);

    await tester.tap(find.byKey(const Key('draw-polyline')));
    await tester.tapAt(canvasPosition(tester, 300, 300));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: canvasPosition(tester, 500, 150));
    await mouse.moveTo(canvasPosition(tester, 500, 150));
    await tester.pump();

    await tester.tapAt(canvasPosition(tester, 600, 300));
    await tester.pump();
    await tester.tap(find.byKey(const Key('draw-finish')));
    await tester.pump();

    expect(created, hasLength(1));
    expect(created.single.type, MapFeatureType.polyline);
    expect(created.single.coordinates, hasLength(2));
    expect(
      created.single.coordinates.first.x,
      lessThan(created.single.coordinates.last.x),
    );
  });

  testWidgets('Polygon finishes without duplicating the first coordinate', (
    tester,
  ) async {
    final created = <MapFeature>[];
    await pumpCanvas(tester, onCreated: created.add);

    await tester.tap(find.byKey(const Key('draw-polygon')));
    await tester.tapAt(canvasPosition(tester, 300, 400));
    await tester.tapAt(canvasPosition(tester, 500, 200));
    await tester.tapAt(canvasPosition(tester, 700, 400));
    await tester.pump();
    await tester.tap(find.byKey(const Key('draw-finish')));
    await tester.pump();

    final polygon = created.single;
    expect(polygon.type, MapFeatureType.polygon);
    expect(polygon.coordinates, hasLength(3));
    final first = polygon.coordinates.first;
    final last = polygon.coordinates.last;
    expect(
      first.x == last.x && first.y == last.y && first.z == last.z,
      isFalse,
    );
  });

  testWidgets('Cancel does not create a feature', (tester) async {
    final created = <MapFeature>[];
    await pumpCanvas(tester, onCreated: created.add);

    await tester.tap(find.byKey(const Key('draw-polyline')));
    await tester.tapAt(canvasPosition(tester, 300, 300));
    await tester.tap(find.byKey(const Key('draw-cancel')));
    await tester.pump();

    expect(created, isEmpty);
  });

  testWidgets('drawing click has priority over existing editing', (
    tester,
  ) async {
    final existing = MapFeature(
      id: 'existing',
      type: MapFeatureType.point,
      coordinates: const [MapCoordinate(x: 0, y: 0)],
    );
    final project = MapProject(
      id: 'project',
      name: 'Project',
      layers: [
        MapLayer(
          id: 'layer',
          name: 'Layer',
          sourceType: MapLayerSourceType.manual,
          features: [existing],
        ),
      ],
    );
    final created = <MapFeature>[];
    final changed = <MapFeatureChange>[];
    await pumpCanvas(
      tester,
      project: project,
      onCreated: created.add,
      onChanged: changed.add,
    );

    await tester.tap(find.byKey(const Key('draw-point')));
    await tester.tapAt(canvasPosition(tester, 500, 350));
    await tester.pump();

    expect(created, hasLength(1));
    expect(changed, isEmpty);
    expect(created.single.coordinates.single.x, 0);
    expect(created.single.coordinates.single.y, 0);
  });

  testWidgets('HomeScreen creates and reuses one manual drawing layer', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HomeScreen(
          initialProject: MapProject(id: 'project', name: 'Project'),
        ),
      ),
    );

    Future<void> drawPoint(Offset localPosition) async {
      await tester.tap(find.byKey(const Key('draw-point')));
      await tester.tapAt(
        canvasPosition(tester, localPosition.dx, localPosition.dy),
      );
      await tester.pump();
    }

    await drawPoint(const Offset(350, 300));
    await drawPoint(const Offset(550, 350));

    final canvas = tester.widget<MapCanvas>(find.byType(MapCanvas));
    final manualLayers = canvas.project.layers
        .where((layer) => layer.sourceType == MapLayerSourceType.manual)
        .toList();
    expect(manualLayers, hasLength(1));
    expect(manualLayers.single.sourcePath, isNull);
    expect(manualLayers.single.features, hasLength(2));
    expect(
      tester.widget<Text>(find.byKey(const Key('project-title'))).data,
      endsWith(' *'),
    );
  });

  testWidgets('HomeScreen does not reuse an unrelated manual layer', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HomeScreen(
          initialProject: MapProject(
            id: 'project',
            name: 'Project',
            layers: [
              MapLayer(
                id: 'existing-manual',
                name: 'Existing Manual Layer',
                sourceType: MapLayerSourceType.manual,
              ),
            ],
          ),
        ),
      ),
    );

    Future<void> drawPoint(Offset localPosition) async {
      await tester.tap(find.byKey(const Key('draw-point')));
      await tester.tapAt(
        canvasPosition(tester, localPosition.dx, localPosition.dy),
      );
      await tester.pump();
    }

    await drawPoint(const Offset(350, 300));
    await drawPoint(const Offset(550, 350));

    final project = tester.widget<MapCanvas>(find.byType(MapCanvas)).project;
    final existingLayer = project.layers.singleWhere(
      (layer) => layer.name == 'Existing Manual Layer',
    );
    final drawingLayers = project.layers
        .where((layer) => layer.name == 'Manual Drawing')
        .toList();

    expect(existingLayer.features, isEmpty);
    expect(drawingLayers, hasLength(1));
    expect(drawingLayers.single.sourceType, MapLayerSourceType.manual);
    expect(drawingLayers.single.sourcePath, isNull);
    expect(drawingLayers.single.features, hasLength(2));
  });

  testWidgets('creation is one undoable and redoable transaction', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HomeScreen(
          initialProject: MapProject(id: 'project', name: 'Project'),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('draw-point')));
    await tester.tapAt(canvasPosition(tester, 450, 350));
    await tester.pump();
    expect(
      tester.widget<MapCanvas>(find.byType(MapCanvas)).project.featureCount,
      1,
    );

    await tester.tap(find.byIcon(Icons.undo));
    await tester.pump();
    expect(
      tester.widget<MapCanvas>(find.byType(MapCanvas)).project.featureCount,
      0,
    );
    expect(
      tester.widget<MapCanvas>(find.byType(MapCanvas)).project.layers,
      isEmpty,
    );

    await tester.tap(find.byIcon(Icons.redo));
    await tester.pump();
    expect(
      tester.widget<MapCanvas>(find.byType(MapCanvas)).project.featureCount,
      1,
    );
  });

  testWidgets('cancelled draft leaves HomeScreen clean', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HomeScreen(
          initialProject: MapProject(id: 'project', name: 'Project'),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('draw-polyline')));
    await tester.tapAt(canvasPosition(tester, 450, 350));
    await tester.tap(find.byKey(const Key('draw-cancel')));
    await tester.pump();

    expect(
      tester.widget<MapCanvas>(find.byType(MapCanvas)).project.layers,
      isEmpty,
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('project-title'))).data,
      isNot(endsWith(' *')),
    );
  });
}
