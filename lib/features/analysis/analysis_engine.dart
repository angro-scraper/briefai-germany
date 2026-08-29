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
    final totalAmount = RegExp(
      r'(?:gesamtbetrag|rechnungsbetrag|zahlbetrag|zu zahlen)\s*:?\s*((?:€|eur)\s?[0-9.,]+|[0-9.,]+\s?(?:€|eur))',
      caseSensitive: false,
    ).firstMatch(text)?.group(1);
    final amount =
        totalAmount ??
        RegExp(
          r'(?:€|eur)\s?([0-9.,]+)|([0-9.,]+)\s?(?:€|eur)',
          caseSensitive: false,
        ).firstMatch(text)?.group(0);
    final senderName = _labeledParty(text, const [
      'absender',
      'rechnungssteller',
      'rechnung von',
      'anbieter',
      'lieferant',
    ]);
    final recipientName = _labeledParty(text, const [
      'rechnungsempfänger',
      'rechnung an',
      'empfänger',
      'kunde',
      'kundin',
      'an',
    ]);
    final paymentRecipient = _labeledParty(text, const [
      'zahlungsempfänger',
      'kontoinhaber',
      'begünstigter',
    ]);
    final invoiceNumber = RegExp(
      r'(?:rechnungsnummer|rechnungs?[- ]?nr\.?|belegnummer)\s*:?\s*([A-Z0-9][A-Z0-9./-]+)',
      caseSensitive: false,
    ).firstMatch(text)?.group(1);
    final servicePeriod = RegExp(
      r'(?:leistungszeitraum|abrechnungszeitraum|zeitraum)\s*:?\s*([^\r\n]+)',
      caseSensitive: false,
    ).firstMatch(text)?.group(1)?.trim();
    final paymentReference = RegExp(
      r'(?:verwendungszweck|zahlungsreferenz|referenz)\s*:?\s*([^\r\n]+)',
      caseSensitive: false,
    ).firstMatch(text)?.group(1)?.trim();
    final paymentIban = RegExp(
      r'\b[A-Z]{2}\s?\d{2}(?:\s?[A-Z0-9]){11,30}\b',
      caseSensitive: false,
    ).firstMatch(text)?.group(0)?.replaceAll(RegExp(r'\s+'), ' ');
    final documentType = _documentType(normalized);
    final isPaymentObligation =
        amount != null &&
        _containsAny(normalized, const [
          'zu zahlen',
          'zahlbetrag',
          'fällig',
          'faellig',
          'rechnung',
          'mahnung',
          'zahlungserinnerung',
          'überweisen',
          'ueberweisen',
        ]);
    final urgency =
        deadline != null && deadline.difference(DateTime.now()).inDays <= 7
        ? Urgency.high
        : deadline != null
        ? Urgency.medium
        : Urgency.low;
    final categoryName = _categoryName(category, locale);
    final family = category == LetterCategory.familienkasse
        ? _familienkasseAnalysis(normalized, locale, deadline: deadline)
        : null;
    final general = family == null
        ? _genericAnalysis(
            normalized,
            locale,
            categoryName,
            originalText: text,
            deadline: deadline,
            amount: amount,
          )
        : null;
    return LetterAnalysis(
      id: id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: family?.title ?? general!.title,
      plainExplanation: family?.explanation ?? general!.explanation,
      category: category,
      urgency: urgency,
      suggestedAction: family?.action ?? general!.action,
      createdAt: DateTime.now(),
      senderName: senderName,
      recipientName: recipientName,
      paymentRecipient: paymentRecipient,
      documentType: documentType,
      invoiceNumber: invoiceNumber,
      servicePeriod: servicePeriod,
      paymentReference: paymentReference,
      paymentIban: paymentIban,
      deadline: deadline,
      paymentDueDate: isPaymentObligation ? deadline : null,
      isPaymentObligation: isPaymentObligation,
      amount: amount,
      sourceText: text,
    );
  }

  String? _labeledParty(String text, List<String> labels) {
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    for (var index = 0; index < lines.length; index++) {
      final lower = lines[index].toLowerCase();
      for (final label in labels) {
        if (lower == label || lower == '$label:') {
          return index + 1 < lines.length ? lines[index + 1] : null;
        }
        final match = RegExp(
          '^${RegExp.escape(label)}\\s*:\\s*(.+)\$',
          caseSensitive: false,
        ).firstMatch(lines[index]);
        final value = match?.group(1)?.trim();
        if (value != null && value.isNotEmpty) return value;
      }
    }
    return null;
  }

  String? _documentType(String text) {
    if (_containsAny(text, const ['mahnung', 'zahlungserinnerung'])) {
      return 'Mahnung / Zahlungserinnerung';
    }
    if (_containsAny(text, const ['gutschrift', 'stornorechnung'])) {
      return 'Gutschrift / Stornorechnung';
    }
    if (_containsAny(text, const ['rechnung', 'invoice'])) return 'Rechnung';
    if (_containsAny(text, const ['bescheid'])) return 'Bescheid';
    if (_containsAny(text, const ['kündigung'])) return 'Kündigung';
    return null;
  }

  LetterCategory _categoryFor(String text) {
    if (_containsAny(text, const [
      'familienkas',
      'kindergeld',
      'kindergeid',
      'kinderzuschlag',
      'kindergeldnummer',
      'kindergeld-nr',
    ])) {
      return LetterCategory.familienkasse;
    }
    if (_containsAny(text, const ['jobcenter', 'bürgergeld'])) {
      return LetterCategory.jobcenter;
    }
    if (_containsAny(text, const [
      'agentur für arbeit',
      'arbeitsagentur',
      'arbeitslosengeld',
      'kundennummer der agentur',
    ])) {
      return LetterCategory.agenturFuerArbeit;
    }
    if (_containsAny(text, const [
      'ausländerbehörde',
      'auslaenderbehoerde',
      'aufenthaltstitel',
      'aufenthaltserlaubnis',
      'niederlassungserlaubnis',
      'fiktionsbescheinigung',
    ])) {
      return LetterCategory.auslaenderbehoerde;
    }
    if (_containsAny(text, const [
      'bürgeramt',
      'buergeramt',
      'einwohnermeldeamt',
      'meldebehörde',
      'personalausweis',
      'anmeldebestätigung',
    ])) {
      return LetterCategory.buergeramt;
    }
    if (_containsAny(text, const [
      'wohngeldstelle',
      'wohngeldbehörde',
      'wohngeldbescheid',
      'wohngeldantrag',
    ])) {
      return LetterCategory.wohngeldstelle;
    }
    if (_containsAny(text, const [
      'jugendamt',
      'unterhaltsvorschuss',
      'beistandschaft',
    ])) {
      return LetterCategory.jugendamt;
    }
    if (_containsAny(text, const [
      'sozialamt',
      'grundsicherung',
      'hilfe zum lebensunterhalt',
      'eingliederungshilfe',
    ])) {
      return LetterCategory.sozialamt;
    }
    if (_containsAny(text, const ['bafög', 'bafoeg', 'ausbildungsförderung'])) {
      return LetterCategory.bafoegAmt;
    }
    if (_containsAny(text, const [
      'deutsche rentenversicherung',
      'rentenversicherung',
      'rentenbescheid',
      'versicherungsverlauf',
    ])) {
      return LetterCategory.rentenversicherung;
    }
    if (_containsAny(text, const [
      'beitragsservice',
      'rundfunkbeitrag',
      'ard zdf deutschlandradio',
      'beitragsnummer',
    ])) {
      return LetterCategory.rundfunkbeitrag;
    }
    if (_containsAny(text, const [
      'hauptzollamt',
      'zollamt',
      'zollverwaltung',
    ])) {
      return LetterCategory.customs;
    }
    if (_containsAny(text, const [
      'staatsanwaltschaft',
      'polizeipräsidium',
      'polizeiinspektion',
      'kriminalpolizei',
      'ermittlungsverfahren',
    ])) {
      return LetterCategory.police;
    }
    if (_containsAny(text, const [
      'amtsgericht',
      'landgericht',
      'sozialgericht',
      'verwaltungsgericht',
      'arbeitsgericht',
      'mahngericht',
    ])) {
      return LetterCategory.court;
    }
    if (_containsAny(text, const [
      'finanzamt',
      'steuerbescheid',
      'einkommensteuer',
      'umsatzsteuer',
      'lohnsteuer',
    ])) {
      return LetterCategory.finanzamt;
    }
    if (_containsAny(text, const [
      'krankenkasse',
      'pflegekasse',
      ' aok ',
      ' techniker krankenkasse',
      'barmer',
      'dak-gesundheit',
    ])) {
      return LetterCategory.krankenkasse;
    }
    if (_containsAny(text, const [
      'inkasso',
      'forderungseinzug',
      'collection services',
      'forderungsgesellschaft',
    ])) {
      return LetterCategory.debtCollection;
    }
    if (_containsAny(text, const [
      'stadtwerke',
      'energieversorgung',
      'energieversorger',
      'stromrechnung',
      'gasrechnung',
      'zählerstand',
      'abschlagszahlung',
    ])) {
      return LetterCategory.energy;
    }
    if (text.contains('versicherung')) return LetterCategory.insurance;
    if (_containsAny(text, const ['bank', 'sparkasse', 'volksbank'])) {
      return LetterCategory.bank;
    }
    if (_containsAny(text, const [
      'telekom',
      'vodafone',
      'telefonica',
      ' o2 ',
    ])) {
      return LetterCategory.telecom;
    }
    if (_containsAny(text, const [
      'arbeitgeber',
      'arbeitsvertrag',
      'lohnabrechnung',
      'gehaltsabrechnung',
    ])) {
      return LetterCategory.employer;
    }
    if (_containsAny(text, const [
      'vermieter',
      'hausverwaltung',
      'mietvertrag',
      'nebenkostenabrechnung',
      'mieterhöhung',
    ])) {
      return LetterCategory.landlord;
    }
    if (text.contains('kindergarten') || text.contains('kita')) {
      return LetterCategory.kindergarten;
    }
    if (text.contains('schule')) return LetterCategory.school;
    return LetterCategory.other;
  }

  bool _containsAny(String text, List<String> values) =>
      values.any(text.contains);

  DateTime? _deadlineFor(String text) {
    final matches = RegExp(
      r'(?:bis(?:\s+spätestens)?\s+(?:zum\s+)?|spätestens\s+(?:am\s+)?|frist(?:\s+\w+){0,4}\s+bis\s+)(\d{1,2})[./](\d{1,2})[./](\d{2}|\d{4})\b',
      caseSensitive: false,
    ).allMatches(text).toList();
    if (matches.isEmpty) return null;
    RegExpMatch? bestMatch;
    var bestScore = -1000;
    for (final match in matches) {
      final start = (match.start - 100).clamp(0, text.length);
      final context = text.substring(start, match.end).toLowerCase();
      var score = 0;
      if (_containsAny(context, const [
        'fällig',
        'faellig',
        'zahlbar',
        'zahlung',
        'überweisen',
        'ueberweisen',
        'frist',
        'spätestens',
      ])) {
        score += 10;
      }
      if (_containsAny(context, const [
        'leistungszeitraum',
        'abrechnungszeitraum',
        'lieferzeitraum',
        'von',
      ])) {
        score -= 4;
      }
      // When evidence has equal strength, the later explicit date is usually
      // the action/payment deadline after header and service-period dates.
      if (score >= bestScore) {
        bestScore = score;
        bestMatch = match;
      }
    }
    final match = bestMatch!;
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
  // The production OpenAI path answers in every selected BCP-47 language.
  // If cloud analysis is temporarily unavailable, English is the neutral
  // fallback for languages whose offline analysis copy is not shipped yet.
  return _copy.containsKey(locale) ? locale : 'en';
}

