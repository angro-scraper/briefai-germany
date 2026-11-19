import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';

const site = new URL('../install-site/', import.meta.url);
const guide = new URL('read-german-official-letter/index.html', site);
const checklist = new URL('official-letter-checklist-en.pdf', site);

test('the English guide links to its published checklist PDF', async () => {
  const html = await readFile(guide, 'utf8');
  const pdf = await readFile(checklist);

  assert.match(html, /href="\/official-letter-checklist-en\.pdf" download/);
  assert.equal((html.match(/href="\/official-letter-checklist-en\.pdf"/g) ?? []).length, 1);
  assert.equal(pdf.subarray(0, 5).toString('ascii'), '%PDF-');
  assert.ok(pdf.length > 10_000, 'the linked PDF must not be an empty placeholder');
});
