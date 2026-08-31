import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';

import '../models/coordinate_reference_system.dart';
import '../services/coordinate_transform_service.dart';

enum CoordinateConversionDirection { utmToWgs84, wgs84ToUtm }

class CoordinateConverterDialog extends StatefulWidget {
  const CoordinateConverterDialog({super.key});

  @override
  State<CoordinateConverterDialog> createState() =>
      _CoordinateConverterDialogState();
}

class _CoordinateConverterDialogState extends State<CoordinateConverterDialog> {
  final CoordinateTransformService _service =
      const CoordinateTransformService();

  final TextEditingController _firstController = TextEditingController();

  final TextEditingController _secondController = TextEditingController();

  CoordinateConversionDirection _direction =
      CoordinateConversionDirection.utmToWgs84;

  int _utmZone = 48;
  UtmHemisphere _hemisphere = UtmHemisphere.north;

  String? _resultTitle;
  String? _resultLine1;
  String? _resultLine2;
  String? _resultCrs;
  String? _errorMessage;

  @override
  void dispose() {
    _firstController.dispose();
    _secondController.dispose();
    super.dispose();
  }

  bool get _isUtmToWgs84 =>
      _direction == CoordinateConversionDirection.utmToWgs84;

  CoordinateReferenceSystem get _utmCrs =>
      CoordinateReferenceSystem.utm(utmZone: _utmZone, hemisphere: _hemisphere);

  void _changeDirection(CoordinateConversionDirection direction) {
    if (_direction == direction) {
      return;
    }

    setState(() {
      _direction = direction;
      _firstController.clear();
      _secondController.clear();
      _clearResult();
    });
  }

  void _swapDirection() {
    _changeDirection(
      _isUtmToWgs84
          ? CoordinateConversionDirection.wgs84ToUtm
          : CoordinateConversionDirection.utmToWgs84,
    );
  }

  void _clearResult() {
    _resultTitle = null;
    _resultLine1 = null;
    _resultLine2 = null;
    _resultCrs = null;
    _errorMessage = null;
  }

  void _convert() {
    final l10n = AppLocalizations.of(context);
    final first = double.tryParse(_firstController.text.trim());
    final second = double.tryParse(_secondController.text.trim());

    if (first == null || second == null) {
      setState(() {
        _clearResult();
        _errorMessage = l10n.coordinateInputRequired;
      });
      return;
    }

    try {
      if (_isUtmToWgs84) {
        final result = _service.utmToWgs84(
          easting: first,
          northing: second,
          zone: _utmZone,
          hemisphere: _hemisphere,
        );

        setState(() {
          _clearResult();
          _resultTitle = l10n.wgs84Result;
          _resultLine1 = 'Longitude: ${result.longitude.toStringAsFixed(8)}°';
          _resultLine2 = 'Latitude: ${result.latitude.toStringAsFixed(8)}°';
          _resultCrs = 'EPSG:4326';
        });
      } else {
        final longitude = first;
        final latitude = second;

        if (!_service.isValidWgs84(longitude: longitude, latitude: latitude)) {
          throw ArgumentError(l10n.longitudeLatitudeRange);
        }

        final suggestedZone = _service.suggestedUtmZone(longitude);
        final suggestedHemisphere = _service.suggestedHemisphere(latitude);

        final result = _service.wgs84ToUtm(
          longitude: longitude,
          latitude: latitude,
          zone: suggestedZone,
          hemisphere: suggestedHemisphere,
        );

        final resultCrs = CoordinateReferenceSystem.utm(
          utmZone: suggestedZone,
          hemisphere: suggestedHemisphere,
        );

        setState(() {
          _utmZone = suggestedZone;
          _hemisphere = suggestedHemisphere;
          _clearResult();
          _resultTitle = l10n.utmResult;
          _resultLine1 = 'Easting (X): ${result.x.toStringAsFixed(3)} m';
          _resultLine2 = 'Northing (Y): ${result.y.toStringAsFixed(3)} m';
          _resultCrs = '${resultCrs.displayName} • EPSG:${resultCrs.epsgCode}';
        });
      }
    } catch (error) {
      setState(() {
        _clearResult();
        _errorMessage = _friendlyError(error);
      });
    }
  }

