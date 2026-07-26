# BriefAI Germany — store release runbook

Ovaj dokument je kontrolna lista za stvarni, potpisani store build. Ne čuvati ključeve, lozinke, servisne naloge ili provisioning profile u repozitorijumu.

## Android / Google Play

1. Kreirati finalni application ID i Firebase Android aplikaciju za `com.briefai.briefai_germany`; preuzeti `google-services.json` i pokrenuti `flutterfire configure` za isti Firebase projekat.
2. Napraviti upload keystore, sačuvati ga van repozitorijuma i generisati Base64 sadržaj bez preloma redova. Ne menjati upload key nakon što je prvi AAB poslat u Play Console.
3. U GitHub `production` environment dodati pet secrets koje koristi workflow `Store release`: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `GOOGLE_SERVICES_JSON_BASE64`.
4. U Play Console aktivirati Google Play Developer API, dodati servisni nalog kao korisnika aplikacije i njegov JSON postaviti samo kao Firebase secret `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`. Podesiti `ANDROID_PACKAGE_NAME=com.briefai.briefai_germany` kao Functions parameter.
5. Kreirati subscriptions `briefai_premium_monthly` (4,99 EUR) i `briefai_pro_monthly` (9,99 EUR), zatim testirati kupovinu, obnovu, otkazivanje i grace period preko internal testing track-a.
6. Ručno pokrenuti GitHub workflow sa sledećim većim `build_number`. Workflow
   gradi `lib/wrapper_main.dart`, odnosno tanki omotač produkcione PWA.
   Preuzeti AAB artefakt, poslati ga u Play Console internal testing i proveriti
   App Check, prijavu, kameru/PDF chooser, lokalni OCR, AI analizu, podsetnik i
   restore na stvarnom uređaju.

## iOS / App Store Connect

1. Na macOS-u dodati `GoogleService-Info.plist` dobijen iz istog Firebase projekta i ponovo pokrenuti `flutterfire configure`.
2. U Apple Developer nalogu za finalni bundle ID uključiti **Sign In with Apple** i **Push Notifications**; napraviti odgovarajući development/distribution provisioning profile.
3. U App Store Connect napraviti pretplate sa identičnim product ID-jevima i dodati App Store Server API key. p8 materijal ide samo u Firebase secret `APPLE_APP_STORE_PRIVATE_KEY`; identifikatori su Functions parameters.
4. Napraviti archive za `lib/wrapper_main.dart` preko Xcode-a, poslati
   TestFlight build i na fizičkom iPhone-u proveriti Apple login, WebView
   kameru/PDF chooser, push dozvolu, lokalni OCR, kupovinu, restore i brisanje
   naloga.

## Pre slanja na review

- Firebase `firestore.rules`, `storage.rules` i Functions su deploy-ovani u odabrani produkcioni projekat; `OPENAI_API_KEY`, Stripe i store secrets su postavljeni kao Functions secrets.
- App Check je u enforcement modu nakon testiranja na realnim aplikacijama; admin panel ima stvaran web Firebase config i reCAPTCHA v3 key.
- Privacy Policy, Terms, data-retention politika i App Store Privacy / Play Data safety odgovori su odobreni od odgovornog pravnog lica.
- Publikovani AAB/IPA su potpisani release profilima. Debug APK sa GitHub release-a je samo za direktno tehničko testiranje i nije Play Store artefakt.
