import 'package:flutter/foundation.dart';

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
    other => 'Ostalo',
  };
}

enum Urgency { low, medium, high }

enum LetterStatus { newLetter, inProgress, done }

class GeneratedReply {
  const GeneratedReply({required this.letter, required this.email});

  final String letter;
  final String email;
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
    this.deadline,
    this.amount,
    this.status = LetterStatus.newLetter,
    this.sourceText = '',
  });

  final String id;
  final String title;
  final String plainExplanation;
  final LetterCategory category;
  final Urgency urgency;
  final String suggestedAction;
  final DateTime createdAt;
  final DateTime? deadline;
  final String? amount;
  final LetterStatus status;
  final String sourceText;

  LetterAnalysis copyWith({LetterStatus? status}) => LetterAnalysis(
    id: id,
    title: title,
    plainExplanation: plainExplanation,
    category: category,
    urgency: urgency,
    suggestedAction: suggestedAction,
    createdAt: createdAt,
    deadline: deadline,
    amount: amount,
    status: status ?? this.status,
    sourceText: sourceText,
  );

  Map<String, dynamic> toMap() => {
    'title': title,
    'plainExplanation': plainExplanation,
    'category': category.label,
    'urgency': urgency.name.toUpperCase(),
    'deadline': deadline?.toIso8601String().split('T').first,
    'amounts': amount == null ? <String>[] : [amount],
    'amount': amount,
    'suggestedAction': suggestedAction,
    'status': status.name,
    'sourceText': sourceText,
  };

  factory LetterAnalysis.fromMap({
    required String id,
    required Map<String, dynamic> map,
    String? sourceText,
  }) {
    final deadlineValue = map['deadline'] as String?;
    final amountValues = map['amounts'];
    final dynamic rawCreatedAt = map['createdAt'];
    final createdAt = rawCreatedAt is DateTime
        ? rawCreatedAt
        : rawCreatedAt?.toDate() as DateTime? ??
              DateTime.tryParse(rawCreatedAt?.toString() ?? '') ??
              DateTime.now();
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
      deadline: deadlineValue == null ? null : DateTime.tryParse(deadlineValue),
      amount:
          map['amount'] as String? ??
          (amountValues is List && amountValues.isNotEmpty
              ? amountValues.first as String?
              : null),
      status: LetterStatus.values.firstWhere(
        (value) => value.name == map['status'],
        orElse: () => LetterStatus.newLetter,
      ),
      sourceText: sourceText ?? map['sourceText'] as String? ?? '',
    );
  }
}

class AppState extends ChangeNotifier {
  bool onboardingComplete = false;
  int freeAnalysesUsed = 0;
  bool isPremium = false;
  final List<LetterAnalysis> letters = [];

  bool get canAnalyse => isPremium || freeAnalysesUsed < 2;

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
    if (!isPremium) freeAnalysesUsed++;
    notifyListeners();
  }

  void setFreeAnalysesUsed(int value) {
    freeAnalysesUsed = value.clamp(0, 2).toInt();
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
