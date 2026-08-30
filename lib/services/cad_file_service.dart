import 'package:file_picker/file_picker.dart';

import '../models/cad_document.dart';

class CadFileService {
  const CadFileService();

  /// Chọn một file AutoCAD.
  ///
  /// Hỗ trợ:
  /// - DWG
  /// - DXF
  Future<CadDocument?> pickCadFile() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: [
        'dwg',
        'dxf',
      ],
      dialogTitle: 'Chọn bản vẽ AutoCAD',
    );

    if (file == null) {
      return null;
    }

    return _createDocument(file);
  }

  /// Chọn nhiều file AutoCAD cùng lúc.
  ///
  /// FilePicker.pickFiles() trong file_picker 12.x
  /// mặc định cho phép chọn nhiều file.
  ///
  /// Hỗ trợ:
  /// - DWG
  /// - DXF
  Future<List<CadDocument>> pickCadFiles() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'dwg',
        'dxf',
      ],
      dialogTitle: 'Chọn nhiều bản vẽ AutoCAD',
    );

    if (files.isEmpty) {
      return const [];
    }

    final documents = <CadDocument>[];

    for (final file in files) {
      final document = _createDocument(file);

      if (document != null) {
        documents.add(document);
      }
    }

    return documents;
  }

  CadDocument? _createDocument(PlatformFile file) {
    final path = file.path;

    if (path == null || path.isEmpty) {
      return null;
    }

    final document = CadDocument.fromFile(
      name: file.name,
      path: path,
    );

    if (document.fileType == CadFileType.unknown) {
      return null;
    }

    return document;
  }
}