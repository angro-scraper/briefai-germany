import {recordPublicAnalytics} from '/firebase-site-security.js';

// These information guides must be measurable without collecting letters,
// email addresses, or other personal data. Tracking is strictly opt-in and
// reuses the same consent choice as the BriefAI landing page.
const consentKey = 'briefai.analytics-consent';
const visitorKey = 'briefai.analytics-visitor-id';
// Keep the guide's SEO label as the default, but honour a short UTM source
// when a community post, directory or partner deliberately links here. This
// lets the consented aggregate distinguish a useful referral from organic
// search without storing a URL, letter, email address or IP address.
const campaignSource = new URLSearchParams(location.search).get('utm_source')?.trim();
const source = campaignSource || document.querySelector('meta[name="briefai-source"]')?.content || 'guide';

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
    .briefai-analytics-choice div { display:flex; justify-content:flex-end; gap:9px; }
    .briefai-analytics-choice button { border:1px solid #98b1ef; border-radius:9px; padding:8px 11px; font:inherit; font-weight:700; cursor:pointer; }
    .briefai-analytics-no { background:transparent; color:#eaf0ff; }
    .briefai-analytics-yes { color:#0b1b40; background:#dbe5ff; }
  `;
  document.head.append(style);

  const banner = document.createElement('aside');
  banner.className = 'briefai-analytics-choice';
  banner.setAttribute('role', 'dialog');
  banner.setAttribute('aria-label', 'Datenschutz und Messung');
  banner.innerHTML = '<strong>Datenschutz &amp; Messung</strong><p>Dürfen wir anonym messen, ob dieser Ratgeber und die Store-Links hilfreich sind? Wir erfassen keine Briefe, Texte, E-Mail-Adressen oder IP-Adressen.</p><div><button class="briefai-analytics-no" type="button">Nein danke</button><button class="briefai-analytics-yes" type="button">Zustimmen</button></div>';
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
document.querySelectorAll('[data-analytics-install]').forEach((link) => {
  link.addEventListener('click', () => void send('install_click'));
});
