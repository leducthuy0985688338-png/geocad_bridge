enum CoordinateReferenceSystemType {
  localCad,
  wgs84,
  utm,
}

enum UtmHemisphere {
  north,
  south,
}

class CoordinateReferenceSystem {
  final CoordinateReferenceSystemType type;
  final int? utmZone;
  final UtmHemisphere? hemisphere;
  final String name;

  const CoordinateReferenceSystem.localCad({
    this.name = 'CAD cục bộ / chưa xác định',
  })  : type = CoordinateReferenceSystemType.localCad,
        utmZone = null,
        hemisphere = null;

  const CoordinateReferenceSystem.wgs84({
    this.name = 'WGS84 (EPSG:4326)',
  })  : type = CoordinateReferenceSystemType.wgs84,
        utmZone = null,
        hemisphere = null;

  const CoordinateReferenceSystem.utm({
    required this.utmZone,
    required this.hemisphere,
    this.name = 'UTM',
  }) : type = CoordinateReferenceSystemType.utm;

  bool get isLocalCad =>
      type == CoordinateReferenceSystemType.localCad;

  bool get isWgs84 =>
      type == CoordinateReferenceSystemType.wgs84;

  bool get isUtm =>
      type == CoordinateReferenceSystemType.utm;

  bool get isValid {
    switch (type) {
      case CoordinateReferenceSystemType.localCad:
      case CoordinateReferenceSystemType.wgs84:
        return true;

      case CoordinateReferenceSystemType.utm:
        final zone = utmZone;
        return zone != null &&
            zone >= 1 &&
            zone <= 60 &&
            hemisphere != null;
    }
  }

  String get displayName {
    switch (type) {
      case CoordinateReferenceSystemType.localCad:
        return name;

      case CoordinateReferenceSystemType.wgs84:
        return 'WGS84 (EPSG:4326)';

      case CoordinateReferenceSystemType.utm:
        final zone = utmZone;
        final hemi =
            hemisphere == UtmHemisphere.south ? 'S' : 'N';
        return zone == null
            ? 'UTM chưa xác định'
            : 'UTM Zone $zone$hemi';
    }
  }

  int? get epsgCode {
    if (isWgs84) {
      return 4326;
    }

    final zone = utmZone;
    final hemi = hemisphere;

    if (!isUtm ||
        zone == null ||
        hemi == null ||
        zone < 1 ||
        zone > 60) {
      return null;
    }

    return hemi == UtmHemisphere.north
        ? 32600 + zone
        : 32700 + zone;
  }

  Map<String, String> toProperties() {
    final result = <String, String>{
      'crsType': type.name,
      'crsName': name,
    };

    final zone = utmZone;
    final hemi = hemisphere;

    if (zone != null) {
      result['utmZone'] = zone.toString();
    }

    if (hemi != null) {
      result['utmHemisphere'] = hemi.name;
    }

    final epsg = epsgCode;
    if (epsg != null) {
      result['epsg'] = epsg.toString();
    }

    return result;
  }

  factory CoordinateReferenceSystem.fromProperties(
    Map<String, String> properties,
  ) {
    final typeName = properties['crsType'];

    if (typeName ==
        CoordinateReferenceSystemType.wgs84.name) {
      return const CoordinateReferenceSystem.wgs84();
    }

    if (typeName ==
        CoordinateReferenceSystemType.utm.name) {
      final zone =
          int.tryParse(properties['utmZone'] ?? '');
      final hemisphereName =
          properties['utmHemisphere'];

      if (zone != null &&
          zone >= 1 &&
          zone <= 60 &&
          hemisphereName != null) {
        return CoordinateReferenceSystem.utm(
          utmZone: zone,
          hemisphere:
              hemisphereName == UtmHemisphere.south.name
                  ? UtmHemisphere.south
                  : UtmHemisphere.north,
        );
      }
    }

    return const CoordinateReferenceSystem.localCad();
  }

  @override
  String toString() => displayName;
}
