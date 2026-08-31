import 'dart:typed_data';

/// Web stub: file path access is not supported on the web.
/// Callers must pass file bytes directly instead of a path.
Future<Uint8List> readFileBytes(String path) async {
  throw UnsupportedError(
      'File path access is not supported on the web. Pass file bytes instead.');
}
