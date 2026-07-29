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

const platformHome = readFileSync(resolve(root, 'index.html'), 'utf8');
check('platform home: persists selected interface language', platformHome.includes('salvescaPlatformLanguage'));
check('platform home: offers Serbian, German, English and Turkish', ['sr','de','en','tr'].every(locale => platformHome.includes(`value="${locale}"`)));
check('platform home: translates product cards after a language switch', platformHome.includes('const content =') && platformHome.includes("document.querySelectorAll('.product').forEach"));
check('platform home: translates privacy and platform principles', platformHome.includes("document.querySelectorAll('.principle').forEach") && platformHome.includes("const footerLinks=document.querySelectorAll('footer a')"));

const assistant = source('asistent');
check('asistent: stores the selected interface language', assistant.includes('salvescaLifeLanguage'));
check('asistent: applies the selected interface language', assistant.includes('applyInterfaceLanguage'));
check('asistent: handles malformed AI answer payloads safely', assistant.includes('normalizeAnswer'));
check('asistent: sends municipality separately to AI guidance', assistant.includes('askApi({question,city,language'));
check('asistent: survives malformed local browser storage', assistant.includes('function readLocalJson'));
check('asistent: exports and safely restores private local data', assistant.includes('salvesca-asistent-backup.json') && assistant.includes('validLifeBackup'));
for (const locale of ['sr:', 'hr:', 'bs:', 'mk:', 'bg:', 'de:', 'en:', 'tr:', 'ru:', 'uk:', 'ro:', 'pl:', 'ar:']) {
  check(`asistent: ${locale} interface copy`, assistant.includes(locale));
}

for (const module of ['posao', 'prevod']) {
  const html = source(module);
  check(`${module}: Firebase professional email integration`, html.includes('generateLifeInGermanyEmail'));
  check(`${module}: authenticated professional draft`, html.includes('auth.currentUser'));
  // Posao may also have a separate, purely local application tracker form.
  // Guard the AI e-mail flow specifically instead of rejecting independent
  // local workflows that legitimately have their own submit handler.
  check(`${module}: one reliable email submission handler`,
    (html.match(/#applicationForm'\)\.onsubmit=/g) ?? []).length === 1 ||
    (html.match(/#form'\)\.onsubmit=/g) ?? []).length === 1);
}

const jobs = source('posao');
check('posao: local email draft remains available without sign-in', jobs.includes('window.createLocalJobDraft') && jobs.includes("if(!auth.currentUser){q('#draft').textContent=localDraft"));
check('posao: validates local checklist storage shape', jobs.includes('Array.isArray(value)?value:[]'));
check('posao: selected interface language is passed to AI', jobs.includes('salvescaJobLanguage') && jobs.includes('language:window.salvescaJobLanguage()'));
check('posao: exports and safely restores private tracker data', jobs.includes('salvesca-posao-backup.json') && jobs.includes('isValidJobBackup'));

const translation = source('prevod');
check('prevod: AI failure leaves a usable local fallback', translation.includes("const localDraft=fallback[kind].replace") && translation.includes("catch(error){query('#result').textContent=localDraft"));
check('prevod: selected interface language is passed to AI', translation.includes('salvescaTranslationLanguage') && translation.includes('language:window.salvescaTranslationLanguage()'));
check('prevod: keeps local drafts available after refresh', translation.includes('salvescaTranslationDrafts') && translation.includes('const renderHistory'));

check('usluge: validates local saved-request storage shape', services.includes('Array.isArray(value)?value.filter(Boolean)') && services.includes('salvescaServiceRequests'));
check('usluge: keeps service-request progress and reminders local', services.includes('requestStatuses') && services.includes('text/calendar'));

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

const finance = source('finansije');
check('finansije: persists the chosen interface language', finance.includes('salvescaFinanceLanguage'));
check('finansije: offers Serbian, German, English and Turkish', ['sr','de','en','tr'].every(locale => finance.includes(`value="${locale}"`)));
check('finansije: applies language changes immediately', finance.includes('function applyLanguage') && finance.includes('language.onchange'));
check('finansije: translates guidance and safety sections after a language switch', finance.includes('extendedCopy') && finance.includes('applyExtendedContent'));

const transport = source('prevoz');
check('prevoz: persists the chosen interface language', transport.includes('salvescaTransportLanguage'));
check('prevoz: offers Serbian, German, English and Turkish', ['sr','de','en','tr'].every(locale => transport.includes(`value="${locale}"`)));
check('prevoz: applies language changes immediately', transport.includes('function applyLanguage') && transport.includes('language.onchange'));
check('prevoz: translates guidance and safety sections after a language switch', transport.includes('extendedCopy') && transport.includes('applyExtendedContent'));

if (failures.length) {
  console.error(`Salvesca platform preflight failed:\n- ${failures.join('\n- ')}`);
  process.exit(1);
}

console.log(`Salvesca platform preflight passed for ${modules.length} modules.`);
