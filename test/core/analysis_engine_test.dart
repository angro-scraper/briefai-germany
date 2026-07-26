import 'package:briefai_germany/core/domain.dart';
import 'package:briefai_germany/features/analysis/analysis_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = AnalysisEngine();

  test('prepoznaje Finanzamt, iznos i rok', () {
    final result = engine.analyse(
      'Finanzamt: Bitte antworten Sie bis zum 05.08.2026. Betrag 120,00 EUR',
    );
    expect(result.category, LetterCategory.finanzamt);
    expect(result.deadline, DateTime(2026, 8, 5));
    expect(result.amount, isNotNull);
  });

  test('pismo bez datuma je niskog prioriteta', () {
    final result = engine.analyse(
      'Allgemeine Information von der Versicherung',
    );
    expect(result.category, LetterCategory.insurance);
    expect(result.urgency, Urgency.low);
  });

  test('Familienkasse sa Steuer-ID nije Finanzamt i daje konkretne korake', () {
    final result = engine.analyse(
      'Bundesagentur für Arbeit - Familienkasse. '
      'Kindergeldnummer 123FK456789. Für die Prüfung Ihres Anspruchs '
      'benötigen wir die folgenden Unterlagen und Ihre steuerliche '
      'Identifikationsnummer. Bitte reichen Sie die Nachweise bis zum '
      '15.08.2026 ein.',
      language: 'sr',
    );

    expect(result.category, LetterCategory.familienkasse);
    expect(result.title, contains('dokumenta'));
    expect(result.plainExplanation, contains('nije Finanzamt'));
    expect(result.plainExplanation, contains('Kindergeld'));
    expect(result.suggestedAction, contains('Kindergeldnummer'));
    expect(result.deadline, DateTime(2026, 8, 15));
  });

  test('datum dokumenta bez oznake roka nije proglašen za rok', () {
    final result = engine.analyse(
      'Familienkasse Bayern Nord, Nürnberg, 05.08.2026. '
      'Mitteilung zu Ihrer Kindergeldnummer.',
    );

    expect(result.category, LetterCategory.familienkasse);
    expect(result.deadline, isNull);
  });

  test('objašnjava na svim podržanim jezicima', () {
    const expectedPhrases = <String, String>{
      'sr': 'Pismo je poslato',
      'hr': 'Pismo je poslao',
      'bs': 'Pismo je poslao',
      'mk': 'Писмото е испратено',
      'bg': 'Писмото е изпратено',
      'de': 'Das Schreiben stammt',
      'en': 'The letter was sent',
    };
    for (final entry in expectedPhrases.entries) {
      final result = engine.analyse(
        'Mitteilung der Krankenkasse bis 05.08.2026',
        language: entry.key,
      );
      expect(result.plainExplanation, contains(entry.value));
      expect(result.category, LetterCategory.krankenkasse);
    }
  });
}
