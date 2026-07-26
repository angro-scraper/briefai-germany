# Pokretanje i produkciona konfiguracija

## Lokalno pokretanje

```powershell
C:\flutter\bin\flutter.bat pub get
C:\flutter\bin\flutter.bat test
C:\flutter\bin\flutter.bat run
```

Ako desktop sandbox ne dozvoljava standardnom `flutter` wrapperu pristup SDK lock fajlu, ekvivalentna test komanda je:

```powershell
C:\flutter\bin\cache\dart-sdk\bin\dart.exe C:\flutter\bin\cache\flutter_tools.snapshot test --no-pub --reporter compact
```

## Firebase pre produkcije

1. Kreirati Firebase projekat i Android/iOS/web aplikacije.
2. Pokrenuti `flutterfire configure`; on zamenjuje početni `lib/firebase_options.dart` stvarnim generisanim opcijama. Generisani fajl se ne menja ručno i mora biti uključen u build. Aplikacija na svakom targetu eksplicitno koristi `DefaultFirebaseOptions.currentPlatform`, pa release ne sme koristiti početni placeholder fajl.
3. Omogućiti Email/Password, Google i Apple prijavu.
4. Dodati Firebase Secret `OPENAI_API_KEY`; nikad ga ne stavljati u Flutter kod ili `.env` koji se objavljuje.
5. Podesiti Play Console, App Store Connect i Stripe webhook tajne na serveru.
6. Pre objave, pravnik treba da odobri nemačku Privacy Policy i Terms & Conditions, posebno obradu dokumenata i AI ograničenja.

Release build namerno ne prelazi u lokalni AI/OCR režim ako Firebase inicijalizacija ne uspe: prikazuje nedostupnost usluge i blokira novu analizu. Lokalni deterministički analizator je dostupan samo u debug buildu.

### Rokovi i push podsetnici

`sendDeadlineReminders` je dnevna Cloud Scheduler funkcija u `europe-west3`. Pre objave Functions omogućiti Cloud Scheduler API i proveriti da servisni nalog Functions ima dozvolu za slanje FCM poruka. Funkcija šalje 7, 3 i 1 dan pre ISO roka i upisuje idempotentni zapis u `reminderDeliveries`, pa retry ne šalje isti podsetnik ponovo. Push i lokalna notifikacija namerno ne sadrže naslov ili tekst pisma, jer mogu biti vidljivi na zaključanom ekranu.

### Admin panel i App Check

U `admin-panel/app.js` popuniti svih šest Firebase web vrednosti i reCAPTCHA v3 site key za App Check. Zatim dodati stvarni admin domen u Firebase App Check, omogućiti App Check za Cloud Functions i postaviti custom claim `{admin: true}` samo proveranim administratorima. Bez App Check tokena ili claima, funkcije `adminOverview` i `sendAdminNotification` odbijaju zahtev.

### Document AI OCR

1. U Google Cloud projektu omogućiti **Document AI API** i napraviti OCR processor u `eu` lokaciji.
2. Firebase Functions servisnom nalogu dodeliti rolu `Document AI API User` za taj processor.
3. Postaviti `DOCUMENT_AI_PROCESSOR=<processor-id>` u `functions/.env`; ovo je deploy parametar, ne API tajna.
4. PDF se čuva privatno u Storage, a `extractDocumentText` proverava da li putanja pripada prijavljenom korisniku pre slanja sadržaja OCR servisu.

Slike sa kamere, galerije i ručno učitane slike se pre uploada obrađuju lokalno: EXIF orijentacija se ispravlja, širina ograničava na 2400 px, a kontrast blago povećava. Produkcioni OCR zatim čita upravo taj privatni, poboljšani JPEG; originalne fotografije se ne šalju u OCR tok.

### Stripe za web

1. U Stripe-u napraviti mesečne recurring cene za Premium i Pro i njihove ID-jeve postaviti kao `STRIPE_PREMIUM_PRICE_ID` i `STRIPE_PRO_PRICE_ID` u `functions/.env`. Postaviti i `WEB_APP_ORIGIN` na jedini dozvoljeni HTTPS origin Flutter web aplikacije; Checkout ne prihvata proizvoljne povratne URL-ove.
2. Postaviti `STRIPE_SECRET_KEY` i `STRIPE_WEBHOOK_SECRET` pomoću `firebase functions:secrets:set`.
3. U Stripe Dashboard-u dodati webhook endpoint `https://europe-west3-<project-id>.cloudfunctions.net/stripeWebhook` i uključiti najmanje `customer.subscription.created`, `customer.subscription.updated` i `customer.subscription.deleted` događaje.
4. Flutter/web klijent poziva `createStripeCheckout`; Stripe webhook, a ne klijent, upisuje `subscriptions/{uid}` entitlement.

### AI asistent za pismo

`askLetterAssistant` prima samo korisničko pitanje i ID pisma. Funkcija učitava analizu i OCR tekst isključivo iz `users/{uid}/letters/{letterId}`, ograničava dužinu sadržaja i šalje tekst OpenAI-ju sa instrukcijom da sadržaj dokumenta ne sme menjati pravila asistenta. Zato se OCR sadržaj drugog korisnika ne može proslediti preko klijenta. Testirati ovaj tok sa stvarnim Firebase Auth korisnikom, App Check-om i nalogom bez pristupa tuđem pismu.

