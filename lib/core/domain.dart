import 'package:flutter/foundation.dart';

import 'app_config.dart';

enum LetterCategory {
  finanzamt,
  krankenkasse,
  jobcenter,
  bank,
  insurance,
  telecom,
  employer,
  landlord,
  school,
  kindergarten,
  court,
  familienkasse,
  agenturFuerArbeit,
  auslaenderbehoerde,
  buergeramt,
  sozialamt,
  jugendamt,
  wohngeldstelle,
  bafoegAmt,
  rentenversicherung,
  rundfunkbeitrag,
  energy,
  debtCollection,
  police,
  customs,
  other;

  String get label => switch (this) {
    finanzamt => 'Finanzamt',
    krankenkasse => 'Krankenkasse',
    jobcenter => 'Jobcenter',
    bank => 'Banka',
    insurance => 'Osiguranje',
    telecom => 'Telekom',
    employer => 'Poslodavac',
    landlord => 'Stanodavac',
    school => 'Škola',
    kindergarten => 'Vrtić',
    court => 'Sud',
    familienkasse => 'Familienkasse',
    agenturFuerArbeit => 'Agentur für Arbeit',
    auslaenderbehoerde => 'Ausländerbehörde',
    buergeramt => 'Bürgeramt',
    sozialamt => 'Sozialamt',
    jugendamt => 'Jugendamt',
    wohngeldstelle => 'Wohngeldstelle',
    bafoegAmt => 'BAföG-Amt',
    rentenversicherung => 'Rentenversicherung',
    rundfunkbeitrag => 'Rundfunkbeitrag',
    energy => 'Energieversorger',
    debtCollection => 'Inkasso',
    police => 'Policija/Tužilaštvo',
    customs => 'Zoll',
    other => 'Ostalo',
  };
}

enum Urgency { low, medium, high }

/// The practical communication state of a letter.  Payment state is stored
/// separately because a sent reply and a paid invoice are independent facts.
enum LetterStatus {
  newLetter,
  inProgress,
  replyPrepared,
  sent,
  awaitingReply,
  done,
}

/// A small, stable set of local folders.  They intentionally complement the
/// automatically detected sender category; a Familienkasse letter can, for
/// example, be filed under `family` without losing its original category.
enum LetterFolder { inbox, housing, work, family, insurance, taxes, finance }

class GeneratedReply {
  const GeneratedReply({required this.letter, required this.email});

  final String letter;
  final String email;
}

class SavedGeneratedReply {
  const SavedGeneratedReply({
    required this.reply,
    required this.userContext,
    required this.updatedAt,
  });

  final GeneratedReply reply;
  final String userContext;
  final DateTime updatedAt;
}

class LetterAnalysis {
  const LetterAnalysis({
    required this.id,
    required this.title,
    required this.plainExplanation,
    required this.category,
    required this.urgency,
    required this.suggestedAction,
    required this.createdAt,
    this.senderName,
    this.recipientName,
    this.paymentRecipient,
    this.documentType,
    this.invoiceNumber,
    this.servicePeriod,
    this.paymentReference,
    this.paymentIban,
    this.deadline,
    this.paymentDueDate,
    this.isPaymentObligation = false,
    this.paymentPaid = false,
    this.paymentPaidAt,
    this.amount,
    this.status = LetterStatus.newLetter,
    this.folder = LetterFolder.inbox,
    this.tags = const <String>[],
    this.sourceText = '',
  });

  final String id;
  final String title;
  final String plainExplanation;
  final LetterCategory category;
  final Urgency urgency;
  final String suggestedAction;
  final DateTime createdAt;
  final String? senderName;
  final String? recipientName;
  final String? paymentRecipient;
  final String? documentType;
  final String? invoiceNumber;
  final String? servicePeriod;
  final String? paymentReference;
  final String? paymentIban;
  final DateTime? deadline;
  final DateTime? paymentDueDate;
  final bool isPaymentObligation;
  final bool paymentPaid;
  final DateTime? paymentPaidAt;
  final String? amount;
  final LetterStatus status;
  final LetterFolder folder;
  final List<String> tags;
  final String sourceText;

