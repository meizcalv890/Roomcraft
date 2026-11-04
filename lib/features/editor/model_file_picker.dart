import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

class PickedModelFile {
  const PickedModelFile(this.name, this.bytes);

  final String name;
  final Uint8List bytes;
}

/// Memilih satu file model dari penyimpanan. Null bila dibatalkan.
/// Melempar [FormatException] ('too_big') bila file melebihi 40 MB.
/// Ditulis untuk file_picker 12.x.
Future<PickedModelFile?> pickModelFile() async {
  final file = await FilePicker.pickFile();

  if (file == null) return null;

  final size = await file.length();

  if (size > 40 * 1024 * 1024) throw const FormatException('too_big');

  return PickedModelFile(file.name, await file.readAsBytes());
}
