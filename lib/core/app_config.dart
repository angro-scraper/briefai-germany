const bool kCloudAiEnabled = bool.fromEnvironment(
  'BRIEFAI_CLOUD_AI_ENABLED',
  defaultValue: true,
);

/// Every new account receives five introductory analyses. Paid plans reset
/// their included analysis allowance each month.
const int kFreeAnalysisLimit = 5;

/// Questionnaire completion is a separate paid workflow.  Its introductory
/// allowance must never consume the analyses granted for letter explanations.
/// The counter is activated by the questionnaire workflow, not by OCR or a
/// drafted reply.
const int kFreeQuestionnaireLimit = 2;

/// Store builds provide the platform-specific subscription management page at
/// compile time. The Apple URL is the safe default for iOS review binaries;
/// Android release workflows override it without embedding third-party store
/// references in the iOS binary.
const String kSubscriptionManagementUrl = String.fromEnvironment(
  'SUBSCRIPTION_MANAGEMENT_URL',
  defaultValue: 'https://apps.apple.com/account/subscriptions',
);

class SubscriptionPlan {
  const SubscriptionPlan({
    required this.key,
    required this.productId,
    required this.monthlyAnalysisLimit,
    required this.fallbackPrice,
  });

  final String key;
  final String productId;
  final int monthlyAnalysisLimit;
  final String fallbackPrice;
}

/// A single-use pack of analysis credits.  These are consumable store
/// products, so the balance is kept against the signed-in BriefAI account by
/// the backend rather than inferred from StoreKit/Google Play restores.
class AnalysisCreditPack {
  const AnalysisCreditPack({
    required this.productId,
    required this.credits,
    required this.fallbackPrice,
  });

  final String productId;
  final int credits;
  final String fallbackPrice;
}

const List<AnalysisCreditPack> kAnalysisCreditPacks = [
  AnalysisCreditPack(
    productId: 'briefai.credits.3',
    credits: 3,
    fallbackPrice: '2,99 €',
  ),
  AnalysisCreditPack(
    productId: 'briefai.credits.5',
    credits: 5,
    fallbackPrice: '3,99 €',
  ),
];

/// One-time questionnaire completion packs.  They are separate from letter
/// analysis credits because filling an official form has its own quota and
/// must never silently consume a user's letter analyses.
class QuestionnaireCreditPack {
  const QuestionnaireCreditPack({
    required this.productId,
    required this.credits,
    required this.fallbackPrice,
  });

  final String productId;
  final int credits;
  final String fallbackPrice;
}

const List<QuestionnaireCreditPack> kQuestionnaireCreditPacks = [
  QuestionnaireCreditPack(
    productId: 'briefai.questionnaires.3',
    credits: 3,
    fallbackPrice: '2,99 €',
  ),
  QuestionnaireCreditPack(
    productId: 'briefai.questionnaires.5',
    credits: 5,
    fallbackPrice: '3,99 €',
  ),
];

/// The first product ID is intentionally kept for compatibility with the
/// subscription that already exists in both supported mobile stores.
const List<SubscriptionPlan> kSubscriptionPlans = [
  SubscriptionPlan(
    key: 'basic',
    productId: 'briefai_premium_monthly',
    monthlyAnalysisLimit: 50,
    fallbackPrice: '9,90 €',
  ),
  SubscriptionPlan(
    key: 'plus',
    productId: 'briefai_plus_monthly',
    monthlyAnalysisLimit: 100,
    fallbackPrice: '19,90 €',
  ),
  SubscriptionPlan(
    key: 'pro',
    productId: 'briefai_pro_monthly',
    monthlyAnalysisLimit: 150,
    fallbackPrice: '29,90 €',
  ),
];
