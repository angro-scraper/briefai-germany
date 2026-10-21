import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import test from "node:test";

const source = readFileSync(new URL("../src/index.ts", import.meta.url), "utf8");
const rules = readFileSync(new URL("../../firestore.rules", import.meta.url), "utf8");

test("partner attribution is limited to a recent authenticated account", () => {
  assert.match(source, /export const claimPartnerReferral/);
  assert.match(source, /affiliateAttributionWindowMs = 30 \* 24 \* 60 \* 60 \* 1000/);
  assert.match(source, /getAuth\(\)\.getUser\(uid\)/);
  assert.match(source, /partnerAttributions"\)\.doc\(uid\)\.create/);
});

test("only verified store receipts create exactly-once partner conversions", () => {
  assert.match(source, /async function recordAffiliateConversion/);
  assert.match(source, /affiliateConversions"\)\.doc\(transactionId\)\.create/);
  assert.match(source, /if \(verification\.active\) \{/);
  assert.match(source, /kind: "briefai_credits"/);
});

test("partners cannot read customer identities or attribution documents", () => {
  assert.match(rules, /match \/partnerAttributions\/\{uid\}/);
  assert.match(rules, /match \/affiliateConversions\/\{conversionId\}/);
  assert.match(rules, /allow read, write: if false/);
});
