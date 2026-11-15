import {recordPublicAnalytics} from '/firebase-site-security.js';
import {resolveGuideSource} from '/analytics-source.js';

// These information guides must be measurable without collecting letters,
// email addresses, or other personal data. Tracking is strictly opt-in and
// reuses the same consent choice as the BriefAI landing page.
const consentKey = 'briefai.analytics-consent';
const visitorKey = 'briefai.analytics-visitor-id';
// Use the campaign tag when supplied; otherwise label the guide and only the
// referral category actually observed. A guide view is not proof of SEO.
const guideLabel = document.querySelector('meta[name="briefai-source"]')?.content;
const source = resolveGuideSource(guideLabel, location.search, document.referrer, location.origin);

function visitorId() {
  let value = localStorage.getItem(visitorKey);
  if (!value) {
    value = crypto.randomUUID();
    localStorage.setItem(visitorKey, value);
  }
  return value;
}

async function send(event) {
  if (localStorage.getItem(consentKey) !== 'yes') return;
  try {
    await recordPublicAnalytics({event, visitorId: visitorId(), source});
  } catch {
    // Analytics must never prevent someone from reading a guide or installing.
  }
}

function addConsentChoice() {
  if (localStorage.getItem(consentKey) !== null) return;

  const style = document.createElement('style');
  style.textContent = `
    .briefai-analytics-choice { position:fixed; z-index:30; right:18px; bottom:18px; max-width:390px; padding:16px; border-radius:14px; color:#edf3ff; background:#0b1b40; box-shadow:0 20px 54px #07163b55; font:14px/1.45 Inter,ui-sans-serif,system-ui,sans-serif; }
    .briefai-analytics-choice strong { display:block; font-size:15px; }
    .briefai-analytics-choice p { margin:7px 0 12px; color:#cad7f7; }
    .briefai-analytics-choice a { color:#dbe5ff; }
    .briefai-analytics-choice div { display:flex; justify-content:flex-end; gap:9px; }
    .briefai-analytics-choice button { border:1px solid #98b1ef; border-radius:9px; padding:8px 11px; font:inherit; font-weight:700; cursor:pointer; }
    .briefai-analytics-no { background:transparent; color:#eaf0ff; }
    .briefai-analytics-yes { color:#0b1b40; background:#dbe5ff; }
  `;
  document.head.append(style);

  const banner = document.createElement('aside');
  banner.className = 'briefai-analytics-choice';
  banner.setAttribute('role', 'dialog');
  const english = document.documentElement.lang.toLowerCase().startsWith('en');
  banner.setAttribute('aria-label', english ? 'Privacy and optional measurement' : 'Datenschutz und freiwillige Messung');
  banner.innerHTML = english
    ? '<strong>Privacy &amp; optional measurement</strong><p>May we measure guide views and store-link clicks using a pseudonymous visitor ID? We do not send letter contents, OCR text or reply drafts to product analytics. Our hosting and Firebase services may separately process technical data, including IP addresses, to operate and secure the site. <a href="/privacy.html">Privacy policy (German)</a>.</p><div><button class="briefai-analytics-no" type="button">No thanks</button><button class="briefai-analytics-yes" type="button">Agree</button></div>'
    : '<strong>Datenschutz &amp; freiwillige Messung</strong><p>Dürfen wir Seitenaufrufe und Store-Link-Klicks mit einer pseudonymen Besucherkennung messen? Briefinhalte, OCR-Texte und Antwortentwürfe senden wir nicht an die Produktanalyse. Hosting und Firebase können für Betrieb und Sicherheit technische Daten einschließlich IP-Adressen separat verarbeiten. <a href="/privacy.html">Datenschutzerklärung</a>.</p><div><button class="briefai-analytics-no" type="button">Nein danke</button><button class="briefai-analytics-yes" type="button">Zustimmen</button></div>';
  document.body.append(banner);

  banner.querySelector('.briefai-analytics-no').addEventListener('click', () => {
    localStorage.setItem(consentKey, 'no');
    banner.remove();
  });
  banner.querySelector('.briefai-analytics-yes').addEventListener('click', () => {
    localStorage.setItem(consentKey, 'yes');
    banner.remove();
    void send('page_view');
  });
}

addConsentChoice();
void send('page_view');

// The in-app registration path accepts the same source label. Preserve it for
// valid campaign links so an opted-in visit from a community or directory is
// not relabelled as generic SEO after the reader opens the app.
document.querySelectorAll('a[href^="/app/"]').forEach((link) => {
  const target = new URL(link.getAttribute('href'), location.origin);
  target.searchParams.set('utm_source', source);
  link.setAttribute('href', `${target.pathname}${target.search}${target.hash}`);
});

document.querySelectorAll('[data-analytics-install]').forEach((link) => {
  link.addEventListener('click', () => void send('install_click'));
});
