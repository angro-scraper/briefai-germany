import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

const site = new URL('../install-site/', import.meta.url);
const read = (path) => readFileSync(new URL(path, site), 'utf8');

test('Serbian Jobcenter guide is discoverable and clearly limited', () => {
  const guide = read('jobcenter-pismo-mitwirkung-sr/index.html');
  const home = read('index.html');
  const sitemap = read('sitemap.xml');

  assert.match(guide, /<html lang="sr-Latn">/);
  assert.match(guide, /Aufforderung zur Mitwirkung/);
  assert.match(guide, /ne pravni ni socijalni savet/i);
  assert.match(guide, /www\.gesetze-im-internet\.de\/sgb_1\/__66\.html/);
  assert.match(guide, /www\.arbeitsagentur\.de\/grundsicherung/);
  assert.match(guide, /play\.google\.com\/store\/apps\/details\?id=com\.briefai\.briefai_germany/);
  assert.match(guide, /apps\.apple\.com\/app\/id6794959959/);
  assert.match(home, /href="\/jobcenter-pismo-mitwirkung-sr\/"/);
  assert.match(sitemap, /https:\/\/briefai\.salvesca\.com\/jobcenter-pismo-mitwirkung-sr\//);
});
