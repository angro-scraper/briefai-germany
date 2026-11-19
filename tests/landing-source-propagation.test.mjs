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
  ['', 'https://www.deutschlanddecoded.com/letter-guide?private=1'],
  ['', 'https://deutschlanddecoded.com.evil.example/'],
  ['', 'https://www.adriaveza.de/de/partner/briefai-germany-amia-technologies.html?private=1'],
  ['', 'https://adriaveza.de.evil.example/'],
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

test('known partner referrers are reduced to safe labels', () => {
  assert.equal(resolveLandingSource('', 'https://deutschlanddecoded.com/letter-guide?private=1', 'https://briefai.salvesca.com'), 'ref_deutschlanddecoded');
  assert.equal(resolveLandingSource('', 'https://www.adriaveza.de/de/partner/briefai-germany-amia-technologies.html?private=1', 'https://briefai.salvesca.com'), 'ref_adriaveza');
  assert.equal(resolveLandingSource('', 'https://deutschlanddecoded.com.evil.example/', 'https://briefai.salvesca.com'), 'ref_external');
  assert.equal(resolveLandingSource('', 'https://adriaveza.de.evil.example/', 'https://briefai.salvesca.com'), 'ref_external');
});
