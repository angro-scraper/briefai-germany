import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const html = readFileSync(new URL('../install-site/de/index.html', import.meta.url), 'utf8');
const mobileStyles = html.match(/@media\(max-width:760px\)\{([^\n]+)\}/)?.[1];

test('German landing keeps the language switch available on mobile', () => {
  assert.match(html, /<a class="lang" href="\/\?lang=sr" aria-label="Andere Sprache wählen">/);
  assert.match(html, /<span class="mobile-label" aria-hidden="true">Sprache<\/span>/);
  assert.ok(mobileStyles, 'mobile breakpoint exists');
  assert.match(mobileStyles, /\.nav\{gap:8px\}/);
  assert.match(mobileStyles, /\.lang \.mobile-label\{display:inline\}/);
  assert.doesNotMatch(mobileStyles, /\.nav \.lang\{display:none\}/);
});