String _categoryName(LetterCategory category, String _) => switch (category) {
  LetterCategory.finanzamt => 'Finanzamt',
  LetterCategory.krankenkasse => 'Krankenkasse',
  LetterCategory.jobcenter => 'Jobcenter',
  LetterCategory.bank => 'Bank',
  LetterCategory.insurance => 'Versicherung',
  LetterCategory.telecom => 'Telekommunikationsanbieter',
  LetterCategory.employer => 'Arbeitgeber',
  LetterCategory.landlord => 'Vermieter',
  LetterCategory.school => 'Schule',
  LetterCategory.kindergarten => 'Kindergarten/Kita',
  LetterCategory.court => 'Gericht',
  LetterCategory.familienkasse => 'Familienkasse',
  LetterCategory.agenturFuerArbeit => 'Agentur für Arbeit',
  LetterCategory.auslaenderbehoerde => 'Ausländerbehörde',
  LetterCategory.buergeramt => 'Bürgeramt',
  LetterCategory.sozialamt => 'Sozialamt',
  LetterCategory.jugendamt => 'Jugendamt',
  LetterCategory.wohngeldstelle => 'Wohngeldstelle',
  LetterCategory.bafoegAmt => 'BAföG-Amt',
  LetterCategory.rentenversicherung => 'Deutsche Rentenversicherung',
  LetterCategory.rundfunkbeitrag => 'ARD ZDF Deutschlandradio Beitragsservice',
  LetterCategory.energy => 'Energieversorger',
  LetterCategory.debtCollection => 'Inkassounternehmen',
  LetterCategory.police => 'Polizei/Staatsanwaltschaft',
  LetterCategory.customs => 'Zoll',
  LetterCategory.other => 'andere Stelle',
};

