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
}
