# BriefAI Germany

Local-first PWA for understanding German official letters, with thin Android
and iOS wrappers.

## Current architecture

- Flutter 3 / Material 3 PWA at `/app/`.
- Native Flutter WebView shell at `lib/wrapper_main.dart`; it always loads the
  current PWA, so ordinary product updates do not require a new Store binary.
- Images and PDFs are OCR-processed on the user's device.
- By default, original files and the letter archive stay in the local
  IndexedDB/application database. An optional, user-initiated encrypted cloud
  backup stores an encrypted archive in the account's private Firebase Storage
  path; it is not uploaded automatically on sign-in.
- Firebase also handles authentication, profile/usage metadata, verified
  subscription entitlement, App Check, messaging and aggregate admin metrics.
- When a user requests AI analysis, recognized text (and answers entered for
  reply or form drafts) is sent through Cloud Functions to the OpenAI API.
  The original image or PDF is not sent for that analysis.
- A private multilingual on-device fallback keeps basic analysis available
  when the AI backend is unavailable.

## Local commands

```powershell
C:\flutter\bin\flutter.bat pub get
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat test
C:\flutter\bin\flutter.bat run -d chrome
```

Build the PWA:

```powershell
C:\flutter\bin\flutter.bat build web --release --base-href /app/
```

Build the thin Android shell:

```powershell
C:\flutter\bin\flutter.bat build apk --debug --target lib/wrapper_main.dart
```

See [setup](docs/SETUP.md), [architecture](docs/ARCHITECTURE.md), and the
[store runbook](docs/STORE_RELEASE.md). Never commit OpenAI, Stripe, Play,
Apple, signing or service-account secrets.

## Published endpoints

- PWA: <https://briefai.salvesca.com/app/>
- Admin: <https://briefai.salvesca.com/admin/>
- Platform page: <https://briefai.salvesca.com/>
- iPhone: <https://apps.apple.com/app/id6794959959>
- Android instalacija i sva buduća ažuriranja:
  <https://play.google.com/store/apps/details?id=com.briefai.briefai_germany>

The Render hostname is the hosting origin only; customer-facing links and
native wrappers use the `briefai.salvesca.com` custom domain. Do not distribute
debug APK files: Android installations must come from Google Play so Play App
Signing can deliver future updates over the existing installation.
