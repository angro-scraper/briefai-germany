# BriefAI Germany — iOS cloud release

The repository can build iOS on GitHub's hosted macOS runner, so the release
operator does not need to own a Mac.

## Workflows

- `iOS cloud check` compiles the release app without signing. It runs for iOS,
  Dart, and dependency changes and can also be started manually.
- `iOS TestFlight` creates or reuses Apple distribution signing files on the
  hosted runner, creates a signed IPA, stores the IPA as a short-lived GitHub
  artifact, and optionally uploads it to TestFlight.

## Apple prerequisites

App Store Connect must contain an app whose explicit bundle ID is:

`com.briefai.briefaiGermany`

The Apple Developer account must provide a team App Store Connect API key with
App Manager access. The workflow uses that key to create or download the
required App Store certificate and provisioning profile. Never commit either
private key to Git.

## GitHub environment and secrets

Create a GitHub environment named `ios-production` and add:

| Secret | Value |
| --- | --- |
| `APPLE_TEAM_ID` | Apple Developer Team ID |
| `APP_STORE_CONNECT_API_KEY_ID` | App Store Connect API key ID |
| `APP_STORE_CONNECT_API_ISSUER_ID` | App Store Connect API issuer ID |
| `APP_STORE_CONNECT_API_PRIVATE_KEY_BASE64` | Base64 of `AuthKey_<KEY_ID>.p8` |
| `IOS_DISTRIBUTION_CERTIFICATE_PRIVATE_KEY_BASE64` | Base64 of the persistent PKCS#8 RSA private key used to create/reuse the Apple distribution certificate |

On Windows PowerShell, create a single-line Base64 value with:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes('C:\path\to\file'))
```

## Release

Open GitHub Actions, select `iOS TestFlight`, choose `Run workflow`, and enter a
new unique build number. Keep `upload_to_testflight` enabled to send the signed
IPA to App Store Connect.

The workflow removes both private keys from the disposable runner even when a
build fails.
