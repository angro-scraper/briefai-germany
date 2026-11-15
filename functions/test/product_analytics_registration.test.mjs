import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import test from "node:test";

const functionSource = readFileSync(new URL("../src/index.ts", import.meta.url), "utf8");
const appSource = readFileSync(new URL("../../lib/app/briefai_app.dart", import.meta.url), "utf8");
const servicesSource = readFileSync(new URL("../../lib/core/app_services.dart", import.meta.url), "utf8");

test("social sign-ins attempt consent-gated registration tracking", () => {
  assert.match(appSource, /Future<void> _google\(\)[\s\S]*?signInWithGoogle\(\);[\s\S]*?trackRegistration\(\)/);
  assert.match(appSource, /Future<void> _apple\(\)[\s\S]*?signInWithApple\(\);[\s\S]*?trackRegistration\(\)/);
  assert.match(servicesSource, /Future<void> setConsent\(bool allowed\)[\s\S]*?if \(allowed\)[\s\S]*?currentUser != null\)[\s\S]*?trackRegistration\(\)/);
});

test("server rejects old sign-ins and deduplicates new identities", () => {
  assert.match(functionSource, /const account = await getAuth\(\)\.getUser\(request\.auth!\.uid\)/);
  assert.match(functionSource, /registrationWindowMs = 30 \* 60 \* 1000/);
  assert.match(functionSource, /Date\.now\(\) - createdAt > registrationWindowMs/);
  assert.match(functionSource, /productAnalyticsRegistrations"\)\.doc\(uid\)/);
});
