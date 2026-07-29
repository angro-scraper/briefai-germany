# Salvesca platform deployment

The static Salvesca hub and modules are intentionally independent of BriefAI's
document archive. They are prepared as separate archives for the domain root
and each subdomain.

## Create a release package

From the repository root:

```powershell
pwsh -File scripts/package-salvesca-platform.ps1
```

The command creates a timestamped folder below
`build/salvesca-platform-release/`. It contains:

- `salvesca-com.zip` for the `salvesca.com` document root;
- `asistent-salvesca-com.zip`, `usluge-salvesca-com.zip`,
  `posao-salvesca-com.zip`, `prevod-salvesca-com.zip`,
  `finansije-salvesca-com.zip` and `prevoz-salvesca-com.zip`. The root
  archive contains only the Salvesca hub, while every subdomain archive
  contains only that module's files;
- `manifest.json` with the source commit and SHA-256 checksum of every archive.

## Publish through CPanel

1. Open the target domain or subdomain document root in **File Manager**.
2. Upload only the archive for that exact target.
3. Extract it directly into that document root. Do not extract into a shared
   `public_html` parent or a sibling subdomain directory.
4. Confirm that the target root contains `index.html` and, for the assistant,
   `life-assistant-logo.png`.
5. Open the public HTTPS URL in a private browser window and verify the
   language selector, primary action, and local-storage flow.

The release package contains no credentials, Firebase secrets, OCR text or
user documents. Do not upload a local `.env` file, Firebase service account,
or `functions/.env*` file to CPanel.
