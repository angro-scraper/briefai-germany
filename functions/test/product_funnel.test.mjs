import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import test from "node:test";

const service = readFileSync(new URL("../../lib/core/app_services.dart", import.meta.url), "utf8");
const app = readFileSync(new URL("../../lib/app/briefai_app.dart", import.meta.url), "utf8");
const backend = readFileSync(new URL("../src/index.ts", import.meta.url), "utf8");
const admin = readFileSync(new URL("../../admin-panel/index.html", import.meta.url), "utf8");

test("in-app funnel events require analytics consent and carry no letter content", () => {
  assert.match(service, /if \(preferences\.getBool\(_consentKey\) != true\) return;/);
  assert.match(service, /if \(!wasAllowed\)[\s\S]*?briefai\.onboarding-complete[\s\S]*?trackOnboardingComplete\(\)/);
  assert.match(service, /final payload = <String, String>\{'event': event, 'source': source\};/);
  assert.match(service, /if \(!funnel\) \{[\s\S]*?payload\['visitorId'\] = visitorId;/);
  assert.match(service, /trackAppOpen\(\).*?'app_open'/);
  assert.match(service, /trackOnboardingComplete\(\)[\s\S]*?'onboarding_complete'/);
  assert.match(service, /trackAnalysisStart\(\).*?'analysis_start'/);
  assert.match(service, /trackAnalysisComplete\(\)[\s\S]*?'analysis_complete'/);
  assert.match(service, /trackSecondDocument\(\)[\s\S]*?'second_document'/);
  assert.match(service, /trackPaywallOpen\(\).*?'paywall_open'/);
});

test("app records milestones rather than treating views as conversions", () => {
  assert.match(app, /_completeOnboarding\(\)[\s\S]*?firstCompletion[\s\S]*?trackOnboardingComplete\(\)/);
  assert.match(app, /_analyse\(\)[\s\S]*?trackAnalysisStart\(\)[\s\S]*?services\.ai\.analyse\(/);
  assert.match(app, /services\.letters\.save\([\s\S]*?trackAnalysisComplete\(\)/);
  assert.match(app, /isSecondDocument = widget\.state\.letters\.length == 1;[\s\S]*?trackSecondDocument\(\)/);
  assert.match(app, /class _SubscriptionScreenState[\s\S]*?trackPaywallOpen\(\)/);
});

test("server stores only aggregate funnel counters, separate from discovery metrics", () => {
  assert.match(backend, /productFunnelDaily/);
  assert.match(backend, /recordFunnelAnalyticsEvent\(event: FunnelEvent, source: unknown\)/);
  assert.match(backend, /\[funnelFields\[event\]\]: FieldValue\.increment\(1\)/);
  assert.match(backend, /if \(event in funnelFields\) \{[\s\S]*?recordFunnelAnalyticsEvent/);
  assert.match(backend, /funnel:?[\s\S]*?productFunnelOverview\(\)/);
  assert.match(admin, /id="analysis-starts"/);
  assert.match(admin, /id="paywall-opens"/);
  assert.doesNotMatch(admin, /id="visit-conversion"/);
});
