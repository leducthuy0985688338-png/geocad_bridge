import 'package:flutter_test/flutter_test.dart';

import 'package:autocad_googleearth/models/map_feature.dart';
import 'package:autocad_googleearth/services/feature_style_resolver.dart';

void main() {
  const resolver = FeatureStyleResolver();

  MapFeature featureWith(Map<String, String> properties) {
    return MapFeature(
      id: 'feature-1',
      type: MapFeatureType.line,
      name: 'Styled feature',
      coordinates: const [
        MapCoordinate(x: 0, y: 0),
        MapCoordinate(x: 10, y: 10),
      ],
      properties: properties,
    );
  }

  group('FeatureStyleResolver', () {
    test('resolves stroke color opacity and width', () {
      final style = resolver.resolve(
        featureWith({
          'style.strokeColor': '#336699',
          'style.strokeOpacity': '0.5',
          'style.strokeWidth': '2.5',
        }),
      );

      expect(style.strokeColor, isNotNull);
      expect(style.strokeColor!.r, closeTo(0x33 / 255, 0.0001));
      expect(style.strokeColor!.g, closeTo(0x66 / 255, 0.0001));
      expect(style.strokeColor!.b, closeTo(0x99 / 255, 0.0001));
      expect(style.strokeColor!.a, closeTo(0.5, 0.0001));
      expect(style.strokeWidth, 2.5);
    });

    test('resolves fill color opacity and binary flags', () {
      final style = resolver.resolve(
        featureWith({
          'style.fillColor': '#FF8000',
          'style.fillOpacity': '0.25',
          'style.fill': '0',
          'style.outline': '1',
        }),
      );

      expect(style.fillColor, isNotNull);
      expect(style.fillColor!.r, closeTo(1, 0.0001));
      expect(style.fillColor!.g, closeTo(0x80 / 255, 0.0001));
      expect(style.fillColor!.b, closeTo(0, 0.0001));
      expect(style.fillColor!.a, closeTo(0.25, 0.0001));
      expect(style.fill, isFalse);
      expect(style.outline, isTrue);
    });

    test('defaults opacity to fully opaque when color is valid', () {
      final style = resolver.resolve(
        featureWith({
          'style.strokeColor': '#123456',
          'style.fillColor': '#ABCDEF',
        }),
      );

      expect(style.strokeColor!.a, closeTo(1, 0.0001));
      expect(style.fillColor!.a, closeTo(1, 0.0001));
    });

    test('rejects invalid colors', () {
      final style = resolver.resolve(
        featureWith({'style.strokeColor': 'red', 'style.fillColor': '#12345'}),
      );

      expect(style.strokeColor, isNull);
      expect(style.fillColor, isNull);
    });

    test('ignores invalid opacity and falls back to opaque', () {
      final style = resolver.resolve(
        featureWith({
          'style.strokeColor': '#112233',
          'style.strokeOpacity': '1.5',
          'style.fillColor': '#445566',
          'style.fillOpacity': '-0.1',
        }),
      );

      expect(style.strokeColor!.a, closeTo(1, 0.0001));
      expect(style.fillColor!.a, closeTo(1, 0.0001));
    });

    test('rejects invalid stroke widths', () {
      expect(
        resolver.resolve(featureWith({'style.strokeWidth': '-1'})).strokeWidth,
        isNull,
      );

      expect(
        resolver
            .resolve(featureWith({'style.strokeWidth': 'invalid'}))
            .strokeWidth,
        isNull,
      );
    });

    test('accepts zero stroke width', () {
      final style = resolver.resolve(featureWith({'style.strokeWidth': '0'}));

      expect(style.strokeWidth, 0);
    });

    test('defaults fill and outline to enabled', () {
      final style = resolver.resolve(featureWith({}));

      expect(style.fill, isTrue);
      expect(style.outline, isTrue);
    });

    test('invalid fill and outline flags use enabled fallback', () {
      final style = resolver.resolve(
        featureWith({'style.fill': 'yes', 'style.outline': 'no'}),
      );

      expect(style.fill, isTrue);
      expect(style.outline, isTrue);
    });

    test('trims canonical style values', () {
      final style = resolver.resolve(
        featureWith({
          'style.strokeColor': ' #AABBCC ',
          'style.strokeOpacity': ' 0.75 ',
          'style.strokeWidth': ' 3.25 ',
          'style.fill': ' 1 ',
          'style.outline': ' 0 ',
        }),
      );

      expect(style.strokeColor, isNotNull);
      expect(style.strokeColor!.a, closeTo(0.75, 0.0001));
      expect(style.strokeWidth, 3.25);
      expect(style.fill, isTrue);
      expect(style.outline, isFalse);
    });
  });
}
