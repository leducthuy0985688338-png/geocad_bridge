import 'dart:math' as math;

import 'package:autocad_googleearth/models/coordinate_reference_system.dart';
import 'package:autocad_googleearth/models/map_feature.dart';
import 'package:autocad_googleearth/models/map_feature_change.dart';
import 'package:autocad_googleearth/models/map_layer.dart';
import 'package:autocad_googleearth/models/map_project.dart';
import 'package:autocad_googleearth/services/canvas_coordinate_service.dart';
import 'package:autocad_googleearth/widgets/map_canvas.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const service = CanvasCoordinateService();
  const local = CoordinateReferenceSystem.localCad();
  const wgs84 = CoordinateReferenceSystem.wgs84();
  const utm48 = CoordinateReferenceSystem.utm(
    utmZone: 48,
    hemisphere: UtmHemisphere.north,
  );
  const utm49 = CoordinateReferenceSystem.utm(
    utmZone: 49,
    hemisphere: UtmHemisphere.north,
  );

  Future<void> pumpCanvas(
    WidgetTester tester,
    MapProject project, {
    ValueChanged<MapFeature>? onCreated,
    ValueChanged<MapFeatureChange>? onChanged,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1000, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(0.8)),
            child: MapCanvas(
              project: project,
              onFeatureCreated: onCreated,
              onFeatureChanged: onChanged,
            ),
          ),
        ),
      ),
    );
  }

  MapFeature point(String id, MapCoordinate coordinate, {String name = ''}) {
    return MapFeature(
      id: id,
      name: name,
      type: MapFeatureType.point,
      coordinates: [coordinate],
    );
  }

  MapLayer layer({
    required String id,
    required CoordinateReferenceSystem crs,
    required List<MapFeature> features,
    bool visible = true,
    bool locked = false,
  }) {
    return MapLayer(
      id: id,
      name: id,
      sourceType: MapLayerSourceType.manual,
      crs: crs,
      features: features,
      visible: visible,
      locked: locked,
    );
  }

  List<MapFeature> displayedFeatures(WidgetTester tester) {
    final paint = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .singleWhere(
          (widget) =>
              widget.painter.runtimeType.toString() == '_MapProjectPainter',
        );
    final dynamic painter = paint.painter;
    return List<MapFeature>.from(painter.features as List);
  }

  Offset screenFor(
    WidgetTester tester,
    List<MapFeature> features,
    MapCoordinate coordinate,
  ) {
    final coordinates = features.expand((feature) => feature.coordinates);
    final minX = coordinates.map((item) => item.x).reduce(math.min);
    final maxX = coordinates.map((item) => item.x).reduce(math.max);
    final minY = coordinates.map((item) => item.y).reduce(math.min);
    final maxY = coordinates.map((item) => item.y).reduce(math.max);
    final scale = math.min(
      920 / math.max(maxX - minX, 0.000001),
      620 / math.max(maxY - minY, 0.000001),
    );
    final offsetX = (1000 - (maxX - minX) * scale) / 2;
    final offsetY = (700 - (maxY - minY) * scale) / 2;
    final local = Offset(
      offsetX + (coordinate.x - minX) * scale,
      700 - offsetY - (coordinate.y - minY) * scale,
    );
    final box = tester.renderObject<RenderBox>(find.byType(MapCanvas));
    return box.localToGlobal(local);
  }

  Future<void> mouseClick(WidgetTester tester, Offset position) async {
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: position);
    await gesture.down(position);
    await gesture.up();
    await gesture.removePointer();
    await tester.pump();
  }

  Future<MapFeature> drawPointNearCenter(
    WidgetTester tester,
    MapProject project,
  ) async {
    final created = <MapFeature>[];
    await pumpCanvas(tester, project, onCreated: created.add);
    await tester.tap(find.byKey(const Key('draw-point')));
    await tester.tapAt(const Offset(506, 350));
    await tester.pump();
    return created.single;
  }

  testWidgets('drawing snaps to visible and locked compatible layer', (
    tester,
  ) async {
    for (final locked in [false, true]) {
      const target = MapCoordinate(x: 25, y: 30, z: 40);
      final created = await drawPointNearCenter(
        tester,
        MapProject(
          id: 'project',
          name: 'Project',
          layers: [
            layer(
              id: locked ? 'locked' : 'visible',
              crs: local,
              features: [point('target', target)],
              locked: locked,
            ),
          ],
        ),
      );
      expect(created.coordinates.single.x, target.x);
      expect(created.coordinates.single.y, target.y);
      expect(created.coordinates.single.z, target.z);
    }
  });

  testWidgets('drawing snaps to transformed WGS84 and cross-zone geometry', (
    tester,
  ) async {
    const geographic = MapCoordinate(x: 108, y: 16, z: 12);
    final zone48 = service
        .toCanvas(coordinate: geographic, sourceCrs: wgs84, canvasCrs: utm48)
        .coordinate!;

    for (final testCase in [
      (sourceCrs: wgs84, canvasCrs: utm48, source: geographic),
      (sourceCrs: utm48, canvasCrs: utm49, source: zone48),
      (sourceCrs: utm48, canvasCrs: wgs84, source: zone48),
    ]) {
      final expected = service
          .toCanvas(
            coordinate: testCase.source,
            sourceCrs: testCase.sourceCrs,
            canvasCrs: testCase.canvasCrs,
          )
          .coordinate!;
      final created = await drawPointNearCenter(
        tester,
        MapProject(
          id: 'project',
          name: 'Project',
          canvasCrs: testCase.canvasCrs,
          layers: [
            layer(
              id: 'transformed',
              crs: testCase.sourceCrs,
              features: [point('target', testCase.source)],
            ),
          ],
        ),
      );
      expect(created.coordinates.single.x, closeTo(expected.x, 1e-6));
      expect(created.coordinates.single.y, closeTo(expected.y, 1e-6));
      expect(created.coordinates.single.z, expected.z);
    }
  });

  testWidgets('hidden and incompatible geometry are not drawing snap targets', (
    tester,
  ) async {
    const target = MapCoordinate(x: 25, y: 30, z: 40);
    final cases = [
      MapProject(
        id: 'hidden-layer',
        name: 'Project',
        layers: [
          layer(
            id: 'hidden',
            crs: local,
            features: [point('target', target)],
            visible: false,
          ),
        ],
      ),
      MapProject(
        id: 'hidden-feature',
        name: 'Project',
        layers: [
          layer(
            id: 'layer',
            crs: local,
            features: [point('target', target).copyWith(visible: false)],
          ),
        ],
      ),
      MapProject(
        id: 'incompatible',
        name: 'Project',
        layers: [
          layer(id: 'wgs', crs: wgs84, features: [point('target', target)]),
        ],
      ),
    ];

    for (final project in cases) {
      final created = await drawPointNearCenter(tester, project);
      expect(created.coordinates.single.x, isNot(target.x));
      expect(created.coordinates.single.y, isNot(target.y));
      expect(created.coordinates.single.z, isNull);
    }
  });

  testWidgets('closer other-layer vertex does not block vertex edit start', (
    tester,
  ) async {
    final active = MapFeature(
      id: 'active',
      name: 'Active',
      type: MapFeatureType.line,
      coordinates: const [
        MapCoordinate(x: -10, y: 0, z: 7),
        MapCoordinate(x: 10, y: 0, z: 8),
      ],
    );
    final blocker = point('blocker', const MapCoordinate(x: -9.9, y: 0));
    final project = MapProject(
      id: 'project',
      name: 'Project',
      layers: [
        layer(id: 'active-layer', crs: local, features: [active]),
        layer(id: 'other-layer', crs: local, features: [blocker]),
      ],
    );
    final changes = <MapFeatureChange>[];
    await pumpCanvas(tester, project, onChanged: changes.add);
    final display = displayedFeatures(tester);
    await mouseClick(
      tester,
      screenFor(tester, display, const MapCoordinate(x: 0, y: 0)),
    );

    final start = screenFor(
      tester,
      display,
      const MapCoordinate(x: -9.9, y: 0),
    );
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: start);
    await gesture.down(start);
    await gesture.moveTo(start + const Offset(0, -40));
    await gesture.up();
    await gesture.removePointer();
    await tester.pump();

    expect(changes, hasLength(1));
    expect(changes.single.originalFeature, same(active));
    expect(changes.single.updatedFeature.coordinates[0].y, isNot(0));
    expect(
      changes.single.updatedFeature.coordinates[1],
      same(active.coordinates[1]),
    );
  });

  testWidgets(
    'vertex drag snaps cross-layer with duplicate IDs and preserves source Z',
    (tester) async {
      final active = MapFeature(
        id: 'duplicate',
        name: 'Active',
        type: MapFeatureType.line,
        coordinates: const [
          MapCoordinate(x: 0, y: 0, z: 7),
          MapCoordinate(x: 10, y: 0, z: 8),
        ],
      );
      final target = MapFeature(
        id: 'duplicate',
        name: 'Target',
        type: MapFeatureType.line,
        coordinates: const [
          MapCoordinate(x: 5, y: 10, z: 999),
          MapCoordinate(x: 5, y: 20, z: 1000),
        ],
      );
      final project = MapProject(
        id: 'project',
        name: 'Project',
        layers: [
          layer(id: 'active-layer', crs: local, features: [active]),
          layer(id: 'target-layer', crs: local, features: [target]),
        ],
      );
      final changes = <MapFeatureChange>[];
      await pumpCanvas(tester, project, onChanged: changes.add);
      final display = displayedFeatures(tester);
      await mouseClick(
        tester,
        screenFor(tester, display, const MapCoordinate(x: 5, y: 0)),
      );

      final start = screenFor(tester, display, const MapCoordinate(x: 0, y: 0));
      final targetScreen = screenFor(
        tester,
        display,
        const MapCoordinate(x: 5, y: 10),
      );
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: start);
      await gesture.down(start);
      await gesture.moveTo(targetScreen + const Offset(5, 3));
      await tester.pump();

      expect(active.coordinates[0].x, 0);
      expect(active.coordinates[0].y, 0);
      expect(changes, isEmpty);

      await gesture.up();
      await gesture.removePointer();
      await tester.pump();

      expect(changes, hasLength(1));
      final change = changes.single;
      expect(change.originalFeature, same(active));
      expect(change.originalFeature, isNot(same(target)));
      expect(change.updatedFeature.coordinates[0].x, 5);
      expect(change.updatedFeature.coordinates[0].y, 10);
      expect(change.updatedFeature.coordinates[0].z, 7);
      expect(change.updatedFeature.coordinates[1], same(active.coordinates[1]));
    },
  );

  testWidgets('vertex drag excludes every vertex of active feature', (
    tester,
  ) async {
    final active = MapFeature(
      id: 'active',
      name: 'Active',
      type: MapFeatureType.line,
      coordinates: const [
        MapCoordinate(x: 0, y: 0, z: 1),
        MapCoordinate(x: 10, y: 0, z: 2),
      ],
    );
    final project = MapProject(
      id: 'project',
      name: 'Project',
      layers: [
        layer(id: 'active-layer', crs: local, features: [active]),
      ],
    );
    final changes = <MapFeatureChange>[];
    await pumpCanvas(tester, project, onChanged: changes.add);
    final display = displayedFeatures(tester);
    await mouseClick(
      tester,
      screenFor(tester, display, const MapCoordinate(x: 5, y: 0)),
    );

    final start = screenFor(tester, display, const MapCoordinate(x: 0, y: 0));
    final end = screenFor(tester, display, const MapCoordinate(x: 10, y: 0));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: start);
    await gesture.down(start);
    await gesture.moveTo(end + const Offset(5, 0));
    await gesture.up();
    await gesture.removePointer();
    await tester.pump();

    expect(changes, hasLength(1));
    expect(changes.single.updatedFeature.coordinates[0].x, isNot(10));
    expect(changes.single.updatedFeature.coordinates[0].z, 1);
  });
}
