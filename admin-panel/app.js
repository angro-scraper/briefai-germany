import {initializeApp} from 'https://www.gstatic.com/firebasejs/11.0.2/firebase-app.js';
import {initializeAppCheck, ReCaptchaV3Provider} from 'https://www.gstatic.com/firebasejs/11.0.2/firebase-app-check.js';
import {
  getAuth,
  GoogleAuthProvider,
  signInWithEmailAndPassword,
  signInWithPopup,
} from 'https://www.gstatic.com/firebasejs/11.0.2/firebase-auth.js';
import {getFunctions, httpsCallable} from 'https://www.gstatic.com/firebasejs/11.0.2/firebase-functions.js';

// Replace values from Firebase Console. This public web configuration is not a secret.
const firebaseConfig = {
  apiKey: 'AIzaSyDmINDRHAwFYipLUys_Y7OYMEfPud8-FeI',
  authDomain: 'briefai-germany.firebaseapp.com',
  projectId: 'briefai-germany',
  appId: '1:891432357321:web:6d3baed44fa3bb77dbac18',
  messagingSenderId: '891432357321',
  // Firebase Console -> App Check -> web app -> reCAPTCHA v3 site key.
  appCheckSiteKey: '6Ldic2YtAAAAAEbpq8I88FwXyTHNXkd6iO53J1cg',
};

const status = document.querySelector('#status');
let functions;
const configured = Object.values(firebaseConfig).every((value) => value !== 'REPLACE_ME' && value.length > 0);
if (configured) {
  const app = initializeApp(firebaseConfig);
  initializeAppCheck(app, {
    provider: new ReCaptchaV3Provider(firebaseConfig.appCheckSiteKey),
    isTokenAutoRefreshEnabled: true,
  });
  const auth = getAuth(app);
  functions = getFunctions(app, 'europe-west3');
  const completeSignIn = async () => {
    await loadMetrics();
    status.textContent =
      'Signed in. Metrics are visible only to users with the Firebase admin custom claim.';
  };
  document.querySelector('#google-sign-in').addEventListener('click', async () => {
    try {
      await signInWithPopup(auth, new GoogleAuthProvider());
      await completeSignIn();
    } catch (error) {
      status.textContent = `Access failed: ${error.message}`;
    }
  });
  document.querySelector('#email-sign-in').addEventListener('submit', async (event) => {
    event.preventDefault();
    try {
      await signInWithEmailAndPassword(
        auth,
        document.querySelector('#admin-email').value,
        document.querySelector('#admin-password').value,
      );
      document.querySelector('#admin-password').value = '';
      await completeSignIn();
    } catch (error) {
      status.textContent = `Access failed: ${error.message}`;
    }
  });
} else {
  document.querySelector('#google-sign-in').disabled = true;
  document.querySelector('#email-sign-in')
    .querySelectorAll('input, button')
    .forEach((element) => {
      element.disabled = true;
    });
  status.textContent = 'Add Firebase web configuration and the App Check reCAPTCHA v3 site key in app.js.';
}

async function loadMetrics() {
  const result = await httpsCallable(functions, 'adminOverview')();
  const metric = result.data;
  document.querySelector('#users').textContent = metric.users ?? 0;
  document.querySelector('#active-users').textContent = metric.activeUsers ?? 0;
  document.querySelector('#analyses').textContent = metric.analyses ?? 0;
  document.querySelector('#premium-users').textContent = metric.premiumUsers ?? 0;
  document.querySelector('#revenue').textContent = new Intl.NumberFormat('de-DE', {style: 'currency', currency: 'EUR'}).format((metric.revenueCents ?? 0) / 100);
  const usd = new Intl.NumberFormat('en-US', {style: 'currency', currency: 'USD'});
  document.querySelector('#ai-spend').textContent =
    `${usd.format((metric.aiCostMicros ?? 0) / 1_000_000)} / ${usd.format(metric.aiMonthlyBudgetUsd ?? 0)}`;
  document.querySelector('#ai-tokens').textContent =
    new Intl.NumberFormat('de-DE').format((metric.aiInputTokens ?? 0) + (metric.aiOutputTokens ?? 0));
  document.querySelector('#ai-model').textContent = metric.aiModel ?? '—';
}

document.querySelector('#notification-form').addEventListener('submit', async (event) => {
  event.preventDefault();
  if (!functions) return;
  try {
    const result = await httpsCallable(functions, 'sendAdminNotification')({
      title: document.querySelector('#title').value,
      body: document.querySelector('#body').value,
    });
    status.textContent = `Notification delivered to ${result.data.delivered} devices.`;
  } catch (error) {
    status.textContent = `Notification failed: ${error.message}`;
  }
});
