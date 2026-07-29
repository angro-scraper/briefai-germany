import {existsSync, readFileSync} from 'node:fs';
import {resolve} from 'node:path';

const root = resolve(import.meta.dirname, '..', 'salvesca-platform');
const modules = ['asistent', 'usluge', 'posao', 'prevod', 'finansije', 'prevoz'];
const failures = [];

function check(label, condition) {
  if (!condition) failures.push(label);
}

function source(module) {
  const path = resolve(root, module, 'index.html');
  check(`${module}: index.html exists`, existsSync(path));
  return existsSync(path) ? readFileSync(path, 'utf8') : '';
}

for (const module of modules) {
  const html = source(module);
  check(`${module}: responsive viewport`, html.includes('viewport'));
  check(`${module}: local privacy statement`, /lokalno|localStorage/i.test(html));
}

const services = source('usluge');
for (const locale of ['sr:', 'de:', 'en:', 'tr:']) {
  check(`usluge: ${locale} translation copy`, services.includes(locale));
}
check('usluge: German service categories', services.includes('germanCategories'));

const assistant = source('asistent');
check('asistent: stores the selected interface language', assistant.includes('salvescaLifeLanguage'));
check('asistent: applies the selected interface language', assistant.includes('applyInterfaceLanguage'));
check('asistent: handles malformed AI answer payloads safely', assistant.includes('normalizeAnswer'));
for (const locale of ['sr:', 'hr:', 'bs:', 'mk:', 'bg:', 'de:', 'en:', 'tr:', 'ru:', 'uk:', 'ro:', 'pl:', 'ar:']) {
  check(`asistent: ${locale} interface copy`, assistant.includes(locale));
}

for (const module of ['posao', 'prevod']) {
  const html = source(module);
  check(`${module}: Firebase professional email integration`, html.includes('generateLifeInGermanyEmail'));
  check(`${module}: authenticated professional draft`, html.includes('auth.currentUser'));
}

for (const module of ['finansije', 'prevoz']) {
  const html = source(module);
  check(`${module}: durable local status`, html.includes("status:'open'"));
  check(`${module}: deadline urgency`, html.includes('Rok je') || html.includes('urgency('));
  check(`${module}: completion state`, html.includes("status:'paid'") || html.includes("status:'done'"));
}

if (failures.length) {
  console.error(`Salvesca platform preflight failed:\n- ${failures.join('\n- ')}`);
  process.exit(1);
}

console.log(`Salvesca platform preflight passed for ${modules.length} modules.`);
