# BriefAI Germany — organic growth baseline

**Captured:** 20 October 2026 (Europe/Berlin)

This is a read-only baseline taken from the production Firebase project. It is
used to measure the 30-day organic outreach plan, not to identify individual
customers.

| Metric | Baseline | Evidence |
| --- | ---: | --- |
| Registered Firebase Authentication users | 14 | Authentication user list |
| Cloud user profiles | 14 | Firestore `users` collection |
| Completed analyses | 40 | Firestore `adminMetrics/current` (last updated 16 October 2026) |
| Active or trial subscriptions | 0 | Firestore `subscriptions` collection contains no documents |
| Google Search performance | Not measured | `https://briefai.salvesca.com/` URL-prefix property verified on 14 November 2026 under `ivicatrajkov702@gmail.com`; Search Console says performance data is still processing |

## Interpretation

- An install does not necessarily create an account: the app can be explored
  anonymously until an account-backed feature is needed.
- Apple Sign In may show a private relay address. This is an expected privacy
  feature and still counts as a registered Firebase user.
- Use store-console numbers only for acquisition; use the Firebase counts
  above for registration and entitlement conversion.
- The Search Console URL-prefix property is verified with the exact HTML file
  Google issued (`install-site/googlec259e446428cd451.html`). Keep the file in
  place to retain verification. The submitted sitemap was processed with 19
  discovered pages. The new Arbeitslosengeld guide passed live URL inspection
  and was queued for priority crawling; neither step proves it is indexed yet.

## Production checkpoint — 14 November 2026, about 22:15 Berlin time

| Metric | Current | Change from baseline | Source and caveat |
| --- | ---: | ---: | --- |
| Firebase Authentication accounts | 17 | +3 | Production Authentication showed 1–17 of 17. One new account is the owner's, so at most two new accounts are potential external users; the other two have not been qualified as customers. |
| Active or trialing subscriptions | 0 | 0 | Production Firestore has no `subscriptions` collection. The deployed `adminOverview` definition counts active/trialing documents in that collection. This does not measure app-store purchases that failed to create a server entitlement. |
| Completed analyses | 62 | +22 | Production `adminMetrics/current`, updated 14 November 2026 at 10:27 Berlin time. Analyses are not unique users. |
| Google Search impressions/clicks | Not available yet | — | Search Console property was newly verified and still says performance data is processing. |

The original goal remains 1,000 new registered users and at least 20
subscriptions within 30 days. This checkpoint is not evidence that the goal is
met. The small increase in accounts despite more analyses makes distribution
and conversion measurement the immediate priorities.

## Organic assets published after the baseline

| Date | Asset | Purpose | Tracking source |
| --- | --- | --- | --- |
| 20 October 2026 | `https://briefai.salvesca.com/jobcenter-bescheid-frist-pruefen/` | German practical guide for Jobcenter letters, deadlines and requested documents | `seo_de_jobcenter_frist` |
| 21 October 2026 | `https://briefai.salvesca.com/krankenkasse-bescheid-verstehen/` | German practical guide for health- and care-insurance decisions, notices and documents | `seo_de_krankenkasse_bescheid` |
| 21 October 2026 | `https://briefai.salvesca.com/auslaenderbehoerde-schreiben-verstehen/` | German practical guide for Foreigners Authority letters, appointments, deadlines and requested documents | `seo_de_auslaenderbehoerde_schreiben` |
| 21 October 2026 | `https://briefai.salvesca.com/familienkasse-kindergeld-brief-verstehen/` | German practical guide for Familienkasse / Kindergeld letters, requested evidence and deadlines | `seo_de_familienkasse_kindergeld` |
| 21 October 2026 | `https://briefai.salvesca.com/finanzamt-steuerbescheid-verstehen/` | German practical guide for Finanzamt tax notices, deadlines and the next steps | `seo_de_finanzamt_steuerbescheid` |
| 21 October 2026 | `https://briefai.salvesca.com/rundfunkbeitrag-gez-brief-verstehen/` | German practical guide for Rundfunkbeitrag / "GEZ" letters, reference numbers, deadlines and official forms | `seo_de_rundfunkbeitrag_gez` |
| 14 November 2026 | `https://briefai.salvesca.com/arbeitslosengeld-bescheid-verstehen/` | German guide to reading an Arbeitslosengeld decision, change or repayment notice, linked to official Bundesagentur für Arbeit guidance | `seo_de_alg_bescheid` |

The guide includes a clear product disclaimer, official Bundesagentur für
Arbeit sources, direct store links, and FAQ structured data. It is a content
asset, not a claim of legal advice or a record of an external promotion.

## Organic distribution

| Date | Channel | Public post | Tracked destination | Outcome evidence |
| --- | --- | --- | --- | --- |
| 14 November 2026 | AMIA Technologies Bluesky | `https://bsky.app/profile/amiatechnologies.bsky.social/post/3n2cef7pma22v` | `https://briefai.salvesca.com/arbeitslosengeld-bescheid-verstehen/?utm_source=bluesky&utm_medium=organic` | Published from the AMIA account with German language metadata and a no-legal-advice disclaimer; visits, registrations and subscriptions not yet measured. |
| 14 November 2026 | AMIA Technologies product page | `https://amia.rs/apps/briefai-germany/?lang=de` | `https://briefai.salvesca.com/de/?utm_source=amia_website&utm_medium=organic` and the guide with the same source tags | Render deployed commit `d06d1e3`; public page shows official site, guide, store links, privacy/terms links, and a clear AI/no-legal-advice warning. Conversions not yet measured. |
