import 'package:briefai_germany/core/app_services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generated reply produces a valid non-empty PDF', () async {
    final bytes = await ReplyExportService().createPdfBytes(
      title: 'BriefAI Germany',
      body:
          'Sehr geehrte Damen und Herren,\n\nhiermit widerspreche ich der Forderung.',
    );

    expect(bytes.length, greaterThan(500));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });
}
