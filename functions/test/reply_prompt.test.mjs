import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import test from "node:test";

const source = readFileSync(new URL("../src/index.ts", import.meta.url), "utf8");

test("reply prompt requires a detailed legal-style letter and substantive email", () => {
  assert.match(source, /senior German legal-correspondence drafting specialist/);
  assert.match(source, /400-800 German words/);
  assert.match(source, /200-450 German words/);
  assert.match(source, /Required letter structure:/);
  assert.match(source, /A clear final request/);
  assert.match(source, /substantive response covering all material points/);
});

test("reply prompt forbids invented legal and personal facts", () => {
  assert.match(source, /Do not invent statutes, case law, legal rights/);
  assert.match(source, /square-bracket placeholder/);
  assert.match(source, /never state or imply that you are a lawyer/);
  assert.match(source, /Do not claim that a document is enclosed/);
});

test("reply generation has enough output budget and requests high verbosity", () => {
  const replyFunction = source.slice(
    source.indexOf("export const generateReply"),
    source.indexOf("export const askLetterAssistant"),
  );
  assert.match(replyFunction, /const maxOutputTokens = 2800/);
  assert.match(replyFunction, /reasoning: \{effort: "low"\}/);
  assert.match(replyFunction, /verbosity: "high"/);
  assert.doesNotMatch(replyFunction, /concise email/);
});
