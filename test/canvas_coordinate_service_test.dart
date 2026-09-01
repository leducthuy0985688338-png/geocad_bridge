import 'package:autocad_googleearth/models/coordinate_reference_system.dart';
import 'package:autocad_googleearth/models/map_feature.dart';
import 'package:autocad_googleearth/models/map_layer.dart';
import 'package:autocad_googleearth/models/map_project.dart';
import 'package:autocad_googleearth/services/canvas_coordinate_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  const utm48South = CoordinateReferenceSystem.utm(
    utmZone: 48,
    hemisphere: UtmHemisphere.south,
  );

  MapCoordinate coordinateOf(CanvasCoordinateResult result) {
    expect(result.status, CanvasCoordinateStatus.success);
    return result.coordinate!;
  }

  test('semantic CRS equality compares type, UTM zone, and hemisphere', () {
    expect(service.isSameCrs(local, local), isTrue);
    expect(service.isSameCrs(wgs84, wgs84), isTrue);
    expect(service.isSameCrs(utm48, utm48), isTrue);
    expect(service.isSameCrs(utm48, utm49), isFalse);
    expect(service.isSameCrs(utm48, utm48South), isFalse);
    expect(service.isSameCrs(local, wgs84), isFalse);
  });

  test('same CRS transformations preserve coordinate values', () {
    const coordinate = MapCoordinate(x: 105, y: 16, z: 25);

    for (final crs in [local, wgs84, utm48]) {
      final result = service.toCanvas(
        coordinate: coordinate,
        sourceCrs: crs,
        canvasCrs: crs,
      );
      final transformed = coordinateOf(result);
      expect(transformed.x, coordinate.x);
      expect(transformed.y, coordinate.y);
      expect(transformed.z, coordinate.z);
      expect(transformed, isNot(same(coordinate)));
    }
  });

  test('WGS84 transforms to UTM and back with altitude preserved', () {
    const source = MapCoordinate(x: 105.8342, y: 21.0278, z: 12.5);
    final utm = coordinateOf(
      service.toCanvas(coordinate: source, sourceCrs: wgs84, canvasCrs: utm48),
    );
    final restored = coordinateOf(
      service.fromCanvas(coordinate: utm, canvasCrs: utm48, targetCrs: wgs84),
    );

    expect(restored.x, closeTo(source.x, 1e-6));
    expect(restored.y, closeTo(source.y, 1e-6));
    expect(restored.z, source.z);
  });

  test('UTM transforms to WGS84', () {
    const source = MapCoordinate(x: 500000, y: 1800000, z: 7);
    final result = service.toCanvas(
      coordinate: source,
      sourceCrs: utm48,
      canvasCrs: wgs84,
    );

    final transformed = coordinateOf(result);
    expect(transformed.x, inInclusiveRange(-180, 180));
    expect(transformed.y, inInclusiveRange(-90, 90));
    expect(transformed.z, 7);
  });

  test('UTM zones transform through WGS84 infrastructure', () {
    const geographic = MapCoordinate(x: 108, y: 16);
    final zone48 = coordinateOf(
      service.toCanvas(
        coordinate: geographic,
        sourceCrs: wgs84,
        canvasCrs: utm48,
      ),
    );
    final zone49 = coordinateOf(
      service.toCanvas(coordinate: zone48, sourceCrs: utm48, canvasCrs: utm49),
    );
    final restored = coordinateOf(
      service.toCanvas(coordinate: zone49, sourceCrs: utm49, canvasCrs: wgs84),
    );

    expect(restored.x, closeTo(geographic.x, 1e-6));
    expect(restored.y, closeTo(geographic.y, 1e-6));
  });

  test('local CAD is incompatible with geographic and projected CRS', () {
    const coordinate = MapCoordinate(x: 1, y: 2);
    for (final pair in [
      (source: local, target: wgs84),
      (source: wgs84, target: local),
      (source: local, target: utm48),
      (source: utm48, target: local),
    ]) {
      final result = service.toCanvas(
        coordinate: coordinate,
        sourceCrs: pair.source,
        canvasCrs: pair.target,
      );
      expect(result.status, CanvasCoordinateStatus.incompatibleCrs);
      expect(result.coordinate, isNull);
      expect(
        service.isCompatible(sourceCrs: pair.source, canvasCrs: pair.target),
        isFalse,
      );
    }
  });

  test('invalid UTM metadata and coordinates fail safely', () {
    const invalidUtm = CoordinateReferenceSystem.utm(
      utmZone: null,
      hemisphere: null,
    );
    final invalidCrs = service.toCanvas(
      coordinate: const MapCoordinate(x: 500000, y: 1800000),
      sourceCrs: invalidUtm,
      canvasCrs: wgs84,
    );
    final invalidCoordinate = service.toCanvas(
      coordinate: const MapCoordinate(x: double.nan, y: 0),
      sourceCrs: wgs84,
      canvasCrs: utm48,
    );

    expect(invalidCrs.status, CanvasCoordinateStatus.invalidCrs);
    expect(invalidCoordinate.status, CanvasCoordinateStatus.invalidCoordinate);
  });

  test('MapProject mutations and copy preserve canvas CRS', () {
    const project = MapProject(
      id: 'project',
      name: 'Project',
      canvasCrs: utm48,
    );
    const layer = MapLayer(
      id: 'layer',
      name: 'Layer',
      sourceType: MapLayerSourceType.manual,
    );

    expect(project.addLayer(layer).canvasCrs.epsgCode, 32648);
    expect(
      project.addLayer(layer).updateLayer(layer).canvasCrs.epsgCode,
      32648,
    );
    expect(
      project.addLayer(layer).removeLayer(layer.id).canvasCrs.epsgCode,
      32648,
    );
    expect(project.copyWith(name: 'Renamed').canvasCrs.epsgCode, 32648);
    expect(project.copyWith(canvasCrs: wgs84).canvasCrs.isWgs84, isTrue);
  });
}
