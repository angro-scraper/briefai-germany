# BriefAI Admin Panel

This lightweight web panel is intentionally static: Firebase Authentication, App Check and callable Functions enforce the actual administrator boundary. Before hosting it, replace every `firebaseConfig` value in `app.js`, including the App Check reCAPTCHA v3 site key; set a Firebase custom claim `{admin: true}` for trusted administrators; and deploy it behind your approved domain and CSP. Register the final admin domain under Firebase App Check before testing the panel.
