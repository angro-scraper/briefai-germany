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
    final family = category == LetterCategory.familienkasse
        ? _familienkasseAnalysis(normalized, locale, deadline: deadline)
        : null;
    final title = switch (category) {
      LetterCategory.finanzamt => copy.finanzamtTitle,
      LetterCategory.jobcenter => copy.jobcenterTitle,
      LetterCategory.krankenkasse => copy.krankenkasseTitle,
      LetterCategory.court => copy.courtTitle,
      LetterCategory.familienkasse => family!.title,
      _ => copy.generalTitle,
    };
    return LetterAnalysis(
      id: id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      plainExplanation:
          family?.explanation ??
          copy.explanation(categoryName, deadline != null),
      category: category,
      urgency: urgency,
      suggestedAction: family?.action ?? copy.action,
      createdAt: DateTime.now(),
      deadline: deadline,
      amount: amount,
      sourceText: text,
    );
  }

  LetterCategory _categoryFor(String text) {
    if (text.contains('familienkasse') ||
        text.contains('kindergeld') ||
        text.contains('kinderzuschlag') ||
        text.contains('kindergeldnummer') ||
        text.contains('kindergeld-nr')) {
      return LetterCategory.familienkasse;
    }
    if (text.contains('finanzamt') ||
        text.contains('steuerbescheid') ||
        text.contains('einkommensteuer') ||
        text.contains('umsatzsteuer') ||
        text.contains('lohnsteuer')) {
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
      r'(?:bis(?:\s+spätestens)?\s+(?:zum\s+)?|spätestens\s+(?:am\s+)?|frist(?:\s+\w+){0,4}\s+bis\s+)(\d{1,2})[./](\d{1,2})[./](\d{2}|\d{4})\b',
      caseSensitive: false,
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
      'Familienkasse',
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
      'Familienkasse',
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
      'Familienkasse',
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
      'Familienkasse',
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
      'Familienkasse',
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
      'Familienkasse',
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
      'Familienkasse',
      'another institution',
    ],
  };
  return names[locale]![category.index];
}

enum _FamilyIntent { documents, repayment, decision, information }

class _FamilyAnalysis {
  const _FamilyAnalysis({
    required this.title,
    required this.explanation,
    required this.action,
  });

  final String title;
  final String explanation;
  final String action;
}

class _FamilyLocale {
  const _FamilyLocale({
    required this.documentsTitle,
    required this.repaymentTitle,
    required this.decisionTitle,
    required this.informationTitle,
    required this.intro,
    required this.documentsExplanation,
    required this.repaymentExplanation,
    required this.decisionExplanation,
    required this.informationExplanation,
    required this.deadlinePrefix,
    required this.documentsAction,
    required this.repaymentAction,
    required this.decisionAction,
    required this.informationAction,
  });

  final String documentsTitle;
  final String repaymentTitle;
  final String decisionTitle;
  final String informationTitle;
  final String intro;
  final String documentsExplanation;
  final String repaymentExplanation;
  final String decisionExplanation;
  final String informationExplanation;
  final String deadlinePrefix;
  final String documentsAction;
  final String repaymentAction;
  final String decisionAction;
  final String informationAction;
}

