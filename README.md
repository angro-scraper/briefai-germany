# BriefAI Germany

Local-first PWA for understanding German official letters, with thin Android
and iOS wrappers.

## Current architecture

- Flutter 3 / Material 3 PWA at `/app/`.
- Native Flutter WebView shell at `lib/wrapper_main.dart`; it always loads the
  current PWA, so ordinary product updates do not require a new Store binary.
- Images and PDFs are OCR-processed on the user's device.
- Original files, OCR text, analyses, replies and letter chat are stored only
  in the local IndexedDB/application database.
- Firebase is limited to authentication, profile/usage metadata, verified
  subscription entitlement, App Check, messaging and aggregate admin metrics.
- OpenAI is called only through authenticated Cloud Functions. The OCR text is
  sent for the current request but is not written to a cloud archive.
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

- PWA: <https://briefai-germany-download.onrender.com/app/>
- Admin: <https://briefai-germany-download.onrender.com/admin/>
- Android QA APK:
  <https://briefai-germany-download.onrender.com/download/app-debug.apk>

The QA APK is debug-signed and is not a Play Store release artifact.
