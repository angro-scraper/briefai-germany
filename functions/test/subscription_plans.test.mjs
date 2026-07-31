import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import test from "node:test";

const source = readFileSync(new URL("../src/index.ts", import.meta.url), "utf8");

test("closed testing grants five analyses before payment", () => {
  assert.match(source, /const freeAnalysisLimit = 5;/);
});

test("three store products map to 50, 100 and 150 monthly analyses", () => {
  assert.match(
    source,
    /productId: "briefai_premium_monthly",\s+monthlyAnalysisLimit: 50/,
  );
  assert.match(
    source,
    /productId: "briefai_plus_monthly",\s+monthlyAnalysisLimit: 100/,
  );
  assert.match(
    source,
    /productId: "briefai_pro_monthly",\s+monthlyAnalysisLimit: 150/,
  );
});

test("paid quota is reserved transactionally and released after failure", () => {
  assert.match(source, /transaction\.get\(monthlyUsageRef\)/);
  assert.match(source, /analysesThisMonth >= plan\.monthlyAnalysisLimit/);
  assert.match(source, /reservedAnalysis === "free"/);
});
