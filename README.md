# BriefAI Germany

Mobile app for people living in Germany who want clear, practical explanations of official German letters.

## What is included

- Flutter Android, iOS and web client using Material Design 3
- Firebase-ready authentication, Firestore archive, Storage, Analytics, Crashlytics and messaging
- ML Kit OCR flow and secure Cloud Functions for AI analysis and reply generation
- Archive, deadlines, reminders, multilingual profile and freemium subscription flows
- Firebase rules, admin dashboard, deployment documentation and tests
- A Render-ready download page in `install-site/`

## Run locally

```bash
flutter pub get
flutter run
```

See [docs/SETUP.md](docs/SETUP.md) for Firebase, OpenAI, Document AI and Stripe configuration. Never commit production credentials or Firebase platform config files.

## Android installation

Published APKs are available from the GitHub Releases page. The Render download page redirects users to the current GitHub Release asset.

## Deployment

`render.yaml` declares a static Render service that publishes `install-site/`. Connect this repository in Render with **New → Blueprint**; subsequent commits deploy automatically.
