import '../../core/domain.dart';

/// Question-aware, private assistant used while cloud AI is disabled.
/// The document text never leaves the device.
class LocalLetterAssistant {
  const LocalLetterAssistant();

  String answer({
    required String question,
    required String language,
    LetterAnalysis? letter,
  }) {
    final locale = _locale(language);
    if (letter == null) return _copy[locale]!.analyseFirst;
    final normalized = question.toLowerCase().trim();
    final copy = _copy[locale]!;

    if (_matches(normalized, _deadlineWords)) {
      final deadline = letter.deadline;
      return deadline == null
          ? copy.noDeadline
          : '${copy.deadline} ${_date(deadline)}. ${copy.keepOriginal}';
    }
    if (_matches(normalized, _paymentWords)) {
      final amount = letter.amount;
      final paymentLanguage = _matches(
        letter.sourceText.toLowerCase(),
        _paymentSourceWords,
      );
      if (amount == null) return copy.noAmount;
      return paymentLanguage
          ? '${copy.amount} $amount. ${copy.verifyPayment}'
          : '${copy.foundAmount} $amount. ${copy.amountNotNecessarilyDue}';
    }
    if (_matches(normalized, _senderWords)) {
      return '${copy.sender} ${_category(letter.category)}. '
          '${copy.titleMeaning} ${letter.title}.';
    }
    if (_matches(normalized, _consequenceWords)) {
      return _consequence(letter, copy);
    }
    if (_matches(normalized, _replyWords)) {
      return '${copy.replyAdvice} ${letter.suggestedAction}';
    }
    if (_matches(normalized, _actionWords)) {
      return '${copy.nextSteps}\n${letter.suggestedAction}';
    }
    if (_matches(normalized, _documentWords)) {
      return '${copy.documentsAdvice} ${letter.suggestedAction}';
    }
    return '${copy.directSummary} ${letter.plainExplanation}\n\n'
        '${copy.nextSteps}\n${letter.suggestedAction}\n\n'
        '${copy.askHint}';
  }

  String _consequence(LetterAnalysis letter, _AssistantCopy copy) {
    final text = letter.sourceText.toLowerCase();
    if (_matches(text, const [
      'vollstreck',
      'inkasso',
      'säumnis',
      'sperr',
      'mahnung',
    ])) {
      return copy.paymentConsequence;
    }
    if (_matches(text, const [
      'ablehn',
      'versag',
      'aufheb',
      'einstell',
      'rückforder',
    ])) {
      return copy.benefitConsequence;
    }
    if (_matches(text, const [
      'rechtsbehelfsbelehrung',
      'widerspruch',
      'klage',
    ])) {
      return copy.appealConsequence;
    }
    return copy.noExplicitConsequence;
  }
}

String _locale(String language) {
  final value = language.toLowerCase().split(RegExp('[-_]')).first;
  return _copy.containsKey(value) ? value : 'sr';
}

bool _matches(String text, List<String> words) =>
    words.any((word) => text.contains(word));

String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}.'
    '${value.month.toString().padLeft(2, '0')}.${value.year}';

String _category(LetterCategory category) => switch (category) {
  LetterCategory.familienkasse => 'Familienkasse',
  LetterCategory.finanzamt => 'Finanzamt',
  LetterCategory.krankenkasse => 'Krankenkasse',
  LetterCategory.jobcenter => 'Jobcenter',
  LetterCategory.agenturFuerArbeit => 'Agentur für Arbeit',
  LetterCategory.auslaenderbehoerde => 'Ausländerbehörde',
  LetterCategory.buergeramt => 'Bürgeramt',
  LetterCategory.sozialamt => 'Sozialamt',
  LetterCategory.jugendamt => 'Jugendamt',
  LetterCategory.wohngeldstelle => 'Wohngeldstelle',
  LetterCategory.bafoegAmt => 'BAföG-Amt',
  LetterCategory.rentenversicherung => 'Deutsche Rentenversicherung',
  LetterCategory.rundfunkbeitrag => 'Beitragsservice',
  LetterCategory.energy => 'Energieversorger',
  LetterCategory.debtCollection => 'Inkasso',
  LetterCategory.police => 'Polizei/Staatsanwaltschaft',
  LetterCategory.customs => 'Zoll',
  LetterCategory.bank => 'Bank',
  LetterCategory.insurance => 'Versicherung',
  LetterCategory.telecom => 'Telekom',
  LetterCategory.employer => 'Arbeitgeber',
  LetterCategory.landlord => 'Vermieter',
  LetterCategory.school => 'Schule',
  LetterCategory.kindergarten => 'Kindergarten/Kita',
  LetterCategory.court => 'Gericht',
  LetterCategory.other => 'nepoznata ili druga institucija',
};

