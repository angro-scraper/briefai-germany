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
| Google Search performance | Not measured | No Search Console property is configured for the domain in either currently signed-in Google account |

## Interpretation

- An install does not necessarily create an account: the app can be explored
  anonymously until an account-backed feature is needed.
- Apple Sign In may show a private relay address. This is an expected privacy
  feature and still counts as a registered Firebase user.
- Use store-console numbers only for acquisition; use the Firebase counts
  above for registration and entitlement conversion.
- Add and verify `briefai.salvesca.com` in Google Search Console before using
  search impressions or clicks as a campaign KPI. Site verification should be
  performed through the domain owner, not by placing an unverified tracking
  tag on the public site.

## Organic assets published after the baseline

| Date | Asset | Purpose | Tracking source |
| --- | --- | --- | --- |
| 20 October 2026 | `https://briefai.salvesca.com/jobcenter-bescheid-frist-pruefen/` | German practical guide for Jobcenter letters, deadlines and requested documents | `seo_de_jobcenter_frist` |

The guide includes a clear product disclaimer, official Bundesagentur für
Arbeit sources, direct store links, and FAQ structured data. It is a content
asset, not a claim of legal advice or a record of an external promotion.