_FamilyAnalysis _familienkasseAnalysis(
  String text,
  String locale, {
  required DateTime? deadline,
}) {
  final intent =
      text.contains('rückforder') ||
          text.contains('zurückzahl') ||
          text.contains('überzahlung') ||
          text.contains('zu unrecht') ||
          text.contains('aufhebungsbescheid')
      ? _FamilyIntent.repayment
      : text.contains('unterlagen') ||
            text.contains('nachweis') ||
            text.contains('mitwirkung') ||
            text.contains('einzureichen') ||
            text.contains('vorzulegen') ||
            text.contains('fehlend') ||
            text.contains('antwortbogen')
      ? _FamilyIntent.documents
      : text.contains('festsetzung') ||
            text.contains('bewilligt') ||
            text.contains('abgelehnt') ||
            text.contains('bescheid')
      ? _FamilyIntent.decision
      : _FamilyIntent.information;
  final copy = _familyCopy[locale]!;
  final title = switch (intent) {
    _FamilyIntent.documents => copy.documentsTitle,
    _FamilyIntent.repayment => copy.repaymentTitle,
    _FamilyIntent.decision => copy.decisionTitle,
    _FamilyIntent.information => copy.informationTitle,
  };
  final purpose = switch (intent) {
    _FamilyIntent.documents => copy.documentsExplanation,
    _FamilyIntent.repayment => copy.repaymentExplanation,
    _FamilyIntent.decision => copy.decisionExplanation,
    _FamilyIntent.information => copy.informationExplanation,
  };
  final action = switch (intent) {
    _FamilyIntent.documents => copy.documentsAction,
    _FamilyIntent.repayment => copy.repaymentAction,
    _FamilyIntent.decision => copy.decisionAction,
    _FamilyIntent.information => copy.informationAction,
  };
  final deadlineText = deadline == null
      ? ''
      : ' ${copy.deadlinePrefix} '
            '${deadline.day.toString().padLeft(2, '0')}.'
            '${deadline.month.toString().padLeft(2, '0')}.'
            '${deadline.year}.';
  return _FamilyAnalysis(
    title: title,
    explanation: '${copy.intro} $purpose$deadlineText',
    action: action,
  );
}