const _deadlineWords = [
  'rok',
  'datum',
  'kada',
  'frist',
  'deadline',
  'when',
  'срок',
  'краен',
  'son tarih',
  'ne zaman',
];
const _paymentWords = [
  'plat',
  'iznos',
  'uplati',
  'zahl',
  'betrag',
  'amount',
  'pay',
  'плат',
  'сума',
  'ödeme',
  'tutar',
];
const _senderWords = [
  'ko je',
  'pošilja',
  'posilja',
  'instituc',
  'sender',
  'absender',
  'von wem',
  'испраќач',
  'подател',
  'gönderen',
  'kimden',
];
const _consequenceWords = [
  'hitno',
  'posled',
  'šta ako',
  'sta ako',
  'ignore',
  'urgent',
  'consequence',
  'passiert',
  'dringend',
  'послед',
  'спеш',
  'acil',
  'sonuç',
];
const _actionWords = [
  'šta da',
  'sta da',
  'dalje',
  'korak',
  'kako da',
  'next',
  'what should',
  'was soll',
  'tun',
  'што да',
  'какво да',
  'ne yap',
  'sonraki',
];
const _replyWords = [
  'odgovor',
  'odgovoriti',
  'reply',
  'antwort',
  'schreiben',
  'одговор',
  'yanıt',
  'cevap',
];
const _documentWords = [
  'dokument',
  'dokaz',
  'unterlagen',
  'nachweis',
  'documents',
  'документ',
  'belge',
  'evrak',
];
const _paymentSourceWords = [
  'zahlung',
  'zu überweisen',
  'zahlbar',
  'fällig',
  'mahnung',
  'rechnung',
  'offene forderung',
];

class _AssistantCopy {
  const _AssistantCopy({
    required this.analyseFirst,
    required this.deadline,
    required this.noDeadline,
    required this.keepOriginal,
    required this.amount,
    required this.noAmount,
    required this.verifyPayment,
    required this.foundAmount,
    required this.amountNotNecessarilyDue,
    required this.sender,
    required this.titleMeaning,
    required this.nextSteps,
    required this.documentsAdvice,
    required this.replyAdvice,
    required this.directSummary,
    required this.askHint,
    required this.paymentConsequence,
    required this.benefitConsequence,
    required this.appealConsequence,
    required this.noExplicitConsequence,
  });

  final String analyseFirst;
  final String deadline;
  final String noDeadline;
  final String keepOriginal;
  final String amount;
  final String noAmount;
  final String verifyPayment;
  final String foundAmount;
  final String amountNotNecessarilyDue;
  final String sender;
  final String titleMeaning;
  final String nextSteps;
  final String documentsAdvice;
  final String replyAdvice;
  final String directSummary;
  final String askHint;
  final String paymentConsequence;
  final String benefitConsequence;
  final String appealConsequence;
  final String noExplicitConsequence;
}

