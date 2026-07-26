import {initializeApp} from 'https://www.gstatic.com/firebasejs/11.0.2/firebase-app.js';
import {getAuth, GoogleAuthProvider, signInWithPopup} from 'https://www.gstatic.com/firebasejs/11.0.2/firebase-auth.js';
import {getFunctions, httpsCallable} from 'https://www.gstatic.com/firebasejs/11.0.2/firebase-functions.js';

// Replace values from Firebase Console. This public web configuration is not a secret.
const firebaseConfig = {
  apiKey: 'REPLACE_ME',
  authDomain: 'REPLACE_ME',
  projectId: 'REPLACE_ME',
  appId: 'REPLACE_ME',
};

const status = document.querySelector('#status');
let functions;
if (firebaseConfig.apiKey !== 'REPLACE_ME') {
  const app = initializeApp(firebaseConfig);
  const auth = getAuth(app);
  functions = getFunctions(app, 'europe-west3');
  document.querySelector('#sign-in').addEventListener('click', async () => {
    try {
      await signInWithPopup(auth, new GoogleAuthProvider());
      await loadMetrics();
      status.textContent = 'Signed in. Metrics are visible only to users with the Firebase admin custom claim.';
    } catch (error) {
      status.textContent = `Access failed: ${error.message}`;
    }
  });
} else {
  document.querySelector('#sign-in').disabled = true;
}

async function loadMetrics() {
  const result = await httpsCallable(functions, 'adminOverview')();
  const metric = result.data;
  document.querySelector('#users').textContent = metric.users ?? 0;
  document.querySelector('#active-users').textContent = metric.activeUsers ?? 0;
  document.querySelector('#analyses').textContent = metric.analyses ?? 0;
  document.querySelector('#premium-users').textContent = metric.premiumUsers ?? 0;
  document.querySelector('#revenue').textContent = new Intl.NumberFormat('de-DE', {style: 'currency', currency: 'EUR'}).format((metric.revenueCents ?? 0) / 100);
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
