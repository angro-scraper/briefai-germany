import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import test from "node:test";

const source = readFileSync(new URL("../src/index.ts", import.meta.url), "utf8");

test("life assistant keeps zero-token guides in their authored language", () => {
  const fn = source.slice(
    source.indexOf("export const askLifeInGermanyAssistant"),
    source.indexOf("export const generateLifeInGermanyEmail"),
  );
  assert.match(fn, /if \(instantGuide && language === "sr"\)/);
  assert.match(fn, /Answer in the requested BCP-47 language code/);
});

test("life assistant receives a separate municipality field", () => {
  const fn = source.slice(
    source.indexOf("export const askLifeInGermanyAssistant"),
    source.indexOf("export const generateLifeInGermanyEmail"),
  );
  assert.match(fn, /City \/ municipality: \$\{city \|\| "Not provided"\}/);
  assert.match(fn, /city-specific rule or link/);
});
