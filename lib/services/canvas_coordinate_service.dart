import '../models/coordinate_reference_system.dart';
import '../models/map_feature.dart';
import 'coordinate_transform_service.dart';

enum CanvasCoordinateStatus {
  success,
  incompatibleCrs,
  invalidCrs,
  invalidCoordinate,
}

class CanvasCoordinateResult {
  final CanvasCoordinateStatus status;
  final MapCoordinate? coordinate;

  const CanvasCoordinateResult.success(this.coordinate)
    : status = CanvasCoordinateStatus.success,
      assert(coordinate != null);

  const CanvasCoordinateResult.failure(CanvasCoordinateStatus status)
    : assert(status != CanvasCoordinateStatus.success),
      status = status,
      coordinate = null;

  bool get isSuccess => status == CanvasCoordinateStatus.success;
}

class CanvasCoordinateService {
  final CoordinateTransformService coordinateTransformService;

  const CanvasCoordinateService({
    this.coordinateTransformService = const CoordinateTransformService(),
  });

  bool isSameCrs(
    CoordinateReferenceSystem first,
    CoordinateReferenceSystem second,
  ) {
    return first.type == second.type &&
        first.utmZone == second.utmZone &&
        first.hemisphere == second.hemisphere;
  }

  bool isCompatible({
    required CoordinateReferenceSystem sourceCrs,
    required CoordinateReferenceSystem canvasCrs,
  }) {
    if (!sourceCrs.isValid || !canvasCrs.isValid) return false;
    if (sourceCrs.isLocalCad || canvasCrs.isLocalCad) {
      return sourceCrs.isLocalCad && canvasCrs.isLocalCad;
    }
    return true;
  }

  CanvasCoordinateResult toCanvas({
    required MapCoordinate coordinate,
    required CoordinateReferenceSystem sourceCrs,
    required CoordinateReferenceSystem canvasCrs,
  }) {
    return _transform(
      coordinate: coordinate,
      sourceCrs: sourceCrs,
      targetCrs: canvasCrs,
    );
  }

  CanvasCoordinateResult fromCanvas({
    required MapCoordinate coordinate,
    required CoordinateReferenceSystem canvasCrs,
    required CoordinateReferenceSystem targetCrs,
  }) {
    return _transform(
      coordinate: coordinate,
      sourceCrs: canvasCrs,
      targetCrs: targetCrs,
    );
  }

  CanvasCoordinateResult _transform({
    required MapCoordinate coordinate,
    required CoordinateReferenceSystem sourceCrs,
    required CoordinateReferenceSystem targetCrs,
  }) {
    if (!sourceCrs.isValid || !targetCrs.isValid) {
      return const CanvasCoordinateResult.failure(
        CanvasCoordinateStatus.invalidCrs,
      );
    }
    if (!isCompatible(sourceCrs: sourceCrs, canvasCrs: targetCrs)) {
      return const CanvasCoordinateResult.failure(
        CanvasCoordinateStatus.incompatibleCrs,
      );
    }
    if (!coordinate.x.isFinite ||
        !coordinate.y.isFinite ||
        (coordinate.z != null && !coordinate.z!.isFinite)) {
      return const CanvasCoordinateResult.failure(
        CanvasCoordinateStatus.invalidCoordinate,
      );
    }

    if (isSameCrs(sourceCrs, targetCrs)) {
      return CanvasCoordinateResult.success(
        MapCoordinate(x: coordinate.x, y: coordinate.y, z: coordinate.z),
      );
    }

    try {
      final geographic = coordinateTransformService.toWgs84(
        coordinate: coordinate,
        sourceCrs: sourceCrs,
      );
      return CanvasCoordinateResult.success(
        coordinateTransformService.fromWgs84(
          coordinate: geographic,
          targetCrs: targetCrs,
        ),
      );
    } on ArgumentError {
      return const CanvasCoordinateResult.failure(
        CanvasCoordinateStatus.invalidCoordinate,
      );
    } on StateError {
      return const CanvasCoordinateResult.failure(
        CanvasCoordinateStatus.invalidCoordinate,
      );
    }
  }
}
