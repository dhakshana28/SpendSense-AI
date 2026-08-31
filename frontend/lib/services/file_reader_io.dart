import 'dart:io';
import 'dart:typed_data';

/// Reads file bytes from a filesystem path (IO platforms only).
Future<Uint8List> readFileBytes(String path) async {
  final f = File(path);
  if (!await f.exists()) {
    throw FileSystemException('File not found', path);
  }
  return f.readAsBytes();
}
