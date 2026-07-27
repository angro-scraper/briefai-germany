# BriefAI Germany — release checklist

## Pravno i privatnost

- [ ] Privacy Policy i Terms & Conditions pregledani od nemačkog pravnika.
- [ ] Jasno upozorenje: AI objašnjenje nije pravni, poreski, medicinski ili finansijski savet.
- [ ] Evidencija svrhe obrade, rokova čuvanja i ugovora o obradi podataka.
- [ ] DSR tokovi: pristup, izvoz, brisanje i povlačenje saglasnosti.
- [ ] Data Protection Impact Assessment za obradu službenih pisama.
- [ ] Pravni identitet, kontakt i poštanska adresa ubačeni kroz `LEGAL_*`
      Dart defines i tekstovi odobreni sa `LEGAL_APPROVED=true`.

## Tehnički

- [ ] Firebase App Check uključen za Android, iOS i web.
- [ ] `OPENAI_API_KEY` postavljen kao Firebase Secret, nikad u klijentu.
- [ ] Firestore/Storage pravila objavljena i proverena u emulatoru.
- [ ] Crashlytics, Analytics i consent režim uključeni.
- [ ] Backup/retention politika i alarmi za greške definisani.
- [ ] OpenAI output šema, redakcija PII iz logova i limitiranje zahteva testirani.
- [ ] Potvrđeno da `/users/{uid}/letters/**` nema cloud write putanju i da
      original, OCR, analiza, odgovor i chat ostaju u lokalnom vault-u.
- [ ] Lokalni JSON izvoz i pojedinačno/kompletno brisanje provereni na webu,
      Androidu i iOS-u.

## Store i naplata

- [ ] Google Play mesečne pretplate: `briefai_premium_monthly` (50 / 9,90 EUR),
  `briefai_plus_monthly` (100 / 19,90 EUR) i `briefai_pro_monthly`
  (150 / 29,90 EUR).
- [ ] App Store mesečne pretplate sa istim ID-jevima, cenama i nivoima unutar
  jedne subscription grupe.
- [ ] Kupovine verifikovane server-side i obnova/cancel/webhook scenariji testirani.
- [ ] Stripe se koristi isključivo za web i entitlement se sinhronizuje server-side.

## QA

- [ ] Testirati fotografiju, galeriju i PDF na stvarnim Android/iOS uređajima.
- [ ] Testirati nemački OCR na mutnim, zakrivljenim i višestraničnim dokumentima.
- [ ] Testirati svih osam potpuno prevedenih interfejsa i reprezentativni
      uzorak dodatnih BCP-47 jezika; AI odgovor mora ostati na izabranom jeziku.
- [ ] Testirati rokove: 7 dana, 3 dana, 1 dan, promena vremenske zone i otkazana obaveštenja.
- [ ] Testirati IndexedDB/app vault posle restarta, update-a, odjave i promene
      naloga; dokumenti ne smeju preći između profila uređaja.
- [ ] Testirati WebView file chooser za kameru, galeriju i PDF i proveriti da
      običan PWA deploy postaje vidljiv bez novog Store binarnog fajla.
- [ ] Pokrenuti unit, widget, integration, Functions emulator i bezbednosne testove pre svakog release-a.
