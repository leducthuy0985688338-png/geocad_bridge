import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:autocad_googleearth/models/coordinate_reference_system.dart';
import 'package:autocad_googleearth/models/map_feature.dart';
import 'package:autocad_googleearth/models/map_layer.dart';
import 'package:autocad_googleearth/models/map_project.dart';
import 'package:autocad_googleearth/services/layer_georeference_service.dart';
import 'package:autocad_googleearth/services/kml_parser_service.dart';
import 'package:autocad_googleearth/services/project_persistence_service.dart';

void main() {
  const service = ProjectPersistenceService();
  final createdAt = DateTime.utc(2026, 1, 2, 3, 4, 5);
  final updatedAt = DateTime.utc(2026, 2, 3, 4, 5, 6);

  MapFeature feature(
    String id,
    MapFeatureType type,
    List<MapCoordinate> coordinates,
  ) {
    return MapFeature(
      id: id,
      type: type,
      coordinates: coordinates,
      name: 'Tên $id',
      description: 'Mô tả $id',
      visible: id != 'text',
      properties: {'z-key': 'z-value', 'a-key': 'a-value'},
    );
  }

  MapProject completeProject({String? sourcePath}) {
    return MapProject(
      id: 'project-1',
      name: 'Dự án UTF-8',
      description: 'Mô tả dự án',
      properties: const {'owner': 'GeoCAD', 'quality': 'survey'},
      layers: [
        MapLayer(
          id: 'local',
          name: 'Local CAD',
          sourceType: MapLayerSourceType.dxf,
          sourcePath: sourcePath,
          visible: false,
          locked: true,
          properties: const {
            'georeferenceRmse': '0.125',
            'georeferenceReviewStatus': 'reviewSuggested',
            'georeferenceSuspectedPointIndices': '4',
          },
          features: [
            feature('point', MapFeatureType.point, const [
              MapCoordinate(x: 1, y: 2, z: 3),
            ]),
            feature('line', MapFeatureType.line, const [
              MapCoordinate(x: 0, y: 0),
              MapCoordinate(x: 1, y: 1),
            ]),
            feature('polyline', MapFeatureType.polyline, const [
              MapCoordinate(x: 2, y: 2),
              MapCoordinate(x: 3, y: 3, z: 4),
            ]),
            feature('polygon', MapFeatureType.polygon, const [
              MapCoordinate(x: 0, y: 0),
              MapCoordinate(x: 2, y: 0),
              MapCoordinate(x: 0, y: 2),
            ]),
            feature('text', MapFeatureType.text, const [
              MapCoordinate(x: 9, y: 8, z: 7),
            ]),
          ],
        ),
        const MapLayer(
          id: 'wgs',
          name: 'WGS84',
          sourceType: MapLayerSourceType.kml,
          crs: CoordinateReferenceSystem.wgs84(),
        ),
        const MapLayer(
          id: 'utm-n',
          name: 'UTM North',
          sourceType: MapLayerSourceType.manual,
          crs: CoordinateReferenceSystem.utm(
            utmZone: 48,
            hemisphere: UtmHemisphere.north,
          ),
        ),
        const MapLayer(
          id: 'utm-s',
          name: 'UTM South',
          sourceType: MapLayerSourceType.manual,
          crs: CoordinateReferenceSystem.utm(
            utmZone: 56,
            hemisphere: UtmHemisphere.south,
          ),
        ),
      ],
    );
  }

  GeoCadProjectDocument document(MapProject project) => GeoCadProjectDocument(
    project: project,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  Map<String, Object?> decodedDocument(MapProject project) =>
      (jsonDecode(service.serialize(document(project))) as Map)
          .cast<String, Object?>();

  test('empty project round-trips with format version and timestamps', () {
    final source = document(
      const MapProject(id: 'empty', name: 'Empty project'),
    );
    final json = service.serialize(source);
    final restored = service.deserialize(json);
    final root = jsonDecode(json) as Map<String, dynamic>;

    expect(root['format'], ProjectPersistenceService.formatName);
    expect(root['version'], 1);
    expect(restored.createdAt, createdAt);
    expect(restored.updatedAt, updatedAt);
    expect(restored.project.id, 'empty');
    expect(restored.project.layers, isEmpty);
    expect(restored.project.canvasCrs.isLocalCad, isTrue);
  });

  test(
    'resolved KML shared style and raw styleUrl survive project round-trip',
    () {
      const kml = '''
<kml><Document>
<Style id="road"><LineStyle><color>800000ff</color><width>2</width></LineStyle></Style>
<Placemark><styleUrl>#road</styleUrl><LineString><coordinates>106,16 107,17</coordinates></LineString></Placemark>
</Document></kml>
''';
      final imported = const KmlParserService()
          .parseString(kml)
          .features
          .single;
      final source = document(
        MapProject(
          id: 'shared-style',
          name: 'Shared style',
          layers: [
            MapLayer(
              id: 'kml-layer',
              name: 'KML',
              sourceType: MapLayerSourceType.kml,
              crs: const CoordinateReferenceSystem.wgs84(),
              features: [imported],
            ),
          ],
        ),
      );

      final restored = service.deserialize(service.serialize(source));
      final properties =
          restored.project.layers.single.features.single.properties;

      expect(properties['kml.styleUrl'], '#road');
      expect(properties['style.strokeColor'], '#FF0000');
      expect(properties['style.strokeOpacity'], '0.501961');
      expect(properties['style.strokeWidth'], '2');
    },
  );

  test('resolved DXF BYLAYER metadata survives project round-trip', () {
    final source = document(
      const MapProject(
        id: 'dxf-bylayer',
        name: 'DXF BYLAYER',
        layers: [
          MapLayer(
            id: 'dxf-layer',
            name: 'drawing.dxf',
            sourceType: MapLayerSourceType.dxf,
            features: [
              MapFeature(
                id: 'line',
                type: MapFeatureType.line,
                coordinates: [
                  MapCoordinate(x: 0, y: 0),
                  MapCoordinate(x: 1, y: 1),
                ],
                properties: {
                  'cadLayer': 'ROADS',
                  'cad.colorIndex': '256',
                  'cad.layer.colorIndex': '-3',
                  'cad.layer.flags': '5',
                  'style.strokeColor': '#00FF00',
                },
              ),
            ],
          ),
        ],
      ),
    );

    final restored = service.deserialize(service.serialize(source));
    expect(restored.project.layers.single.features.single.properties, {
      'cadLayer': 'ROADS',
      'cad.colorIndex': '256',
      'cad.layer.colorIndex': '-3',
      'cad.layer.flags': '5',
      'style.strokeColor': '#00FF00',
    });
  });

  test('project canvas CRS round-trips for WGS84 and UTM', () {
    const projects = [
      MapProject(
        id: 'wgs',
        name: 'WGS',
        canvasCrs: CoordinateReferenceSystem.wgs84(),
      ),
      MapProject(
        id: 'utm',
        name: 'UTM',
        canvasCrs: CoordinateReferenceSystem.utm(
          utmZone: 48,
          hemisphere: UtmHemisphere.north,
        ),
      ),
      MapProject(
        id: 'utm-south',
        name: 'UTM South',
        canvasCrs: CoordinateReferenceSystem.utm(
          utmZone: 56,
          hemisphere: UtmHemisphere.south,
        ),
      ),
    ];

    final restored = projects
        .map(
          (project) =>
              service.deserialize(service.serialize(document(project))).project,
        )
        .toList();
    expect(restored[0].canvasCrs.isWgs84, isTrue);
    expect(restored[1].canvasCrs.epsgCode, 32648);
    expect(restored[2].canvasCrs.epsgCode, 32756);
  });

  test('legacy projects without canvas CRS use deterministic local CAD', () {
    final legacyProjects = <MapProject>[
      const MapProject(id: 'empty', name: 'Empty'),
      const MapProject(
        id: 'local',
        name: 'Local',
        layers: [
          MapLayer(
            id: 'local-layer',
            name: 'Local',
            sourceType: MapLayerSourceType.dxf,
          ),
        ],
      ),
      completeProject(),
    ];

    for (final project in legacyProjects) {
      final root = decodedDocument(project);
      (root['project'] as Map).remove('canvasCrs');
      final restored = service.deserialize(jsonEncode(root));
      expect(restored.project.canvasCrs.isLocalCad, isTrue);
      expect(restored.project.layers, hasLength(project.layers.length));
    }
  });

  test(
    'complete project preserves ordering geometry CRS state and metadata',
    () {
      final restored = service.deserialize(
        service.serialize(document(completeProject())),
      );

      expect(restored.project.layers.map((layer) => layer.id), [
        'local',
        'wgs',
        'utm-n',
        'utm-s',
      ]);
      final local = restored.project.layers.first;
      expect(local.features.map((item) => item.type), MapFeatureType.values);
      expect(local.features.map((item) => item.id), [
        'point',
        'line',
        'polyline',
        'polygon',
        'text',
      ]);
      expect(local.features[2].coordinates[1].z, 4);
      expect(local.visible, isFalse);
      expect(local.locked, isTrue);
      expect(local.properties['georeferenceRmse'], '0.125');
      expect(restored.project.layers[1].crs.isWgs84, isTrue);
      expect(restored.project.layers[2].crs.epsgCode, 32648);
      expect(restored.project.layers[3].crs.epsgCode, 32756);
      expect(restored.project.properties['owner'], 'GeoCAD');
      expect(local.features.first.properties['a-key'], 'a-value');
    },
  );

  test('serialization is deterministic for fixed document timestamps', () {
    final source = document(completeProject());
    expect(service.serialize(source), service.serialize(source));
    expect(
      service.serialize(source).indexOf('"a-key"'),
      lessThan(service.serialize(source).indexOf('"z-key"')),
    );
  });

  test('deserialized graph does not share mutable collections with source', () {
    final sourceProperties = <String, String>{'project': 'source'};
    final featureProperties = <String, String>{'feature': 'source'};
    final coordinates = <MapCoordinate>[const MapCoordinate(x: 1, y: 2)];
    final features = <MapFeature>[
      MapFeature(
        id: 'point',
        type: MapFeatureType.point,
        coordinates: coordinates,
        properties: featureProperties,
      ),
    ];
    final layers = <MapLayer>[
      MapLayer(
        id: 'layer',
        name: 'Layer',
        sourceType: MapLayerSourceType.manual,
        features: features,
      ),
    ];
    final source = MapProject(
      id: 'project',
      name: 'Project',
      layers: layers,
      properties: sourceProperties,
    );
    final restored = service.deserialize(service.serialize(document(source)));

    sourceProperties['project'] = 'changed';
    featureProperties['feature'] = 'changed';
    coordinates.add(const MapCoordinate(x: 3, y: 4));
    features.clear();
    layers.clear();

    expect(restored.project.layers, hasLength(1));
    expect(restored.project.properties['project'], 'source');
    expect(
      restored.project.layers.single.features.single.properties['feature'],
      'source',
    );
    expect(
      restored.project.layers.single.features.single.coordinates,
      hasLength(1),
    );
    expect(
      restored.project.layers.single.features.single.coordinates.single,
      isNot(same(coordinates.first)),
    );
  });

  test('unknown optional fields are ignored', () {
    final root = decodedDocument(
      const MapProject(id: 'project', name: 'Project'),
    );
    root['futureField'] = {'anything': true};
    final restored = service.deserialize(jsonEncode(root));
    expect(restored.project.id, 'project');
  });

  test('rejects malformed JSON root format and version', () {
    expect(
      () => service.deserialize('{'),
      throwsA(isA<ProjectPersistenceException>()),
    );
    expect(
      () => service.deserialize('[]'),
      throwsA(isA<ProjectPersistenceException>()),
    );

    final root = decodedDocument(
      const MapProject(id: 'project', name: 'Project'),
    );
    for (final mutation in <void Function(Map<String, Object?>)>[
      (value) => value['format'] = 'Other',
      (value) => value.remove('version'),
      (value) => value['version'] = '1',
      (value) => value['version'] = 2,
    ]) {
      final copy = jsonDecode(jsonEncode(root)) as Map<String, dynamic>;
      mutation(copy);
      expect(
        () => service.deserialize(jsonEncode(copy)),
        throwsA(isA<ProjectPersistenceException>()),
      );
    }
  });

  test('rejects invalid enum CRS and properties', () {
    final root = decodedDocument(completeProject());
    final layers = ((root['project'] as Map)['layers'] as List);
    final first = layers.first as Map;
    for (final mutation in <void Function(Map)>[
      (layer) => layer['sourceType'] = 'future',
      (layer) => (layer['crs'] as Map)['type'] = 'future',
      (layer) {
        layer['crs'] = {
          'type': 'utm',
          'name': 'UTM',
          'utmZone': 0,
          'hemisphere': 'north',
        };
      },
      (layer) {
        layer['crs'] = {'type': 'utm', 'name': 'UTM', 'utmZone': 48};
      },
      (layer) => layer['properties'] = {'bad': 1},
    ]) {
      final copy = jsonDecode(jsonEncode(root)) as Map<String, dynamic>;
      final layer = (((copy['project'] as Map)['layers'] as List).first as Map);
      mutation(layer);
      expect(
        () => service.deserialize(jsonEncode(copy)),
        throwsA(isA<ProjectPersistenceException>()),
      );
    }
    expect(first, isNotEmpty);
  });

  test('rejects malformed geometry and duplicate IDs', () {
    final root = decodedDocument(completeProject());
    for (final mutation in <void Function(Map<String, dynamic>)>[
      (copy) {
        final layer =
            (((copy['project'] as Map)['layers'] as List).first as Map);
        ((layer['features'] as List).first as Map)['coordinates'] = [];
      },
      (copy) {
        final layers = (copy['project'] as Map)['layers'] as List;
        (layers[1] as Map)['id'] = (layers[0] as Map)['id'];
      },
      (copy) {
        final features =
            ((((copy['project'] as Map)['layers'] as List).first
                    as Map)['features']
                as List);
        (features[1] as Map)['id'] = (features[0] as Map)['id'];
      },
    ]) {
      final copy = jsonDecode(jsonEncode(root)) as Map<String, dynamic>;
      mutation(copy);
      expect(
        () => service.deserialize(jsonEncode(copy)),
        throwsA(isA<ProjectPersistenceException>()),
      );
    }
  });

  test('rejects non-finite coordinates during serialization', () {
    final project = MapProject(
      id: 'project',
      name: 'Project',
      layers: [
        MapLayer(
          id: 'layer',
          name: 'Layer',
          sourceType: MapLayerSourceType.manual,
          features: [
            feature('point', MapFeatureType.point, const [
              MapCoordinate(x: double.nan, y: 0),
            ]),
          ],
        ),
      ],
    );
    expect(
      () => service.serialize(document(project)),
      throwsA(isA<ProjectPersistenceException>()),
    );
  });

  test('missing source is a non-blocking warning and geometry survives', () {
    final missing =
        '${Directory.systemTemp.path}${Platform.pathSeparator}missing-${DateTime.now().microsecondsSinceEpoch}.dxf';
    final restored = service.deserialize(
      service.serialize(document(completeProject(sourcePath: missing))),
    );

    expect(restored.warnings, hasLength(1));
    expect(restored.project.layers.first.sourcePath, missing);
    expect(restored.project.layers.first.features, hasLength(5));
  });

  test('georeference control points survive serialize and deserialize', () {
    final georeferenced = const LayerGeoreferenceService()
        .georeferenceLayerWithControlPoints(
          sourceLayer: const MapLayer(
            id: 'cad',
            name: 'CAD',
            sourceType: MapLayerSourceType.dxf,
            features: [
              MapFeature(
                id: 'point',
                type: MapFeatureType.point,
                coordinates: [MapCoordinate(x: 1, y: 2, z: 3)],
              ),
            ],
          ),
          controlPoints: const [
            GeoreferenceControlPoint(
              local: MapCoordinate(x: 0, y: 0, z: 10),
              target: MapCoordinate(x: 500000, y: 1800000, z: 20),
            ),
            GeoreferenceControlPoint(
              local: MapCoordinate(x: 10, y: 0, z: 11),
              target: MapCoordinate(x: 500010, y: 1800000, z: 21),
            ),
          ],
          targetCrs: const CoordinateReferenceSystem.utm(
            utmZone: 48,
            hemisphere: UtmHemisphere.north,
          ),
        );
    final restored = service.deserialize(
      service.serialize(
        document(
          MapProject(
            id: 'project',
            name: 'Project',
            layers: [georeferenced.layer],
          ),
        ),
      ),
    );
    final metadata = jsonDecode(
      restored.project.layers.single.properties['georeferenceControlPoints']!,
    ) as List<dynamic>;

    expect(metadata, hasLength(2));
    expect((metadata.first as Map)['local'], {'x': 0.0, 'y': 0.0, 'z': 10.0});
    expect((metadata.first as Map)['target'], {
      'x': 500000.0,
      'y': 1800000.0,
      'z': 20.0,
    });
  });

  test(
    'filesystem save load overwrite and cleanup work in temp directory',
    () async {
      final directory = await Directory.systemTemp.createTemp('geocad-test-');
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}${Platform.pathSeparator}project.geocad';

      await service.save(
        path,
        document(const MapProject(id: 'first', name: 'First')),
      );
      await service.save(
        path,
        document(const MapProject(id: 'second', name: 'Second')),
      );
      final loaded = await service.load(path);

      expect(loaded.project.id, 'second');
      expect(await File(path).exists(), isTrue);
      expect(directory.listSync().map((entry) => entry.path), [path]);
    },
  );
}
