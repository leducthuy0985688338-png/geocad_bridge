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
    ValueChanged<MapFeatureChange>? onChanged,
    ValueChanged<MapFeature>? onCreated,
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
              onFeatureChanged: onChanged,
              onFeatureCreated: onCreated,
            ),
          ),
        ),
      ),
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

  MapLayer layer({
    required String id,
    required CoordinateReferenceSystem crs,
    required List<MapFeature> features,
  }) {
    return MapLayer(
      id: id,
      name: id,
      sourceType: MapLayerSourceType.manual,
      crs: crs,
      features: features,
    );
  }

  MapFeature point(
    String id,
    MapCoordinate coordinate, {
    String name = '',
    Map<String, String> properties = const {},
  }) {
    return MapFeature(
      id: id,
      name: name,
      type: MapFeatureType.point,
      coordinates: [coordinate],
      properties: properties,
    );
  }

  Future<void> mouseClick(WidgetTester tester, Offset position) async {
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: position);
    await gesture.down(position);
    await gesture.up();
    await gesture.removePointer();
    await tester.pump();
  }

  Future<void> mouseDrag(WidgetTester tester, Offset start, Offset end) async {
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: start);
    await gesture.down(start);
    await gesture.moveTo(end);
    await gesture.up();
    await gesture.removePointer();
    await tester.pump();
  }

  testWidgets('same-CRS local WGS84 and UTM display without value changes', (
    tester,
  ) async {
    for (final crs in [local, wgs84, utm48]) {
      const coordinate = MapCoordinate(x: 105, y: 16, z: 9);
      final source = point('same', coordinate);
      final project = MapProject(
        id: 'project',
        name: 'Project',
        canvasCrs: crs,
        layers: [
          layer(id: 'layer', crs: crs, features: [source]),
        ],
      );

      await pumpCanvas(tester, project);
      final display = displayedFeatures(tester).single;
      expect(display.coordinates.single.x, coordinate.x);
      expect(display.coordinates.single.y, coordinate.y);
      expect(display.coordinates.single.z, coordinate.z);
      expect(display, isNot(same(source)));
      expect(source.coordinates.single, same(coordinate));
    }
  });

  testWidgets('WGS84 UTM and cross-zone display transforms preserve metadata', (
    tester,
  ) async {
    const sourceCoordinate = MapCoordinate(x: 108, y: 16, z: 12);
    final source = point(
      'feature',
      sourceCoordinate,
      name: 'Styled',
      properties: const {'color': '#123456', 'strokeWidth': '3'},
    );

    final pairs = [
      (source: wgs84, canvas: utm48, coordinate: sourceCoordinate),
      (
        source: utm48,
        canvas: wgs84,
        coordinate: service
            .toCanvas(
              coordinate: sourceCoordinate,
              sourceCrs: wgs84,
              canvasCrs: utm48,
            )
            .coordinate!,
      ),
      (
        source: utm48,
        canvas: utm49,
        coordinate: service
            .toCanvas(
              coordinate: sourceCoordinate,
              sourceCrs: wgs84,
              canvasCrs: utm48,
            )
            .coordinate!,
      ),
    ];
    for (var pairIndex = 0; pairIndex < pairs.length; pairIndex++) {
      final pair = pairs[pairIndex];
      final transformResult = service.toCanvas(
        coordinate: pair.coordinate,
        sourceCrs: pair.source,
        canvasCrs: pair.canvas,
      );
      expect(transformResult.isSuccess, isTrue, reason: 'pair $pairIndex');
      final current = source.copyWith(coordinates: [pair.coordinate]);
      final project = MapProject(
        id: 'project',
        name: 'Project',
        canvasCrs: pair.canvas,
        layers: [
          layer(id: 'source', crs: pair.source, features: [current]),
        ],
      );
      await pumpCanvas(tester, project);

      final features = displayedFeatures(tester);
      expect(features, hasLength(1), reason: 'pair $pairIndex');
      final display = features.single;
      final expected = transformResult.coordinate!;
      expect(display.coordinates.single.x, closeTo(expected.x, 1e-6));
      expect(display.coordinates.single.y, closeTo(expected.y, 1e-6));
      expect(display.coordinates.single.z, expected.z);
      expect(display.id, current.id);
      expect(display.name, current.name);
      expect(display.properties, same(current.properties));

      final restored = service
          .fromCanvas(
            coordinate: display.coordinates.single,
            canvasCrs: pair.canvas,
            targetCrs: pair.source,
          )
          .coordinate!;
      expect(restored.x, closeTo(pair.coordinate.x, 1e-3));
      expect(restored.y, closeTo(pair.coordinate.y, 1e-3));
      expect(restored.z, pair.coordinate.z);
    }
  });

  testWidgets('incompatible features are excluded and do not mutate source', (
    tester,
  ) async {
    for (final pair in [
      (canvas: local, source: wgs84),
      (canvas: wgs84, source: local),
    ]) {
      final incompatible = point(
        'incompatible',
        const MapCoordinate(x: 999999999, y: -999999999, z: 5),
      );
      final compatible = point('compatible', const MapCoordinate(x: 0, y: 0));
      final project = MapProject(
        id: 'project',
        name: 'Project',
        canvasCrs: pair.canvas,
        layers: [
          layer(
            id: 'compatible-layer',
            crs: pair.canvas,
            features: [compatible],
          ),
          layer(
            id: 'incompatible-layer',
            crs: pair.source,
            features: [incompatible],
          ),
        ],
      );
      final changed = <MapFeatureChange>[];
      await pumpCanvas(tester, project, onChanged: changed.add);

      expect(displayedFeatures(tester), [isA<MapFeature>()]);
      expect(displayedFeatures(tester).single.id, 'compatible');
      expect(incompatible.coordinates.single.x, 999999999);
      expect(project.layers.last.features.single, same(incompatible));
      expect(changed, isEmpty);
    }
  });

  testWidgets('transformed duplicate IDs select deterministic source layer', (
    tester,
  ) async {
    final left = point(
      'duplicate',
      const MapCoordinate(x: 105, y: 20),
      name: 'Left',
    );
    final right = point(
      'duplicate',
      const MapCoordinate(x: 106, y: 20),
      name: 'Right',
    );
    final project = MapProject(
      id: 'project',
      name: 'Project',
      canvasCrs: utm48,
      layers: [
        layer(id: 'left-layer', crs: wgs84, features: [left]),
        layer(id: 'right-layer', crs: wgs84, features: [right]),
      ],
    );
    await pumpCanvas(tester, project);

    await mouseClick(tester, const Offset(960, 350));
    expect(find.text('Right'), findsOneWidget);
    expect(find.text('Left'), findsNothing);
  });

  testWidgets('move inverse-commits every final coordinate in source CRS', (
    tester,
  ) async {
    final source = MapFeature(
      id: 'line',
      name: 'Line',
      type: MapFeatureType.line,
      coordinates: const [
        MapCoordinate(x: 104, y: 10, z: 11),
        MapCoordinate(x: 108, y: 30, z: 22),
      ],
    );
    final project = MapProject(
      id: 'project',
      name: 'Project',
      canvasCrs: utm48,
      layers: [
        layer(id: 'wgs', crs: wgs84, features: [source]),
      ],
    );
    final changes = <MapFeatureChange>[];
    await pumpCanvas(tester, project, onChanged: changes.add);

    await mouseClick(tester, const Offset(500, 350));
    await mouseDrag(tester, const Offset(500, 350), const Offset(550, 350));

    expect(changes, hasLength(1));
    final change = changes.single;
    expect(change.originalFeature, same(source));
    expect(change.updatedFeature.coordinates, hasLength(2));
    expect(change.updatedFeature.coordinates[0].z, 11);
    expect(change.updatedFeature.coordinates[1].z, 22);
    expect(
      change.updatedFeature.coordinates[0].x,
      isNot(source.coordinates[0].x),
    );
    expect(
      change.updatedFeature.coordinates[1].x,
      isNot(source.coordinates[1].x),
    );

    final before = source.coordinates
        .map(
          (coordinate) => service
              .toCanvas(
                coordinate: coordinate,
                sourceCrs: wgs84,
                canvasCrs: utm48,
              )
              .coordinate!,
        )
        .toList();
    final after = change.updatedFeature.coordinates
        .map(
          (coordinate) => service
              .toCanvas(
                coordinate: coordinate,
                sourceCrs: wgs84,
                canvasCrs: utm48,
              )
              .coordinate!,
        )
        .toList();
    expect(after[0].x - before[0].x, closeTo(after[1].x - before[1].x, 0.02));
    expect(after[0].y - before[0].y, closeTo(after[1].y - before[1].y, 0.02));
  });

  testWidgets('vertex drag inverse-commits exact index and preserves Z', (
    tester,
  ) async {
    final source = MapFeature(
      id: 'line',
      name: 'Line',
      type: MapFeatureType.line,
      coordinates: const [
        MapCoordinate(x: 105, y: 20, z: 31),
        MapCoordinate(x: 106, y: 20, z: 42),
      ],
    );
    final project = MapProject(
      id: 'project',
      name: 'Project',
      canvasCrs: utm48,
      layers: [
        layer(id: 'wgs', crs: wgs84, features: [source]),
      ],
    );
    final changes = <MapFeatureChange>[];
    await pumpCanvas(tester, project, onChanged: changes.add);

    await mouseClick(tester, const Offset(500, 350));
    await mouseDrag(tester, const Offset(40, 350), const Offset(90, 300));

    expect(changes, hasLength(1));
    final updated = changes.single.updatedFeature;
    expect(changes.single.originalFeature, same(source));
    expect(updated.coordinates[0].x, isNot(source.coordinates[0].x));
    expect(updated.coordinates[0].z, 31);
    expect(updated.coordinates[1], same(source.coordinates[1]));
    expect(updated.coordinates[1].z, 42);
  });

  testWidgets('add delete and coordinate editor commit source semantics', (
    tester,
  ) async {
    final source = MapFeature(
      id: 'polyline',
      name: 'Polyline',
      type: MapFeatureType.polyline,
      coordinates: const [
        MapCoordinate(x: 105, y: 20, z: 7),
        MapCoordinate(x: 106, y: 20, z: 8),
        MapCoordinate(x: 107, y: 20, z: 9),
      ],
    );
    final project = MapProject(
      id: 'project',
      name: 'Project',
      canvasCrs: utm48,
      layers: [
        layer(id: 'wgs', crs: wgs84, features: [source]),
      ],
    );
    final changes = <MapFeatureChange>[];
    await pumpCanvas(tester, project, onChanged: changes.add);
    await mouseClick(tester, const Offset(500, 350));

    await tester.tap(find.byIcon(Icons.add_location_alt_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Thêm đỉnh'));
    await tester.pumpAndSettle();
    expect(changes.single.originalFeature, same(source));
    expect(changes.single.updatedFeature.coordinates, hasLength(4));
    final inserted = changes.single.updatedFeature.coordinates[1];
    expect(inserted.x, inInclusiveRange(104.0, 107.0));
    expect(inserted.y, inInclusiveRange(19.0, 21.0));
    expect(inserted.z, closeTo(7.5, 1e-9));

    changes.clear();
    await tester.tap(find.byIcon(Icons.remove_circle_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Xóa đỉnh'));
    await tester.pumpAndSettle();
    expect(changes.single.originalFeature, same(source));
    expect(
      changes.single.updatedFeature.coordinates,
      source.coordinates.sublist(1),
    );

    changes.clear();
    await tester.tap(find.byIcon(Icons.pin_drop_outlined));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '105.0000'), findsOneWidget);
    expect(find.widgetWithText(TextField, '20.0000'), findsOneWidget);
  });

  testWidgets('add vertex applies display-segment Z interpolation policy', (
    tester,
  ) async {
    final cases =
        <({double? startZ, double? endZ, double? expectedZ, bool zero})>[
          (startZ: 10, endZ: 20, expectedZ: 15, zero: false),
          (startZ: 10, endZ: null, expectedZ: 10, zero: false),
          (startZ: null, endZ: 20, expectedZ: 20, zero: false),
          (startZ: null, endZ: null, expectedZ: null, zero: false),
          (startZ: 10, endZ: 20, expectedZ: 10, zero: true),
        ];

    for (final testCase in cases) {
      final endX = testCase.zero ? 0.0 : 10.0;
      final source = MapFeature(
        id: 'z-polyline',
        type: MapFeatureType.polyline,
        coordinates: [
          MapCoordinate(x: 0, y: 0, z: testCase.startZ),
          MapCoordinate(x: endX, y: 0, z: testCase.endZ),
          const MapCoordinate(x: 20, y: 0, z: 30),
        ],
      );
      final project = MapProject(
        id: 'project',
        name: 'Project',
        layers: [
          layer(id: 'local', crs: local, features: [source]),
        ],
      );
      final changes = <MapFeatureChange>[];
      await pumpCanvas(tester, project, onChanged: changes.add);
      await mouseClick(
        tester,
        testCase.zero ? const Offset(40, 350) : const Offset(270, 350),
      );

      await tester.tap(find.byIcon(Icons.add_location_alt_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Thêm đỉnh'));
      await tester.pumpAndSettle();

      expect(changes, hasLength(1));
      final insertedZ = changes.single.updatedFeature.coordinates[1].z;
      if (testCase.expectedZ == null) {
        expect(insertedZ, isNull);
      } else {
        expect(insertedZ!.isFinite, isTrue);
        expect(insertedZ, closeTo(testCase.expectedZ!, 1e-9));
      }
    }
  });

  testWidgets('drawing remains canvas-space identity and render is transient', (
    tester,
  ) async {
    final source = point('source', const MapCoordinate(x: 105, y: 20, z: 3));
    final project = MapProject(
      id: 'project',
      name: 'Project',
      canvasCrs: utm48,
      layers: [
        layer(id: 'wgs', crs: wgs84, features: [source]),
      ],
    );
    final created = <MapFeature>[];
    final changed = <MapFeatureChange>[];
    await pumpCanvas(
      tester,
      project,
      onCreated: created.add,
      onChanged: changed.add,
    );

    expect(changed, isEmpty);
    expect(project.layers.single.features.single, same(source));
    await tester.tap(find.byKey(const Key('draw-point')));
    await tester.tapAt(const Offset(600, 400));
    await tester.pump();

    expect(created, hasLength(1));
    expect(created.single.coordinates.single.x.abs(), greaterThan(1000));
    expect(changed, isEmpty);
    expect(project.layers.single.features.single, same(source));
  });
}
