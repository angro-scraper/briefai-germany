Future<bool> nativeStoreAvailable() async => false;

Future<Map<String, dynamic>> nativeStoreRequest(
  String action, [
  Map<String, dynamic> payload = const {},
]) {
  throw UnsupportedError('Native Store most nije dostupan.');
}