  LetterAnalysis copyWith({
    LetterStatus? status,
    LetterFolder? folder,
    List<String>? tags,
    bool? paymentPaid,
    DateTime? paymentPaidAt,
    bool clearPaymentPaidAt = false,
  }) => LetterAnalysis(
    id: id,
    title: title,
    plainExplanation: plainExplanation,
    category: category,
    urgency: urgency,
    suggestedAction: suggestedAction,
    createdAt: createdAt,
    senderName: senderName,
    recipientName: recipientName,
    paymentRecipient: paymentRecipient,
    documentType: documentType,
    invoiceNumber: invoiceNumber,
    servicePeriod: servicePeriod,
    paymentReference: paymentReference,
    paymentIban: paymentIban,
    deadline: deadline,
    paymentDueDate: paymentDueDate,
    isPaymentObligation: isPaymentObligation,
    paymentPaid: paymentPaid ?? this.paymentPaid,
    paymentPaidAt: clearPaymentPaidAt
        ? null
        : paymentPaidAt ?? this.paymentPaidAt,
    amount: amount,
    status: status ?? this.status,
    folder: folder ?? this.folder,
    tags: tags ?? this.tags,
    sourceText: sourceText,
  );

  Map<String, dynamic> toMap() => {
    'title': title,
    'plainExplanation': plainExplanation,
    'category': category.label,
    'urgency': urgency.name.toUpperCase(),
    'deadline': deadline?.toIso8601String().split('T').first,
    'paymentDueDate': paymentDueDate?.toIso8601String().split('T').first,
    'isPaymentObligation': isPaymentObligation,
    'amounts': amount == null ? <String>[] : [amount],
    'amount': amount,
    'suggestedAction': suggestedAction,
    'senderName': senderName,
    'recipientName': recipientName,
    'paymentRecipient': paymentRecipient,
    'documentType': documentType,
    'invoiceNumber': invoiceNumber,
    'servicePeriod': servicePeriod,
    'paymentReference': paymentReference,
    'paymentIban': paymentIban,
    'totalAmount': amount,
    'status': status.name,
    'folder': folder.name,
    'tags': tags,
    'paymentPaid': paymentPaid,
    'paymentPaidAt': paymentPaidAt?.toIso8601String(),
    'sourceText': sourceText,
  };

  factory LetterAnalysis.fromMap({
    required String id,
    required Map<String, dynamic> map,
    String? sourceText,
  }) {
    final deadlineValue = map['deadline'] as String?;
    final paymentDueDateValue = map['paymentDueDate'] as String?;
    final paymentPaidAtValue = map['paymentPaidAt'] as String?;
    final amountValues = map['amounts'];
    final createdAt = _readCreatedAt(map['createdAt']);
    return LetterAnalysis(
      id: id,
      title: map['title'] as String? ?? 'Službeno pismo',
      plainExplanation: map['plainExplanation'] as String? ?? '',
      category: LetterCategory.values.firstWhere(
        (value) => value.label == map['category'],
        orElse: () => LetterCategory.other,
      ),
      urgency: Urgency.values.firstWhere(
        (value) => value.name.toUpperCase() == map['urgency'],
        orElse: () => Urgency.low,
      ),
      suggestedAction: map['suggestedAction'] as String? ?? '',
      createdAt: createdAt,
      senderName: _nonEmptyString(map['senderName']),
      recipientName: _nonEmptyString(map['recipientName']),
      paymentRecipient: _nonEmptyString(map['paymentRecipient']),
      documentType: _nonEmptyString(map['documentType']),
      invoiceNumber: _nonEmptyString(map['invoiceNumber']),
      servicePeriod: _nonEmptyString(map['servicePeriod']),
      paymentReference: _nonEmptyString(map['paymentReference']),
      paymentIban: _nonEmptyString(map['paymentIban']),
      deadline: deadlineValue == null ? null : DateTime.tryParse(deadlineValue),
      paymentDueDate: paymentDueDateValue == null
          ? null
          : DateTime.tryParse(paymentDueDateValue),
      isPaymentObligation: map['isPaymentObligation'] == true,
      paymentPaid: map['paymentPaid'] == true,
      paymentPaidAt: paymentPaidAtValue == null
          ? null
          : DateTime.tryParse(paymentPaidAtValue),
      amount:
          _nonEmptyString(map['totalAmount']) ??
          _nonEmptyString(map['amount']) ??
          (amountValues is List && amountValues.isNotEmpty
              ? amountValues.first as String?
              : null),
      status: LetterStatus.values.firstWhere(
        (value) => value.name == map['status'],
        orElse: () => LetterStatus.newLetter,
      ),
      folder: LetterFolder.values.firstWhere(
        (value) => value.name == map['folder'],
        orElse: () => LetterFolder.inbox,
      ),
      tags:
          (map['tags'] as List?)
              ?.whereType<String>()
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toSet()
              .toList(growable: false) ??
          const <String>[],
      sourceText: sourceText ?? map['sourceText'] as String? ?? '',
    );
  }
}

