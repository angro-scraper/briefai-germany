import 'package:briefai_germany/core/domain.dart';
import 'package:briefai_germany/core/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('subscription plans expose the commercial monthly quotas', () {
    expect(
      kSubscriptionPlans.map((plan) => plan.monthlyAnalysisLimit).toList(),
      [50, 100, 150],
    );
    expect(kSubscriptionPlans.map((plan) => plan.fallbackPrice).toList(), [
      '9,90 €',
      '19,90 €',
      '29,90 €',
    ]);
    expect(kSubscriptionPlans.map((plan) => plan.productId).toSet().length, 3);
  });

  test('letter analysis round-trips the server data contract', () {
    final analysis = LetterAnalysis.fromMap(
      id: 'letter-1',
      map: {
        'title': 'Finanzamt zahtev',
        'plainExplanation': 'Pošaljite dokumenta.',
        'senderName': 'Muster Energie GmbH',
        'recipientName': 'Max Mustermann',
        'paymentRecipient': 'Muster Energie GmbH',
        'documentType': 'Rechnung',
        'invoiceNumber': 'RE-2026-123',
        'servicePeriod': '01.06.2026–30.06.2026',
        'totalAmount': '84,50 EUR',
        'paymentReference': 'RE-2026-123',
        'category': 'Finanzamt',
        'urgency': 'HIGH',
        'deadline': '2026-08-05',
        'paymentDueDate': '2026-08-05',
        'isPaymentObligation': true,
        'amounts': ['120,00 EUR'],
        'suggestedAction': 'Odgovorite do roka.',
        'status': 'inProgress',
        'sourceText': 'Bitte antworten.',
      },
    );

    expect(analysis.category, LetterCategory.finanzamt);
    expect(analysis.urgency, Urgency.high);
    expect(analysis.deadline, DateTime(2026, 8, 5));
    expect(analysis.paymentDueDate, DateTime(2026, 8, 5));
    expect(analysis.isPaymentObligation, isTrue);
    expect(analysis.senderName, 'Muster Energie GmbH');
    expect(analysis.recipientName, 'Max Mustermann');
    expect(analysis.invoiceNumber, 'RE-2026-123');
    expect(analysis.amount, '84,50 EUR');
    expect(analysis.paymentReference, 'RE-2026-123');
    expect(analysis.toMap()['servicePeriod'], '01.06.2026–30.06.2026');
    expect(analysis.status, LetterStatus.inProgress);
    expect(analysis.toMap()['status'], 'inProgress');
  });

  test('local archive records reload when createdAt is an ISO string', () {
    final createdAt = DateTime.utc(2026, 7, 28, 19, 45);
    final restored = LetterAnalysis.fromMap(
      id: 'local-letter',
      map: {
        'title': 'Lokalno sačuvano pismo',
        'createdAt': createdAt.toIso8601String(),
        'category': 'Ostalo',
        'urgency': 'LOW',
        'suggestedAction': 'Sačuvajte dokument.',
        'status': 'newLetter',
      },
    );

    expect(restored.createdAt, createdAt);
    expect(restored.title, 'Lokalno sačuvano pismo');
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

  test('app state changes every supported interface language immediately', () {
    final state = AppState();

    for (final language in const ['hr', 'bs', 'mk', 'de', 'en', 'bg', 'sr']) {
      state.setLocale(language);
      expect(state.localeCode, language);
    }
  });

  test(
    'introductory plan includes five analyses before a paid plan is required',
    () {
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

      state.setFreeAnalysesUsed(4);

      expect(state.freeAnalysesUsed, 4);
      expect(state.canAnalyse, isTrue);
      state.setFreeAnalysesUsed(5);
      expect(state.canAnalyse, isFalse);
      state.setPremium(true);
      expect(state.canAnalyse, isTrue);
    },
  );

  test('generated reply retains separate letter and email variants', () {
    const reply = GeneratedReply(
      letter: 'Sehr geehrte Damen und Herren,',
      email: 'Betreff: Antwort auf Ihr Schreiben',
    );

    expect(reply.letter, startsWith('Sehr geehrte'));
    expect(reply.email, startsWith('Betreff:'));
  });
}
