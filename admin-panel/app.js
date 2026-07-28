import {initializeApp} from 'https://www.gstatic.com/firebasejs/11.0.2/firebase-app.js';
import {
  getAuth,
  browserLocalPersistence,
  createUserWithEmailAndPassword,
  GoogleAuthProvider,
  onAuthStateChanged,
  sendPasswordResetEmail,
  setPersistence,
  signOut,
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
};

const status = document.querySelector('#status');
let functions;
let auth;
let completingSignIn;
let accounts = [];
let nextAccountsPageToken = null;
const configured = Object.values(firebaseConfig).every((value) => value !== 'REPLACE_ME' && value.length > 0);
if (configured) {
  const app = initializeApp(firebaseConfig);
  // Admin callable functions verify the Firebase admin custom claim directly.
  // Do not initialize App Check here: reCAPTCHA is not needed for this private
  // back office and a blocked CAPTCHA used to make otherwise valid logins fail.
  auth = getAuth(app);
  await setPersistence(auth, browserLocalPersistence);
  functions = getFunctions(app, 'europe-west3');
  const completeSignIn = async () => {
    if (!auth.currentUser) return;
    if (completingSignIn) return completingSignIn;
    completingSignIn = (async () => {
      try {
        await loadMetrics();
      } catch (error) {
        // The authorized founder can safely self-claim the admin role. The
        // callable function compares the authenticated email with a server-side
        // Firebase Secret, so changing this page cannot grant access to anyone
        // else.
        if (error.code !== 'functions/permission-denied') throw error;
        const result = await httpsCallable(functions, 'claimFounderAccess')();
        if (result.data?.admin !== true) throw error;
        await auth.currentUser?.getIdToken(true);
        await loadMetrics();
      }
      await loadAccounts({reset: true});
      document.body.classList.add('is-signed-in');
      document.querySelector('#sign-out').hidden = false;
      document.querySelector('#google-sign-in').hidden = true;
      status.textContent =
        'Signed in. You can now manage accounts and view operational metrics.';
    })();
    try {
      await completingSignIn;
    } finally {
      completingSignIn = undefined;
    }
  };
  document.querySelector('#google-sign-in').addEventListener('click', async () => {
    try {
      await signInWithPopup(auth, new GoogleAuthProvider());
      await completeSignIn();
    } catch (error) {
      status.textContent = `Access failed: ${error.message}`;
    }
  });
  document.querySelector('#sign-out').addEventListener('click', async () => {
    await signOut(auth);
    status.textContent = 'Signed out.';
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
  document.querySelector('#create-account').addEventListener('click', async () => {
    const email = document.querySelector('#admin-email').value.trim();
    const password = document.querySelector('#admin-password').value;
    if (!email || !password) {
      status.textContent = 'Enter your email and a new password first.';
      return;
    }
    try {
      await createUserWithEmailAndPassword(auth, email, password);
      document.querySelector('#admin-password').value = '';
      await completeSignIn();
      status.textContent = 'Account created and signed in. Founder access is granted only to the configured founder email.';
    } catch (error) {
      status.textContent = `Account creation failed: ${error.message}`;
    }
  });
  document.querySelector('#password-reset').addEventListener('click', async () => {
    const email = document.querySelector('#admin-email').value.trim();
    if (!email) {
      status.textContent = 'Enter your founder email first, then request a password setup link.';
      document.querySelector('#admin-email').focus();
      return;
    }
    try {
      await sendPasswordResetEmail(auth, email, {
        url: 'https://briefai.salvesca.com/admin/',
        handleCodeInApp: false,
      });
      status.textContent = 'Password setup link sent. Check your email inbox and spam folder.';
    } catch (error) {
      status.textContent = `Password setup failed: ${error.message}`;
    }
  });
  document.querySelector('#refresh-dashboard').addEventListener('click', async () => {
    if (!auth.currentUser) {
      status.textContent = 'Sign in before refreshing the dashboard.';
      return;
    }
    try {
      await Promise.all([loadMetrics(), loadAccounts({reset: true})]);
      status.textContent = 'Dashboard refreshed.';
    } catch (error) {
      status.textContent = `Refresh failed: ${error.message}`;
    }
  });
  document.querySelector('#load-more-accounts').addEventListener('click', async () => {
    if (!nextAccountsPageToken) return;
    try {
      await loadAccounts({reset: false});
    } catch (error) {
      status.textContent = `Could not load more accounts: ${error.message}`;
    }
  });
  document.querySelector('#account-search').addEventListener('input', renderAccounts);
  onAuthStateChanged(auth, async (user) => {
    if (!user) {
      document.body.classList.remove('is-signed-in');
      document.querySelector('#sign-out').hidden = true;
      document.querySelector('#google-sign-in').hidden = false;
      return;
    }
    try {
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
  document.querySelector('#create-account').disabled = true;
  document.querySelector('#password-reset').disabled = true;
  status.textContent = 'Add Firebase web configuration in app.js.';
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
  renderPlans(metric);
}

function renderPlans(metric) {
  const container = document.querySelector('#plan-list');
  container.replaceChildren();
  const trial = document.createElement('div');
  trial.className = 'plan-row';
  trial.innerHTML = `<strong>Test trial</strong><span>${metric.freeAnalysisLimit ?? '—'} analyses</span>`;
  container.append(trial);
  for (const plan of metric.plans ?? []) {
    const row = document.createElement('div');
    row.className = 'plan-row';
    const title = document.createElement('strong');
    title.textContent = String(plan.key).toUpperCase();
    const details = document.createElement('span');
    details.textContent = `${plan.monthlyAnalysisLimit} analyses / month · AI cap $${plan.aiBudgetUsd}`;
    row.append(title, details);
    container.append(row);
  }
}

async function loadAccounts({reset}) {
  const result = await httpsCallable(functions, 'adminListAccounts')({
    limit: 50,
    ...(reset ? {} : {pageToken: nextAccountsPageToken}),
  });
  const incoming = Array.isArray(result.data?.accounts) ? result.data.accounts : [];
  accounts = reset ? incoming : [...accounts, ...incoming];
  nextAccountsPageToken = result.data?.nextPageToken ?? null;
  renderAccounts();
}

function formatDate(value) {
  if (!value) return '—';
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? '—' : new Intl.DateTimeFormat('de-DE', {dateStyle: 'medium'}).format(date);
}

function accountCell(account) {
  const cell = document.createElement('td');
  const name = document.createElement('strong');
  name.textContent = account.displayName || account.email || 'No name';
  const email = document.createElement('small');
  email.textContent = account.email || account.uid;
  const provider = document.createElement('small');
  provider.textContent = (account.providers || []).join(', ') || 'email/password';
  cell.append(name, email, provider);
  return cell;
}

function textCell(main, sub) {
  const cell = document.createElement('td');
  cell.textContent = main;
  if (sub) {
    const detail = document.createElement('small');
    detail.textContent = sub;
    cell.append(detail);
  }
  return cell;
}

function formatUsdFromMicros(value) {
  return new Intl.NumberFormat('en-US', {style: 'currency', currency: 'USD', maximumFractionDigits: 4})
    .format((Number(value) || 0) / 1_000_000);
}

function renderAccounts() {
  const table = document.querySelector('#accounts-table');
  const query = document.querySelector('#account-search').value.trim().toLowerCase();
  const filtered = accounts.filter((account) =>
    !query || `${account.email || ''} ${account.displayName || ''}`.toLowerCase().includes(query),
  );
  table.replaceChildren();
  if (!filtered.length) {
    const row = document.createElement('tr');
    const cell = document.createElement('td');
    cell.colSpan = 6;
    cell.textContent = accounts.length ? 'No accounts match this search.' : 'No accounts loaded yet.';
    row.append(cell);
    table.append(row);
  }
  for (const account of filtered) {
    const row = document.createElement('tr');
    row.append(accountCell(account));
    row.append(textCell(String(account.plan || 'trial').toUpperCase(), account.subscriptionStatus || 'no subscription'));
    row.append(textCell(
      `${account.analysesLifetime || 0} total · ${account.analysesThisMonth || 0} this month`,
      `AI: ${formatUsdFromMicros(account.aiCostMicros)} · ${account.aiRequests || 0} requests · ${new Intl.NumberFormat('de-DE').format((account.aiInputTokens || 0) + (account.aiOutputTokens || 0))} tokens`,
    ));
    row.append(textCell(formatDate(account.lastActiveAt), `Signed in: ${formatDate(account.lastSignInAt)}`));
    const stateCell = document.createElement('td');
    const badge = document.createElement('span');
    badge.className = `status-pill ${account.disabled ? 'disabled' : 'active'}`;
    badge.textContent = account.disabled ? 'Suspended' : 'Active';
    stateCell.append(badge);
    if (account.aiBlocked) {
      const aiBadge = document.createElement('span');
      aiBadge.className = 'status-pill disabled';
      aiBadge.textContent = 'AI stopped';
      stateCell.append(document.createElement('br'), aiBadge);
    }
    row.append(stateCell);
    const controlCell = document.createElement('td');
    const actions = document.createElement('div');
    actions.className = 'control-stack';
    const action = document.createElement('button');
    action.className = account.disabled ? 'secondary-action' : 'danger-action';
    action.textContent = account.disabled ? 'Restore' : 'Suspend';
    action.addEventListener('click', () => setAccountDisabled(account));
    const aiAction = document.createElement('button');
    aiAction.className = account.aiBlocked ? 'secondary-action' : 'danger-action';
    aiAction.textContent = account.aiBlocked ? 'Enable AI' : 'Stop AI';
    aiAction.addEventListener('click', () => setAccountAiBlocked(account));
    actions.append(action, aiAction);
    controlCell.append(actions);
    row.append(controlCell);
    table.append(row);
  }
  document.querySelector('#accounts-summary').textContent = `${filtered.length} shown · ${accounts.length} loaded`;
  document.querySelector('#load-more-accounts').disabled = !nextAccountsPageToken;
}

async function setAccountDisabled(account) {
  const disabled = !account.disabled;
  const label = account.email || account.uid;
  if (!window.confirm(`${disabled ? 'Suspend' : 'Restore'} ${label}?`)) return;
  try {
    await httpsCallable(functions, 'adminSetAccountDisabled')({uid: account.uid, disabled});
    document.querySelector('#service-state').textContent = `${label} was ${disabled ? 'suspended and signed out' : 'restored'}.`;
    await loadAccounts({reset: true});
  } catch (error) {
    status.textContent = `Account control failed: ${error.message}`;
  }
}

async function setAccountAiBlocked(account) {
  const aiBlocked = !account.aiBlocked;
  const label = account.email || account.uid;
  if (!window.confirm(`${aiBlocked ? 'Stop all new AI requests for' : 'Restore AI access for'} ${label}?`)) return;
  try {
    await httpsCallable(functions, 'adminSetAccountAiBlocked')({uid: account.uid, aiBlocked});
    document.querySelector('#service-state').textContent = aiBlocked
      ? `AI requests are now blocked for ${label}. Existing local letters remain untouched.`
      : `AI access was restored for ${label}.`;
    await loadAccounts({reset: true});
  } catch (error) {
    status.textContent = `AI access control failed: ${error.message}`;
  }
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
