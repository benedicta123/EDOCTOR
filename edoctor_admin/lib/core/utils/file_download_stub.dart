import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

Future<void> downloadOrSaveBytes(
  Uint8List bytes,
  String filename, {
  String mimeType = 'application/octet-stream',
}) async {
  await FilePicker.saveFile(
    dialogTitle: 'Enregistrer la pièce justificative',
    fileName: filename,
    bytes: bytes,
    mimeType: mimeType,
  );
}

Future<bool> openBytesInNewTab(
  Uint8List bytes, {
  String mimeType = 'application/pdf',
}) async {
  try {
    final ext = mimeType.contains('pdf')
        ? 'pdf'
        : mimeType.contains('png')
            ? 'png'
            : 'jpg';
    final tempDir = Directory.systemTemp;
    final tempFile = File('${tempDir.path}${Platform.pathSeparator}edoctor_doc_${DateTime.now().millisecondsSinceEpoch}.$ext');
    await tempFile.writeAsBytes(bytes);
    if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', tempFile.path]);
      return true;
    } else if (Platform.isMacOS) {
      await Process.run('open', [tempFile.path]);
      return true;
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [tempFile.path]);
      return true;
    }
  } catch (_) {}
  return false;
}