const _familyCopy = <String, _FamilyLocale>{
  'sr': _FamilyLocale(
    documentsTitle: 'Familienkasse traži dokumenta za Kindergeld',
    repaymentTitle: 'Familienkasse proverava povraćaj Kindergelda',
    decisionTitle: 'Odluka Familienkasse o Kindergeldu',
    informationTitle: 'Obaveštenje Familienkasse o Kindergeldu',
    intro:
        'Ovo je pismo Familienkasse (Bundesagentur für Arbeit), institucije za Kindergeld i Kinderzuschlag — nije Finanzamt.',
    documentsExplanation:
        'Prepoznati tekst pokazuje da traže dokumenta ili podatke kako bi proverili vaše pravo ili nastavak isplate. Tačan spisak dokaza proverite u originalnom pismu.',
    repaymentExplanation:
        'Prepoznati tekst ukazuje na moguću izmenu odluke, preplatu ili zahtev za povraćaj. Proverite navedeni period, razlog i iznos u originalu.',
    decisionExplanation:
        'Pismo izgleda kao odluka o odobravanju, odbijanju ili promeni Kindergelda/Kinderzuschlaga. Proverite period važenja i obračun.',
    informationExplanation:
        'Pismo sadrži informacije o vašem predmetu za Kindergeld ili Kinderzuschlag. U originalu proverite predmet i da li se od vas traži odgovor.',
    deadlinePrefix: 'Izričito naveden rok je',
    documentsAction:
        '1. Zapišite Kindergeldnummer. 2. Napravite kopije tačno navedenih dokumenata. 3. Pošaljite ih preko portala Familienkasse ili na adresu iz pisma pre roka. 4. Sačuvajte potvrdu slanja.',
    repaymentAction:
        '1. Proverite period, iznos, obrazloženje i Kindergeldnummer. 2. Ne ignorišite pismo. 3. Ako nešto nije jasno, kontaktirajte Familienkasse ili savetovalište pre uplate ili odgovora.',
    decisionAction:
        '1. Uporedite ime, Kindergeldnummer, period i iznos sa svojim podacima. 2. Sačuvajte rešenje. 3. Odgovorite samo ako pismo traži radnju ili su podaci netačni.',
    informationAction:
        'Proverite naslov predmeta, Kindergeldnummer i označene zahteve. Ako nema zahteva ni roka, sačuvajte pismo uz ostalu dokumentaciju.',
  ),
  'hr': _FamilyLocale(
    documentsTitle: 'Familienkasse traži dokumente za Kindergeld',
    repaymentTitle: 'Familienkasse provjerava povrat Kindergelda',
    decisionTitle: 'Odluka Familienkasse o Kindergeldu',
    informationTitle: 'Obavijest Familienkasse o Kindergeldu',
    intro:
        'Ovo je pismo Familienkasse (Bundesagentur für Arbeit), ustanove za Kindergeld i Kinderzuschlag — nije Finanzamt.',
    documentsExplanation:
        'Prepoznati tekst pokazuje da traže dokumente ili podatke radi provjere prava ili nastavka isplate. Točan popis dokaza provjerite u izvornom pismu.',
    repaymentExplanation:
        'Prepoznati tekst upućuje na moguću izmjenu odluke, preplatu ili zahtjev za povrat. Provjerite navedeno razdoblje, razlog i iznos.',
    decisionExplanation:
        'Pismo izgleda kao odluka o odobravanju, odbijanju ili promjeni Kindergelda/Kinderzuschlaga. Provjerite razdoblje i obračun.',
    informationExplanation:
        'Pismo sadrži informacije o vašem predmetu za Kindergeld ili Kinderzuschlag. Provjerite traži li se odgovor.',
    deadlinePrefix: 'Izričito navedeni rok je',
    documentsAction:
        '1. Zapišite Kindergeldnummer. 2. Kopirajte točno navedene dokumente. 3. Pošaljite ih preko portala Familienkasse ili na adresu iz pisma prije roka. 4. Sačuvajte potvrdu slanja.',
    repaymentAction:
        '1. Provjerite razdoblje, iznos, obrazloženje i Kindergeldnummer. 2. Ne ignorirajte pismo. 3. Ako nešto nije jasno, kontaktirajte Familienkasse ili savjetovalište prije uplate ili odgovora.',
    decisionAction:
        'Usporedite ime, Kindergeldnummer, razdoblje i iznos sa svojim podacima, sačuvajte rješenje i odgovorite ako se to traži ili su podaci netočni.',
    informationAction:
        'Provjerite predmet, Kindergeldnummer i označene zahtjeve. Ako nema zahtjeva ni roka, spremite pismo uz ostalu dokumentaciju.',
  ),
  'bs': _FamilyLocale(
    documentsTitle: 'Familienkasse traži dokumente za Kindergeld',
    repaymentTitle: 'Familienkasse provjerava povrat Kindergelda',
    decisionTitle: 'Odluka Familienkasse o Kindergeldu',
    informationTitle: 'Obavještenje Familienkasse o Kindergeldu',
    intro:
        'Ovo je pismo Familienkasse (Bundesagentur für Arbeit), institucije za Kindergeld i Kinderzuschlag — nije Finanzamt.',
    documentsExplanation:
        'Prepoznati tekst pokazuje da traže dokumente ili podatke radi provjere prava ili nastavka isplate. Tačan spisak dokaza provjerite u originalnom pismu.',
    repaymentExplanation:
        'Prepoznati tekst ukazuje na moguću izmjenu odluke, preplatu ili zahtjev za povrat. Provjerite navedeni period, razlog i iznos.',
    decisionExplanation:
        'Pismo izgleda kao odluka o odobravanju, odbijanju ili promjeni Kindergelda/Kinderzuschlaga. Provjerite period i obračun.',
    informationExplanation:
        'Pismo sadrži informacije o vašem predmetu za Kindergeld ili Kinderzuschlag. Provjerite da li se traži odgovor.',
    deadlinePrefix: 'Izričito navedeni rok je',
    documentsAction:
        '1. Zapišite Kindergeldnummer. 2. Kopirajte tačno navedene dokumente. 3. Pošaljite ih preko portala Familienkasse ili na adresu iz pisma prije roka. 4. Sačuvajte potvrdu slanja.',
    repaymentAction:
        '1. Provjerite period, iznos, obrazloženje i Kindergeldnummer. 2. Ne ignorišite pismo. 3. Ako nešto nije jasno, kontaktirajte Familienkasse ili savjetovalište prije uplate ili odgovora.',
    decisionAction:
        'Uporedite ime, Kindergeldnummer, period i iznos sa svojim podacima, sačuvajte rješenje i odgovorite ako se to traži ili su podaci netačni.',
    informationAction:
        'Provjerite predmet, Kindergeldnummer i označene zahtjeve. Ako nema zahtjeva ni roka, sačuvajte pismo uz ostalu dokumentaciju.',
  ),
  'mk': _FamilyLocale(
    documentsTitle: 'Familienkasse бара документи за Kindergeld',
    repaymentTitle: 'Familienkasse проверува враќање на Kindergeld',
    decisionTitle: 'Одлука на Familienkasse за Kindergeld',
    informationTitle: 'Известување од Familienkasse за Kindergeld',
    intro:
        'Ова е писмо од Familienkasse (Bundesagentur für Arbeit), институцијата за Kindergeld и Kinderzuschlag — не е Finanzamt.',
    documentsExplanation:
        'Препознаениот текст покажува дека бараат документи или податоци за проверка на правото или продолжување на исплатата. Точниот список проверете го во оригиналот.',
    repaymentExplanation:
        'Текстот укажува на можна промена на одлуката, преплата или барање за враќање. Проверете ги периодот, причината и износот.',
    decisionExplanation:
        'Писмото изгледа како одлука за одобрување, одбивање или промена на Kindergeld/Kinderzuschlag. Проверете ги периодот и пресметката.',
    informationExplanation:
        'Писмото содржи информации за вашиот предмет за Kindergeld или Kinderzuschlag. Проверете дали се бара одговор.',
    deadlinePrefix: 'Изрично наведениот рок е',
    documentsAction:
        '1. Запишете ја Kindergeldnummer. 2. Подгответе копии од точно наведените документи. 3. Испратете ги преку порталот или на адресата од писмото пред рокот. 4. Чувајте потврда.',
    repaymentAction:
        'Проверете ги периодот, износот, образложението и Kindergeldnummer. Не го игнорирајте писмото; ако нешто не е јасно, контактирајте ја Familienkasse или советувалиште.',
    decisionAction:
        'Споредете ги името, Kindergeldnummer, периодот и износот со вашите податоци. Чувајте ја одлуката и одговорете ако тоа се бара или има грешка.',
    informationAction:
        'Проверете ги предметот, Kindergeldnummer и означените барања. Ако нема барање или рок, зачувајте го писмото.',
  ),
  'bg': _FamilyLocale(
    documentsTitle: 'Familienkasse иска документи за Kindergeld',
    repaymentTitle: 'Familienkasse проверява връщане на Kindergeld',
    decisionTitle: 'Решение на Familienkasse за Kindergeld',
    informationTitle: 'Известие от Familienkasse за Kindergeld',
    intro:
        'Това е писмо от Familienkasse (Bundesagentur für Arbeit), институцията за Kindergeld и Kinderzuschlag — не е Finanzamt.',
    documentsExplanation:
        'Разпознатият текст показва, че се искат документи или данни за проверка на правото или продължаване на плащането. Проверете точния списък в оригинала.',
    repaymentExplanation:
        'Текстът сочи възможна промяна на решение, надплащане или искане за връщане. Проверете периода, причината и сумата.',
    decisionExplanation:
        'Писмото изглежда като решение за одобрение, отказ или промяна на Kindergeld/Kinderzuschlag. Проверете периода и изчислението.',
    informationExplanation:
        'Писмото съдържа информация за вашия случай за Kindergeld или Kinderzuschlag. Проверете дали се изисква отговор.',
    deadlinePrefix: 'Изрично посоченият срок е',
    documentsAction:
        'Запишете Kindergeldnummer, подгответе копия на точно посочените документи, изпратете ги през портала или на адреса от писмото преди срока и пазете потвърждение.',
    repaymentAction:
        'Проверете периода, сумата, мотивите и Kindergeldnummer. Не пренебрегвайте писмото; при неяснота се свържете с Familienkasse или консултант.',
    decisionAction:
        'Сравнете името, Kindergeldnummer, периода и сумата с вашите данни. Пазете решението и отговорете, ако това се изисква или има грешка.',
    informationAction:
        'Проверете предмета, Kindergeldnummer и отбелязаните искания. Ако няма искане или срок, запазете писмото.',
  ),
  'de': _FamilyLocale(
    documentsTitle: 'Familienkasse fordert Unterlagen zum Kindergeld an',
    repaymentTitle: 'Familienkasse prüft eine Kindergeld-Rückforderung',
    decisionTitle: 'Kindergeld-Entscheidung der Familienkasse',
    informationTitle: 'Mitteilung der Familienkasse zum Kindergeld',
    intro:
        'Dieses Schreiben stammt von der Familienkasse (Bundesagentur für Arbeit), die Kindergeld und Kinderzuschlag bearbeitet — nicht vom Finanzamt.',
    documentsExplanation:
        'Der erkannte Text deutet auf angeforderte Unterlagen oder Angaben zur Prüfung des Anspruchs oder der weiteren Zahlung hin. Prüfen Sie die genaue Liste im Original.',
    repaymentExplanation:
        'Der Text deutet auf eine mögliche Änderung, Überzahlung oder Rückforderung hin. Prüfen Sie Zeitraum, Begründung und Betrag im Original.',
    decisionExplanation:
        'Das Schreiben scheint eine Bewilligung, Ablehnung oder Änderung von Kindergeld/Kinderzuschlag mitzuteilen. Prüfen Sie Zeitraum und Berechnung.',
    informationExplanation:
        'Das Schreiben enthält Informationen zu Ihrem Kindergeld- oder Kinderzuschlag-Vorgang. Prüfen Sie, ob eine Antwort verlangt wird.',
    deadlinePrefix: 'Die ausdrücklich genannte Frist ist der',
    documentsAction:
        'Notieren Sie die Kindergeldnummer, kopieren Sie genau die genannten Unterlagen, senden Sie diese vor der Frist über das Portal oder an die Briefadresse und bewahren Sie den Nachweis auf.',
    repaymentAction:
        'Prüfen Sie Zeitraum, Betrag, Begründung und Kindergeldnummer. Ignorieren Sie das Schreiben nicht; klären Sie Unklarheiten vor Zahlung oder Antwort mit der Familienkasse oder einer Beratungsstelle.',
    decisionAction:
        'Vergleichen Sie Name, Kindergeldnummer, Zeitraum und Betrag mit Ihren Daten. Bewahren Sie den Bescheid auf und reagieren Sie bei Aufforderung oder falschen Angaben.',
    informationAction:
        'Prüfen Sie Betreff, Kindergeldnummer und markierte Anforderungen. Ohne Aufforderung oder Frist legen Sie das Schreiben zu Ihren Unterlagen.',
  ),
  'en': _FamilyLocale(
    documentsTitle: 'Familienkasse requests documents for child benefit',
    repaymentTitle: 'Familienkasse is reviewing a child-benefit repayment',
    decisionTitle: 'Familienkasse child-benefit decision',
    informationTitle: 'Familienkasse child-benefit notice',
    intro:
        'This letter is from Familienkasse (Federal Employment Agency), which handles Kindergeld and Kinderzuschlag — not from the tax office.',
    documentsExplanation:
        'The recognized text indicates a request for documents or information to verify eligibility or continue payments. Check the original for the exact list.',
    repaymentExplanation:
        'The text indicates a possible amended decision, overpayment, or repayment request. Check the stated period, reason, and amount.',
    decisionExplanation:
        'The letter appears to approve, reject, or change Kindergeld/Kinderzuschlag. Check the applicable period and calculation.',
    informationExplanation:
        'The letter contains information about your Kindergeld or Kinderzuschlag case. Check whether it asks for a response.',
    deadlinePrefix: 'The explicitly stated deadline is',
    documentsAction:
        'Note the Kindergeldnummer, copy exactly the listed documents, send them through the Familienkasse portal or to the address in the letter before the deadline, and keep proof of submission.',
    repaymentAction:
        'Check the period, amount, reason, and Kindergeldnummer. Do not ignore the letter; clarify uncertainties with Familienkasse or an advice centre before paying or replying.',
    decisionAction:
        'Compare the name, Kindergeldnummer, period, and amount with your records. Keep the decision and respond if requested or if details are incorrect.',
    informationAction:
        'Check the subject, Kindergeldnummer, and highlighted requests. If there is no request or deadline, keep the letter with your records.',
  ),
};

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
