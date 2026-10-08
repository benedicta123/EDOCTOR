import 'dart:typed_data';
import 'file_download_stub.dart'
    if (dart.library.html) 'file_download_web.dart';

class FileDownloadHelper {
  FileDownloadHelper._();

  static Future<void> download({
    required Uint8List bytes,
    required String filename,
    String mimeType = 'text/csv;charset=utf-8',
  }) async {
    await downloadOrSaveBytes(bytes, filename, mimeType: mimeType);
  }
}