`analyzeLetter` transakcijski rezerviše besplatnu analizu pre OpenAI poziva; tako paralelni zahtevi ne mogu preći limit od dve analize mesečno. Ako AI poziv ne uspe, rezervacija se vraća. `generateReply` vraća strogo strukturisane `letter` i `email` varijante, koje klijent prikazuje odvojeno i koristi za PDF odnosno e-mail izvoz.

Klijent prikazuje kvotu čitajući samo svoj `users/{uid}/usage/current` dokument. Taj dokument je read-only za klijent, upisuje ga samo Cloud Function i resetuje se po `Europe/Berlin` mesecu, pa lokalno stanje ne može otključati dodatne analize.

### GDPR izvoz podataka

`exportAccountData` sastavlja JSON profila, arhive analiza/OCR teksta i statusa pretplate na serveru, pa ga upisuje samo u privatni Storage prefix pozivaoca (`users/{uid}/exports`). Klijent preuzima taj fajl, otvara sistemski share sheet za JSON i uvek briše privremeni Storage objekat. Izvorni PDF-ovi i slike ostaju privatni u postojećem `letters` prefixu; za vrlo velike arhive funkcija bezbedno odbija nepotpun direktni izvoz umesto da truncira podatke.

## Važna ograničenja ove isporuke

Ovaj repozitorijum sadrži funkcionalni lokalni tok korisničkog interfejsa i deterministički razvojni analizator da se aplikacija može testirati bez slanja stvarnih dokumenata. Prava OCR/AI obrada, prijava, naplata, obaveštenja i objava zahtevaju konfiguraciju navedenih eksternih naloga i nikada se ne mogu bezbedno završiti bez njihovih podataka.

## Obavezne produkcione komande

```powershell
firebase login
firebase use --add
firebase functions:secrets:set OPENAI_API_KEY
firebase deploy --only firestore:rules,storage,functions
firebase target:apply hosting admin <admin-hosting-site-id>
firebase deploy --only hosting:admin
flutterfire configure
C:\flutter\bin\flutter.bat build appbundle --release
```

Release build mora sadržati i pravni identitet, koji se prosleđuje kao Dart defines: `LEGAL_ENTITY_NAME`, `LEGAL_CONTACT_EMAIL`, `LEGAL_POSTAL_ADDRESS` i `LEGAL_APPROVED=true`. Aplikacija namerno blokira cloud rad u release režimu ako bilo koja od tih vrednosti nedostaje. Potvrdu `LEGAL_APPROVED=true` postaviti tek nakon pregleda Privacy Policy i Terms & Conditions od nemačkog pravnika.

Nakon `flutterfire configure`, proveriti da je generisani `lib/firebase_options.dart` uključen u `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`. Pre slanja u prodavnice, uneti i verifikovati proizvode `briefai_premium_monthly` i `briefai_pro_monthly`; entitlement se na produkciji ažurira isključivo posle server-side provere store transakcije.

### Native pretplate: server-side provera

Klijent nikada ne dodeljuje Premium lokalno. Posle kupovine ili restore-a šalje store dokaz funkciji `verifyStorePurchase`; funkcija proverava status kod prodavnice, veže hash dokaza za jedan korisnički nalog i tek tada upisuje `subscriptions/{uid}`.

1. Dodati Firebase Secret `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` sa kompletnim JSON-om servisnog naloga kome je u Play Console dodeljen pristup aplikaciji i Google Play Developer API-ju. U `functions/.env` postaviti `ANDROID_PACKAGE_NAME`.
2. Za App Store Server API dodati Firebase Secret `APPLE_APP_STORE_PRIVATE_KEY` (p8 ključ), a u `functions/.env` postaviti `APPLE_APP_STORE_ISSUER_ID`, `APPLE_APP_STORE_KEY_ID`, `APPLE_BUNDLE_ID` i `APPLE_APP_STORE_ENV` (`sandbox` za test, `production` za objavu).
3. U Play Console i App Store Connect napraviti auto-renewable proizvode sa identifikatorima `briefai_premium_monthly` i `briefai_pro_monthly`. Testirati kupovinu i restore na stvarnom sandbox uređaju pre objave.

### Potpisani store build preko GitHub Actions

Workflow **Store release** ne pravi javni debug APK. Ručno se pokreće tek kada su secrets popunjeni i pravi potpisani Android App Bundle (`.aab`) za Play Console. Potrebni repository secrets su `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` i `GOOGLE_SERVICES_JSON_BASE64`. Sadrže samo potpisni materijal i Android Firebase konfiguraciju; OpenAI, Stripe i store API ključevi ostaju isključivo Firebase Functions secrets.

Pre aktiviranja workflow-a, zameniti placeholder kroz `flutterfire configure`, dodati iOS `GoogleService-Info.plist`, proveriti Apple Sign In / Push Notifications capabilities i napraviti TestFlight build na macOS-u. Detaljan redosled je u `docs/STORE_RELEASE.md`.
