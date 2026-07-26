import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

Future<void> prepareLocalOcr() async {}

Future<String> recognizeLocalDocument({
  required Uint8List bytes,
  required String mimeType,
  required String? path,
}) async {
  if (mimeType == 'application/pdf') {
    throw StateError(
      'PDF OCR je dostupan u web/PWA verziji. Za mobilni omot koristite web aplikaciju.',
    );
  }
  if (path == null) {
    throw StateError('Lokalni OCR ne može da otvori izabranu sliku.');
  }
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final result = await recognizer.processImage(InputImage.fromFilePath(path));
    return result.text.trim();
  } finally {
    await recognizer.close();
  }
}
