enum CadFileType {
  dwg,
  dxf,
  unknown,
}

class CadDocument {
  final String name;
  final String path;
  final CadFileType fileType;

  const CadDocument({
    required this.name,
    required this.path,
    required this.fileType,
  });

  String get extension {
    switch (fileType) {
      case CadFileType.dwg:
        return 'DWG';
      case CadFileType.dxf:
        return 'DXF';
      case CadFileType.unknown:
        return 'UNKNOWN';
    }
  }

  bool get isDwg => fileType == CadFileType.dwg;

  bool get isDxf => fileType == CadFileType.dxf;

  static CadFileType detectFileType(String fileName) {
    final lowerCaseName = fileName.toLowerCase();

    if (lowerCaseName.endsWith('.dwg')) {
      return CadFileType.dwg;
    }

    if (lowerCaseName.endsWith('.dxf')) {
      return CadFileType.dxf;
    }

    return CadFileType.unknown;
  }

  factory CadDocument.fromFile({
    required String name,
    required String path,
  }) {
    return CadDocument(
      name: name,
      path: path,
      fileType: detectFileType(name),
    );
  }

  @override
  String toString() {
    return 'CadDocument('
        'name: $name, '
        'path: $path, '
        'fileType: $extension'
        ')';
  }
}