import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:briefai_germany/core/app_services.dart';
import 'package:briefai_germany/core/email_composer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generated reply produces a valid non-empty PDF', () async {
    final bytes = await ReplyExportService().createPdfBytes(
      title: 'BriefAI Germany',
      body: 'Poštovani,\n\nОвим оспоравам потраживање. Grüße aus München.',
    );

    expect(bytes.length, greaterThan(500));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('Word export is a valid editable OOXML document with Unicode text', () {
    final bytes = ReplyExportService().createWordBytes(
      title: 'Odgovor — München',
      body: 'Poštovani,\n\nТекст остаје читљив у Word-у. & <provera>',
    );
    final files = ZipDecoder().decodeBytes(bytes);
    final document = files.findFile('word/document.xml');

    expect(String.fromCharCodes(bytes.take(2)), 'PK');
    expect(document, isNotNull);
    final xml = utf8.decode(document!.content as List<int>);
    expect(xml, contains('Poštovani'));
    expect(xml, contains('Текст остаје читљив у Word-у.'));
    expect(xml, contains('&amp;'));
    expect(xml, contains('&lt;provera&gt;'));
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

  test('plain-text export removes formatting signs but keeps real letters', () {
    final exported = preparePlainTextForExport(
      '\uFEFF**Odgovor za porodicu**\u2028\u2028Poštovani, Grüße aus München.\u200B',
    );

    expect(exported, 'Odgovor za porodicu\n\nPoštovani, Grüße aus München.');
    expect(exported, isNot(contains('**')));
  });

  test('plain-text export recovers accidentally escaped paragraphs', () {
    expect(
      preparePlainTextForExport(r'Poštovani,\n\nOvo je odgovor.'),
      'Poštovani,\n\nOvo je odgovor.',
    );
  });
}
