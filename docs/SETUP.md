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
2. Pokrenuti `flutterfire configure`; on zamenjuje početni `lib/firebase_options.dart` stvarnim generisanim opcijama. Generisani fajl se ne menja ručno i mora biti uključen u build.
3. Omogućiti Email/Password, Google i Apple prijavu.
4. Dodati Firebase Secret `OPENAI_API_KEY`; nikad ga ne stavljati u Flutter kod ili `.env` koji se objavljuje.
5. Podesiti Play Console, App Store Connect i Stripe webhook tajne na serveru.
6. Pre objave, pravnik treba da odobri nemačku Privacy Policy i Terms & Conditions, posebno obradu dokumenata i AI ograničenja.

Release build namerno ne prelazi u lokalni AI/OCR režim ako Firebase inicijalizacija ne uspe: prikazuje nedostupnost usluge i blokira novu analizu. Lokalni deterministički analizator je dostupan samo u debug buildu.

### Document AI OCR

1. U Google Cloud projektu omogućiti **Document AI API** i napraviti OCR processor u `eu` lokaciji.
2. Firebase Functions servisnom nalogu dodeliti rolu `Document AI API User` za taj processor.
3. Postaviti `DOCUMENT_AI_PROCESSOR=<processor-id>` u `functions/.env`; ovo je deploy parametar, ne API tajna.
4. PDF se čuva privatno u Storage, a `extractDocumentText` proverava da li putanja pripada prijavljenom korisniku pre slanja sadržaja OCR servisu.

### Stripe za web

1. U Stripe-u napraviti mesečne recurring cene za Premium i Pro i njihove ID-jeve postaviti kao `STRIPE_PREMIUM_PRICE_ID` i `STRIPE_PRO_PRICE_ID` u `functions/.env`. Postaviti i `WEB_APP_ORIGIN` na jedini dozvoljeni HTTPS origin Flutter web aplikacije; Checkout ne prihvata proizvoljne povratne URL-ove.
2. Postaviti `STRIPE_SECRET_KEY` i `STRIPE_WEBHOOK_SECRET` pomoću `firebase functions:secrets:set`.
3. U Stripe Dashboard-u dodati webhook endpoint `https://europe-west3-<project-id>.cloudfunctions.net/stripeWebhook` i uključiti najmanje `customer.subscription.created`, `customer.subscription.updated` i `customer.subscription.deleted` događaje.
4. Flutter/web klijent poziva `createStripeCheckout`; Stripe webhook, a ne klijent, upisuje `subscriptions/{uid}` entitlement.

### AI asistent za pismo

`askLetterAssistant` prima samo korisničko pitanje i ID pisma. Funkcija učitava analizu i OCR tekst isključivo iz `users/{uid}/letters/{letterId}`, ograničava dužinu sadržaja i šalje tekst OpenAI-ju sa instrukcijom da sadržaj dokumenta ne sme menjati pravila asistenta. Zato se OCR sadržaj drugog korisnika ne može proslediti preko klijenta. Testirati ovaj tok sa stvarnim Firebase Auth korisnikom, App Check-om i nalogom bez pristupa tuđem pismu.

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

Nakon `flutterfire configure`, proveriti da je generisani `lib/firebase_options.dart` uključen u `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`. Pre slanja u prodavnice, uneti i verifikovati proizvode `briefai_premium_monthly` i `briefai_pro_monthly`; entitlement se na produkciji ažurira isključivo posle server-side provere store transakcije.

### Native pretplate: server-side provera

Klijent nikada ne dodeljuje Premium lokalno. Posle kupovine ili restore-a šalje store dokaz funkciji `verifyStorePurchase`; funkcija proverava status kod prodavnice, veže hash dokaza za jedan korisnički nalog i tek tada upisuje `subscriptions/{uid}`.

1. Dodati Firebase Secret `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` sa kompletnim JSON-om servisnog naloga kome je u Play Console dodeljen pristup aplikaciji i Google Play Developer API-ju. U `functions/.env` postaviti `ANDROID_PACKAGE_NAME`.
2. Za App Store Server API dodati Firebase Secret `APPLE_APP_STORE_PRIVATE_KEY` (p8 ključ), a u `functions/.env` postaviti `APPLE_APP_STORE_ISSUER_ID`, `APPLE_APP_STORE_KEY_ID`, `APPLE_BUNDLE_ID` i `APPLE_APP_STORE_ENV` (`sandbox` za test, `production` za objavu).
3. U Play Console i App Store Connect napraviti auto-renewable proizvode sa identifikatorima `briefai_premium_monthly` i `briefai_pro_monthly`. Testirati kupovinu i restore na stvarnom sandbox uređaju pre objave.