enum _DocumentIntent {
  documents,
  payment,
  appointment,
  decision,
  response,
  information,
}

class _GenericAnalysis {
  const _GenericAnalysis({
    required this.title,
    required this.explanation,
    required this.action,
  });

  final String title;
  final String explanation;
  final String action;
}

class _IntentLocale {
  const _IntentLocale({
    required this.titles,
    required this.explanations,
    required this.actions,
    required this.senderPrefix,
    required this.deadlinePrefix,
    required this.amountPrefix,
  });

  final List<String> titles;
  final List<String> explanations;
  final List<String> actions;
  final String senderPrefix;
  final String deadlinePrefix;
  final String amountPrefix;
}

_GenericAnalysis _genericAnalysis(
  String text,
  String locale,
  String category, {
  required String originalText,
  required DateTime? deadline,
  required String? amount,
}) {
  final intent = _documentIntent(text);
  final copy = _intentCopy[locale]!;
  final index = intent.index;
  final facts = <String>[];
  if (deadline != null) {
    facts.add(
      '${copy.deadlinePrefix} '
      '${deadline.day.toString().padLeft(2, '0')}.'
      '${deadline.month.toString().padLeft(2, '0')}.'
      '${deadline.year}.',
    );
  }
  if (amount != null) {
    facts.add('${copy.amountPrefix} $amount.');
  }
  facts.addAll(_analysisNotes(text, originalText, locale));
  return _GenericAnalysis(
    title: '${copy.titles[index]} — $category',
    explanation: [
      '${copy.senderPrefix} $category.',
      copy.explanations[index],
      ...facts,
    ].join(' '),
    action: _concreteAction(
      locale,
      copy.actions[index],
      deadline: deadline,
      reference: _referenceFor(originalText),
    ),
  );
}

