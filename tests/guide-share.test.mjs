import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {test} from 'node:test';
import {buildGuideShareUrl, setupGuideShare} from '../install-site/share-guide.js';

test('share links contain only a guide path and coarse campaign labels', () => {
  assert.equal(
    buildGuideShareUrl('https://briefai.salvesca.com', '/read-german-official-letter/'),
    'https://briefai.salvesca.com/read-german-official-letter/?utm_source=friend_share&utm_medium=organic',
  );
  assert.equal(
    buildGuideShareUrl('https://briefai.salvesca.com', '/deutschen-brief-verstehen/'),
    'https://briefai.salvesca.com/deutschen-brief-verstehen/?utm_source=friend_share&utm_medium=organic',
  );
});

test('desktop fallback copies only the public guide link after a click', async () => {
  let click;
  let copied;
  const button = {addEventListener: (event, callback) => {assert.equal(event, 'click'); click = callback;}};
  const status = {textContent: ''};
  const url = buildGuideShareUrl('https://briefai.salvesca.com', '/read-german-official-letter/');
  setupGuideShare({
    button, status, url, title: 'Free guide', text: 'General information, not legal advice.',
    copiedMessage: 'Copied.', manualMessage: 'Copy:',
    shareNavigator: {clipboard: {writeText: async value => {copied = value;}}},
  });
  assert.equal(copied, undefined);
  await click();
  assert.equal(copied, url);
  assert.equal(status.textContent, 'Copied.');
});

for (const [page, guide] of [['en/index.html', '/read-german-official-letter/'], ['de/index.html', '/deutschen-brief-verstehen/']]) {
  test(`${page} offers a voluntary guide share`, () => {
    const html = readFileSync(new URL(`../install-site/${page}`, import.meta.url), 'utf8');
    assert.match(html, /data-guide-share/);
    assert.match(html, /share-guide\.js/);
    assert.ok(html.includes(`buildGuideShareUrl(location.origin, '${guide}')`));
  });
}
