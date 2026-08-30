import 'package:flutter_test/flutter_test.dart';

import 'package:autocad_googleearth/models/coordinate_reference_system.dart';
import 'package:autocad_googleearth/models/map_feature.dart';
import 'package:autocad_googleearth/services/coordinate_transform_service.dart';

void main() {
  const service = CoordinateTransformService();

  test('WGS84 to UTM and back keeps coordinates', () {
    const longitude = 106.0;
    const latitude = 16.0;

    final zone = service.suggestedUtmZone(longitude);
    final hemisphere = service.suggestedHemisphere(latitude);

    final utm = service.wgs84ToUtm(
      longitude: longitude,
      latitude: latitude,
      zone: zone,
      hemisphere: hemisphere,
    );

    final restored = service.utmToWgs84(
      easting: utm.x,
      northing: utm.y,
      zone: zone,
      hemisphere: hemisphere,
    );

    expect(zone, 48);
    expect(restored.longitude, closeTo(longitude, 0.000001));
    expect(restored.latitude, closeTo(latitude, 0.000001));
  });

  test('CRS properties round trip', () {
    const original = CoordinateReferenceSystem.utm(
      utmZone: 48,
      hemisphere: UtmHemisphere.north,
    );

    final restored = CoordinateReferenceSystem.fromProperties(
      original.toProperties(),
    );

    expect(restored.type, original.type);
    expect(restored.utmZone, 48);
    expect(restored.hemisphere, UtmHemisphere.north);
    expect(restored.epsgCode, 32648);
    expect(restored.isValid, isTrue);
  });

  test('converts fixed northern UTM reference to WGS84', () {
    final result = service.utmToWgs84(
      easting: 500000,
      northing: 1768935.376,
      zone: 48,
      hemisphere: UtmHemisphere.north,
    );

    expect(result.longitude, closeTo(105, 0.000001));
    expect(result.latitude, closeTo(16, 0.000001));
  });

  test('converts fixed southern UTM reference to WGS84', () {
    final result = service.utmToWgs84(
      easting: 500000,
      northing: 6126956.936,
      zone: 55,
      hemisphere: UtmHemisphere.south,
    );

    expect(result.longitude, closeTo(147, 0.000001));
    expect(result.latitude, closeTo(-35, 0.000001));
  });

  test('supports UTM boundary zones 1 and 60', () {
    final zone1 = service.utmToWgs84(
      easting: 500000,
      northing: 0,
      zone: 1,
      hemisphere: UtmHemisphere.north,
    );
    final zone60 = service.utmToWgs84(
      easting: 500000,
      northing: 0,
      zone: 60,
      hemisphere: UtmHemisphere.north,
    );

    expect(zone1.longitude, closeTo(-177, 0.0000001));
    expect(zone1.latitude, closeTo(0, 0.0000001));
    expect(zone60.longitude, closeTo(177, 0.0000001));
    expect(zone60.latitude, closeTo(0, 0.0000001));
    expect(service.suggestedUtmZone(-180), 1);
    expect(service.suggestedUtmZone(180), 60);
  });

  test('rejects invalid UTM zones and coordinate bounds', () {
    for (final zone in [0, 61]) {
      expect(
        () => service.utmToWgs84(
          easting: 500000,
          northing: 0,
          zone: zone,
          hemisphere: UtmHemisphere.north,
        ),
        throwsArgumentError,
      );
    }

    for (final coordinate in [
      (99999.0, 0.0),
      (1000001.0, 0.0),
      (500000.0, -1.0),
      (500000.0, 10000001.0),
    ]) {
      expect(
        () => service.utmToWgs84(
          easting: coordinate.$1,
          northing: coordinate.$2,
          zone: 48,
          hemisphere: UtmHemisphere.north,
        ),
        throwsArgumentError,
      );
    }
  });

  test('rejects incomplete UTM CRS without null-check failure', () {
    const coordinate = MapCoordinate(x: 500000, y: 0);

    for (final crs in [
      const CoordinateReferenceSystem.utm(
        utmZone: null,
        hemisphere: UtmHemisphere.north,
      ),
      const CoordinateReferenceSystem.utm(utmZone: 48, hemisphere: null),
    ]) {
      expect(crs.isValid, isFalse);
      expect(
        () => service.toWgs84(coordinate: coordinate, sourceCrs: crs),
        throwsArgumentError,
      );
    }
  });

  test('invalid hemisphere metadata does not fall back to north', () {
    final restored = CoordinateReferenceSystem.fromProperties(const {
      'crsType': 'utm',
      'utmZone': '48',
      'utmHemisphere': 'invalid',
    });

    expect(restored.isLocalCad, isTrue);
    expect(restored.utmZone, isNull);
    expect(restored.hemisphere, isNull);
  });

  test('rejects NaN infinity and non-finite altitude', () {
    expect(() => service.suggestedUtmZone(double.nan), throwsArgumentError);
    expect(
      () => service.suggestedHemisphere(double.infinity),
      throwsArgumentError,
    );
    expect(
      () => service.utmToWgs84(
        easting: double.nan,
        northing: 0,
        zone: 48,
        hemisphere: UtmHemisphere.north,
      ),
      throwsArgumentError,
    );
    expect(
      () => service.wgs84ToUtm(
        longitude: 105,
        latitude: 16,
        zone: 48,
        hemisphere: UtmHemisphere.north,
        altitude: double.negativeInfinity,
      ),
      throwsArgumentError,
    );
  });

  test('validates UTM latitude domain and hemisphere', () {
    for (final latitude in [-80.000001, 84.000001]) {
      expect(
        () => service.wgs84ToUtm(
          longitude: 105,
          latitude: latitude,
          zone: 48,
          hemisphere: latitude < 0 ? UtmHemisphere.south : UtmHemisphere.north,
        ),
        throwsArgumentError,
      );
    }

    expect(
      () => service.wgs84ToUtm(
        longitude: 105,
        latitude: 16,
        zone: 48,
        hemisphere: UtmHemisphere.south,
      ),
      throwsArgumentError,
    );
    expect(
      () => service.wgs84ToUtm(
        longitude: 147,
        latitude: -35,
        zone: 55,
        hemisphere: UtmHemisphere.north,
      ),
      throwsArgumentError,
    );
  });

  test('preserves altitude through coordinate transformations', () {
    const source = MapCoordinate(x: 500000, y: 1768935.376, z: 123.45);
    const utmCrs = CoordinateReferenceSystem.utm(
      utmZone: 48,
      hemisphere: UtmHemisphere.north,
    );

    final geographic = service.toWgs84(coordinate: source, sourceCrs: utmCrs);
    final restored = service.fromWgs84(
      coordinate: geographic,
      targetCrs: utmCrs,
    );

    expect(geographic.altitude, 123.45);
    expect(restored.z, 123.45);
  });
}