List<String> _analysisNotes(String text, String originalText, String locale) {
  final notes = <String>[];
  final reference = _referenceFor(originalText);
  if (reference != null) {
    notes.add(switch (locale) {
      'hr' => 'Prepoznati broj predmeta: $reference.',
      'bs' => 'Prepoznati broj predmeta: $reference.',
      'mk' => 'Препознаен број на предмет: $reference.',
      'bg' => 'Разпознат номер на преписка: $reference.',
      'de' => 'Erkanntes Aktenzeichen: $reference.',
      'en' => 'Recognized reference number: $reference.',
      _ => 'Prepoznati broj predmeta: $reference.',
    });
  }
  if (_hasAny(text, const [
    'vollstreck',
    'inkasso',
    'säumnis',
    'sperr',
    'mahnung',
  ])) {
    notes.add(switch (locale) {
      'hr' =>
        'Rizik ako se pismo zanemari: mogući su dodatni troškovi, obustava usluge, naplata ili ovrha.',
      'bs' =>
        'Rizik ako se pismo zanemari: mogući su dodatni troškovi, obustava usluge, naplata ili prinudno izvršenje.',
      'mk' =>
        'Ризик ако писмото се игнорира: можни се дополнителни трошоци, блокада, наплата или извршување.',
      'bg' =>
        'Риск при игнориране: възможни са допълнителни разходи, спиране, събиране или принудително изпълнение.',
      'de' =>
        'Risiko bei Nichtreaktion: zusätzliche Kosten, Sperre, Inkasso oder Vollstreckung sind möglich.',
      'en' =>
        'Risk if ignored: additional fees, suspension, collection, or enforcement may follow.',
      _ =>
        'Rizik ako se pismo ignoriše: mogući su dodatni troškovi, obustava usluge, naplata ili prinudno izvršenje.',
    });
  } else if (_hasAny(text, const [
    'ablehn',
    'versag',
    'aufheb',
    'einstell',
    'rückforder',
  ])) {
    notes.add(switch (locale) {
      'hr' =>
        'Rizik ako se ne reagira: pravo ili isplata mogu biti odbijeni, obustavljeni ili zatraženi natrag.',
      'bs' =>
        'Rizik ako se ne reaguje: pravo ili isplata mogu biti odbijeni, obustavljeni ili zatraženi nazad.',
      'mk' =>
        'Ризик без одговор: правото или исплатата може да бидат одбиени, запрени или побарани назад.',
      'bg' =>
        'Риск без отговор: право или плащане може да бъдат отказани, спрени или поискани обратно.',
      'de' =>
        'Risiko bei Nichtreaktion: Anspruch oder Zahlung können abgelehnt, eingestellt oder zurückgefordert werden.',
      'en' =>
        'Risk if no action is taken: an entitlement or payment may be denied, stopped, or reclaimed.',
      _ =>
        'Rizik ako se ne reaguje: pravo ili isplata mogu biti odbijeni, obustavljeni ili zatraženi nazad.',
    });
  }
  if (_hasAny(text, const ['rechtsbehelfsbelehrung', 'widerspruch', 'klage'])) {
    final relative = _hasAny(text, const [
      'innerhalb eines monats',
      'innerhalb von einem monat',
    ]);
    notes.add(switch (locale) {
      'hr' =>
        relative
            ? 'Pravni lijek: tekst upućuje na rok od jednog mjeseca od dostave/objave; provjerite Rechtsbehelfsbelehrung.'
            : 'Pravni lijek: provjerite Rechtsbehelfsbelehrung i točan rok u originalu.',
      'bs' =>
        relative
            ? 'Pravni lijek: tekst ukazuje na rok od jednog mjeseca od dostave/objave; provjerite Rechtsbehelfsbelehrung.'
            : 'Pravni lijek: provjerite Rechtsbehelfsbelehrung i tačan rok u originalu.',
      'mk' =>
        relative
            ? 'Правен лек: текстот укажува на рок од еден месец од доставувањето; проверете ја Rechtsbehelfsbelehrung.'
            : 'Правен лек: проверете ја Rechtsbehelfsbelehrung и точниот рок.',
      'bg' =>
        relative
            ? 'Обжалване: текстът сочи срок от един месец от връчването; проверете Rechtsbehelfsbelehrung.'
            : 'Обжалване: проверете Rechtsbehelfsbelehrung и точния срок.',
      'de' =>
        relative
            ? 'Rechtsbehelf: Der Text nennt einen Monat ab Bekanntgabe/Zustellung; Rechtsbehelfsbelehrung genau prüfen.'
            : 'Rechtsbehelf: Rechtsbehelfsbelehrung und genaue Frist im Original prüfen.',
      'en' =>
        relative
            ? 'Appeal: the text indicates one month from notification/service; verify the Rechtsbehelfsbelehrung.'
            : 'Appeal: verify the Rechtsbehelfsbelehrung and exact deadline in the original.',
      _ =>
        relative
            ? 'Pravni lek: tekst ukazuje na rok od jednog meseca od dostave/objave; proverite Rechtsbehelfsbelehrung.'
            : 'Pravni lek: proverite Rechtsbehelfsbelehrung i tačan rok u originalu.',
    });
  }
  notes.add(switch (locale) {
    'hr' =>
      'Provjerite u originalu ime, adresu, broj predmeta, sve stranice i priloge prije postupanja.',
    'bs' =>
      'Provjerite u originalu ime, adresu, broj predmeta, sve stranice i priloge prije postupanja.',
    'mk' =>
      'Пред постапување проверете ги името, адресата, бројот на предметот, сите страници и прилози.',
    'bg' =>
      'Преди действие проверете името, адреса, номер на преписка, всички страници и приложения.',
    'de' =>
      'Vor dem Handeln Name, Anschrift, Aktenzeichen, alle Seiten und Anlagen im Original prüfen.',
    'en' =>
      'Before acting, verify the name, address, reference number, every page, and all attachments.',
    _ =>
      'Pre postupanja proverite u originalu ime, adresu, broj predmeta, sve stranice i priloge.',
  });
  return notes;
}

