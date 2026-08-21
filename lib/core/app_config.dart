const bool kCloudAiEnabled = bool.fromEnvironment(
  'BRIEFAI_CLOUD_AI_ENABLED',
  defaultValue: true,
);

/// Every new account receives five introductory analyses. Paid plans reset
/// their included analysis allowance each month.
const int kFreeAnalysisLimit = 5;

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
