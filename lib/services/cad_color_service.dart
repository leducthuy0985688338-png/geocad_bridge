class CadColorService {
  const CadColorService();

  String? resolveCanonicalColor({String? colorIndex, String? trueColor}) {
    final resolvedTrueColor = trueColorToHex(trueColor);
    if (resolvedTrueColor != null) {
      return resolvedTrueColor;
    }

    return aciToHex(colorIndex);
  }

  String? trueColorToHex(String? value) {
    if (value == null) return null;

    final parsed = int.tryParse(value.trim());
    if (parsed == null || parsed < 0 || parsed > 0xFFFFFF) {
      return null;
    }

    return _rgbToHex(
      (parsed >> 16) & 0xFF,
      (parsed >> 8) & 0xFF,
      parsed & 0xFF,
    );
  }

  String? aciToHex(String? value) {
    if (value == null) return null;

    final aci = int.tryParse(value.trim());
    if (aci == null || aci < 1 || aci > 255) {
      return null;
    }

    if (aci <= 9) {
      return _basicAciColors[aci];
    }

    if (aci >= 250) {
      return _grayscaleAciColors[aci - 250];
    }

    final offset = aci - 10;
    final hueGroup = offset ~/ 10;
    final shade = offset % 10;

    final hue = hueGroup * 15.0;
    final saturation = shade.isEven ? 1.0 : 0.5;

    final valueIndex = shade ~/ 2;
    final brightness = _shadeBrightness[valueIndex];

    final rgb = _hsvToRgb(hue: hue, saturation: saturation, value: brightness);

    return _rgbToHex(rgb.$1, rgb.$2, rgb.$3);
  }

  static const List<String?> _basicAciColors = [
    null,
    '#FF0000',
    '#FFFF00',
    '#00FF00',
    '#00FFFF',
    '#0000FF',
    '#FF00FF',
    '#FFFFFF',
    '#808080',
    '#C0C0C0',
  ];

  static const List<String> _grayscaleAciColors = [
    '#333333',
    '#505050',
    '#696969',
    '#828282',
    '#BEBEBE',
    '#FFFFFF',
  ];

  static const List<double> _shadeBrightness = [1.0, 1.0, 0.65, 0.65, 0.5];

  (int, int, int) _hsvToRgb({
    required double hue,
    required double saturation,
    required double value,
  }) {
    final chroma = value * saturation;
    final huePrime = hue / 60.0;
    final x = chroma * (1 - ((huePrime % 2) - 1).abs());

    double red;
    double green;
    double blue;

    if (huePrime < 1) {
      red = chroma;
      green = x;
      blue = 0;
    } else if (huePrime < 2) {
      red = x;
      green = chroma;
      blue = 0;
    } else if (huePrime < 3) {
      red = 0;
      green = chroma;
      blue = x;
    } else if (huePrime < 4) {
      red = 0;
      green = x;
      blue = chroma;
    } else if (huePrime < 5) {
      red = x;
      green = 0;
      blue = chroma;
    } else {
      red = chroma;
      green = 0;
      blue = x;
    }

    final match = value - chroma;

    return (
      ((red + match) * 255).round(),
      ((green + match) * 255).round(),
      ((blue + match) * 255).round(),
    );
  }

  String _rgbToHex(int red, int green, int blue) {
    String channel(int value) => value
        .clamp(0, 255)
        .toInt()
        .toRadixString(16)
        .padLeft(2, '0')
        .toUpperCase();

    return '#${channel(red)}${channel(green)}${channel(blue)}';
  }
}
