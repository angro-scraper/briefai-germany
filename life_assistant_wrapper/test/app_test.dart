import 'package:flutter_test/flutter_test.dart';
import 'package:life_assistant_germany/main.dart';

void main() {
  test('creates the assistant application shell', () {
    expect(const LifeAssistantApp(), isA<LifeAssistantApp>());
  });
}