/// Local Sembast records serialize dates as ISO strings, while the optional
/// cloud-compatible format can expose a Timestamp-like value with `toDate()`.
/// Never call `toDate()` on a local String: doing so stopped the complete
/// archive stream when the app reopened after a successful local save.
DateTime _readCreatedAt(Object? value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  try {
    final dynamic timestampLike = value;
    final date = timestampLike?.toDate();
    if (date is DateTime) return date;
  } on Object {
    // A local malformed legacy value must not hide every other letter.
  }
  return DateTime.now();
}

String? _nonEmptyString(dynamic value) {
  if (value is! String || value.trim().isEmpty) return null;
  return value.trim();
}

class AppState extends ChangeNotifier {
  bool onboardingComplete = false;
  int freeAnalysesUsed = 0;
  bool isPremium = false;

  /// Language used by the static application interface. It is deliberately
  /// limited to bundles shipped with the app.
  String localeCode = 'sr';

  /// Language sent to AI for explanations, chat and reminders. This may use
  /// the wider AI language catalogue without changing interface copy.
  String aiLanguageCode = 'sr';
  final List<LetterAnalysis> letters = [];

  bool get canAnalyse => isPremium || freeAnalysesUsed < kFreeAnalysisLimit;

  void setLocale(String value) {
    if (!const <String>{
      'ar',
      'bg',
      'bs',
      'de',
      'el',
      'en',
      'hr',
      'it',
      'mk',
      'pl',
      'ro',
      'ru',
      'sq',
      'sr',
      'tr',
      'uk',
    }.contains(value)) {
      value = 'en';
    }
    if (localeCode == value) return;
    localeCode = value;
    notifyListeners();
  }

  void setAiLanguage(String value) {
    if (!const <String>{
      'sq',
      'ar',
      'hy',
      'az',
      'bn',
      'bs',
      'bg',
      'zh',
      'hr',
      'cs',
      'da',
      'nl',
      'en',
      'et',
      'fa',
      'fi',
      'fr',
      'ka',
      'de',
      'el',
      'he',
      'hi',
      'hu',
      'is',
      'id',
      'it',
      'ja',
      'kk',
      'ko',
      'ku',
      'lv',
      'lt',
      'mk',
      'ms',
      'no',
      'ps',
      'pl',
      'pt',
      'ro',
      'ru',
      'sr',
      'sk',
      'sl',
      'es',
      'sw',
      'sv',
      'ta',
      'th',
      'tr',
      'uk',
      'ur',
      'uz',
      'vi',
    }.contains(value)) {
      value = 'en';
    }
    if (aiLanguageCode == value) return;
    aiLanguageCode = value;
    notifyListeners();
  }

  void completeOnboarding() {
    onboardingComplete = true;
    notifyListeners();
  }

  void restoreOnboarding(bool completed) {
    onboardingComplete = completed;
    notifyListeners();
  }

  void addAnalysis(LetterAnalysis analysis) {
    letters.insert(0, analysis);
    notifyListeners();
  }

  void setFreeAnalysesUsed(int value) {
    freeAnalysesUsed = value.clamp(0, kFreeAnalysisLimit).toInt();
    notifyListeners();
  }

  void updateStatus(String id, LetterStatus status) {
    final index = letters.indexWhere((letter) => letter.id == id);
    if (index == -1) return;
    letters[index] = letters[index].copyWith(status: status);
    notifyListeners();
  }

  void replaceLetters(List<LetterAnalysis> values) {
    letters
      ..clear()
      ..addAll(values);
    notifyListeners();
  }

  void activatePremium() {
    isPremium = true;
    notifyListeners();
  }

  void setPremium(bool value) {
    isPremium = value;
    notifyListeners();
  }
}
