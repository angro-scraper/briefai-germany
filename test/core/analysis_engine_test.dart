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
