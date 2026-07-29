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
check('asistent: sends municipality separately to AI guidance', assistant.includes('askApi({question,city,language'));
check('asistent: survives malformed local browser storage', assistant.includes('function readLocalJson'));
for (const locale of ['sr:', 'hr:', 'bs:', 'mk:', 'bg:', 'de:', 'en:', 'tr:', 'ru:', 'uk:', 'ro:', 'pl:', 'ar:']) {
  check(`asistent: ${locale} interface copy`, assistant.includes(locale));
}

for (const module of ['posao', 'prevod']) {
  const html = source(module);
  check(`${module}: Firebase professional email integration`, html.includes('generateLifeInGermanyEmail'));
  check(`${module}: authenticated professional draft`, html.includes('auth.currentUser'));
  check(`${module}: one reliable email submission handler`, (html.match(/\.onsubmit=/g) ?? []).length === 1);
}

const jobs = source('posao');
check('posao: local email draft remains available without sign-in', jobs.includes('window.createLocalJobDraft') && jobs.includes("if(!auth.currentUser){q('#draft').textContent=localDraft"));
check('posao: validates local checklist storage shape', jobs.includes('Array.isArray(value)?value:[]'));

const translation = source('prevod');
check('prevod: AI failure leaves a usable local fallback', translation.includes("const localDraft=fallback[kind].replace") && translation.includes("catch(error){query('#result').textContent=localDraft"));

check('usluge: validates local saved-request storage shape', services.includes('Array.isArray(value)?value:[]'));

for (const module of ['finansije', 'prevoz']) {
  const html = source(module);
  check(`${module}: durable local status`, html.includes("status:'open'"));
  check(`${module}: deadline urgency`, html.includes('Rok je') || html.includes('urgency('));
  check(`${module}: completion state`, html.includes("status:'paid'") || html.includes("status:'done'"));
  check(`${module}: one local workflow script`, (html.match(/<script>/g) ?? []).length === 1);
  check(`${module}: one form submission handler`, (html.match(/\.onsubmit=/g) ?? []).length === 1);
  check(`${module}: validates local storage shape`, html.includes('Array.isArray(value)?value:[]'));
  check(`${module}: exports private 7/3/1-day calendar reminders`, html.includes('BEGIN:VALARM') && html.includes('TRIGGER:-P7D') && html.includes('TRIGGER:-P3D') && html.includes('TRIGGER:-P1D'));
}

if (failures.length) {
  console.error(`Salvesca platform preflight failed:\n- ${failures.join('\n- ')}`);
  process.exit(1);
}

console.log(`Salvesca platform preflight passed for ${modules.length} modules.`);
