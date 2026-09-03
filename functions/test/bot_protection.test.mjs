import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import test from "node:test";

const source = readFileSync(new URL("../src/index.ts", import.meta.url), "utf8");
const landing = readFileSync(new URL("../../install-site/index.html", import.meta.url), "utf8");
const testerPage = readFileSync(new URL("../../install-site/testeri.html", import.meta.url), "utf8");
const siteSecurity = readFileSync(
  new URL("../../install-site/firebase-site-security.js", import.meta.url),
  "utf8",
);

function exportedFunction(name, nextName) {
  return source.slice(
    source.indexOf(`export const ${name}`),
    source.indexOf(`export const ${nextName}`),
  );
}

test("public endpoints require valid Firebase App Check tokens", () => {
  const analytics = exportedFunction("publicAnalytics", "submitTesterLead");
  const testerLead = exportedFunction("submitTesterLead", "analyzeLetter");
  assert.match(analytics, /onCall\([\s\S]*enforceAppCheck: true/);
  assert.match(testerLead, /onCall\([\s\S]*enforceAppCheck: true/);
  assert.match(source, /recordAnalyticsEvent = onCall\(\s*\{region: "europe-west3", enforceAppCheck: true\}/);
});

test("public website obtains invisible reCAPTCHA Enterprise App Check tokens", () => {
  assert.match(siteSecurity, /ReCaptchaEnterpriseProvider/);
  assert.match(siteSecurity, /initializeAppCheck/);
  assert.match(siteSecurity, /httpsCallable\(functions, 'publicAnalytics'\)/);
  assert.match(siteSecurity, /httpsCallable\(functions, 'submitTesterLead'\)/);
  assert.match(landing, /recordPublicAnalytics/);
});

test("tester form combines App Check, a honeypot and minimum completion time", () => {
  assert.match(testerPage, /name="website"/);
  assert.match(testerPage, /startedAt/);
  assert.match(testerPage, /submitProtectedTesterLead/);
  assert.match(source, /elapsed < 1500/);
  assert.match(source, /requirePublicBurstAllowance\(request, "tester-lead", 5/);
});

test("authenticated expensive operations have server-side burst limits", () => {
  for (const bucket of [
    "analyze-letter",
    "generate-reply",
    "letter-assistant",
    "life-assistant",
    "life-email",
    "stripe-checkout",
    "stripe-portal",
    "verify-store-purchase",
    "account-export",
  ]) {
    assert.match(source, new RegExp(`requireUserRateAllowance\\(uid, "${bucket}"`));
  }
});
