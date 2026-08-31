import 'package:flutter_test/flutter_test.dart';
import 'package:autocad_googleearth/services/cad_color_service.dart';

void main() {
  const service = CadColorService();

  group('CadColorService True Color', () {
    test('converts decimal True Color to canonical RGB hex', () {
      expect(service.trueColorToHex('16711680'), '#FF0000');
      expect(service.trueColorToHex('65280'), '#00FF00');
      expect(service.trueColorToHex('255'), '#0000FF');
      expect(service.trueColorToHex('16777215'), '#FFFFFF');
      expect(service.trueColorToHex('0'), '#000000');
    });

    test('rejects invalid True Color values', () {
      expect(service.trueColorToHex(null), isNull);
      expect(service.trueColorToHex(''), isNull);
      expect(service.trueColorToHex('invalid'), isNull);
      expect(service.trueColorToHex('-1'), isNull);
      expect(service.trueColorToHex('16777216'), isNull);
    });

    test('trims True Color input', () {
      expect(service.trueColorToHex(' 16711680 '), '#FF0000');
    });
  });

  group('CadColorService ACI', () {
    test('maps primary ACI colors', () {
      expect(service.aciToHex('1'), '#FF0000');
      expect(service.aciToHex('2'), '#FFFF00');
      expect(service.aciToHex('3'), '#00FF00');
      expect(service.aciToHex('4'), '#00FFFF');
      expect(service.aciToHex('5'), '#0000FF');
      expect(service.aciToHex('6'), '#FF00FF');
      expect(service.aciToHex('7'), '#FFFFFF');
    });

    test('maps basic gray ACI colors', () {
      expect(service.aciToHex('8'), '#808080');
      expect(service.aciToHex('9'), '#C0C0C0');
    });

    test('maps representative ACI palette colors', () {
      expect(service.aciToHex('10'), '#FF0000');
      expect(service.aciToHex('20'), '#FF4000');
      expect(service.aciToHex('30'), '#FF8000');
      expect(service.aciToHex('40'), '#FFBF00');
      expect(service.aciToHex('50'), '#FFFF00');
      expect(service.aciToHex('90'), '#00FF00');
      expect(service.aciToHex('130'), '#00FFFF');
      expect(service.aciToHex('170'), '#0000FF');
      expect(service.aciToHex('210'), '#FF00FF');
    });

    test('maps ACI grayscale range', () {
      expect(service.aciToHex('250'), '#333333');
      expect(service.aciToHex('251'), '#505050');
      expect(service.aciToHex('252'), '#696969');
      expect(service.aciToHex('253'), '#828282');
      expect(service.aciToHex('254'), '#BEBEBE');
      expect(service.aciToHex('255'), '#FFFFFF');
    });

    test('supports every explicit ACI color from 1 through 255', () {
      for (var aci = 1; aci <= 255; aci++) {
        final color = service.aciToHex('$aci');

        expect(
          color,
          matches(RegExp(r'^#[0-9A-F]{6}$')),
          reason: 'ACI $aci must resolve to canonical #RRGGBB',
        );
      }
    });

    test('rejects BYBLOCK BYLAYER negative and out-of-range ACI', () {
      expect(service.aciToHex('0'), isNull);
      expect(service.aciToHex('256'), isNull);
      expect(service.aciToHex('-1'), isNull);
      expect(service.aciToHex('257'), isNull);
      expect(service.aciToHex('invalid'), isNull);
      expect(service.aciToHex(null), isNull);
    });

    test('trims ACI input', () {
      expect(service.aciToHex(' 3 '), '#00FF00');
    });
  });

  group('CadColorService precedence', () {
    test('valid True Color wins over ACI', () {
      expect(
        service.resolveCanonicalColor(colorIndex: '3', trueColor: '16711680'),
        '#FF0000',
      );
    });

    test('falls back to ACI when True Color is missing', () {
      expect(service.resolveCanonicalColor(colorIndex: '3'), '#00FF00');
    });

    test('falls back to ACI when True Color is invalid', () {
      expect(
        service.resolveCanonicalColor(colorIndex: '5', trueColor: 'invalid'),
        '#0000FF',
      );
    });

    test('returns null when neither color is resolvable', () {
      expect(
        service.resolveCanonicalColor(colorIndex: '256', trueColor: '-1'),
        isNull,
      );
    });
  });
}
