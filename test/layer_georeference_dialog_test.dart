import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autocad_googleearth/models/map_feature.dart';
import 'package:autocad_googleearth/models/map_layer.dart';
import 'package:autocad_googleearth/widgets/layer_georeference_dialog.dart';

void main() {
  const layer = MapLayer(
    id: 'local-layer',
    name: 'Survey.dxf',
    sourceType: MapLayerSourceType.dxf,
    features: [
      MapFeature(
        id: 'line',
        type: MapFeatureType.line,
        coordinates: [MapCoordinate(x: 0, y: 0), MapCoordinate(x: 10, y: 0)],
      ),
    ],
  );

  Future<void> openDialog(
    WidgetTester tester,
    ValueChanged<LayerGeoreferenceRequest?> onResult,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  key: const Key('open-dialog'),
                  onPressed: () async {
                    final result = await showDialog<LayerGeoreferenceRequest>(
                      context: context,
                      builder: (_) =>
                          const LayerGeoreferenceDialog(layer: layer),
                    );
                    onResult(result);
                  },
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open-dialog')));
    await tester.pumpAndSettle();
  }

  Future<void> enterTwoPointTargets(WidgetTester tester) async {
    await tester.enterText(find.byKey(const Key('target-x-0')), '500000');
    await tester.enterText(find.byKey(const Key('target-y-0')), '1800000');
    await tester.enterText(find.byKey(const Key('target-x-1')), '500010');
    await tester.enterText(find.byKey(const Key('target-y-1')), '1800000');
  }

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('starts with two points and supports add/remove', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await openDialog(tester, (_) {});

    expect(find.byKey(const Key('control-point-0')), findsOneWidget);
    expect(find.byKey(const Key('control-point-1')), findsOneWidget);
    expect(find.byKey(const Key('control-point-2')), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);

    final addButton = find.byKey(const Key('add-control-point'));
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('control-point-2')), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsNWidgets(3));

    final removeButton = find.byKey(const Key('remove-control-point-2'));
    await tester.ensureVisible(removeButton);
    await tester.tap(removeButton);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('control-point-2')), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets(
    'shows residual metrics and invalidates preview on input change',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await openDialog(tester, (_) {});
      await enterTwoPointTargets(tester);

      final previewButton = find.byKey(
        const Key('calculate-georeference-preview'),
      );
      await tester.ensureVisible(previewButton);
      await tester.tap(previewButton);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('georeference-fit-summary')), findsOneWidget);
      expect(find.byKey(const Key('residual-0')), findsOneWidget);
      expect(find.byKey(const Key('residual-1')), findsOneWidget);
      expect(find.textContaining('RMSE:'), findsOneWidget);
      expect(find.textContaining('Sai số lớn nhất:'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('target-x-0')), '500001');
      await tester.pump();

      expect(find.byKey(const Key('georeference-fit-summary')), findsNothing);
      expect(find.byKey(const Key('residual-0')), findsNothing);
    },
  );

  testWidgets('apply returns all control points with legacy getters', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    LayerGeoreferenceRequest? captured;

    await openDialog(tester, (result) => captured = result);
    await enterTwoPointTargets(tester);

    final addButton = find.byKey(const Key('add-control-point'));
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('local-x-2')), '0');
    await tester.enterText(find.byKey(const Key('local-y-2')), '10');
    await tester.enterText(find.byKey(const Key('target-x-2')), '500000');
    await tester.enterText(find.byKey(const Key('target-y-2')), '1800010');

    final applyButton = find.byKey(const Key('apply-georeference'));
    await tester.ensureVisible(applyButton);
    await tester.tap(applyButton);
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.controlPoints, hasLength(3));
    expect(captured!.point1, same(captured!.controlPoints[0]));
    expect(captured!.point2, same(captured!.controlPoints[1]));
    expect(captured!.targetCrs.epsgCode, 32648);
  });
}
