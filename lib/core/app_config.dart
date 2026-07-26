/// Release switches for the public beta.
///
/// They are compile-time values so no secret is ever shipped through Render's
/// static hosting. A later paid build can override them with `--dart-define`.
const bool kFreeBetaMode = bool.fromEnvironment(
  'BRIEFAI_FREE_BETA',
  defaultValue: true,
);

const bool kPaymentsEnabled = bool.fromEnvironment(
  'BRIEFAI_PAYMENTS_ENABLED',
  defaultValue: false,
);

const bool kCloudAiEnabled = bool.fromEnvironment(
  'BRIEFAI_CLOUD_AI_ENABLED',
  defaultValue: true,
);
