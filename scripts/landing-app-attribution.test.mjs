import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import test from 'node:test';
import {resolveAppLinkSource} from '../install-site/analytics-source.js';

const englishHtml = await readFile(
  new URL('../install-site/en/index.html', import.meta.url),
  'utf8',
);

test('real external campaign labels replace the static page fallback', () => {
  assert.equal(resolveAppLinkSource('ref_deutschlanddecoded', 'seo_en_landing'), 'ref_deutschlanddecoded');
  assert.equal(resolveAppLinkSource('applauncher', 'seo_en_landing'), 'applauncher');
});

test('unknown and internal visits retain the CTA fallback instead of being mislabeled', () => {
  assert.equal(resolveAppLinkSource('unknown', 'seo_en_landing'), 'seo_en_landing');
  assert.equal(resolveAppLinkSource('internal', 'seo_en_landing'), 'seo_en_landing');
  assert.equal(resolveAppLinkSource('unknown', null), null);
});

test('source selection is wired into English hosted-app links', () => {
  assert.match(englishHtml, /import \{resolveAppLinkSource, resolveLandingSource\} from '\/analytics-source\.js'/);
  assert.match(englishHtml, /resolveAppLinkSource\(source, destination\.searchParams\.get\('utm_source'\)\)/);
});
