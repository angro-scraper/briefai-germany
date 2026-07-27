/// Release switches for the public beta.
///
/// They are compile-time values so no secret is ever shipped through Render's
/// static hosting. A later paid build can override them with `--dart-define`.
const bool kFreeBetaMode = bool.fromEnvironment(
  'BRIEFAI_FREE_BETA',
  defaultValue: false,
);

const bool kPaymentsEnabled = bool.fromEnvironment(
  'BRIEFAI_PAYMENTS_ENABLED',
  defaultValue: false,
);

const bool kCloudAiEnabled = bool.fromEnvironment(
  'BRIEFAI_CLOUD_AI_ENABLED',
  defaultValue: true,
);

/// Store-review and closed-testing accounts can analyse fifteen letters
/// without payment. This is a lifetime testing allowance, not a monthly one.
const int kFreeAnalysisLimit = 15;

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

/// The first product ID is intentionally kept for compatibility with the
/// subscription that already exists in Google Play and App Store Connect.
const List<SubscriptionPlan> kSubscriptionPlans = [
  SubscriptionPlan(
    key: 'basic',
    productId: 'briefai_premium_monthly',
    monthlyAnalysisLimit: 50,
    fallbackPrice: '9,90 € / mesečno',
  ),
  SubscriptionPlan(
    key: 'plus',
    productId: 'briefai_plus_monthly',
    monthlyAnalysisLimit: 100,
    fallbackPrice: '19,90 € / mesečno',
  ),
  SubscriptionPlan(
    key: 'pro',
    productId: 'briefai_pro_monthly',
    monthlyAnalysisLimit: 150,
    fallbackPrice: '29,90 € / mesečno',
  ),
];
