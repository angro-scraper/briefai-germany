# BriefAI Germany — produkciona arhitektura

## Privacy boundary

Originalni dokument, OCR tekst, analiza, generisani odgovor i chat istorija
ostaju u lokalnom vault-u uređaja. Klijent nema Firestore ili Storage putanju
na koju može da otpremi pismo. Firestore i Storage pravila tu zabranu sprovode
i na serverskoj granici.

```text
PWA (izvor proizvoda)
  ├─ lokalni OCR: Tesseract.js / PDF.js
  ├─ lokalni vault: IndexedDB (Sembast)
  ├─ Auth: Firebase Email, Google, Apple
  ├─ lokalni rokovi: 7 / 3 / 1 dan u 09:00 Europe/Berlin
  └─ callable request sa OCR tekstom
       └─ Firebase Function → OpenAI Responses API
            └─ strukturisan rezultat se vraća klijentu, bez cloud arhive

Android / iOS shell
  └─ bezbedni WebView → ista produkciona PWA
       ├─ kamera / galerija / PDF picker
       └─ obični UI update bez novog Store binarnog fajla
```

## Dozvoljeni cloud podaci

| Putanja | Namena |
|---|---|
| `users/{uid}` | nalog, aktivnost i minimalni profil |
| `users/{uid}/usage/current` | serverska FREE kvota |
| `subscriptions/{uid}` | server-verifikovan entitlement |
| `deviceTokens/{token}` | opcionalna servisna obaveštenja |
| `adminMetrics/current` | agregati bez sadržaja pisama |

Ne postoje cloud `letters`, `messages` ili OCR kolekcije. Storage dozvoljava
samo kratkotrajni server-generisani izvoz naloga; `/letters/**` je eksplicitno
zabranjen.

## AI granica

API ključ je Firebase Secret i nikad nije deo Flutter/JavaScript builda.
`analyzeLetter`, `generateReply` i `askLetterAssistant` primaju samo sadržaj
potreban za taj poziv, ograničavaju veličinu, zahtevaju Auth i App Check i
tretiraju dokument kao nepoverljiv sadržaj. Rezultati se validiraju JSON
šemom gde je primenljivo.

## Pretplate

- FREE: dve analize po Berlin kalendarskom mesecu.
- PREMIUM/PRO: entitlement upisuje isključivo Stripe webhook ili funkcija koja
  proverava Google Play/App Store dokaz kod same prodavnice.
- Klijent nikada ne može sam sebi dodeliti Premium.

## Brisanje i izvoz

Pojedinačno brisanje uklanja lokalni original, OCR, analizu i njegove
notifikacije. Brisanje naloga prvo čisti ceo lokalni vault i podsetnike, zatim
poziva server cascade za Auth, tokene, profil, entitlement i privremeni
Storage. Lokalni JSON izvoz uključuje originalne bajtove kao Base64 jer oni
nikada nisu dostupni serveru.
