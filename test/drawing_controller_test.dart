import 'package:flutter_test/flutter_test.dart';

import 'package:autocad_googleearth/models/map_feature.dart';
import 'package:autocad_googleearth/services/drawing_controller.dart';

void main() {
  group('DrawingController', () {
    late DrawingController controller;

    setUp(() {
      controller = DrawingController();
    });

    test('starts in idle state', () {
      expect(controller.mode, DrawingMode.none);
      expect(controller.isDrawing, isFalse);
      expect(controller.coordinates, isEmpty);
      expect(controller.hoverCoordinate, isNull);
      expect(controller.canFinish, isFalse);
    });

    test('start activates requested drawing mode', () {
      controller.start(DrawingMode.polyline);

      expect(controller.mode, DrawingMode.polyline);
      expect(controller.isDrawing, isTrue);
      expect(controller.coordinates, isEmpty);
      expect(controller.canFinish, isFalse);
    });

    test('start none leaves controller idle', () {
      controller.start(DrawingMode.none);

      expect(controller.mode, DrawingMode.none);
      expect(controller.isDrawing, isFalse);
      expect(controller.coordinates, isEmpty);
    });

    test('starting another mode clears existing draft and hover', () {
      controller.start(DrawingMode.polyline);
      controller.addCoordinate(const MapCoordinate(x: 10, y: 20));
      controller.updateHoverCoordinate(const MapCoordinate(x: 30, y: 40));

      controller.start(DrawingMode.polygon);

      expect(controller.mode, DrawingMode.polygon);
      expect(controller.coordinates, isEmpty);
      expect(controller.hoverCoordinate, isNull);
      expect(controller.canFinish, isFalse);
    });

    test('addCoordinate does nothing while idle', () {
      controller.addCoordinate(const MapCoordinate(x: 10, y: 20));

      expect(controller.coordinates, isEmpty);
      expect(controller.canFinish, isFalse);
    });

    test('point accepts exactly one coordinate', () {
      const first = MapCoordinate(x: 10, y: 20);
      const second = MapCoordinate(x: 30, y: 40);

      controller.start(DrawingMode.point);
      controller.addCoordinate(first);
      controller.addCoordinate(second);

      expect(controller.coordinates, hasLength(1));
      expect(controller.coordinates.first, same(first));
      expect(controller.canFinish, isTrue);
    });

    test('polyline requires at least two coordinates', () {
      controller.start(DrawingMode.polyline);

      controller.addCoordinate(const MapCoordinate(x: 10, y: 20));
      expect(controller.canFinish, isFalse);

      controller.addCoordinate(const MapCoordinate(x: 30, y: 40));
      expect(controller.canFinish, isTrue);

      controller.addCoordinate(const MapCoordinate(x: 50, y: 60));
      expect(controller.canFinish, isTrue);
    });

    test('polygon requires at least three coordinates', () {
      controller.start(DrawingMode.polygon);

      controller.addCoordinate(const MapCoordinate(x: 0, y: 0));
      controller.addCoordinate(const MapCoordinate(x: 10, y: 0));

      expect(controller.canFinish, isFalse);

      controller.addCoordinate(const MapCoordinate(x: 10, y: 10));

      expect(controller.canFinish, isTrue);
    });

    test('polygon keeps vertices in order without closing duplicate', () {
      const first = MapCoordinate(x: 0, y: 0);
      const second = MapCoordinate(x: 10, y: 0);
      const third = MapCoordinate(x: 10, y: 10);

      controller.start(DrawingMode.polygon);
      controller.addCoordinate(first);
      controller.addCoordinate(second);
      controller.addCoordinate(third);

      final feature = controller.finish(id: 'polygon-1');

      expect(feature, isNotNull);
      expect(feature!.coordinates, hasLength(3));
      expect(feature.coordinates[0], same(first));
      expect(feature.coordinates[1], same(second));
      expect(feature.coordinates[2], same(third));
    });

    test('hover coordinate is preview only and not a vertex', () {
      const vertex = MapCoordinate(x: 10, y: 20);
      const hover = MapCoordinate(x: 30, y: 40);

      controller.start(DrawingMode.polyline);
      controller.addCoordinate(vertex);
      controller.updateHoverCoordinate(hover);

      expect(controller.hoverCoordinate, same(hover));
      expect(controller.coordinates, hasLength(1));
      expect(controller.coordinates.single, same(vertex));
      expect(controller.canFinish, isFalse);
    });

    test('hover is ignored while idle', () {
      controller.updateHoverCoordinate(const MapCoordinate(x: 10, y: 20));

      expect(controller.hoverCoordinate, isNull);
    });

    test('hover can be cleared while drawing', () {
      controller.start(DrawingMode.polygon);
      controller.updateHoverCoordinate(const MapCoordinate(x: 10, y: 20));

      expect(controller.hoverCoordinate, isNotNull);

      controller.updateHoverCoordinate(null);

      expect(controller.hoverCoordinate, isNull);
    });

    test('finish returns null when geometry is incomplete', () {
      controller.start(DrawingMode.polygon);
      controller.addCoordinate(const MapCoordinate(x: 0, y: 0));
      controller.addCoordinate(const MapCoordinate(x: 10, y: 0));

      final feature = controller.finish(id: 'incomplete');

      expect(feature, isNull);

      // Failed finish must preserve the draft so drawing can continue.
      expect(controller.mode, DrawingMode.polygon);
      expect(controller.coordinates, hasLength(2));
      expect(controller.isDrawing, isTrue);
    });

    test('finish creates point feature and resets controller', () {
      const coordinate = MapCoordinate(x: 105.25, y: 20.75, z: 12);

      controller.start(DrawingMode.point);
      controller.addCoordinate(coordinate);

      final feature = controller.finish(
        id: 'point-1',
        name: 'Điểm khảo sát',
        description: 'ຈຸດສຳຫຼວດ Survey point',
        properties: const {'layerName': 'Ranh giới ຂອບເຂດ Boundary'},
      );

      expect(feature, isNotNull);
      expect(feature!.id, 'point-1');
      expect(feature.type, MapFeatureType.point);
      expect(feature.coordinates, hasLength(1));
      expect(feature.coordinates.single, same(coordinate));
      expect(feature.name, 'Điểm khảo sát');
      expect(feature.description, 'ຈຸດສຳຫຼວດ Survey point');
      expect(feature.properties['layerName'], 'Ranh giới ຂອບເຂດ Boundary');

      expect(controller.mode, DrawingMode.none);
      expect(controller.isDrawing, isFalse);
      expect(controller.coordinates, isEmpty);
      expect(controller.hoverCoordinate, isNull);
      expect(controller.canFinish, isFalse);
    });

    test('finish creates polyline feature', () {
      controller.start(DrawingMode.polyline);
      controller.addCoordinate(const MapCoordinate(x: 0, y: 0));
      controller.addCoordinate(const MapCoordinate(x: 10, y: 10));

      final feature = controller.finish(id: 'polyline-1');

      expect(feature, isNotNull);
      expect(feature!.type, MapFeatureType.polyline);
      expect(feature.coordinates, hasLength(2));
    });

    test('finish creates polygon feature', () {
      controller.start(DrawingMode.polygon);
      controller.addCoordinate(const MapCoordinate(x: 0, y: 0));
      controller.addCoordinate(const MapCoordinate(x: 10, y: 0));
      controller.addCoordinate(const MapCoordinate(x: 10, y: 10));

      final feature = controller.finish(id: 'polygon-1', visible: false);

      expect(feature, isNotNull);
      expect(feature!.type, MapFeatureType.polygon);
      expect(feature.coordinates, hasLength(3));
      expect(feature.visible, isFalse);
    });

    test('finish copies properties instead of sharing input map', () {
      final properties = <String, String>{'name': 'Original'};

      controller.start(DrawingMode.point);
      controller.addCoordinate(const MapCoordinate(x: 1, y: 2));

      final feature = controller.finish(id: 'point-1', properties: properties);

      properties['name'] = 'Changed';

      expect(feature, isNotNull);
      expect(feature!.properties['name'], 'Original');
    });

    test('coordinates getter cannot mutate controller state', () {
      controller.start(DrawingMode.polyline);
      controller.addCoordinate(const MapCoordinate(x: 1, y: 2));

      final coordinates = controller.coordinates;

      expect(
        () => coordinates.add(const MapCoordinate(x: 3, y: 4)),
        throwsUnsupportedError,
      );

      expect(controller.coordinates, hasLength(1));
    });

    test('cancel resets complete drawing state', () {
      controller.start(DrawingMode.polygon);
      controller.addCoordinate(const MapCoordinate(x: 0, y: 0));
      controller.updateHoverCoordinate(const MapCoordinate(x: 5, y: 5));

      controller.cancel();

      expect(controller.mode, DrawingMode.none);
      expect(controller.isDrawing, isFalse);
      expect(controller.coordinates, isEmpty);
      expect(controller.hoverCoordinate, isNull);
      expect(controller.canFinish, isFalse);
    });

    test('controller can start a new drawing after finish', () {
      controller.start(DrawingMode.point);
      controller.addCoordinate(const MapCoordinate(x: 1, y: 2));

      expect(controller.finish(id: 'point-1'), isNotNull);

      controller.start(DrawingMode.polyline);

      expect(controller.mode, DrawingMode.polyline);
      expect(controller.isDrawing, isTrue);
      expect(controller.coordinates, isEmpty);
    });
  });
}
