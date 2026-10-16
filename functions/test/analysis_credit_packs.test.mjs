import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import test from "node:test";

const source = readFileSync(new URL("../src/index.ts", import.meta.url), "utf8");

test("one-time analysis packs have fixed server-side credit values", () => {
  assert.match(source, /"briefai\.credits\.3": \{credits: 3\}/);
  assert.match(source, /"briefai\.credits\.5": \{credits: 5\}/);
});

test("analysis credits are account-bound and used before free allowance", () => {
  assert.match(source, /const analysisCredits = Number\(usage\.data\(\)\?\.analysisCredits \?\? 0\)/);
  assert.match(source, /analysisCredits: analysisCredits - 1/);
  assert.match(source, /reservedAnalysis === "credit"/);
});

test("a consumable receipt is granted exactly once", () => {
  assert.match(source, /if \(!prior\.exists\) \{/);
  assert.match(source, /creditsAdded = credits!/);
  assert.match(source, /analysisCredits \+= creditsAdded/);
  assert.match(source, /collection\("storeTransactions"\)/);
});
