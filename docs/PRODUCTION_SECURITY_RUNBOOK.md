# BriefAI — produkcioni bezbednosni postupak

Ovaj postupak se odnosi isključivo na Firebase projekat `briefai-germany` i
mobilne aplikacije BriefAI. Ne unosi se nijedan API ključ u aplikaciju, Git ili
store paket.

## Pre aktiviranja App Check-a

Mobilni kod već aktivira sledeće provajdere u release izdanjima:

- Android: Play Integrity
- iOS: Apple App Attest (sa podrškom platforme Firebase)
- Web: reCAPTCHA Enterprise

Pre registracije potvrditi da je `OPENAI_API_KEY` prisutan kao Firebase/Google
Cloud Secret, bez prikazivanja njegove vrednosti. Za aplikacije koje koriste
AI, originalna fotografija i PDF ostaju u lokalnoj arhivi; backendu se šalje
samo OCR tekst uz korisnikovu saglasnost.

## Android — Play Integrity

1. U Google Play Console otvoriti **BriefAI Germany** → *Setup* → *App
   integrity* → *App signing*.
2. Kopirati **SHA-256 App signing certificate**. Ne koristiti debug sertifikat
   niti upload sertifikat ako se razlikuje od Play App Signing sertifikata.
3. U Firebase Console → *App Check* → *Apps* → **BriefAI Germany Android**
   registrovati *Play Integrity* i uneti taj SHA-256.
4. Sačuvati registraciju, ali **ne uključivati enforcement** za Authentication,
   Firestore ili Functions u istom koraku.
5. Instalirati test izdanje iz Play test track-a i proveriti login, analizu,
   arhivu i AI asistenta.
6. Tek nakon uspešnog testa uključivati enforcement po jednoj API oblasti i
   proveravati metriku odbijenih zahteva između promena.

## iOS — App Attest

1. U Firebase Console → *App Check* → *Apps* → **BriefAI Germany iOS**
   izabrati *App Attest*.
2. Pre toga proveriti da App ID `com.briefai.briefaiGermany` ima uključen App
   Attest capability u Apple Developer nalogu i da je novi provisioning profil
   upotrebljen u Codemagic build-u.
3. Sačuvati registraciju bez uključivanja enforcement-a.
4. Testirati TestFlight izdanje na fizičkom iPhone-u: prijava, fotografisanje,
   OCR analiza, lokalna arhiva i AI odgovor.
5. Enforcement uključivati tek kada Firebase App Check metrike pokazuju validne
   tokene sa stvarnih uređaja.

## Store i bezbednosna provera izdanja

Pre svake objave proveriti:

- verziju i `versionCode` / build broj;
- da je Android paket potpisan istim upload ključem koji Play Console očekuje;
- da iOS build dolazi iz BriefAI Codemagic workflow-a;
- da se samo BriefAI release menja, bez otvaranja ili menjanja drugih aplikacija;
- da su 3 test analize / founder izuzetak i lokalna arhiva provereni na čistom
  uređaju.

Ako se upload sertifikat resetuje, sačekati vreme aktivacije koje Play Console
navede. Ne praviti novu aplikaciju i ne menjati package ID kao zaobilazno
rešenje.

