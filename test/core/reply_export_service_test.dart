import 'package:briefai_germany/core/app_services.dart';
import 'package:briefai_germany/core/email_composer.dart';
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

  test('generated email keeps paragraphs and extracts German subject', () {
    final draft = prepareGeneratedEmail(
      fallbackSubject: 'Antwort: Inkasso-Schreiben',
      generatedBody:
          'Betreff: Widerspruch gegen die Forderung\n\n'
          'Sehr geehrte Damen und Herren,\n\n'
          'hiermit widerspreche ich der Forderung.\n\n'
          'Mit freundlichen Grüßen',
    );

    expect(draft.subject, 'Widerspruch gegen die Forderung');
    expect(draft.body, isNot(contains('Betreff:')));
    expect(
      draft.body,
      'Sehr geehrte Damen und Herren,\r\n\r\n'
      'hiermit widerspreche ich der Forderung.\r\n\r\n'
      'Mit freundlichen Grüßen',
    );
  });

  test('mailto URI preserves UTF-8 text, spaces and paragraph order', () {
    final draft = prepareGeneratedEmail(
      fallbackSubject: 'Antwort für Familienkasse',
      generatedBody: 'Sehr geehrte Damen und Herren,\n\nGrüße aus München.',
    );
    final uri = draft.toMailtoUri();

    expect(uri.toString(), contains('Antwort%20f%C3%BCr%20Familienkasse'));
    expect(uri.toString(), contains('%0D%0A%0D%0A'));
    expect(uri.queryParameters['subject'], draft.subject);
    expect(uri.queryParameters['body'], draft.body);
  });
}
