# BriefAI Admin Panel

This lightweight web panel is intentionally static: Firebase Authentication and callable Functions enforce the actual administrator boundary. Before hosting it, replace `firebaseConfig` in `app.js`, set a Firebase custom claim `{admin: true}` for trusted administrators, and deploy it behind your approved domain and CSP.
