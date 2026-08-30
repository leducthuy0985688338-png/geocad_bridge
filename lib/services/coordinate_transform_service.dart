import 'dart:math' as math;

import '../models/coordinate_reference_system.dart';
import '../models/map_feature.dart';

class GeographicCoordinate {
  final double longitude;
  final double latitude;

  const GeographicCoordinate({
    required this.longitude,
    required this.latitude,
  });

  @override
  String toString() {
    return 'GeographicCoordinate('
        'longitude: $longitude, latitude: $latitude)';
  }
}

class CoordinateTransformService {
  const CoordinateTransformService();

  static const double _a = 6378137.0;
  static const double _eccSquared = 0.00669438;
  static const double _k0 = 0.9996;

  bool isValidWgs84({
    required double longitude,
    required double latitude,
  }) {
    return longitude.isFinite &&
        latitude.isFinite &&
        longitude >= -180.0 &&
        longitude <= 180.0 &&
        latitude >= -90.0 &&
        latitude <= 90.0;
  }

  bool isValidUtm({
    required double easting,
    required double northing,
    required int zone,
  }) {
    return easting.isFinite &&
        northing.isFinite &&
        zone >= 1 &&
        zone <= 60 &&
        easting >= 100000.0 &&
        easting <= 1000000.0 &&
        northing >= 0.0 &&
        northing <= 10000000.0;
  }

  GeographicCoordinate utmToWgs84({
    required double easting,
    required double northing,
    required int zone,
    required UtmHemisphere hemisphere,
  }) {
    if (!isValidUtm(
      easting: easting,
      northing: northing,
      zone: zone,
    )) {
      throw ArgumentError('Tọa độ UTM không hợp lệ.');
    }

    var x = easting - 500000.0;
    var y = northing;

    if (hemisphere == UtmHemisphere.south) {
      y -= 10000000.0;
    }

    final eccPrimeSquared =
        _eccSquared / (1.0 - _eccSquared);

    final m = y / _k0;
    final mu = m /
        (_a *
            (1.0 -
                _eccSquared / 4.0 -
                3.0 * _eccSquared * _eccSquared / 64.0 -
                5.0 *
                    _eccSquared *
                    _eccSquared *
                    _eccSquared /
                    256.0));

    final e1 = (1.0 - math.sqrt(1.0 - _eccSquared)) /
        (1.0 + math.sqrt(1.0 - _eccSquared));

    final phi1Rad = mu +
        (3.0 * e1 / 2.0 - 27.0 * math.pow(e1, 3) / 32.0) *
            math.sin(2.0 * mu) +
        (21.0 * e1 * e1 / 16.0 -
                55.0 * math.pow(e1, 4) / 32.0) *
            math.sin(4.0 * mu) +
        (151.0 * math.pow(e1, 3) / 96.0) *
            math.sin(6.0 * mu) +
        (1097.0 * math.pow(e1, 4) / 512.0) *
            math.sin(8.0 * mu);

    final n1 = _a /
        math.sqrt(
          1.0 -
              _eccSquared *
                  math.sin(phi1Rad) *
                  math.sin(phi1Rad),
        );

    final t1 =
        math.tan(phi1Rad) * math.tan(phi1Rad);

    final c1 = eccPrimeSquared *
        math.cos(phi1Rad) *
        math.cos(phi1Rad);

    final r1 = _a *
        (1.0 - _eccSquared) /
        math.pow(
          1.0 -
              _eccSquared *
                  math.sin(phi1Rad) *
                  math.sin(phi1Rad),
          1.5,
        );

    final d = x / (n1 * _k0);

    var latitude = phi1Rad -
        (n1 * math.tan(phi1Rad) / r1) *
            (d * d / 2.0 -
                (5.0 +
                        3.0 * t1 +
                        10.0 * c1 -
                        4.0 * c1 * c1 -
                        9.0 * eccPrimeSquared) *
                    math.pow(d, 4) /
                    24.0 +
                (61.0 +
                        90.0 * t1 +
                        298.0 * c1 +
                        45.0 * t1 * t1 -
                        252.0 * eccPrimeSquared -
                        3.0 * c1 * c1) *
                    math.pow(d, 6) /
                    720.0);

    var longitude =
        (d -
                (1.0 + 2.0 * t1 + c1) *
                    math.pow(d, 3) /
                    6.0 +
                (5.0 -
                        2.0 * c1 +
                        28.0 * t1 -
                        3.0 * c1 * c1 +
                        8.0 * eccPrimeSquared +
                        24.0 * t1 * t1) *
                    math.pow(d, 5) /
                    120.0) /
            math.cos(phi1Rad);

    final longOrigin =
        (zone - 1) * 6 - 180 + 3;

    latitude = _radToDeg(latitude);
    longitude =
        longOrigin + _radToDeg(longitude);

    if (!isValidWgs84(
      longitude: longitude,
      latitude: latitude,
    )) {
      throw StateError(
        'Kết quả WGS84 nằm ngoài phạm vi hợp lệ.',
      );
    }

    return GeographicCoordinate(
      longitude: longitude,
      latitude: latitude,
    );
  }