String _concreteAction(
  String locale,
  String coreAction, {
  required DateTime? deadline,
  required String? reference,
}) {
  final deadlineText = deadline == null
      ? null
      : '${deadline.day.toString().padLeft(2, '0')}.'
            '${deadline.month.toString().padLeft(2, '0')}.${deadline.year}';
  return switch (locale) {
    'hr' =>
      '1. Otvorite original i označite zahtjev'
          '${reference == null ? '' : ' te broj predmeta $reference'}. '
          '2. $coreAction '
          '3. ${deadlineText == null ? 'Ako nema jasnog roka, potvrdite ga kod pošiljatelja.' : 'Dovršite radnju prije $deadlineText.'} '
          '4. Sačuvajte kopiju i potvrdu slanja; ako nešto nije jasno, kontaktirajte ustanovu prije roka.',
    'bs' =>
      '1. Otvorite original i označite zahtjev'
          '${reference == null ? '' : ' i broj predmeta $reference'}. '
          '2. $coreAction '
          '3. ${deadlineText == null ? 'Ako nema jasnog roka, potvrdite ga kod pošiljaoca.' : 'Završite radnju prije $deadlineText.'} '
          '4. Sačuvajte kopiju i potvrdu slanja; nejasnoću provjerite kod institucije.',
    'mk' =>
      '1. Во оригиналот означете го барањето'
          '${reference == null ? '' : ' и бројот $reference'}. '
          '2. $coreAction '
          '3. ${deadlineText == null ? 'Ако нема јасен рок, потврдете го кај испраќачот.' : 'Завршете пред $deadlineText.'} '
          '4. Чувајте копија и потврда за испраќање.',
    'bg' =>
      '1. В оригинала отбележете искането'
          '${reference == null ? '' : ' и номера $reference'}. '
          '2. $coreAction '
          '3. ${deadlineText == null ? 'Ако няма ясен срок, потвърдете го с подателя.' : 'Приключете преди $deadlineText.'} '
          '4. Пазете копие и доказателство за изпращане.',
    'de' =>
      '1. Aufforderung'
          '${reference == null ? '' : ' und Aktenzeichen $reference'} im Original markieren. '
          '2. $coreAction '
          '3. ${deadlineText == null ? 'Unklare Frist beim Absender bestätigen.' : 'Vor dem $deadlineText erledigen.'} '
          '4. Kopie und Versandnachweis aufbewahren; Unklarheiten vor Fristablauf klären.',
    'en' =>
      '1. Mark the request'
          '${reference == null ? '' : ' and reference $reference'} in the original. '
          '2. $coreAction '
          '3. ${deadlineText == null ? 'Confirm any unclear deadline with the sender.' : 'Complete it before $deadlineText.'} '
          '4. Keep a copy and proof of submission; clarify uncertainty before the deadline.',
    _ =>
      '1. Otvorite original i označite tačan zahtev'
          '${reference == null ? '' : ' i broj predmeta $reference'}. '
          '2. $coreAction '
          '3. ${deadlineText == null ? 'Ako rok nije jasan, potvrdite ga kod pošiljaoca.' : 'Završite radnju pre $deadlineText.'} '
          '4. Sačuvajte kopiju i potvrdu slanja; svaku nejasnoću proverite kod institucije pre roka.',
  };
}

String? _referenceFor(String text) {
  final match = RegExp(
    r'(?:Aktenzeichen|Geschäftszeichen|Kundennummer|BG-Nummer|'
    r'Kindergeldnummer|Versicherungsnummer|Steuernummer|Beitragsnummer)'
    r'\s*[:#.-]?\s*([A-Z0-9][A-Z0-9/.-]{3,30})',
    caseSensitive: false,
  ).firstMatch(text);
  return match?.group(1)?.trim();
}

_DocumentIntent _documentIntent(String text) {
  if (_hasAny(text, const [
    'unterlagen',
    'nachweis',
    'mitwirkung',
    'einzureichen',
    'vorzulegen',
    'nachzureichen',
    'formular ausfüllen',
    'fehlende dokumente',
  ])) {
    return _DocumentIntent.documents;
  }
  if (_hasAny(text, const [
    'mahnung',
    'zahlung',
    'zu überweisen',
    'offene forderung',
    'zahlbar',
    'fällig',
    'rechnung',
    'rückstand',
    'vollstreckung',
  ])) {
    return _DocumentIntent.payment;
  }
  if (_hasAny(text, const [
    'termin',
    'vorladung',
    'einladung',
    'persönliche vorsprache',
    'persönlich erscheinen',
  ])) {
    return _DocumentIntent.appointment;
  }
  if (_hasAny(text, const [
    'bescheid',
    'bewilligt',
    'abgelehnt',
    'festgesetzt',
    'genehmigt',
    'rechtsbehelfsbelehrung',
  ])) {
    return _DocumentIntent.decision;
  }
  if (_hasAny(text, const [
    'anhörung',
    'stellungnahme',
    'bitte antworten',
    'äußerung',
    'rückmeldung',
  ])) {
    return _DocumentIntent.response;
  }
  return _DocumentIntent.information;
}

bool _hasAny(String text, List<String> values) => values.any(text.contains);