const _copy = <String, _AssistantCopy>{
  'sr': _AssistantCopy(
    analyseFirst: 'Prvo fotografišite ili učitajte pismo i pokrenite analizu.',
    deadline: 'Pouzdano prepoznat rok je',
    noDeadline:
        'Nisam pouzdano našao izričit rok. Proverite pasuse sa „bis“, „innerhalb“ i „Frist“ u originalu.',
    keepOriginal: 'Sačuvajte original i dokaz slanja.',
    amount: 'U pismu je prepoznata obaveza i iznos',
    noAmount:
        'Nisam pouzdano našao iznos za plaćanje. To ne znači da obaveza ne postoji; proverite originalnu tabelu i priloge.',
    verifyPayment:
        'Pre uplate proverite primaoca, IBAN, period, broj predmeta i da li je iznos konačan.',
    foundAmount: 'Prepoznat je iznos',
    amountNotNecessarilyDue:
        'Tekst ga ne označava pouzdano kao iznos za uplatu, zato nemojte plaćati samo prema sažetku.',
    sender: 'Prepoznata institucija:',
    titleMeaning: 'Vrsta pisma:',
    nextSteps: 'Konkretni sledeći koraci:',
    documentsAdvice:
        'Tačan spisak dokumenata proverite u originalu. Zatim pratite ove korake:',
    replyAdvice:
        'Odgovor treba da sadrži broj predmeta, činjenice i samo relevantne priloge. Predlog:',
    directSummary: 'Direktan odgovor na osnovu pisma:',
    askHint:
        'Možete posebno pitati: „Koji je rok?“, „Da li moram da platim?“ ili „Šta da uradim dalje?“',
    paymentConsequence:
        'Pismo upozorava na moguću opomenu, dodatne troškove, blokadu usluge ili prinudnu naplatu. Proverite rok i kontaktirajte pošiljaoca pre isteka.',
    benefitConsequence:
        'Ako se zahtev ignoriše, pravo ili isplata mogu biti odbijeni, obustavljeni ili zatraženi nazad. Reagujte pre roka i sačuvajte dokaz.',
    appealConsequence:
        'Pismo sadrži pravni lek. Propuštanje roka može učiniti odluku konačnom, zato proverite Rechtsbehelfsbelehrung u originalu.',
    noExplicitConsequence:
        'U prepoznatom tekstu nije pouzdano naveden konkretan ishod ako ne reagujete. Nemojte pretpostavljati; proverite poslednji pasus i priloge.',
  ),
  'hr': _AssistantCopy(
    analyseFirst:
        'Najprije fotografirajte ili učitajte pismo i pokrenite analizu.',
    deadline: 'Pouzdano prepoznati rok je',
    noDeadline:
        'Nisam pouzdano pronašao izričit rok. Provjerite odlomke s „bis“, „innerhalb“ i „Frist“ u izvorniku.',
    keepOriginal: 'Sačuvajte izvornik i potvrdu slanja.',
    amount: 'U pismu je prepoznata obveza i iznos',
    noAmount:
        'Nisam pouzdano pronašao iznos za plaćanje. Provjerite izvornu tablicu i priloge.',
    verifyPayment:
        'Prije uplate provjerite primatelja, IBAN, razdoblje, broj predmeta i konačni iznos.',
    foundAmount: 'Prepoznat je iznos',
    amountNotNecessarilyDue:
        'Tekst ga ne označava pouzdano kao iznos za uplatu.',
    sender: 'Prepoznata ustanova:',
    titleMeaning: 'Vrsta pisma:',
    nextSteps: 'Konkretni sljedeći koraci:',
    documentsAdvice: 'Točan popis dokumenata provjerite u izvorniku. Zatim:',
    replyAdvice:
        'Odgovorite s brojem predmeta, činjenicama i relevantnim prilozima. Prijedlog:',
    directSummary: 'Izravan odgovor na temelju pisma:',
    askHint:
        'Možete pitati: „Koji je rok?“, „Moram li platiti?“ ili „Što dalje?“',
    paymentConsequence:
        'Moguća je opomena, dodatni troškovi, obustava ili prisilna naplata. Reagirajte prije roka.',
    benefitConsequence:
        'Pravo ili isplata mogu biti odbijeni, obustavljeni ili zatraženi natrag. Sačuvajte potvrdu odgovora.',
    appealConsequence:
        'Propuštanje roka za pravni lijek može učiniti odluku konačnom. Provjerite Rechtsbehelfsbelehrung.',
    noExplicitConsequence:
        'Prepoznati tekst ne navodi pouzdano posljedicu. Provjerite posljednji odlomak i priloge.',
  ),
  'bs': _AssistantCopy(
    analyseFirst: 'Prvo fotografišite ili učitajte pismo i pokrenite analizu.',
    deadline: 'Pouzdano prepoznat rok je',
    noDeadline:
        'Nisam pouzdano našao izričit rok. Provjerite pasuse sa „bis“, „innerhalb“ i „Frist“.',
    keepOriginal: 'Sačuvajte original i potvrdu slanja.',
    amount: 'U pismu je prepoznata obaveza i iznos',
    noAmount:
        'Nisam pouzdano našao iznos za plaćanje. Provjerite original i priloge.',
    verifyPayment:
        'Prije uplate provjerite primaoca, IBAN, period, broj predmeta i konačni iznos.',
    foundAmount: 'Prepoznat je iznos',
    amountNotNecessarilyDue:
        'Tekst ga ne označava pouzdano kao iznos za uplatu.',
    sender: 'Prepoznata institucija:',
    titleMeaning: 'Vrsta pisma:',
    nextSteps: 'Konkretni sljedeći koraci:',
    documentsAdvice: 'Tačan spisak dokumenata provjerite u originalu. Zatim:',
    replyAdvice:
        'Odgovorite s brojem predmeta, činjenicama i relevantnim prilozima. Prijedlog:',
    directSummary: 'Direktan odgovor na osnovu pisma:',
    askHint:
        'Možete pitati: „Koji je rok?“, „Moram li platiti?“ ili „Šta dalje?“',
    paymentConsequence:
        'Moguća je opomena, dodatni troškovi, obustava ili prinudna naplata. Reagujte prije roka.',
    benefitConsequence:
        'Pravo ili isplata mogu biti odbijeni, obustavljeni ili zatraženi nazad. Sačuvajte potvrdu odgovora.',
    appealConsequence:
        'Propuštanje roka za pravni lijek može učiniti odluku konačnom. Provjerite Rechtsbehelfsbelehrung.',
    noExplicitConsequence:
        'Prepoznati tekst ne navodi pouzdano posljedicu. Provjerite posljednji pasus i priloge.',
  ),
  'mk': _AssistantCopy(
    analyseFirst: 'Прво фотографирајте или вчитајте писмо и започнете анализа.',
    deadline: 'Сигурно препознаениот рок е',
    noDeadline:
        'Не најдов сигурно наведен рок. Проверете ги пасусите со „bis“, „innerhalb“ и „Frist“.',
    keepOriginal: 'Чувајте го оригиналот и потврдата за испраќање.',
    amount: 'Препознаена е обврска и износ',
    noAmount:
        'Не најдов сигурен износ за плаќање. Проверете ја оригиналната табела и прилозите.',
    verifyPayment:
        'Пред плаќање проверете примач, IBAN, период, број на предмет и конечен износ.',
    foundAmount: 'Препознаен е износ',
    amountNotNecessarilyDue:
        'Текстот не потврдува дека тоа е износ за плаќање.',
    sender: 'Препознаена институција:',
    titleMeaning: 'Вид на писмо:',
    nextSteps: 'Конкретни следни чекори:',
    documentsAdvice:
        'Точниот список документи проверете го во оригиналот. Потоа:',
    replyAdvice:
        'Одговорот нека содржи број на предмет, факти и релевантни прилози. Предлог:',
    directSummary: 'Директен одговор според писмото:',
    askHint:
        'Прашајте: „Кој е рокот?“, „Морам ли да платам?“ или „Што понатаму?“',
    paymentConsequence:
        'Можни се опомена, дополнителни трошоци, блокада или присилна наплата. Реагирајте пред рокот.',
    benefitConsequence:
        'Правото или исплатата може да бидат одбиени, запрени или побарани назад. Чувајте доказ.',
    appealConsequence:
        'Пропуштањето на рокот за жалба може да ја направи одлуката конечна. Проверете ја правната поука.',
    noExplicitConsequence:
        'Текстот не наведува сигурна последица. Проверете го последниот пасус и прилозите.',
  ),
  'bg': _AssistantCopy(
    analyseFirst: 'Първо снимайте или качете писмото и стартирайте анализа.',
    deadline: 'Надеждно разпознатият срок е',
    noDeadline:
        'Не намерих надеждно изричен срок. Проверете абзаците с „bis“, „innerhalb“ и „Frist“.',
    keepOriginal: 'Пазете оригинала и доказателството за изпращане.',
    amount: 'Разпознати са задължение и сума',
    noAmount:
        'Не намерих надеждно сума за плащане. Проверете оригиналната таблица и приложенията.',
    verifyPayment:
        'Преди плащане проверете получателя, IBAN, периода, номера на преписката и крайната сума.',
    foundAmount: 'Разпозната е сума',
    amountNotNecessarilyDue:
        'Текстът не потвърждава, че това е сума за плащане.',
    sender: 'Разпозната институция:',
    titleMeaning: 'Вид писмо:',
    nextSteps: 'Конкретни следващи стъпки:',
    documentsAdvice:
        'Проверете точния списък документи в оригинала. След това:',
    replyAdvice:
        'Отговорът трябва да съдържа номер на преписка, факти и съответните приложения. Предложение:',
    directSummary: 'Пряк отговор според писмото:',
    askHint:
        'Попитайте: „Какъв е срокът?“, „Трябва ли да платя?“ или „Какво следва?“',
    paymentConsequence:
        'Възможни са напомняне, допълнителни разходи, спиране или принудително събиране. Реагирайте преди срока.',
    benefitConsequence:
        'Правото или плащането може да бъдат отказани, спрени или поискани обратно. Пазете доказателство.',
    appealConsequence:
        'Пропускането на срока за обжалване може да направи решението окончателно. Проверете правните указания.',
    noExplicitConsequence:
        'Текстът не посочва надеждно последица. Проверете последния абзац и приложенията.',
  ),
  'de': _AssistantCopy(
    analyseFirst:
        'Fotografieren oder laden Sie zuerst das Schreiben und starten Sie die Analyse.',
    deadline: 'Die zuverlässig erkannte Frist ist der',
    noDeadline:
        'Keine ausdrückliche Frist wurde zuverlässig erkannt. Prüfen Sie Absätze mit „bis“, „innerhalb“ und „Frist“.',
    keepOriginal: 'Original und Versandnachweis aufbewahren.',
    amount: 'Erkannte Zahlungspflicht und Betrag:',
    noAmount:
        'Kein zu zahlender Betrag wurde zuverlässig erkannt. Prüfen Sie Tabelle und Anlagen im Original.',
    verifyPayment:
        'Vor Zahlung Empfänger, IBAN, Zeitraum, Aktenzeichen und Endbetrag prüfen.',
    foundAmount: 'Erkannter Betrag:',
    amountNotNecessarilyDue:
        'Der Text kennzeichnet ihn nicht sicher als Zahlbetrag.',
    sender: 'Erkannte Stelle:',
    titleMeaning: 'Schreibenstyp:',
    nextSteps: 'Konkrete nächste Schritte:',
    documentsAdvice: 'Die genaue Unterlagenliste im Original prüfen. Danach:',
    replyAdvice:
        'Die Antwort sollte Aktenzeichen, Fakten und nur relevante Anlagen enthalten. Vorschlag:',
    directSummary: 'Direkte Antwort anhand des Schreibens:',
    askHint:
        'Fragen Sie z. B.: „Welche Frist gilt?“, „Muss ich zahlen?“ oder „Was soll ich jetzt tun?“',
    paymentConsequence:
        'Möglich sind Mahnkosten, Sperre, Inkasso oder Vollstreckung. Vor Fristablauf reagieren.',
    benefitConsequence:
        'Leistung oder Anspruch können abgelehnt, eingestellt oder zurückgefordert werden. Nachweis aufbewahren.',
    appealConsequence:
        'Eine versäumte Rechtsbehelfsfrist kann die Entscheidung bestandskräftig machen. Rechtsbehelfsbelehrung prüfen.',
    noExplicitConsequence:
        'Im erkannten Text steht keine eindeutige Folge. Letzten Absatz und Anlagen prüfen.',
  ),
  'en': _AssistantCopy(
    analyseFirst:
        'Photograph or upload the letter first, then start the analysis.',
    deadline: 'The reliably recognized deadline is',
    noDeadline:
        'No explicit deadline was reliably found. Check paragraphs containing “bis”, “innerhalb”, or “Frist”.',
    keepOriginal: 'Keep the original and proof of submission.',
    amount: 'A payment obligation and amount were recognized:',
    noAmount:
        'No payable amount was reliably found. Check the original table and attachments.',
    verifyPayment:
        'Before paying, verify the recipient, IBAN, period, reference number, and final amount.',
    foundAmount: 'Recognized amount:',
    amountNotNecessarilyDue:
        'The text does not reliably identify it as payable.',
    sender: 'Recognized institution:',
    titleMeaning: 'Letter type:',
    nextSteps: 'Concrete next steps:',
    documentsAdvice: 'Check the exact document list in the original. Then:',
    replyAdvice:
        'Include the reference number, facts, and only relevant attachments. Suggested approach:',
    directSummary: 'Direct answer based on the letter:',
    askHint:
        'You can ask: “What is the deadline?”, “Do I have to pay?”, or “What should I do next?”',
    paymentConsequence:
        'Possible consequences include reminder fees, suspension, collection, or enforcement. Act before the deadline.',
    benefitConsequence:
        'A benefit or entitlement may be denied, stopped, or reclaimed. Keep proof of your response.',
    appealConsequence:
        'Missing an appeal deadline may make the decision final. Check the Rechtsbehelfsbelehrung section.',
    noExplicitConsequence:
        'No specific consequence was reliably found. Check the final paragraph and attachments.',
  ),
  'tr': _AssistantCopy(
    analyseFirst:
        'Önce mektubun fotoğrafını çekin veya yükleyin, ardından analizi başlatın.',
    deadline: 'Güvenilir biçimde tanınan son tarih',
    noDeadline:
        'Açık bir son tarih güvenilir biçimde bulunamadı. Orijinalde “bis”, “innerhalb” ve “Frist” geçen bölümleri kontrol edin.',
    keepOriginal: 'Orijinali ve gönderim belgesini saklayın.',
    amount: 'Bir ödeme yükümlülüğü ve tutar tanındı:',
    noAmount:
        'Ödenecek tutar güvenilir biçimde bulunamadı. Orijinal tabloyu ve ekleri kontrol edin.',
    verifyPayment:
        'Ödemeden önce alıcıyı, IBAN’ı, dönemi, dosya numarasını ve nihai tutarı doğrulayın.',
    foundAmount: 'Tanınan tutar:',
    amountNotNecessarilyDue:
        'Metin bunun ödenecek tutar olduğunu güvenilir biçimde göstermiyor.',
    sender: 'Tanınan kurum:',
    titleMeaning: 'Mektup türü:',
    nextSteps: 'Somut sonraki adımlar:',
    documentsAdvice:
        'Gerekli belgelerin tam listesini orijinalde kontrol edin. Ardından:',
    replyAdvice:
        'Yanıtta dosya numarasını, gerçekleri ve yalnızca ilgili ekleri belirtin. Öneri:',
    directSummary: 'Mektuba dayalı doğrudan yanıt:',
    askHint:
        'Şunları sorabilirsiniz: “Son tarih nedir?”, “Ödeme yapmalı mıyım?” veya “Şimdi ne yapmalıyım?”',
    paymentConsequence:
        'Hatırlatma ücreti, hizmetin durdurulması, tahsilat veya icra söz konusu olabilir. Son tarihten önce harekete geçin.',
    benefitConsequence:
        'Bir hak veya ödeme reddedilebilir, durdurulabilir ya da geri istenebilir. Yanıtınızın kanıtını saklayın.',
    appealConsequence:
        'İtiraz süresinin kaçırılması kararı kesinleştirebilir. Rechtsbehelfsbelehrung bölümünü kontrol edin.',
    noExplicitConsequence:
        'Belirli bir sonuç güvenilir biçimde bulunamadı. Son paragrafı ve ekleri kontrol edin.',
  ),
};
