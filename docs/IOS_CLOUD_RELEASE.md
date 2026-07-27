# BriefAI Germany — iOS cloud release

The repository can build iOS on GitHub's hosted macOS runner, so the release
operator does not need to own a Mac.

## Workflows

- `iOS cloud check` compiles the release app without signing. It runs for iOS,
  Dart, and dependency changes and can also be started manually.
- `iOS TestFlight` imports Apple signing material, creates a signed IPA, stores
  the IPA as a short-lived GitHub artifact, and optionally uploads it to
  TestFlight.

## Apple prerequisites

App Store Connect must contain an app whose explicit bundle ID is:

`com.briefai.briefaiGermany`

The Apple Developer account must provide:

1. An Apple Distribution certificate exported as a password-protected `.p12`.
2. An App Store Connect provisioning profile for the bundle ID above.
3. A team App Store Connect API key with access to upload builds.

Never commit these files to Git.

## GitHub environment and secrets

Create a GitHub environment named `ios-production` and add:

| Secret | Value |
| --- | --- |
| `APPLE_TEAM_ID` | Apple Developer Team ID |
| `IOS_DISTRIBUTION_CERTIFICATE_BASE64` | Base64 of the `.p12` certificate |
| `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD` | Password used when exporting the `.p12` |
| `IOS_PROVISIONING_PROFILE_BASE64` | Base64 of the `.mobileprovision` file |
| `IOS_TEMP_KEYCHAIN_PASSWORD` | A long random temporary keychain password |
| `APP_STORE_CONNECT_API_KEY_ID` | App Store Connect API key ID |
| `APP_STORE_CONNECT_API_ISSUER_ID` | App Store Connect API issuer ID |
| `APP_STORE_CONNECT_API_PRIVATE_KEY_BASE64` | Base64 of `AuthKey_<KEY_ID>.p8` |

On Windows PowerShell, create a single-line Base64 value with:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes('C:\path\to\file'))
```

## Release

Open GitHub Actions, select `iOS TestFlight`, choose `Run workflow`, and enter a
new unique build number. Keep `upload_to_testflight` enabled to send the signed
IPA to App Store Connect.

The workflow removes the temporary keychain, certificate, provisioning profile,
and API private key from the runner even when a build fails.
