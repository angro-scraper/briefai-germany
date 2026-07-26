import '../../core/domain.dart';

class AnalysisEngine {
  const AnalysisEngine();

  LetterAnalysis analyse(String text) {
    final normalized = text.toLowerCase();
    final category = _categoryFor(normalized);
    final deadline = _deadlineFor(text);
    final amount = RegExp(
      r'(?:€|eur)\s?([0-9.,]+)|([0-9.,]+)\s?(?:€|eur)',
      caseSensitive: false,
    ).firstMatch(text)?.group(0);
    final urgency =
        deadline != null && deadline.difference(DateTime.now()).inDays <= 7
        ? Urgency.high
        : deadline != null
        ? Urgency.medium
        : Urgency.low;
    final heading = switch (category) {
      LetterCategory.finanzamt => 'Zahtev poreske uprave',
      LetterCategory.jobcenter => 'Obaveštenje Jobcentera',
      LetterCategory.krankenkasse => 'Poruka zdravstvenog osiguranja',
      LetterCategory.court => 'Pravno obaveštenje',
      _ => 'Službeno pismo: potrebno je proveriti detalje',
    };
    return LetterAnalysis(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: heading,
      plainExplanation:
          'Pismo je prepoznato kao ${category.label}. Pročitajte zahtev i sačuvajte svu prateću dokumentaciju. ${deadline == null ? 'Nije pronađen jasan rok; proverite original.' : 'Pronađen je rok, zato reagujte na vreme.'}',
      category: category,
      urgency: urgency,
      suggestedAction:
          'Pripremite tražena dokumenta, proverite podatke i pošaljite odgovor pisanim putem. Ako je sadržaj nejasan, obratite se savetovalištu ili nadležnoj instituciji.',
      createdAt: DateTime.now(),
      deadline: deadline,
      amount: amount,
      sourceText: text,
    );
  }

  LetterCategory _categoryFor(String text) {
    if (text.contains('finanzamt') || text.contains('steuer')) {
      return LetterCategory.finanzamt;
    }
    if (text.contains('jobcenter') || text.contains('bürgergeld')) {
      return LetterCategory.jobcenter;
    }
    if (text.contains('krankenkasse') ||
        text.contains('aok') ||
        text.contains('tk ')) {
      return LetterCategory.krankenkasse;
    }
    if (text.contains('gericht') || text.contains('amtsgericht')) {
      return LetterCategory.court;
    }
    if (text.contains('versicherung')) {
      return LetterCategory.insurance;
    }
    if (text.contains('bank') || text.contains('sparkasse')) {
      return LetterCategory.bank;
    }
    if (text.contains('vermieter') || text.contains('miete')) {
      return LetterCategory.landlord;
    }
    if (text.contains('schule')) {
      return LetterCategory.school;
    }
    return LetterCategory.other;
  }

  DateTime? _deadlineFor(String text) {
    final match = RegExp(
      r'\b(\d{1,2})[./](\d{1,2})[./](\d{4})\b',
    ).firstMatch(text);
    if (match == null) {
      return null;
    }
    return DateTime(
      int.parse(match.group(3)!),
      int.parse(match.group(2)!),
      int.parse(match.group(1)!),
    );
  }
}
