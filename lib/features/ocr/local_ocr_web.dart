import 'dart:js_interop';
import 'dart:typed_data';

@JS('briefAiRecognizeDocument')
external JSPromise<JSString> _recognizeDocument(
  JSUint8Array bytes,
  JSString mimeType,
);

Future<String> recognizeLocalDocument({
  required Uint8List bytes,
  required String mimeType,
  required String? path,
}) async {
  final result = await _recognizeDocument(bytes.toJS, mimeType.toJS).toDart;
  return result.toDart.trim();
}
