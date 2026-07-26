import 'dart:convert';
import 'dart:js_interop';

@JS('briefAiNativeStoreAvailable')
external JSBoolean _nativeStoreAvailable();

@JS('briefAiNativeStoreRequest')
external JSPromise<JSString> _nativeStoreRequest(
  JSString action,
  JSString payload,
);

Future<bool> nativeStoreAvailable() async => _nativeStoreAvailable().toDart;

Future<Map<String, dynamic>> nativeStoreRequest(
  String action, [
  Map<String, dynamic> payload = const {},
]) async {
  final response = await _nativeStoreRequest(
    action.toJS,
    jsonEncode(payload).toJS,
  ).toDart;
  final decoded = jsonDecode(response.toDart);
  if (decoded is! Map) {
    throw StateError('Native Store odgovor nema očekivani format.');
  }
  return Map<String, dynamic>.from(decoded);
}
