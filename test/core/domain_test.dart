import 'package:briefai_germany/core/domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('letter analysis round-trips the server data contract', () {
    final analysis = LetterAnalysis.fromMap(
      id: 'letter-1',
      map: {
        'title': 'Finanzamt zahtev',
        'plainExplanation': 'Pošaljite dokumenta.',
        'category': 'Finanzamt',
        'urgency': 'HIGH',
        'deadline': '2026-08-05',
        'amounts': ['120,00 EUR'],
        'suggestedAction': 'Odgovorite do roka.',
        'status': 'inProgress',
        'sourceText': 'Bitte antworten.',
      },
    );

    expect(analysis.category, LetterCategory.finanzamt);
    expect(analysis.urgency, Urgency.high);
    expect(analysis.deadline, DateTime(2026, 8, 5));
    expect(analysis.status, LetterStatus.inProgress);
    expect(analysis.toMap()['status'], 'inProgress');
  });

  test('app state replaces the local archive with synced archive', () {
    final state = AppState();
    state.addAnalysis(
      LetterAnalysis(
        id: 'old',
        title: 'Old',
        plainExplanation: '',
        category: LetterCategory.other,
        urgency: Urgency.low,
        suggestedAction: '',
        createdAt: DateTime(2026),
      ),
    );
    state.replaceLetters([
      LetterAnalysis(
        id: 'cloud',
        title: 'Cloud',
        plainExplanation: '',
        category: LetterCategory.bank,
        urgency: Urgency.medium,
        suggestedAction: '',
        createdAt: DateTime(2026),
      ),
    ]);

    expect(state.letters.single.id, 'cloud');
  });

  test('app state restores completed onboarding', () {
    final state = AppState();

    state.restoreOnboarding(true);

    expect(state.onboardingComplete, isTrue);
  });

  test('server quota replaces local free analysis counter', () {
    final state = AppState();
    state.addAnalysis(
      LetterAnalysis(
        id: 'local',
        title: 'Local',
        plainExplanation: '',
        category: LetterCategory.other,
        urgency: Urgency.low,
        suggestedAction: '',
        createdAt: DateTime(2026),
      ),
    );

    state.setFreeAnalysesUsed(2);

    expect(state.freeAnalysesUsed, 2);
    expect(state.canAnalyse, isFalse);
  });

  test('generated reply retains separate letter and email variants', () {
    const reply = GeneratedReply(
      letter: 'Sehr geehrte Damen und Herren,',
      email: 'Betreff: Antwort auf Ihr Schreiben',
    );

    expect(reply.letter, startsWith('Sehr geehrte'));
    expect(reply.email, startsWith('Betreff:'));
  });
}
