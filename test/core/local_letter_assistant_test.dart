import 'package:briefai_germany/core/domain.dart';
import 'package:briefai_germany/features/assistant/local_letter_assistant.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const assistant = LocalLetterAssistant();
  final letter = LetterAnalysis(
    id: 'test',
    title: 'Plaćanje ili opomena — Energieversorger',
    plainExplanation: 'Pismo je opomena za neplaćeni račun.',
    category: LetterCategory.energy,
    urgency: Urgency.high,
    suggestedAction: '1. Proverite račun. 2. Kontaktirajte pošiljaoca.',
    createdAt: DateTime(2026, 7, 26),
    deadline: DateTime(2026, 8, 5),
    amount: '84,50 EUR',
    sourceText:
        'Mahnung: 84,50 EUR ist bis zum 05.08.2026 fällig. Danach Inkasso.',
  );

  test('rok, plaćanje i sledeći koraci daju različite direktne odgovore', () {
    final deadline = assistant.answer(
      question: 'Koji je rok?',
      language: 'sr',
      letter: letter,
    );
    final payment = assistant.answer(
      question: 'Da li moram da platim?',
      language: 'sr',
      letter: letter,
    );
    final action = assistant.answer(
      question: 'Šta da uradim dalje?',
      language: 'sr',
      letter: letter,
    );

    expect(deadline, contains('05.08.2026'));
    expect(payment, contains('84,50 EUR'));
    expect(action, contains('Konkretni sledeći koraci'));
    expect({deadline, payment, action}, hasLength(3));
  });

  test('ne izmišlja rok ili iznos kada nisu prepoznati', () {
    final informational = LetterAnalysis(
      id: 'info',
      title: 'Obaveštenje',
      plainExplanation: 'Informativno pismo.',
      category: LetterCategory.insurance,
      urgency: Urgency.low,
      suggestedAction: 'Sačuvajte pismo.',
      createdAt: DateTime(2026, 7, 26),
      sourceText: 'Allgemeine Information.',
    );

    expect(
      assistant.answer(
        question: 'Koji je rok?',
        language: 'sr',
        letter: informational,
      ),
      contains('Nisam pouzdano'),
    );
    expect(
      assistant.answer(
        question: 'Koliko treba da platim?',
        language: 'sr',
        letter: informational,
      ),
      contains('Nisam pouzdano'),
    );
  });
}