  String _friendlyError(Object error) {
    if (error is ArgumentError) {
      final message = error.message;
      return message?.toString() ??
          AppLocalizations.of(context).invalidCoordinates;
    }

    if (error is StateError) {
      return error.message;
    }

    return AppLocalizations.of(context).coordinateConversionFailed;
  }

  @override
  Widget build(BuildContext context) {
    final crs = _utmCrs;
    final l10n = AppLocalizations.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.sync_alt,
                    color: Color(0xFF1565C0),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.coordinateConverter,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          l10n.utmWgs84,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.close,
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              SegmentedButton<CoordinateConversionDirection>(
                segments: const [
                  ButtonSegment(
                    value: CoordinateConversionDirection.utmToWgs84,
                    icon: Icon(Icons.map_outlined),
                    label: Text('UTM → WGS84'),
                  ),
                  ButtonSegment(
                    value: CoordinateConversionDirection.wgs84ToUtm,
                    icon: Icon(Icons.public),
                    label: Text('WGS84 → UTM'),
                  ),
                ],
                selected: {_direction},
                onSelectionChanged: (selection) {
                  _changeDirection(selection.first);
                },
              ),
              const SizedBox(height: 18),
              _CrsCard(
                title: _isUtmToWgs84
                    ? l10n.sourceCoordinateSystem
                    : l10n.targetCoordinateSystem,
                crsName: crs.displayName,
                epsgCode: crs.epsgCode,
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _utmZone,
                        decoration: InputDecoration(
                          labelText: l10n.utmZone,
                          border: OutlineInputBorder(),
                        ),
                        items: List.generate(
                          60,
                          (index) => DropdownMenuItem(
                            value: index + 1,
                            child: Text('Zone ${index + 1}'),
                          ),
                        ),
                        onChanged: _isUtmToWgs84
                            ? (value) {
                                if (value == null) return;
                                setState(() {
                                  _utmZone = value;
                                  _clearResult();
                                });
                              }
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<UtmHemisphere>(
                        initialValue: _hemisphere,
                        decoration: InputDecoration(
                          labelText: l10n.hemisphere,
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: UtmHemisphere.north,
                            child: Text(l10n.north),
                          ),
                          DropdownMenuItem(
                            value: UtmHemisphere.south,
                            child: Text(l10n.south),
                          ),
                        ],
                        onChanged: _isUtmToWgs84
                            ? (value) {
                                if (value == null) return;
                                setState(() {
                                  _hemisphere = value;
                                  _clearResult();
                                });
                              }
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              if (!_isUtmToWgs84) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.autoUtmHint,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _firstController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: InputDecoration(
                        labelText: _isUtmToWgs84 ? 'Easting (X)' : 'Longitude',
                        suffixText: _isUtmToWgs84 ? 'm' : '°',
                        border: const OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _convert(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _secondController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: InputDecoration(
                        labelText: _isUtmToWgs84 ? 'Northing (Y)' : 'Latitude',
                        suffixText: _isUtmToWgs84 ? 'm' : '°',
                        border: const OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _convert(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _swapDirection,
                    icon: const Icon(Icons.swap_horiz),
                    label: Text(l10n.swapDirection),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _convert,
                    icon: const Icon(Icons.calculate_outlined),
                    label: Text(l10n.convert),
                  ),
                ],
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_resultTitle != null) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFA5D6A7)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            color: Color(0xFF2E7D32),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _resultTitle!,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SelectableText(
                        _resultLine1!,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SelectableText(
                        _resultLine2!,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _resultCrs!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Text(
                l10n.cadLocalConversionNote,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CrsCard extends StatelessWidget {
  final String title;
  final String crsName;
  final int? epsgCode;
  final Widget child;

  const _CrsCard({
    required this.title,
    required this.crsName,
    required this.epsgCode,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDE3E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 3),
          Text(
            epsgCode == null ? crsName : '$crsName • EPSG:$epsgCode',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
