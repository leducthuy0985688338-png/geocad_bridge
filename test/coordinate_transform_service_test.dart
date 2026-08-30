import 'package:flutter_test/flutter_test.dart';

import 'package:autocad_googleearth/models/coordinate_reference_system.dart';
import 'package:autocad_googleearth/services/coordinate_transform_service.dart';

void main() {
  const service = CoordinateTransformService();

  test('WGS84 to UTM and back keeps coordinates', () {
    const longitude = 106.0;
    const latitude = 16.0;

    final zone = service.suggestedUtmZone(longitude);
    final hemisphere =
        service.suggestedHemisphere(latitude);

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
    expect(
      restored.longitude,
      closeTo(longitude, 0.000001),
    );
    expect(
      restored.latitude,
      closeTo(latitude, 0.000001),
    );
  });

  test('CRS properties round trip', () {
    const original = CoordinateReferenceSystem.utm(
      utmZone: 48,
      hemisphere: UtmHemisphere.north,
    );

    final restored =
        CoordinateReferenceSystem.fromProperties(
      original.toProperties(),
    );

    expect(restored.type, original.type);
    expect(restored.utmZone, 48);
    expect(
      restored.hemisphere,
      UtmHemisphere.north,
    );
    expect(restored.epsgCode, 32648);
    expect(restored.isValid, isTrue);
  });
}
