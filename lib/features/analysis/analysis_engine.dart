import '../../core/domain.dart';

/// Private on-device fallback used when the AI backend is temporarily
/// unavailable. It never sends the OCR text off the device.
class AnalysisEngine {
  const AnalysisEngine();

  LetterAnalysis analyse(String text, {String language = 'sr', String? id}) {
    final locale = _supportedLocale(language);
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
    final copy = _copy[locale]!;
    final categoryName = _categoryName(category, locale);
    final title = switch (category) {
      LetterCategory.finanzamt => copy.finanzamtTitle,
      LetterCategory.jobcenter => copy.jobcenterTitle,
      LetterCategory.krankenkasse => copy.krankenkasseTitle,
      LetterCategory.court => copy.courtTitle,
      _ => copy.generalTitle,
    };
    return LetterAnalysis(
      id: id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      plainExplanation: copy.explanation(categoryName, deadline != null),
      category: category,
      urgency: urgency,
      suggestedAction: copy.action,
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
        text.contains(' tk ')) {
      return LetterCategory.krankenkasse;
    }
    if (text.contains('gericht') || text.contains('amtsgericht')) {
      return LetterCategory.court;
    }
    if (text.contains('versicherung')) return LetterCategory.insurance;
    if (text.contains('bank') || text.contains('sparkasse')) {
      return LetterCategory.bank;
    }
    if (text.contains('telekom') ||
        text.contains('vodafone') ||
        text.contains('o2')) {
      return LetterCategory.telecom;
    }
    if (text.contains('arbeitgeber') || text.contains('kündigung')) {
      return LetterCategory.employer;
    }
    if (text.contains('vermieter') || text.contains('miete')) {
      return LetterCategory.landlord;
    }
    if (text.contains('kindergarten') || text.contains('kita')) {
      return LetterCategory.kindergarten;
    }
    if (text.contains('schule')) return LetterCategory.school;
    return LetterCategory.other;
  }

  DateTime? _deadlineFor(String text) {
    final match = RegExp(
      r'\b(\d{1,2})[./](\d{1,2})[./](\d{2}|\d{4})\b',
    ).firstMatch(text);
    if (match == null) return null;
    var year = int.parse(match.group(3)!);
    if (year < 100) year += 2000;
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(1)!);
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    return DateTime(year, month, day);
  }
}

String _supportedLocale(String value) {
  final locale = value.toLowerCase().split(RegExp('[-_]')).first;
  return _copy.containsKey(locale) ? locale : 'sr';
}

String _categoryName(LetterCategory category, String locale) {
  const names = <String, List<String>>{
    'sr': [
      'poreska uprava',
      'zdravstveno osiguranje',
      'Jobcenter',
      'banka',
      'osiguranje',
      'telekom',
      'poslodavac',
      'stanodavac',
      'škola',
      'vrtić',
      'sud',
      'druga institucija',
    ],
    'hr': [
      'porezna uprava',
      'zdravstveno osiguranje',
      'Jobcenter',
      'banka',
      'osiguranje',
      'telekom',
      'poslodavac',
      'stanodavac',
      'škola',
      'vrtić',
      'sud',
      'druga institucija',
    ],
    'bs': [
      'porezna uprava',
      'zdravstveno osiguranje',
      'Jobcenter',
      'banka',
      'osiguranje',
      'telekom',
      'poslodavac',
      'stanodavac',
      'škola',
      'vrtić',
      'sud',
      'druga institucija',
    ],
    'mk': [
      'даночна управа',
      'здравствено осигурување',
      'Jobcenter',
      'банка',
      'осигурување',
      'телеком',
      'работодавач',
      'сопственик на стан',
      'училиште',
      'градинка',
      'суд',
      'друга институција',
    ],
    'bg': [
      'данъчна служба',
      'здравна каса',
      'Jobcenter',
      'банка',
      'застраховател',
      'телеком',
      'работодател',
      'наемодател',
      'училище',
      'детска градина',
      'съд',
      'друга институция',
    ],
    'de': [
      'Finanzamt',
      'Krankenkasse',
      'Jobcenter',
      'Bank',
      'Versicherung',
      'Telekommunikationsanbieter',
      'Arbeitgeber',
      'Vermieter',
      'Schule',
      'Kindergarten',
      'Gericht',
      'andere Stelle',
    ],
    'en': [
      'tax office',
      'health insurer',
      'Jobcenter',
      'bank',
      'insurer',
      'telecom provider',
      'employer',
      'landlord',
      'school',
      'kindergarten',
      'court',
      'another institution',
    ],
  };
  return names[locale]![category.index];
}

typedef _Explanation = String Function(String category, bool hasDeadline);

class _LocalCopy {
  const _LocalCopy({
    required this.finanzamtTitle,
    required this.jobcenterTitle,
    required this.krankenkasseTitle,
    required this.courtTitle,
    required this.generalTitle,
    required this.explanation,
    required this.action,
  });

  final String finanzamtTitle;
  final String jobcenterTitle;
  final String krankenkasseTitle;
  final String courtTitle;
  final String generalTitle;
  final _Explanation explanation;
  final String action;
}

