const bool kCloudAiEnabled = bool.fromEnvironment(
  'BRIEFAI_CLOUD_AI_ENABLED',
  defaultValue: true,
);

/// Every new account receives five introductory analyses. Paid plans reset
/// their included analysis allowance each month.
const int kFreeAnalysisLimit = 5;

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
