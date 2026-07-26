# BriefAI Germany — arhitektura

## Princip

Mobilni klijent nikada ne poziva OpenAI direktno i nikada ne čuva API ključ. Sva obrada poverljivih pisama prolazi kroz autentifikovanu Firebase Cloud Function. Dokumenti se čuvaju privatno u Firebase Storage, sa pravilima zasnovanim na `uid` korisnika.

```text
Flutter (Android / iOS / web)
  ├─ Firebase Auth: Email, Google, Apple
  ├─ Storage: original + obrađena slika/PDF
  ├─ Firestore: korisnik, dokument, analiza, pretplata, podsetnici
  ├─ FCM: podsetnici i servisna obaveštenja
  └─ Callable Functions
        ├─ analyzeDocument → OCR → OpenAI structured output → Firestore
        ├─ generateReply → OpenAI structured output
        ├─ scheduleDeadlineReminders → Cloud Tasks / FCM
        ├─ deleteAccount → Auth + Storage + Firestore cascade
        └─ Stripe webhook → subscription entitlement
```

## Kolekcije u Firestore

| Putanja | Namena |
|---|---|
| `users/{uid}` | profil, jezik, plan, GDPR dozvole |
| `users/{uid}/letters/{letterId}` | metapodaci pisma, rezultat analize, status, rok |
| `users/{uid}/letters/{letterId}/messages/{messageId}` | kontekst AI razgovora |
| `subscriptions/{uid}` | server-verifikovan entitlement |
| `adminMetrics/{period}` | agregati za admin panel |

## Kritične bezbednosne odluke

1. OpenAI ključ postoji samo kao Firebase Secret.
2. Dokumenti nemaju javne URL-ove; generišu se kratkotrajni signed URL-ovi samo gde je potrebno.
3. Firestore i Storage pravila dozvoljavaju isključivo vlasniku dokumenta pristup.
4. AI izlaz je JSON validiran šemom, sa upozorenjem da nije pravni savet.
5. Zadatak za brisanje naloga trajno briše Auth profil, dokumente, analize, chat i token uređaja.

## Faze razvoja

1. Auth, profil, onboarding i lokalizacija.
2. Upload/kamera, optimizacija slike i ML Kit OCR.
3. Cloud Function za AI analizu i rezultat.
4. Arhiva, statusi, rokovi i FCM podsetnici.
5. AI odgovori, deljenje emailom i PDF izvoz.
6. Pretplate i server-side validacija kupovina.
7. Admin web, monitoring, GDPR procesi, QA i store materijali.
