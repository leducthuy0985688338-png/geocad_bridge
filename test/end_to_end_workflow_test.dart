import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autocad_googleearth/models/cad_document.dart';
import 'package:autocad_googleearth/models/coordinate_reference_system.dart';
import 'package:autocad_googleearth/models/map_feature.dart';
import 'package:autocad_googleearth/models/map_layer.dart';
import 'package:autocad_googleearth/models/map_project.dart';
import 'package:autocad_googleearth/screens/home_screen.dart';
import 'package:autocad_googleearth/services/dxf_export_service.dart';
import 'package:autocad_googleearth/services/dxf_parser_service.dart';
import 'package:autocad_googleearth/services/kml_export_service.dart';
import 'package:autocad_googleearth/services/kml_parser_service.dart';
import 'package:autocad_googleearth/services/layer_georeference_service.dart';
import 'package:autocad_googleearth/services/layer_reprojection_service.dart';
import 'package:autocad_googleearth/services/project_persistence_service.dart';

void main() {
  const utm48North = CoordinateReferenceSystem.utm(
    utmZone: 48,
    hemisphere: UtmHemisphere.north,
  );

  Future<void> pumpCadImportHome(
    WidgetTester tester,
    String path, {
    String fileName = 'fixture.dxf',
  }) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          initialProject: const MapProject(id: 'import', name: 'Import test'),
          cadDocumentsSelectorOverride: () async => [
            CadDocument(name: fileName, path: path, fileType: CadFileType.dxf),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  String projectTitle(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('project-title'))).data!;

  Future<void> tapCadImport(WidgetTester tester) async {
    await tester.tap(find.text('Thêm bản vẽ AutoCAD'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    for (var attempt = 0; attempt < 50; attempt++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.text('Kết quả nhập DXF').evaluate().isNotEmpty ||
          find.text('Kết quả nhập bản vẽ').evaluate().isNotEmpty) {
        return;
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
    throw TestFailure('DXF import did not present a result dialog.');
  }

  Future<String> writeWidgetDxf(
    WidgetTester tester,
    String fileName,
    String content,
  ) async {
    final fixture = (await tester.runAsync(() async {
      final directory = await Directory.systemTemp.createTemp('geocad-e2e-');
      final path = '${directory.path}${Platform.pathSeparator}$fileName';
      await File(path).writeAsString(content);
      return (directory: directory, path: path);
    }))!;
    addTearDown(() => fixture.directory.delete(recursive: true));
    return fixture.path;
  }

  test(
    'DXF local CAD -> georeference -> WGS84 -> KML preserves semantics',
    () async {
      final directory = await Directory.systemTemp.createTemp('geocad-e2e-');
      addTearDown(() => directory.delete(recursive: true));
      final dxfPath = '${directory.path}${Platform.pathSeparator}source.dxf';
      await File(dxfPath).writeAsString('''0
SECTION
2
ENTITIES
0
LINE
8
SURVEY
10
0
20
0
30
12
11
100
21
0
31
12
0
ENDSEC
0
EOF
''');

      final parsed = await const DxfParserService().parseFile(dxfPath);
      final source = MapLayer(
        id: 'cad',
        name: 'CAD survey',
        sourceType: MapLayerSourceType.dxf,
        sourcePath: dxfPath,
        features: parsed.features,
        properties: const {'owner': 'survey-team'},
      );
      final sourceCoordinates = source.features.single.coordinates;
      final sourceProperties = Map<String, String>.from(source.properties);

      final georeferenced = const LayerGeoreferenceService().georeferenceLayer(
        sourceLayer: source,
        point1: const GeoreferenceControlPoint(
          local: MapCoordinate(x: 0, y: 0),
          target: MapCoordinate(x: 500000, y: 1800000),
        ),
        point2: const GeoreferenceControlPoint(
          local: MapCoordinate(x: 100, y: 0),
          target: MapCoordinate(x: 500100, y: 1800000),
        ),
        targetCrs: utm48North,
      );
      final wgs84 = const LayerReprojectionService().reprojectLayer(
        sourceLayer: georeferenced.layer,
        targetCrs: const CoordinateReferenceSystem.wgs84(),
      );
      final kml = const KmlExportService().exportLayers(
        documentName: 'DXF workflow',
        layers: [wgs84.layer],
      );

      expect(parsed.features, hasLength(1));
      expect(parsed.features.single.type, MapFeatureType.line);
      expect(parsed.features.single.properties['cadLayer'], 'SURVEY');
      expect(georeferenced.layer.crs.isUtm, isTrue);
      expect(wgs84.layer.crs.isWgs84, isTrue);
      expect(wgs84.layer.features.single.properties['cadLayer'], 'SURVEY');
      expect(
        wgs84.layer.features.single.coordinates.every((c) => c.z == 12),
        isTrue,
      );
      expect(kml, contains('<kml xmlns="http://www.opengis.net/kml/2.2">'));
      expect(kml, contains('<LineString>'));
      expect(source.crs.isLocalCad, isTrue);
      expect(source.properties, sourceProperties);
      expect(source.features.single.coordinates, same(sourceCoordinates));
      expect(sourceCoordinates.first.x, 0);
    },
  );

  test(
    'KML -> WGS84 -> UTM -> DXF -> DXF import round-trips geometry',
    () async {
      const kml = '''
<kml><Placemark><name>Route</name><LineString><coordinates>
105.0,16.0 105.001,16.001 105.002,16.002
</coordinates></LineString></Placemark></kml>
''';
      final parsedKml = const KmlParserService().parseString(kml);
      final wgsSource = MapLayer(
        id: 'kml',
        name: 'GOOGLE_ROUTE',
        sourceType: MapLayerSourceType.kml,
        crs: const CoordinateReferenceSystem.wgs84(),
        features: parsedKml.features,
      );
      final original = wgsSource.features.single.coordinates
          .map((c) => MapCoordinate(x: c.x, y: c.y, z: c.z))
          .toList();
      final utm = const LayerReprojectionService().reprojectLayer(
        sourceLayer: wgsSource,
        targetCrs: utm48North,
      );
      final exported = const DxfExportService().serialize(
        documentName: 'KML round trip',
        layers: [utm.layer],
      );
      final directory = await Directory.systemTemp.createTemp('geocad-e2e-');
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}${Platform.pathSeparator}roundtrip.dxf';
      await File(path).writeAsBytes(exported.bytes);
      final parsedDxf = await const DxfParserService().parseFile(path);

      expect(exported.exportedCrs.epsgCode, 32648);
      expect(parsedDxf.features, hasLength(1));
      expect(parsedDxf.features.single.type, MapFeatureType.polyline);
      expect(
        parsedDxf.features.single.properties['cadLayer'],
        'GOOGLE_ROUTE (UTM Zone 48N)',
      );
      expect(parsedDxf.features.single.coordinates, hasLength(3));
      for (var i = 0; i < 3; i++) {
        expect(
          parsedDxf.features.single.coordinates[i].x,
          closeTo(utm.layer.features.single.coordinates[i].x, 1e-6),
        );
        expect(
          parsedDxf.features.single.coordinates[i].y,
          closeTo(utm.layer.features.single.coordinates[i].y, 1e-6),
        );
        expect(wgsSource.features.single.coordinates[i].x, original[i].x);
        expect(wgsSource.features.single.coordinates[i].y, original[i].y);
      }
      expect(wgsSource.crs.isWgs84, isTrue);
    },
  );

  test(
    'workflow project save/load preserves CRS geometry and metadata',
    () async {
      const source = MapLayer(
        id: 'cad',
        name: 'CAD',
        sourceType: MapLayerSourceType.dxf,
        visible: false,
        locked: true,
        properties: {'owner': 'team'},
        features: [
          MapFeature(
            id: 'point',
            type: MapFeatureType.point,
            coordinates: [MapCoordinate(x: 5, y: 6, z: 7)],
            properties: {'cadLayer': 'CONTROL'},
          ),
        ],
      );
      final layer = const LayerGeoreferenceService()
          .georeferenceLayer(
            sourceLayer: source,
            point1: const GeoreferenceControlPoint(
              local: MapCoordinate(x: 0, y: 0),
              target: MapCoordinate(x: 500000, y: 1800000),
            ),
            point2: const GeoreferenceControlPoint(
              local: MapCoordinate(x: 10, y: 0),
              target: MapCoordinate(x: 500010, y: 1800000),
            ),
            targetCrs: utm48North,
          )
          .layer;
      final project = MapProject(
        id: 'workflow',
        name: 'Workflow',
        properties: const {'client': 'A'},
        layers: [layer],
      );
      final document = GeoCadProjectDocument(
        project: project,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 2),
      );
      final directory = await Directory.systemTemp.createTemp('geocad-e2e-');
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}${Platform.pathSeparator}workflow.geocad';
      const persistence = ProjectPersistenceService();

      await persistence.save(path, document);
      final restored = await persistence.load(path);
      final restoredLayer = restored.project.layers.single;

      expect(restored.project.id, project.id);
      expect(restored.project.properties, project.properties);
      expect(restoredLayer.crs.epsgCode, 32648);
      expect(restoredLayer.visible, isFalse);
      expect(restoredLayer.locked, isTrue);
      expect(restoredLayer.properties['owner'], 'team');
      expect(restoredLayer.properties['georeferenced'], 'true');
      expect(restoredLayer.features.single.properties['cadLayer'], 'CONTROL');
      expect(restoredLayer.features.single.coordinates.single.x, 500005);
      expect(restoredLayer.features.single.coordinates.single.y, 1800006);
      expect(restoredLayer.features.single.coordinates.single.z, 7);
    },
  );

  test(
    'KML export is read-only for layers features properties and coordinates',
    () {
      final coordinate = const MapCoordinate(x: 105, y: 16, z: 8);
      final featureProperties = <String, String>{'cadLayer': 'POINTS'};
      final feature = MapFeature(
        id: 'point',
        type: MapFeatureType.point,
        coordinates: [coordinate],
        properties: featureProperties,
      );
      final layerProperties = <String, String>{'source': 'survey'};
      final layer = MapLayer(
        id: 'wgs',
        name: 'WGS',
        sourceType: MapLayerSourceType.manual,
        crs: const CoordinateReferenceSystem.wgs84(),
        features: [feature],
        properties: layerProperties,
      );

      final kml = const KmlExportService().exportLayers(
        documentName: 'Read only',
        layers: [layer],
      );

      expect(
        kml,
        contains('105.000000000000,16.0000000000000,8.00000000000000'),
      );
      expect(layer.features.single, same(feature));
      expect(feature.coordinates.single, same(coordinate));
      expect(feature.properties, same(featureProperties));
      expect(layer.properties, same(layerProperties));
      expect(featureProperties, {'cadLayer': 'POINTS'});
      expect(layerProperties, {'source': 'survey'});
    },
  );

  test(
    'DXF diagnostics prevent non-finite values entering project model',
    () async {
      final directory = await Directory.systemTemp.createTemp('geocad-e2e-');
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}${Platform.pathSeparator}mixed.dxf';
      await File(path).writeAsString('''0
SECTION
2
ENTITIES
0
POINT
8
VALID
10
10
20
20
0
LINE
8
INVALID
10
0
20
0
11
Infinity
21
1
0
SPLINE
8
UNSUPPORTED
0
ENDSEC
0
EOF
''');

      final parsed = await const DxfParserService().parseFile(path);
      final project = MapProject(
        id: 'safe-import',
        name: 'Safe import',
        layers: [
          MapLayer(
            id: 'dxf',
            name: 'Mixed',
            sourceType: MapLayerSourceType.dxf,
            sourcePath: path,
            features: parsed.features,
          ),
        ],
      );

      expect(parsed.features, hasLength(1));
      expect(parsed.diagnostics.totalEntityCount, 3);
      expect(parsed.diagnostics.parsedEntityCount, 1);
      expect(parsed.diagnostics.malformedEntityCount, 1);
      expect(parsed.diagnostics.unsupportedEntityCounts, {'SPLINE': 1});
      expect(
        project.layers
            .expand((layer) => layer.features)
            .expand((feature) => feature.coordinates)
            .every(
              (coordinate) =>
                  coordinate.x.isFinite &&
                  coordinate.y.isFinite &&
                  (coordinate.z?.isFinite ?? true),
            ),
        isTrue,
      );
    },
  );

  testWidgets('structural DXF failure does not mutate or dirty HomeScreen', (
    tester,
  ) async {
    final path = await writeWidgetDxf(tester, 'broken.dxf', '0\nSECTION\n2');

    await pumpCadImportHome(tester, path, fileName: 'broken.dxf');
    expect(projectTitle(tester), isNot(endsWith(' *')));
    await tapCadImport(tester);

    expect(projectTitle(tester), isNot(endsWith(' *')));
    expect(find.textContaining('Chưa có lớp dữ liệu'), findsOneWidget);
    expect(find.byTooltip('Ẩn layer'), findsNothing);
    expect(find.text('Kết quả nhập bản vẽ'), findsOneWidget);
    await tester.tap(find.text('Đóng'));
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('zero valid DXF shows diagnostics without adding a layer', (
    tester,
  ) async {
    final path = await writeWidgetDxf(tester, 'invalid-only.dxf', '''0
SECTION
2
ENTITIES
0
POINT
10
NaN
20
1
0
SPLINE
8
UNSUPPORTED
0
ENDSEC
0
EOF
''');

    await pumpCadImportHome(tester, path, fileName: 'invalid-only.dxf');
    await tapCadImport(tester);

    expect(find.text('Kết quả nhập DXF'), findsOneWidget);
    expect(find.text('Đã nhập: 0 entity'), findsOneWidget);
    expect(find.text('Malformed đã bỏ qua: 1'), findsOneWidget);
    expect(find.text('Entity chưa hỗ trợ: 1'), findsOneWidget);
    expect(find.text('  • SPLINE: 1'), findsOneWidget);
    expect(projectTitle(tester), isNot(endsWith(' *')));
    expect(find.byTooltip('Ẩn layer'), findsNothing);

    await tester.tap(find.text('Đóng'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(projectTitle(tester), isNot(endsWith(' *')));
    expect(find.byTooltip('Ẩn layer'), findsNothing);
  });

  testWidgets('valid warned DXF adds once and dialog is read-only', (
    tester,
  ) async {
    final path = await writeWidgetDxf(tester, 'warning.dxf', '''0
SECTION
2
ENTITIES
0
LWPOLYLINE
70
0
10
0
20
0
42
0.5
10
10
20
0
0
ENDSEC
0
EOF
''');

    await pumpCadImportHome(tester, path, fileName: 'warning.dxf');
    await tapCadImport(tester);

    expect(find.text('Kết quả nhập DXF'), findsOneWidget);
    expect(find.text('Đã nhập: 1 entity'), findsOneWidget);
    expect(find.text('Malformed đã bỏ qua: 0'), findsOneWidget);
    expect(find.text('Entity chưa hỗ trợ: 0'), findsOneWidget);
    expect(find.text('Cảnh báo fidelity:'), findsOneWidget);
    expect(projectTitle(tester), endsWith(' *'));
    expect(find.byTooltip('Ẩn layer'), findsOneWidget);

    await tester.tap(find.text('Đóng'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(projectTitle(tester), endsWith(' *'));
    expect(find.byTooltip('Ẩn layer'), findsOneWidget);
  });
}
