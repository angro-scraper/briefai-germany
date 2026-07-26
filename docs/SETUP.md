# Pokretanje i produkciona konfiguracija

## Već vezani projekat

Repozitorijum je vezan isključivo za Firebase projekat `briefai-germany`.
Render servis je `briefai-germany-download`. Ne koristiti konfiguraciju drugog
Firebase ili Render projekta.

Email/Password Auth i Firestore baza u `europe-west3` su kreirani. Javni web
Firebase config i reCAPTCHA site key nisu tajne; privatni reCAPTCHA secret,
OpenAI, Stripe i Store ključevi ne smeju u repozitorijum.

## Firebase aktivacija

Cloud Functions zahtevaju Blaze plan. Posle eksplicitnog vlasničkog odobrenja:

```powershell
Copy-Item functions/.env.example functions/.env.briefai-germany
$env:OPENAI_SECRET_CONFIGURED='true'
$env:APP_CHECK_REGISTERED='true'
$env:FIREBASE_BLAZE_APPROVED='true'
node scripts/production-preflight.mjs
npx firebase-tools login
npx firebase-tools use briefai-germany
npx firebase-tools functions:secrets:set OPENAI_API_KEY
npx firebase-tools deploy --only firestore:rules,storage,functions
```

Pre deploy-a podesiti Functions parametre:

```text
WEB_APP_ORIGIN=https://briefai-germany-download.onrender.com
ANDROID_PACKAGE_NAME=com.briefai.briefai_germany
APPLE_BUNDLE_ID=com.briefai.briefaiGermany
STRIPE_PREMIUM_PRICE_ID=<Stripe recurring price>
STRIPE_PRO_PRICE_ID=<Stripe recurring price>
```

Omogućiti Google provider u Firebase Auth. Za Apple provider uneti Apple
Services ID, Team ID, Key ID i privatni ključ iz naloga vlasnika.

## OpenAI

`OPENAI_API_KEY` se postavlja samo kao Firebase Secret. Klijent nikada ne
poziva OpenAI direktno. Funkcije koriste Responses API, strogu šemu i podršku
za `sr`, `hr`, `bs`, `mk`, `bg`, `de` i `en`. OCR tekst se koristi samo tokom
poziva i ne upisuje u Firestore/Storage.

## App Check

Web domeni koji moraju biti registrovani:

```text
briefai-germany-download.onrender.com
briefai-germany.firebaseapp.com
```

Posle testiranja validnih web, Android Play Integrity i Apple App Attest
tokena uključiti Functions enforcement. Debug provider se koristi samo u
debug buildovima.

## Admin

Admin panel je na `/admin/`. Prijava sama po sebi ne daje pristup. Izabranom
Firebase Auth korisniku server-side postaviti custom claim:

```js
await getAuth().setCustomUserClaims(uid, {admin: true});
```

Posle promene claim-a korisnik mora ponovo da se prijavi. `adminOverview` i
`sendAdminNotification` proveravaju claim i App Check na svakom zahtevu.

Na računaru koji ima Google Application Default Credentials:

```powershell
Set-Location functions
npm run admin:claim -- --email=ADMIN_EMAIL --confirm-project=briefai-germany
```

Alat čuva postojeće custom claim-ove i odbija izvršenje ako cilj nije tačno
`briefai-germany`. Za uklanjanje privilegije dodati `--revoke`.

## Stripe i Store

Stripe secrets:

```text
STRIPE_SECRET_KEY
STRIPE_WEBHOOK_SECRET
```

Webhook endpoint je
`https://europe-west3-briefai-germany.cloudfunctions.net/stripeWebhook`.
Uključiti `customer.subscription.created`, `.updated` i `.deleted`.

Google/Apple proizvodi:

```text
briefai_premium_monthly
briefai_pro_monthly
```

Google servisni nalog ide u `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`; Apple p8 ide u
`APPLE_APP_STORE_PRIVATE_KEY`. Ostali Apple identifikatori su Functions
parametri. Kupovinu, restore, renewal, cancellation i grace period obavezno
testirati u internal/sandbox okruženju.

## Pravni identitet

Store build i javna komercijalna promocija zahtevaju odobrene vrednosti:

```text
LEGAL_ENTITY_NAME
LEGAL_CONTACT_EMAIL
LEGAL_POSTAL_ADDRESS
LEGAL_APPROVED=true
```

Bez njih aplikacija jasno prikazuje razvojno pravno upozorenje, ali tehničke
funkcije nisu tiho isključene. `LEGAL_APPROVED=true` postaviti tek posle
pregleda nemačke politike privatnosti i uslova korišćenja.

## Verifikacija

```powershell
C:\flutter\bin\flutter.bat analyze --no-pub
C:\flutter\bin\flutter.bat test
Set-Location functions
npm run build
```

Za potpisane Store pakete pratiti [STORE_RELEASE.md](STORE_RELEASE.md).
Pre potpisivanja pokrenuti `node scripts/production-preflight.mjs --store`;
komanda mora završiti bez ijednog failure zapisa.