final _copy = <String, _LocalCopy>{
  'sr': _LocalCopy(
    finanzamtTitle: 'Zahtev poreske uprave',
    jobcenterTitle: 'Obaveštenje Jobcentera',
    krankenkasseTitle: 'Poruka zdravstvenog osiguranja',
    courtTitle: 'Pravno obaveštenje',
    generalTitle: 'Službeno pismo koje treba proveriti',
    explanation: (category, hasDeadline) =>
        'Pismo je poslato od strane: $category. Proverite šta se od vas traži. ${hasDeadline ? 'Pronađen je datum koji može biti rok, zato reagujte na vreme.' : 'Jasan rok nije pronađen; proverite originalno pismo.'}',
    action:
        'Pripremite tražena dokumenta, proverite lične podatke i odgovorite pisanim putem. Za pravni ili finansijski rizik obratite se stručnom savetovalištu.',
  ),
  'hr': _LocalCopy(
    finanzamtTitle: 'Zahtjev porezne uprave',
    jobcenterTitle: 'Obavijest Jobcentera',
    krankenkasseTitle: 'Poruka zdravstvenog osiguranja',
    courtTitle: 'Pravna obavijest',
    generalTitle: 'Službeno pismo koje treba provjeriti',
    explanation: (category, hasDeadline) =>
        'Pismo je poslao: $category. Provjerite što se od vas traži. ${hasDeadline ? 'Pronađen je datum koji može biti rok, zato reagirajte na vrijeme.' : 'Jasan rok nije pronađen; provjerite izvorno pismo.'}',
    action:
        'Pripremite tražene dokumente, provjerite osobne podatke i odgovorite pisanim putem. Za pravni ili financijski rizik obratite se stručnom savjetovalištu.',
  ),
  'bs': _LocalCopy(
    finanzamtTitle: 'Zahtjev porezne uprave',
    jobcenterTitle: 'Obavijest Jobcentera',
    krankenkasseTitle: 'Poruka zdravstvenog osiguranja',
    courtTitle: 'Pravno obavještenje',
    generalTitle: 'Službeno pismo koje treba provjeriti',
    explanation: (category, hasDeadline) =>
        'Pismo je poslao: $category. Provjerite šta se od vas traži. ${hasDeadline ? 'Pronađen je datum koji može biti rok, zato reagujte na vrijeme.' : 'Jasan rok nije pronađen; provjerite originalno pismo.'}',
    action:
        'Pripremite tražene dokumente, provjerite lične podatke i odgovorite pisanim putem. Za pravni ili finansijski rizik obratite se stručnom savjetovalištu.',
  ),
  'mk': _LocalCopy(
    finanzamtTitle: 'Барање од даночната управа',
    jobcenterTitle: 'Известување од Jobcenter',
    krankenkasseTitle: 'Порака од здравственото осигурување',
    courtTitle: 'Правно известување',
    generalTitle: 'Службено писмо што треба да се провери',
    explanation: (category, hasDeadline) =>
        'Писмото е испратено од: $category. Проверете што се бара од вас. ${hasDeadline ? 'Пронајден е датум што може да биде рок, затоа реагирајте навреме.' : 'Не е пронајден јасен рок; проверете го оригиналното писмо.'}',
    action:
        'Подгответе ги бараните документи, проверете ги личните податоци и одговорете писмено. За правен или финансиски ризик обратете се во стручно советувалиште.',
  ),
  'bg': _LocalCopy(
    finanzamtTitle: 'Искане от данъчната служба',
    jobcenterTitle: 'Известие от Jobcenter',
    krankenkasseTitle: 'Съобщение от здравната каса',
    courtTitle: 'Правно известие',
    generalTitle: 'Официално писмо за проверка',
    explanation: (category, hasDeadline) =>
        'Писмото е изпратено от: $category. Проверете какво се изисква от вас. ${hasDeadline ? 'Открита е дата, която може да е краен срок, затова реагирайте навреме.' : 'Не е открит ясен срок; проверете оригиналното писмо.'}',
    action:
        'Подгответе исканите документи, проверете личните данни и отговорете писмено. При правен или финансов риск потърсете професионална консултация.',
  ),
  'de': _LocalCopy(
    finanzamtTitle: 'Anforderung des Finanzamts',
    jobcenterTitle: 'Mitteilung des Jobcenters',
    krankenkasseTitle: 'Nachricht der Krankenkasse',
    courtTitle: 'Rechtliche Mitteilung',
    generalTitle: 'Behördliches Schreiben zur Prüfung',
    explanation: (category, hasDeadline) =>
        'Das Schreiben stammt von: $category. Prüfen Sie, was von Ihnen verlangt wird. ${hasDeadline ? 'Ein Datum wurde erkannt und kann eine Frist sein; reagieren Sie rechtzeitig.' : 'Keine eindeutige Frist erkannt; prüfen Sie das Original.'}',
    action:
        'Stellen Sie die angeforderten Unterlagen zusammen, prüfen Sie Ihre Daten und antworten Sie schriftlich. Holen Sie bei rechtlichen oder finanziellen Risiken fachlichen Rat ein.',
  ),
  'en': _LocalCopy(
    finanzamtTitle: 'Request from the tax office',
    jobcenterTitle: 'Jobcenter notice',
    krankenkasseTitle: 'Health insurance message',
    courtTitle: 'Legal notice',
    generalTitle: 'Official letter requiring review',
    explanation: (category, hasDeadline) =>
        'The letter was sent by: $category. Check what it asks you to do. ${hasDeadline ? 'A date was detected and may be a deadline, so respond in time.' : 'No clear deadline was detected; check the original letter.'}',
    action:
        'Prepare the requested documents, verify your personal details and reply in writing. Seek professional advice for legal or financial risks.',
  ),
};
