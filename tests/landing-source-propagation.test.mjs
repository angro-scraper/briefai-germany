import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';
import test from 'node:test';
import { resolveGuideSource, resolveLandingSource } from '../install-site/analytics-source.js';

const landing = readFileSync(new URL('../install-site/index.html', import.meta.url), 'utf8');
const analyticsSourceScript = readFileSync(new URL('../install-site/analytics-source.js', import.meta.url), 'utf8');
const appointmentGuide = readFileSync(new URL('../install-site/jobcenter-einladung-termin-verstehen/index.html', import.meta.url), 'utf8');
const germanLanding = readFileSync(new URL('../install-site/de/index.html', import.meta.url), 'utf8');
const sitemap = readFileSync(new URL('../install-site/sitemap.xml', import.meta.url), 'utf8');
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
  ['', 'https://getindieapps.com/app/briefai-germany?private=1'],
  ['', 'https://indie-apps.com/apps/briefai-germany-959959?private=1'],
  ['', 'https://iapp4me.com/apps/briefai-germany?private=1'],
  ['', 'https://getindieapps.com.evil.example/'],
  ['', 'https://iapp4me.com.evil.example/'],
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
  assert.equal(resolveLandingSource('', 'https://getindieapps.com/app/briefai-germany?private=1', 'https://briefai.salvesca.com'), 'ref_getindieapps');
  assert.equal(resolveLandingSource('', 'https://indie-apps.com/apps/briefai-germany-959959?private=1', 'https://briefai.salvesca.com'), 'ref_indieapps');
  assert.equal(resolveLandingSource('', 'https://www.iapp4me.com/apps/briefai-germany?private=1', 'https://briefai.salvesca.com'), 'ref_iapp4me');
  assert.equal(resolveLandingSource('', 'https://deutschlanddecoded.com.evil.example/', 'https://briefai.salvesca.com'), 'ref_external');
  assert.equal(resolveLandingSource('', 'https://adriaveza.de.evil.example/', 'https://briefai.salvesca.com'), 'ref_external');
  assert.equal(resolveLandingSource('', 'https://getindieapps.com.evil.example/', 'https://briefai.salvesca.com'), 'ref_external');
  assert.equal(resolveLandingSource('', 'https://iapp4me.com.evil.example/', 'https://briefai.salvesca.com'), 'ref_external');
});

test('iApp4Me referral labels remain within the backend source limit', () => {
  const site = 'https://briefai.salvesca.com';
  const publisher = 'https://www.iapp4me.com/apps/briefai-germany';
  const guideLabels = [...analyticsSourceScript.matchAll(/^  (seo_[a-z0-9_]+):/gm)]
    .map((match) => match[1]);
  assert.ok(guideLabels.length >= 10, 'expected all published guide labels');
  for (const guide of guideLabels) {
    const source = resolveGuideSource(guide, '', publisher, site);
    assert.ok(source.length <= 32, `${guide} source exceeds backend limit: ${source}`);
    assert.ok(source.endsWith('_ref_iapp4me'), `${guide} referral attribution was lost`);
  }
});

test('guide source stays within the backend limit for long publisher referrers', () => {
  const site = 'https://briefai.salvesca.com';
  const publisher = 'https://deutschlanddecoded.com/jobcenter-letter';
  const guideLabels = [...analyticsSourceScript.matchAll(/^  (seo_[a-z0-9_]+):/gm)]
    .map((match) => match[1]);
  assert.ok(guideLabels.length >= 10, 'expected all published guide labels');
  for (const guide of guideLabels) {
    const source = resolveGuideSource(guide, '', publisher, site);
    assert.ok(source.length <= 32, `${guide} source exceeds backend limit: ${source}`);
    assert.ok(source.endsWith('_ref_dd'), `${guide} publisher attribution was lost`);
  }
});

test('English Jobcenter guide has its own short source label', () => {
  assert.equal(
    resolveGuideSource('seo_en_jobcenter_documents', '', '', 'https://briefai.salvesca.com'),
    'g_en_jcdocs_unknown',
  );
});

test('German Jobcenter appointment guide has its own short source label', () => {
  assert.equal(
    resolveGuideSource('seo_de_jobcenter_termin', '', '', 'https://briefai.salvesca.com'),
    'g_de_jcterm_unknown',
  );
});

test('Jobcenter appointment guide is discoverable and offers both stores with a disclaimer', () => {
  const slug = '/jobcenter-einladung-termin-verstehen/';
  assert.match(appointmentGuide, /<meta name="briefai-source" content="seo_de_jobcenter_termin"/);
  assert.ok(germanLanding.includes(`href="${slug}"`));
  assert.ok(sitemap.includes(`https://briefai.salvesca.com${slug}`));
  assert.match(appointmentGuide, /apps\.apple\.com\/app\/id6794959959/);
  assert.match(appointmentGuide, /play\.google\.com\/store\/apps\/details\?id=com\.briefai\.briefai_germany/);
  assert.match(appointmentGuide, /keine Rechts- oder Sozialberatung/);
  assert.match(appointmentGuide, /https:\/\/www\.arbeitsagentur\.de\/grundsicherung\/termin-jobcenter/);
});
