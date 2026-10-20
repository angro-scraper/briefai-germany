# BriefAI Germany — Google Search Console access runbook

## Purpose

Give the BriefAI operator read-only, measurable organic-search data for the
whole `briefai.salvesca.com` domain. This is a measurement step, not a change
to the app, user data, Firebase, or billing.

## Current observed state

On 21 October 2026, the currently signed-in Google account did not have
access to the `briefai.salvesca.com` Search Console property. Do not infer
search impressions or clicks until the domain owner has completed one of the
access routes below.

## Preferred route: domain owner grants access

1. Sign into Search Console with the Google account that owns
   `briefai.salvesca.com`.
2. Select the **Domain property** `salvesca.com` or `briefai.salvesca.com`.
3. Open **Settings → Users and permissions**.
4. Add the reporting Google account with **Full** or **Restricted** access.
   Restricted access is enough for viewing performance; Full access is only
   needed for property configuration.
5. Keep the existing domain verification record in DNS.

This route is preferable to sharing a password, a verification token, or
Firebase credentials.

## Alternative route: verify the domain property

Use this only with the domain/DNS owner's approval.

1. In Search Console, create a **Domain property** for
   `salvesca.com` (without `https://`, `www`, or a path). A domain property
   covers subdomains such as `briefai.salvesca.com`.
2. Select the **TXT** verification option and copy the unique
   `google-site-verification=...` value that Google generates.
3. At the DNS provider, add that value as a TXT record at the domain root
   (usually blank host or `@`, depending on the provider).
4. Return to Search Console and select **Verify** after the DNS record has
   propagated.
5. Leave the verification TXT record in place after verification.

Do not publish the token in a page, source repository, social post, support
message, or screenshot. Do not replace or delete unrelated TXT, MX, CNAME or
DNSSEC records.

## First measurement after access

Record the last 28 days for the domain property:

| Metric | Where to read it |
| --- | --- |
| Google search clicks and impressions | Performance → Search results |
| Queries | Performance → Queries |
| Pages | Performance → Pages |
| Countries and devices | Performance → Countries / Devices |
| Indexed pages and issues | Indexing → Pages |

Compare the page-level results with first-party consented guide events and the
Firebase account / activation baseline. Search Console reports search
behaviour, not registrations or purchases.

## Official reference

- Google Search Console Help, “Verify your site ownership”:
  <https://support.google.com/webmasters/answer/9008080>