  MapCoordinate wgs84ToUtm({
    required double longitude,
    required double latitude,
    required int zone,
    required UtmHemisphere hemisphere,
  }) {
    if (!isValidWgs84(
      longitude: longitude,
      latitude: latitude,
    )) {
      throw ArgumentError('Tọa độ WGS84 không hợp lệ.');
    }

    if (zone < 1 || zone > 60) {
      throw ArgumentError('UTM Zone phải từ 1 đến 60.');
    }

    final latRad = _degToRad(latitude);
    final longRad = _degToRad(longitude);

    final longOrigin =
        (zone - 1) * 6 - 180 + 3;
    final longOriginRad =
        _degToRad(longOrigin.toDouble());

    final eccPrimeSquared =
        _eccSquared / (1.0 - _eccSquared);

    final n = _a /
        math.sqrt(
          1.0 -
              _eccSquared *
                  math.sin(latRad) *
                  math.sin(latRad),
        );

    final t =
        math.tan(latRad) * math.tan(latRad);

    final c = eccPrimeSquared *
        math.cos(latRad) *
        math.cos(latRad);

    final aTerm = math.cos(latRad) *
        (longRad - longOriginRad);

    final m = _a *
        ((1.0 -
                    _eccSquared / 4.0 -
                    3.0 * _eccSquared * _eccSquared / 64.0 -
                    5.0 *
                        _eccSquared *
                        _eccSquared *
                        _eccSquared /
                        256.0) *
                latRad -
            (3.0 * _eccSquared / 8.0 +
                    3.0 * _eccSquared * _eccSquared / 32.0 +
                    45.0 *
                        _eccSquared *
                        _eccSquared *
                        _eccSquared /
                        1024.0) *
                math.sin(2.0 * latRad) +
            (15.0 * _eccSquared * _eccSquared / 256.0 +
                    45.0 *
                        _eccSquared *
                        _eccSquared *
                        _eccSquared /
                        1024.0) *
                math.sin(4.0 * latRad) -
            (35.0 *
                    _eccSquared *
                    _eccSquared *
                    _eccSquared /
                    3072.0) *
                math.sin(6.0 * latRad));

    final easting = _k0 *
            n *
            (aTerm +
                (1.0 - t + c) *
                    math.pow(aTerm, 3) /
                    6.0 +
                (5.0 -
                        18.0 * t +
                        t * t +
                        72.0 * c -
                        58.0 * eccPrimeSquared) *
                    math.pow(aTerm, 5) /
                    120.0) +
        500000.0;

    var northing = _k0 *
        (m +
            n *
                math.tan(latRad) *
                (aTerm * aTerm / 2.0 +
                    (5.0 -
                            t +
                            9.0 * c +
                            4.0 * c * c) *
                        math.pow(aTerm, 4) /
                        24.0 +
                    (61.0 -
                            58.0 * t +
                            t * t +
                            600.0 * c -
                            330.0 * eccPrimeSquared) *
                        math.pow(aTerm, 6) /
                        720.0));

    if (hemisphere == UtmHemisphere.south) {
      northing += 10000000.0;
    }

    if (!isValidUtm(
      easting: easting,
      northing: northing,
      zone: zone,
    )) {
      throw StateError(
        'Kết quả UTM nằm ngoài phạm vi hợp lệ.',
      );
    }

    return MapCoordinate(
      x: easting,
      y: northing,
    );
  }

  GeographicCoordinate toWgs84({
    required MapCoordinate coordinate,
    required CoordinateReferenceSystem sourceCrs,
  }) {
    switch (sourceCrs.type) {
      case CoordinateReferenceSystemType.wgs84:
        if (!isValidWgs84(
          longitude: coordinate.x,
          latitude: coordinate.y,
        )) {
          throw ArgumentError(
            'Tọa độ WGS84 không hợp lệ.',
          );
        }

        return GeographicCoordinate(
          longitude: coordinate.x,
          latitude: coordinate.y,
        );

      case CoordinateReferenceSystemType.utm:
        return utmToWgs84(
          easting: coordinate.x,
          northing: coordinate.y,
          zone: sourceCrs.utmZone!,
          hemisphere: sourceCrs.hemisphere!,
        );

      case CoordinateReferenceSystemType.localCad:
        throw StateError(
          'CAD cục bộ chưa có đủ thông tin để '
          'chuyển sang WGS84.',
        );
    }
  }

  MapCoordinate fromWgs84({
    required GeographicCoordinate coordinate,
    required CoordinateReferenceSystem targetCrs,
  }) {
    switch (targetCrs.type) {
      case CoordinateReferenceSystemType.wgs84:
        if (!isValidWgs84(
          longitude: coordinate.longitude,
          latitude: coordinate.latitude,
        )) {
          throw ArgumentError(
            'Tọa độ WGS84 không hợp lệ.',
          );
        }

        return MapCoordinate(
          x: coordinate.longitude,
          y: coordinate.latitude,
        );

      case CoordinateReferenceSystemType.utm:
        return wgs84ToUtm(
          longitude: coordinate.longitude,
          latitude: coordinate.latitude,
          zone: targetCrs.utmZone!,
          hemisphere: targetCrs.hemisphere!,
        );

      case CoordinateReferenceSystemType.localCad:
        throw StateError(
          'Không thể tự động chuyển WGS84 sang '
          'CAD cục bộ khi chưa có phép định vị.',
        );
    }
  }

  int suggestedUtmZone(double longitude) {
    if (longitude < -180.0 || longitude > 180.0) {
      throw ArgumentError(
        'Kinh độ phải nằm trong [-180, 180].',
      );
    }

    if (longitude == 180.0) return 60;

    return ((longitude + 180.0) / 6.0).floor() + 1;
  }

  UtmHemisphere suggestedHemisphere(
    double latitude,
  ) {
    return latitude >= 0
        ? UtmHemisphere.north
        : UtmHemisphere.south;
  }

  double _degToRad(double degrees) {
    return degrees * math.pi / 180.0;
  }

  double _radToDeg(double radians) {
    return radians * 180.0 / math.pi;
  }
}
