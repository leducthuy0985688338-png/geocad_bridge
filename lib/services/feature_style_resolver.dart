import 'package:flutter/material.dart';

import '../models/map_feature.dart';

class ResolvedFeatureStyle {
  final Color? strokeColor;
  final double? strokeWidth;
  final Color? fillColor;
  final bool fill;
  final bool outline;

  const ResolvedFeatureStyle({
    required this.strokeColor,
    required this.strokeWidth,
    required this.fillColor,
    required this.fill,
    required this.outline,
  });
}

class FeatureStyleResolver {
  const FeatureStyleResolver();

  ResolvedFeatureStyle resolve(MapFeature feature) {
    final properties = feature.properties;

    final strokeColor = _resolveColor(
      properties['style.strokeColor'],
      properties['style.strokeOpacity'],
    );

    final fillColor = _resolveColor(
      properties['style.fillColor'],
      properties['style.fillOpacity'],
    );

    return ResolvedFeatureStyle(
      strokeColor: strokeColor,
      strokeWidth: _resolveWidth(properties['style.strokeWidth']),
      fillColor: fillColor,
      fill: _resolveFlag(properties['style.fill'], fallback: true),
      outline: _resolveFlag(properties['style.outline'], fallback: true),
    );
  }

  Color? _resolveColor(String? rawColor, String? rawOpacity) {
    final color = _parseColor(rawColor);
    if (color == null) {
      return null;
    }

    final opacity = _parseOpacity(rawOpacity) ?? 1.0;

    return color.withValues(alpha: opacity);
  }

  Color? _parseColor(String? raw) {
    if (raw == null) {
      return null;
    }

    final value = raw.trim();

    if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value)) {
      return null;
    }

    final rgb = int.tryParse(value.substring(1), radix: 16);
    if (rgb == null) {
      return null;
    }

    return Color(0xFF000000 | rgb);
  }

  double? _parseOpacity(String? raw) {
    if (raw == null) {
      return null;
    }

    final value = double.tryParse(raw.trim());

    if (value == null || !value.isFinite || value < 0 || value > 1) {
      return null;
    }

    return value;
  }

  double? _resolveWidth(String? raw) {
    if (raw == null) {
      return null;
    }

    final value = double.tryParse(raw.trim());

    if (value == null || !value.isFinite || value < 0) {
      return null;
    }

    return value;
  }

  bool _resolveFlag(String? raw, {required bool fallback}) {
    switch (raw?.trim()) {
      case '0':
        return false;
      case '1':
        return true;
      default:
        return fallback;
    }
  }
}
