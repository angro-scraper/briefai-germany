import {applicationDefault, initializeApp} from 'firebase-admin/app';
import {getAuth} from 'firebase-admin/auth';

const expectedProject = 'briefai-germany';
const args = new Map(
  process.argv.slice(2).map((argument) => {
    const separator = argument.indexOf('=');
    return separator === -1
      ? [argument, 'true']
      : [argument.slice(0, separator), argument.slice(separator + 1)];
  }),
);
const email = args.get('--email');
const confirmedProject = args.get('--confirm-project');
const revoke = args.has('--revoke');

if (!email || !email.includes('@')) {
  throw new Error('Dodajte --email=administrator@example.com.');
}
if (confirmedProject !== expectedProject) {
  throw new Error(`Potvrdite cilj sa --confirm-project=${expectedProject}.`);
}

initializeApp({
  credential: applicationDefault(),
  projectId: expectedProject,
});
const auth = getAuth();
const user = await auth.getUserByEmail(email);
const currentClaims = user.customClaims ?? {};
await auth.setCustomUserClaims(user.uid, {
  ...currentClaims,
  admin: !revoke,
});

process.stdout.write(
  JSON.stringify({
    projectId: expectedProject,
    uid: user.uid,
    email: user.email,
    admin: !revoke,
    note: 'Korisnik mora ponovo da se prijavi da bi dobio novi token.',
  }, null, 2),
);
