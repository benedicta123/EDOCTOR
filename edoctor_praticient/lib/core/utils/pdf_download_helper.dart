import 'dart:typed_data';
import 'pdf_download_stub.dart'
    if (dart.library.html) 'pdf_download_web.dart';

class PdfDownloadHelper {
  PdfDownloadHelper._();

  static Future<void> download(Uint8List bytes, String filename) async {
    await downloadOrOpenPdfBytes(bytes, filename);
  }
}
