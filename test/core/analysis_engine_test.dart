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

  test('račun ne meša izdavaoca, primaoca i primaoca uplate', () {
    final result = engine.analyse(
      'Rechnungssteller: Muster Energie GmbH\n'
      'Rechnungsempfänger: Max Mustermann\n'
      'Zahlungsempfänger: Muster Energie Abrechnung GmbH\n'
      'Rechnungsnummer: RE-2026-123\n'
      'Leistungszeitraum: 01.06.2026 bis 30.06.2026\n'
      'Stromrechnung 84,50 EUR, fällig bis zum 15.08.2026.',
    );

    expect(result.senderName, 'Muster Energie GmbH');
    expect(result.recipientName, 'Max Mustermann');
    expect(result.paymentRecipient, 'Muster Energie Abrechnung GmbH');
    expect(result.documentType, 'Rechnung');
    expect(result.invoiceNumber, 'RE-2026-123');
    expect(result.servicePeriod, '01.06.2026 bis 30.06.2026');
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

  test('prepoznaje širok skup nemačkih institucija', () {
    const cases = <String, LetterCategory>{
      'Agentur für Arbeit: Bescheid über Arbeitslosengeld':
          LetterCategory.agenturFuerArbeit,
      'Ausländerbehörde: Unterlagen zum Aufenthaltstitel':
          LetterCategory.auslaenderbehoerde,
      'Bürgeramt: Termin für Ihren Personalausweis': LetterCategory.buergeramt,
      'Sozialamt: Bescheid über Grundsicherung': LetterCategory.sozialamt,
      'Jugendamt: Unterhaltsvorschuss und Beistandschaft':
          LetterCategory.jugendamt,
      'Wohngeldstelle: Wohngeldbescheid': LetterCategory.wohngeldstelle,
      'BAföG-Amt: Ausbildungsförderung bewilligt': LetterCategory.bafoegAmt,
      'Deutsche Rentenversicherung: Ihr Rentenbescheid':
          LetterCategory.rentenversicherung,
      'ARD ZDF Deutschlandradio Beitragsservice, Beitragsnummer 123':
          LetterCategory.rundfunkbeitrag,
      'Stadtwerke: Stromrechnung und Abschlagszahlung': LetterCategory.energy,
      'Inkasso: Mahnung wegen offener Forderung': LetterCategory.debtCollection,
      'Staatsanwaltschaft: Ermittlungsverfahren': LetterCategory.police,
      'Hauptzollamt: Schreiben der Zollverwaltung': LetterCategory.customs,
    };

    for (final entry in cases.entries) {
      expect(
        engine.analyse(entry.key).category,
        entry.value,
        reason: entry.key,
      );
    }
  });

  test('objašnjenje razlikuje vrstu radnje', () {
    final documents = engine.analyse(
      'Ausländerbehörde: Bitte reichen Sie Unterlagen und Nachweise '
      'bis zum 20.09.2026 ein.',
    );
    final payment = engine.analyse(
      'Stadtwerke: Mahnung. Offene Forderung 84,50 EUR ist fällig.',
    );
    final appointment = engine.analyse(
      'Bürgeramt: Termin zur persönlichen Vorsprache am 10.09.2026.',
    );

    expect(documents.title, contains('dokumenta'));
    expect(documents.suggestedAction, contains('potvrdu slanja'));
    expect(payment.title, contains('Plaćanje'));
    expect(payment.suggestedAction, contains('Ne plaćajte'));
    expect(appointment.title, contains('Termin'));
    expect(appointment.suggestedAction, contains('kalendar'));
  });

  test('objašnjava na svim podržanim jezicima', () {
    const expectedPhrases = <String, String>{
      'sr': 'Prepoznati pošiljalac',
      'hr': 'Prepoznati pošiljatelj',
      'bs': 'Prepoznati pošiljalac',
      'mk': 'Препознаен испраќач',
      'bg': 'Разпознат подател',
      'de': 'Erkannter Absender',
      'en': 'Recognized sender',
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

  test('opomena daje rizik i numerisane konkretne korake', () {
    final result = engine.analyse(
      'Stadtwerke Mahnung. Kundennummer A123456. Offene Forderung '
      '84,50 EUR ist bis zum 18.08.2026 fällig. Danach Inkasso.',
      language: 'sr',
    );

    expect(result.plainExplanation, contains('Rizik'));
    expect(result.plainExplanation, contains('A123456'));
    expect(result.suggestedAction, startsWith('1.'));
    expect(result.suggestedAction, contains('18.08.2026'));
    expect(result.suggestedAction, contains('4.'));
  });

  test('prepoznaje relativni rok za pravni lek u objašnjenju', () {
    final result = engine.analyse(
      'Bescheid mit Rechtsbehelfsbelehrung. Gegen diesen Bescheid kann '
      'innerhalb eines Monats nach Bekanntgabe Widerspruch erhoben werden.',
      language: 'sr',
    );

    expect(result.plainExplanation, contains('jednog meseca'));
    expect(result.plainExplanation, contains('Rechtsbehelfsbelehrung'));
  });
}
