import {initializeApp} from 'https://www.gstatic.com/firebasejs/11.0.2/firebase-app.js';
import {
  initializeAppCheck,
  ReCaptchaEnterpriseProvider,
} from 'https://www.gstatic.com/firebasejs/11.0.2/firebase-app-check.js';
import {
  getFunctions,
  httpsCallable,
} from 'https://www.gstatic.com/firebasejs/11.0.2/firebase-functions.js';

// Firebase's web identifiers and App Check site key are public client
// configuration. Protection comes from the server validating the short-lived
// App Check token, not from hiding these values.
const app = initializeApp({
  apiKey: 'AIzaSyDmINDRHAwFYipLUys_Y7OYMEfPud8-FeI',
  authDomain: 'briefai-germany.firebaseapp.com',
  projectId: 'briefai-germany',
  appId: '1:891432357321:web:6d3baed44fa3bb77dbac18',
  messagingSenderId: '891432357321',
});

initializeAppCheck(app, {
  provider: new ReCaptchaEnterpriseProvider('6LcSEWctAAAAACxE9d6yObjEogL8mhkh74kSbFc2'),
  isTokenAutoRefreshEnabled: true,
});

const functions = getFunctions(app, 'europe-west3');

export const recordPublicAnalytics = httpsCallable(functions, 'publicAnalytics');
export const submitProtectedTesterLead = httpsCallable(functions, 'submitTesterLead');
