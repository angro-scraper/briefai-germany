import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';
import test from 'node:test';
import { resolveLandingSource } from '../install-site/analytics-source.js';

const landing = readFileSync(new URL('../install-site/index.html', import.meta.url), 'utf8');
const sourceExpression = landing.match(/const campaignSource = (\(\(\) => \{[\s\S]*?\}\)\(\));/);
assert.ok(sourceExpression, 'the root landing must derive its web-app source');
assert.match(landing, /if \(campaignSource\) appQuery\.set\('utm_source', campaignSource\)/);

for (const [query, referrer] of [
  ['', ''],
  ['?utm_source=bluesky', ''],
  ['?utm_source=Bluesky_Video', 'https://google.de/search?q=letter'],
  ['?utm_source=invalid%20value', 'https://www.google.de/search?q=letter'],
  ['', 'https://bing.com/search?q=letter'],
  ['', 'https://briefai.salvesca.com/de/'],
  ['', 'https://other.example/path?private=1'],
]) {
  test(`root web-app source matches consented analytics for ${query || '(untagged)'} / ${referrer || '(no referrer)'}`, () => {
    const siteOrigin = 'https://briefai.salvesca.com';
    const actual = runInNewContext(sourceExpression[1], {
      landingQuery: new URLSearchParams(query),
      document: { referrer },
      location: { hostname: 'briefai.salvesca.com' },
      URL,
    });
    assert.equal(actual, resolveLandingSource(query, referrer, siteOrigin));
    assert.ok(actual.length <= 32);
  });
}
