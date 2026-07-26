# BriefAI Germany — release checklist

## Pravno i privatnost

- [ ] Privacy Policy i Terms & Conditions pregledani od nemačkog pravnika.
- [ ] Jasno upozorenje: AI objašnjenje nije pravni, poreski, medicinski ili finansijski savet.
- [ ] Evidencija svrhe obrade, rokova čuvanja i ugovora o obradi podataka.
- [ ] DSR tokovi: pristup, izvoz, brisanje i povlačenje saglasnosti.
- [ ] Data Protection Impact Assessment za obradu službenih pisama.

## Tehnički

- [ ] Firebase App Check uključen za Android, iOS i web.
- [ ] `OPENAI_API_KEY` postavljen kao Firebase Secret, nikad u klijentu.
- [ ] Firestore/Storage pravila objavljena i proverena u emulatoru.
- [ ] Crashlytics, Analytics i consent režim uključeni.
- [ ] Backup/retention politika i alarmi za greške definisani.
- [ ] OpenAI output šema, redakcija PII iz logova i limitiranje zahteva testirani.

## Store i naplata

- [ ] Google Play proizvodi: `briefai_premium_monthly` i `briefai_pro_monthly`.
- [ ] App Store proizvodi sa istim entitlement mapiranjem.
- [ ] Kupovine verifikovane server-side i obnova/cancel/webhook scenariji testirani.
- [ ] Stripe se koristi isključivo za web i entitlement se sinhronizuje server-side.

## QA

- [ ] Testirati fotografiju, galeriju i PDF na stvarnim Android/iOS uređajima.
- [ ] Testirati nemački OCR na mutnim, zakrivljenim i višestraničnim dokumentima.
- [ ] Testirati sve podržane jezike: sr, hr, bs, mk, de, en, bg.
- [ ] Testirati rokove: 7 dana, 3 dana, 1 dan, promena vremenske zone i otkazana obaveštenja.
- [ ] Pokrenuti unit, widget, integration, Functions emulator i bezbednosne testove pre svakog release-a.