const _intentCopy = <String, _IntentLocale>{
  'sr': _IntentLocale(
    titles: [
      'Zahtev za dokumenta',
      'Plaćanje ili opomena',
      'Termin ili poziv',
      'Službena odluka',
      'Traži se vaš odgovor',
      'Službeno obaveštenje',
    ],
    senderPrefix: 'Prepoznati pošiljalac ili vrsta institucije:',
    explanations: [
      'U pismu se traže dokumenta, dokazi ili dodatni podaci radi obrade vašeg predmeta. Tačan spisak mora se proveriti u originalu.',
      'Pismo sadrži račun, dospelu obavezu, zahtev za plaćanje ili opomenu. Prvo proverite osnov, period, primaoca i da li je iznos zaista označen kao dug.',
      'Pismo navodi termin, poziv ili lično javljanje. Proverite datum, vreme, adresu, potrebna dokumenta i da li je dolazak označen kao obavezan.',
      'Pismo izgleda kao rešenje ili odluka kojom se nešto odobrava, odbija, menja ili obračunava. Proverite period važenja i obrazloženje.',
      'Institucija traži odgovor, izjavu ili vaše izjašnjenje. Proverite na koje pitanje treba odgovoriti i koji broj predmeta treba navesti.',
      'Pismo je informativno ili zahtev nije pouzdano prepoznat. Proverite predmet, označene pasuse i da li postoji konkretna radnja.',
    ],
    deadlinePrefix: 'Izričito prepoznat rok:',
    amountPrefix: 'Prepoznat je iznos koji treba proveriti u kontekstu pisma:',
    actions: [
      '1. Zapišite broj predmeta. 2. Napravite kopije samo traženih dokumenata. 3. Pošaljite ih na navedeni kanal pre roka. 4. Sačuvajte potvrdu slanja.',
      'Ne plaćajte samo na osnovu sažetka. Uporedite pošiljaoca, IBAN, broj predmeta, period i iznos sa originalom. Kod nejasne ili sporne obaveze prvo kontaktirajte pošiljaoca ili savetovalište.',
      'Unesite termin u kalendar, pripremite navedena dokumenta i odmah kontaktirajte pošiljaoca ako ne možete doći. Sačuvajte potvrdu o promeni termina.',
      'Proverite lične podatke, period, iznos i obrazloženje. Sačuvajte celu odluku i pročitajte odeljak o roku i mogućnosti prigovora ako postoji.',
      'Odgovorite kratko i činjenično, navedite broj predmeta i priložite samo relevantne dokaze. Sačuvajte kopiju odgovora i potvrdu slanja.',
      'Sačuvajte pismo. Ako original ne sadrži zahtev ili rok, nije potrebna hitna radnja; kod nejasnoće kontaktirajte pošiljaoca koristeći podatke sa zvanične stranice.',
    ],
  ),
  'hr': _IntentLocale(
    titles: [
      'Zahtjev za dokumente',
      'Plaćanje ili opomena',
      'Termin ili poziv',
      'Službena odluka',
      'Traži se vaš odgovor',
      'Službena obavijest',
    ],
    senderPrefix: 'Prepoznati pošiljatelj ili vrsta ustanove:',
    explanations: [
      'U pismu se traže dokumenti, dokazi ili dodatni podaci za obradu predmeta. Točan popis provjerite u izvorniku.',
      'Pismo sadrži račun, dospjelu obvezu, zahtjev za plaćanje ili opomenu. Provjerite osnovu, razdoblje, primatelja i je li iznos označen kao dug.',
      'Pismo navodi termin, poziv ili osobni dolazak. Provjerite datum, vrijeme, adresu, dokumente i je li dolazak obvezan.',
      'Pismo izgleda kao rješenje ili odluka kojom se nešto odobrava, odbija, mijenja ili obračunava.',
      'Ustanova traži odgovor, izjavu ili očitovanje. Provjerite pitanje i broj predmeta koji treba navesti.',
      'Pismo je informativno ili zahtjev nije pouzdano prepoznat. Provjerite predmet i označene odlomke.',
    ],
    deadlinePrefix: 'Izričito prepoznati rok:',
    amountPrefix: 'Prepoznati iznos koji treba provjeriti u kontekstu:',
    actions: [
      'Zapišite broj predmeta, kopirajte samo tražene dokumente, pošaljite ih navedenim kanalom prije roka i sačuvajte potvrdu.',
      'Ne plaćajte samo prema sažetku. Usporedite pošiljatelja, IBAN, predmet, razdoblje i iznos s izvornikom; nejasnu obvezu prvo provjerite.',
      'Unesite termin u kalendar, pripremite dokumente i kontaktirajte pošiljatelja ako ne možete doći.',
      'Provjerite osobne podatke, razdoblje, iznos i obrazloženje. Sačuvajte odluku i pročitajte uputu o pravnom lijeku.',
      'Odgovorite kratko i činjenično, navedite broj predmeta, priložite relevantne dokaze i sačuvajte potvrdu slanja.',
      'Sačuvajte pismo. Bez zahtjeva ili roka nema hitne radnje; nejasnoću provjerite kod pošiljatelja.',
    ],
  ),
  'bs': _IntentLocale(
    titles: [
      'Zahtjev za dokumente',
      'Plaćanje ili opomena',
      'Termin ili poziv',
      'Službena odluka',
      'Traži se vaš odgovor',
      'Službeno obavještenje',
    ],
    senderPrefix: 'Prepoznati pošiljalac ili vrsta institucije:',
    explanations: [
      'U pismu se traže dokumenti, dokazi ili dodatni podaci za obradu predmeta. Tačan spisak provjerite u originalu.',
      'Pismo sadrži račun, dospjelu obavezu, zahtjev za plaćanje ili opomenu. Provjerite osnov, period, primaoca i da li je iznos označen kao dug.',
      'Pismo navodi termin, poziv ili lični dolazak. Provjerite datum, vrijeme, adresu, dokumente i da li je dolazak obavezan.',
      'Pismo izgleda kao rješenje ili odluka kojom se nešto odobrava, odbija, mijenja ili obračunava.',
      'Institucija traži odgovor, izjavu ili izjašnjenje. Provjerite pitanje i broj predmeta koji treba navesti.',
      'Pismo je informativno ili zahtjev nije pouzdano prepoznat. Provjerite predmet i označene pasuse.',
    ],
    deadlinePrefix: 'Izričito prepoznat rok:',
    amountPrefix: 'Prepoznat iznos koji treba provjeriti u kontekstu:',
    actions: [
      'Zapišite broj predmeta, kopirajte samo tražene dokumente, pošaljite ih navedenim kanalom prije roka i sačuvajte potvrdu.',
      'Ne plaćajte samo prema sažetku. Uporedite pošiljaoca, IBAN, predmet, period i iznos s originalom; nejasnu obavezu prvo provjerite.',
      'Unesite termin u kalendar, pripremite dokumente i kontaktirajte pošiljaoca ako ne možete doći.',
      'Provjerite lične podatke, period, iznos i obrazloženje. Sačuvajte odluku i pročitajte uputu o pravnom lijeku.',
      'Odgovorite kratko i činjenično, navedite broj predmeta, priložite relevantne dokaze i sačuvajte potvrdu slanja.',
      'Sačuvajte pismo. Bez zahtjeva ili roka nema hitne radnje; nejasnoću provjerite kod pošiljaoca.',
    ],
  ),
  'mk': _IntentLocale(
    titles: [
      'Барање за документи',
      'Плаќање или опомена',
      'Термин или покана',
      'Службена одлука',
      'Се бара ваш одговор',
      'Службено известување',
    ],
    senderPrefix: 'Препознаен испраќач или вид институција:',
    explanations: [
      'Се бараат документи, докази или дополнителни податоци за обработка на предметот. Точниот список проверете го во оригиналот.',
      'Писмото содржи сметка, доспеана обврска, барање за плаќање или опомена. Проверете ги основата, периодот, примачот и износот.',
      'Писмото наведува термин, покана или лично јавување. Проверете ги датумот, времето, адресата, документите и дали присуството е задолжително.',
      'Писмото изгледа како решение со кое нешто се одобрува, одбива, менува или пресметува.',
      'Институцијата бара одговор, изјава или произнесување. Проверете го прашањето и бројот на предметот.',
      'Писмото е информативно или барањето не е сигурно препознаено. Проверете ги предметот и означените пасуси.',
    ],
    deadlinePrefix: 'Изрично препознаен рок:',
    amountPrefix: 'Препознаен износ што треба да се провери:',
    actions: [
      'Запишете го бројот на предметот, копирајте ги само бараните документи, испратете ги преку наведениот канал пред рокот и чувајте потврда.',
      'Не плаќајте само според резимето. Споредете ги испраќачот, IBAN, предметот, периодот и износот со оригиналот.',
      'Внесете го терминот во календар, подгответе ги документите и контактирајте го испраќачот ако не можете да дојдете.',
      'Проверете ги личните податоци, периодот, износот и образложението. Чувајте ја одлуката и прочитајте ја правната поука.',
      'Одговорете кратко и фактички, наведете го бројот на предметот, приложете релевантни докази и чувајте потврда.',
      'Чувајте го писмото. Без барање или рок нема итна постапка; нејаснотијата проверете ја кај испраќачот.',
    ],
  ),
  'bg': _IntentLocale(
    titles: [
      'Искане за документи',
      'Плащане или напомняне',
      'Среща или призовка',
      'Официално решение',
      'Изисква се ваш отговор',
      'Официално известие',
    ],
    senderPrefix: 'Разпознат подател или вид институция:',
    explanations: [
      'Искат се документи, доказателства или допълнителни данни за обработване на случая. Проверете точния списък в оригинала.',
      'Писмото съдържа сметка, изискуемо задължение, искане за плащане или напомняне. Проверете основанието, периода, получателя и сумата.',
      'Писмото посочва среща, покана или лично явяване. Проверете датата, часа, адреса, документите и дали присъствието е задължително.',
      'Писмото изглежда като решение, с което нещо се одобрява, отказва, променя или изчислява.',
      'Институцията иска отговор, декларация или становище. Проверете въпроса и номера на преписката.',
      'Писмото е информативно или искането не е разпознато надеждно. Проверете темата и отбелязаните абзаци.',
    ],
    deadlinePrefix: 'Изрично разпознат срок:',
    amountPrefix: 'Разпозната сума за проверка в контекста:',
    actions: [
      'Запишете номера на преписката, копирайте само исканите документи, изпратете ги по посочения канал преди срока и пазете потвърждение.',
      'Не плащайте само по резюмето. Сравнете подателя, IBAN, преписката, периода и сумата с оригинала.',
      'Добавете срещата в календара, подгответе документите и се свържете с подателя, ако не можете да присъствате.',
      'Проверете личните данни, периода, сумата и мотивите. Пазете решението и прочетете указанията за обжалване.',
      'Отговорете кратко и фактологично, посочете номера на преписката, приложете относимите доказателства и пазете потвърждение.',
      'Пазете писмото. Без искане или срок няма спешно действие; проверете неяснотата при подателя.',
    ],
  ),
  'de': _IntentLocale(
    titles: [
      'Unterlagenanforderung',
      'Zahlung oder Mahnung',
      'Termin oder Vorladung',
      'Behördliche Entscheidung',
      'Ihre Antwort wird verlangt',
      'Offizielle Mitteilung',
    ],
    senderPrefix: 'Erkannter Absender oder Institutionstyp:',
    explanations: [
      'Das Schreiben fordert Unterlagen, Nachweise oder zusätzliche Angaben zur Bearbeitung des Vorgangs an. Prüfen Sie die genaue Liste im Original.',
      'Das Schreiben enthält eine Rechnung, fällige Forderung, Zahlungsaufforderung oder Mahnung. Prüfen Sie Grundlage, Zeitraum, Empfänger und Betrag.',
      'Das Schreiben nennt einen Termin, eine Einladung oder persönliche Vorsprache. Prüfen Sie Datum, Uhrzeit, Anschrift, Unterlagen und Anwesenheitspflicht.',
      'Das Schreiben scheint etwas zu bewilligen, abzulehnen, zu ändern oder festzusetzen. Prüfen Sie Zeitraum und Begründung.',
      'Die Stelle verlangt eine Antwort, Stellungnahme oder Anhörung. Prüfen Sie die konkrete Frage und das anzugebende Aktenzeichen.',
      'Das Schreiben ist informativ oder die Aufforderung wurde nicht sicher erkannt. Prüfen Sie Betreff und hervorgehobene Abschnitte.',
    ],
    deadlinePrefix: 'Ausdrücklich erkannte Frist:',
    amountPrefix: 'Im Kontext zu prüfender erkannter Betrag:',
    actions: [
      'Aktenzeichen notieren, nur die verlangten Unterlagen kopieren, fristgerecht über den genannten Kanal senden und den Nachweis aufbewahren.',
      'Nicht allein aufgrund der Zusammenfassung zahlen. Absender, IBAN, Aktenzeichen, Zeitraum und Betrag mit dem Original abgleichen und Unklarheiten klären.',
      'Termin eintragen, Unterlagen vorbereiten und den Absender sofort kontaktieren, wenn Sie nicht teilnehmen können.',
      'Personendaten, Zeitraum, Betrag und Begründung prüfen. Entscheidung vollständig aufbewahren und die Rechtsbehelfsbelehrung lesen.',
      'Kurz und sachlich antworten, Aktenzeichen nennen, nur relevante Nachweise beifügen und Versandnachweis aufbewahren.',
      'Schreiben aufbewahren. Ohne Aufforderung oder Frist besteht keine dringende Handlung; Unklarheiten beim Absender klären.',
    ],
  ),
  'en': _IntentLocale(
    titles: [
      'Document request',
      'Payment or reminder',
      'Appointment or summons',
      'Official decision',
      'Your response is required',
      'Official notice',
    ],
    senderPrefix: 'Recognized sender or institution type:',
    explanations: [
      'The letter requests documents, evidence, or additional information to process the case. Check the original for the exact list.',
      'The letter contains an invoice, amount due, payment request, or reminder. Verify the basis, period, recipient, and amount.',
      'The letter gives an appointment, invitation, or personal-attendance request. Check the date, time, address, documents, and whether attendance is mandatory.',
      'The letter appears to approve, reject, change, or calculate something. Check the applicable period and reasoning.',
      'The institution requests a reply, statement, or hearing response. Check the exact question and reference number.',
      'The letter is informational or its request was not recognized reliably. Check the subject and highlighted sections.',
    ],
    deadlinePrefix: 'Explicitly recognized deadline:',
    amountPrefix: 'Recognized amount to verify in context:',
    actions: [
      'Note the reference number, copy only requested documents, submit them through the stated channel before the deadline, and keep proof.',
      'Do not pay based on the summary alone. Compare the sender, IBAN, reference, period, and amount with the original and clarify uncertainty first.',
      'Add the appointment to your calendar, prepare the documents, and contact the sender immediately if you cannot attend.',
      'Check personal data, period, amount, and reasons. Keep the complete decision and read any appeal-information section.',
      'Reply briefly and factually, include the reference number, attach only relevant evidence, and keep proof of submission.',
      'Keep the letter. Without a request or deadline, no urgent action is indicated; clarify uncertainty with the sender.',
    ],
  ),
};

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
  'tr': _LocalCopy(
    finanzamtTitle: 'Vergi dairesinden talep',
    jobcenterTitle: 'Jobcenter bildirimi',
    krankenkasseTitle: 'Sağlık sigortası bildirimi',
    courtTitle: 'Hukuki bildirim',
    generalTitle: 'İncelenmesi gereken resmî mektup',
    explanation: (category, hasDeadline) =>
        'Mektubu gönderen: $category. Sizden ne istendiğini kontrol edin. ${hasDeadline ? 'Bir tarih algılandı ve bu bir son tarih olabilir; zamanında yanıt verin.' : 'Açık bir son tarih algılanmadı; orijinal mektubu kontrol edin.'}',
    action:
        'İstenen belgeleri hazırlayın, kişisel bilgilerinizi doğrulayın ve yazılı yanıt verin. Hukuki veya mali risk varsa uzman desteği alın.',
  ),
};
