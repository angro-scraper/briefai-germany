import {existsSync, readFileSync} from 'node:fs';
import {resolve} from 'node:path';

const root = resolve(import.meta.dirname, '..');
const mode = process.argv.includes('--static')
  ? 'static'
  : process.argv.includes('--store')
    ? 'store'
    : 'firebase';
const failures = [];
const passes = [];

function check(label, condition, fix) {
  (condition ? passes : failures).push({label, ...(condition ? {} : {fix})});
}

function text(path) {
  return readFileSync(resolve(root, path), 'utf8');
}

const firebaseRc = JSON.parse(text('.firebaserc'));
check(
  'Firebase target is briefai-germany',
  firebaseRc.projects?.default === 'briefai-germany',
  'Set .firebaserc default project to briefai-germany.',
);
check(
  'Flutter Firebase config targets briefai-germany',
  text('lib/firebase_options.dart').includes("projectId: 'briefai-germany'"),
  'Run flutterfire configure for briefai-germany.',
);
check(
  'Documents are denied in Storage rules',
  /letters\/\{path=\*\*\}[\s\S]*allow read, write: if false/.test(
    text('storage.rules'),
  ),
  'Restore the deny-all letters rule.',
);
check(
  'Firestore has no client letter archive',
  !text('firestore.rules').includes('match /letters/'),
  'Remove cloud letter collections; documents must remain local.',
);
check(
  'OpenAI key is a Functions secret',
  text('functions/src/index.ts').includes(
    'defineSecret("OPENAI_API_KEY")',
  ),
  'Declare OPENAI_API_KEY with defineSecret.',
);
if (mode !== 'static') {
  check(
    'Functions production parameters exist',
    existsSync(resolve(root, 'functions/.env.briefai-germany')),
    'Copy functions/.env.example to functions/.env.briefai-germany and replace placeholders.',
  );
  if (existsSync(resolve(root, 'functions/.env.briefai-germany'))) {
    const parameterText = text('functions/.env.briefai-germany');
    for (const name of [
      'WEB_APP_ORIGIN',
      'ANDROID_PACKAGE_NAME',
      'APPLE_BUNDLE_ID',
      'APPLE_APP_STORE_ISSUER_ID',
      'APPLE_APP_STORE_KEY_ID',
      'APPLE_APP_STORE_ENV',
      'STRIPE_PREMIUM_PRICE_ID',
      'STRIPE_PRO_PRICE_ID',
    ]) {
      const match = parameterText.match(new RegExp(`^${name}=(.+)$`, 'm'));
      check(
        `Parameter ${name} is configured`,
        Boolean(match && !match[1].includes('REPLACE_')),
        `Set a non-placeholder ${name} in functions/.env.briefai-germany.`,
      );
    }
  }

  for (const flag of [
    'OPENAI_SECRET_CONFIGURED',
    'APP_CHECK_REGISTERED',
    'FIREBASE_BLAZE_APPROVED',
  ]) {
    check(
      `${flag}=true`,
      process.env[flag] === 'true',
      `Set ${flag}=true only after verifying it in the owner console.`,
    );
  }
}

if (mode === 'store') {
  for (const flag of [
    'LEGAL_APPROVED',
    'STORE_PRODUCTS_CONFIGURED',
    'STORE_SANDBOX_TESTED',
  ]) {
    check(
      `${flag}=true`,
      process.env[flag] === 'true',
      `Set ${flag}=true only after the corresponding owner/legal gate passes.`,
    );
  }
  check(
    'Android signing properties exist',
    existsSync(resolve(root, 'android/key.properties')),
    'Create android/key.properties on the signing machine.',
  );
  check(
    'Android Firebase config exists',
    existsSync(resolve(root, 'android/app/google-services.json')),
    'Download google-services.json from briefai-germany.',
  );
}

process.stdout.write(
  `${JSON.stringify({mode, passes, failures}, null, 2)}\n`,
);
if (failures.length > 0) process.exitCode = 1;
