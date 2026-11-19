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

For this 30-day campaign, use the actual **20 October baseline of 14 Auth
accounts** as day 0. The 14 November count of 17 is a later checkpoint, not
a reset of the campaign clock. The target is **1,000 new registrations** in
the 30-day window (equivalent to 1,014 total Auth accounts only if none are
deleted), alongside at least **20 newly verified paid subscriptions**. A
fresh production read is needed before reporting any change; the
consent-based `Registrations` event cannot replace the Auth count.

The public German Google Play listing showed the coarse "5+ downloads" band on
14 November; this is not a count of new installs. The German App Store listing
still points its privacy-policy field at the legacy `onrender.com` host. That
legacy page now forwards browsers to the current policy on
`briefai.salvesca.com`; Apple says the store-field URL itself changes only with
the next app version. App Store Connect required a fresh login during this
check, so its metadata was not edited.

## Organic assets published after the baseline

| Date | Asset | Purpose | Tracking source |
| --- | --- | --- | --- |
| 20 October 2026 | `https://briefai.salvesca.com/jobcenter-bescheid-frist-pruefen/` | German practical guide for Jobcenter letters, deadlines and requested documents | `seo_de_jobcenter_frist` |
| 14 November 2026 | `https://briefai.salvesca.com/jobcenter-anhoerung-verstehen/` | German checklist for understanding a Jobcenter hearing letter, based on official BA and SGB X sources; no blanket deadline or promised outcome | `seo_de_jobcenter_anhoerung` |
| 21 October 2026 | `https://briefai.salvesca.com/krankenkasse-bescheid-verstehen/` | German practical guide for health- and care-insurance decisions, notices and documents | `seo_de_krankenkasse_bescheid` |
| 21 October 2026 | `https://briefai.salvesca.com/auslaenderbehoerde-schreiben-verstehen/` | German practical guide for Foreigners Authority letters, appointments, deadlines and requested documents | `seo_de_auslaenderbehoerde_schreiben` |
| 21 October 2026 | `https://briefai.salvesca.com/familienkasse-kindergeld-brief-verstehen/` | German practical guide for Familienkasse / Kindergeld letters, requested evidence and deadlines | `seo_de_familienkasse_kindergeld` |
| 21 October 2026 | `https://briefai.salvesca.com/finanzamt-steuerbescheid-verstehen/` | German practical guide for Finanzamt tax notices, deadlines and the next steps | `seo_de_finanzamt_steuerbescheid` |
| 21 October 2026 | `https://briefai.salvesca.com/rundfunkbeitrag-gez-brief-verstehen/` | German practical guide for Rundfunkbeitrag / "GEZ" letters, reference numbers, deadlines and official forms | `seo_de_rundfunkbeitrag_gez` |
| 14 November 2026 | `https://briefai.salvesca.com/arbeitslosengeld-bescheid-verstehen/` | German guide to reading an Arbeitslosengeld decision, change or repayment notice, linked to official Bundesagentur für Arbeit guidance | `seo_de_alg_bescheid` |
| 14 November 2026 | `https://briefai.salvesca.com/read-german-official-letter/` | English five-point checklist for reading German official letters, with clear AI limitations and official sources; live URL checked after deployment | `seo_en_official_letter` |

The guide includes a clear product disclaimer, official Bundesagentur für
Arbeit sources, direct store links, and FAQ structured data. It is a content
asset, not a claim of legal advice or a record of an external promotion.

## Organic distribution

| Date | Channel | Public post | Tracked destination | Outcome evidence |
| --- | --- | --- | --- | --- |
| 14 November 2026 | AMIA Technologies Bluesky | `https://bsky.app/profile/amiatechnologies.bsky.social/post/3n2cef7pma22v` | `https://briefai.salvesca.com/arbeitslosengeld-bescheid-verstehen/?utm_source=bluesky&utm_medium=organic` | Published from the AMIA account with German language metadata and a no-legal-advice disclaimer; visits, registrations and subscriptions not yet measured. |
| 14 November 2026 | AMIA Technologies Bluesky | `https://bsky.app/profile/amiatechnologies.bsky.social/post/3n2ckim5obk2w` | `https://briefai.salvesca.com/read-german-official-letter/?utm_source=bluesky&utm_medium=organic` | User-approved English checklist post published from the AMIA account, with English language metadata, attribution and no-legal-advice disclaimer. Bluesky profile displayed it publicly; conversions not yet measured. |
| 14 November 2026 | AMIA Technologies product page | `https://amia.rs/apps/briefai-germany/?lang=de` | `https://briefai.salvesca.com/de/?utm_source=amia_website&utm_medium=organic` and the guide with the same source tags | Render deployed commit `d06d1e3`; public page shows official site, guide, store links, privacy/terms links, and a clear AI/no-legal-advice warning. Conversions not yet measured. |
| 14 November 2026 | Reddit `u/AMIA_Technologies` in `r/sideprojects` | `https://www.reddit.com/r/sideprojects/comments/1xh6owe/what_are_you_building_lets_self_promote/` | Direct iOS and Android store links (no UTM tags) | The thread explicitly invited project introductions. Reddit confirmed "Komentar je uspešno objavljen" and displayed the approved text under `AMIA_Technologies`; visits, registrations and subscriptions not yet measured. |
| 15 November 2026 | AMIA Technologies Bluesky, first Jobcenter video | `https://bsky.app/profile/amiatechnologies.bsky.social/post/3n2cpww6zcs24` | `https://briefai.salvesca.com/jobcenter-bescheid-frist-pruefen/?utm_source=bluesky_video` | User-approved original 27-second fictional-example video and exact German text published from the AMIA account. Bluesky showed “Your post was sent” and the profile displayed an embedded 27-second player. Views, visits, registrations and subscriptions not yet measured. |
| 15 November 2026 | BriefAI German site, Jobcenter Mitwirkung guide | `https://briefai.salvesca.com/jobcenter-aufforderung-zur-mitwirkung/` | Direct App Store and Play links with the site's consent-based install-click analytics | After explicit approval of the exact page, commit `34e74c9` was pushed to `main`. The public guide returned HTTP 200; the German homepage linked to it and the public sitemap included it. Search Console's live URL test said it was available for indexing, and the request-indexing confirmation said it had been added to the priority crawl queue. This is not proof of indexing, search clicks, installs or registrations. |

## Follow-up — 14 November 2026, about 22:35 Berlin time

- The approved Reddit comment is publicly visible at
  `https://www.reddit.com/r/sideprojects/comments/1xh6owe/comment/19sn4mk78tt2c/`.
  The account's comment view showed **1 view** and the focused thread showed no
  reply to it yet. One view is not an app visit or a conversion.
- Firebase Authentication still showed **17 total accounts** (`1–17 of 17`),
  unchanged from the checkpoint above. This does not establish that any account
  came from Reddit or Bluesky.
- Search Console's Performance and Page Indexing reports both still said data
  was processing. No clicks, impressions or indexed-page count can be reported
  from those reports yet.

## Distribution checkpoint — 14 November 2026, about 22:45 Berlin time

- All **19 public URLs** in the live sitemap returned HTTP 200. The German
  landing page already exposes the first-five-analyses offer, web-app and store
  CTAs, a privacy explanation and a legal-information disclaimer. There is no
  evidence yet that changing that CTA would improve registrations.
- Firestore `productAnalyticsDaily/2026-11-14` recorded **1 page view, 1 store
  install click and 1 unique visitor**, all under `sources.direct`. These are
  consent-dependent aggregate events, not verified external visitors, installs
  or registrations; internal testing may account for them.
- The public Bluesky API reported **0 likes, 0 reposts, 0 replies and 0 quotes**
  on the 14 November AMIA post. It does not report visits or registrations.
- Decision: do not repeat the same promotion in generic maker channels or
  attribute sign-ups to them without evidence. Focus the next distribution
  effort on a relevant migrant-facing directory/partner and a German-reviewed
  short video, each with a distinct source label and the user's exact approval
  before any external submission.

## Search Console follow-up — 14 November 2026, about 22:49 Berlin time

- URL inspection for the existing Jobcenter guide reported **"URL is not on
  Google"** because it was unknown to Google; no crawl date or referring
  sitemap was shown for this URL yet. The live URL test reported that the page
  is available to Google and can be indexed.
- Submitted a single **Request indexing** for
  `https://briefai.salvesca.com/jobcenter-bescheid-frist-pruefen/`.
  Search Console confirmed that the URL was added to the priority crawling
  queue. This is **not** proof that it has been crawled, indexed, ranked or
  visited. Do not resubmit it merely to change its queue priority.

## Directory outreach — 14 November 2026, 23:04 Berlin time

- Sent the user's approved free-listing eligibility enquiry from
  `info@amia.rs` to `contact@migratespace.com`, subject
  `Free directory listing enquiry — BriefAI Germany`. Roundcube's **Sent**
  folder shows the message to that recipient at 23:04. This proves submission
  through our mailbox, not delivery, acceptance, a listing or conversions.
- The enquiry asks whether MigrateSpace accepts a non-EU company's mobile
  information tool serving Germany and whether the listing can be arranged by
  email instead of its Google form. Do not submit a duplicate while awaiting a
  response.

## English-guide indexing — 14 November 2026, 23:22 Berlin time

- Google Search Console URL inspection reported that
  `https://briefai.salvesca.com/read-german-official-letter/` is **not yet on
  Google** because the URL is unknown to it. The live URL test reported that
  the page is available to Google and can be indexed.
- Submitted one **Request indexing** for that URL. Search Console confirmed
  that it was added to its priority crawling queue. This is not proof of an
  actual crawl, indexing, search impressions, visits or registrations. Do not
  repeat the request merely to change its queue position.

## ExpatListing screening — 14 November 2026

- Its current Germany directory states 228 listings, but does not provide
  verified audience or conversion figures. Its terms say a basic business
  listing is currently free and must be accurate, relevant to a covered
  country, and submitted by an authorised representative.
- The submission path requires a new account, plus business category,
  address, website, phone, contact email and description. No BriefAI listing
  or account was created. Before doing so, verify that a Serbia-based remote
  information app is acceptable for the Germany directory and confirm the
  public contact/address details to display. Do not invent a German address.

## Partner outreach and account check — 14 November 2026, about 23:30 Berlin time

- Firebase Authentication still showed **17 total accounts** (`1–17 of 17`),
  with no new account since the previous checkpoint. No registrations can be
  attributed to today's organic posts.
- Sent the user's exact approved free-editorial enquiry from `info@amia.rs` to
  `contact@ananthya.com`, subject
  `Free educational resource enquiry — BriefAI Germany`. Roundcube's **Sent**
  folder displayed the message to that recipient at 23:30. This is not proof
  of delivery, editorial acceptance, a listing or a conversion. Do not send
  a duplicate while awaiting a response.
- IamExpat sent a follow-up asking whether the earlier material had been
  reviewed. It did not add a free option to the previous advertorial offer of
  €590 excluding VAT, so no paid campaign was accepted under this organic-only
  plan.

## BBA Community editorial enquiry — 14 November 2026, 23:51 Berlin time

- BBA Community publicly welcomes unpaid guest articles for international
  women living in Germany, ideally 1,000–1,500 words. Its community includes
  discussions of bureaucracy and daily life in Germany. This is a relevant
  audience, but its article form asks for personal author details and an
  editable Google Drive folder; a company-authored article with an app link
  has not been confirmed as acceptable.
- After the user's approval of the exact text and final send action, sent one
  eligibility enquiry from `info@amia.rs` to `team@bbacommunity.com`, subject
  `Free educational guide for international women in Germany — BriefAI`.
  Roundcube's **Sent** folder listed the message at 23:51. The enquiry offers
  an original, sourced guide and transparent AMIA authorship, and asks about
  editorial/byline/link policy before preparing or submitting it.
- Do not submit a guest article or send a duplicate enquiry while awaiting
  their response. The Sent entry proves mailbox submission only, not delivery,
  acceptance, publication, visits, registrations or subscriptions.

## Attribution audit — 14 November 2026, about 23:56 Berlin time

- The public guides' `guide-analytics.js` sends consented, pseudonymous
  `page_view` and `install_click` events with a short source label. Guide links
  to `/app/` preserve that label as `utm_source`; the web app reads it for
  consented events. A store-link click is **not** an installation or a new user.
- The app currently calls `trackRegistration()` only after a newly created
  email/password Firebase identity. Google and Apple sign-in paths do not call
  it. Consequently, `productAnalyticsDaily.registrations` undercounts new
  accounts and cannot be used as the sole measure of the 1,000-user goal.
- Firebase Authentication user count is the account baseline; verified paid
  subscription records/store financial reports are the subscription baseline.
  No new account or subscription count was read in this audit. Keep the last
  verified figures (17 total accounts, zero subscription documents) labelled
  as **last verified**, not current. Do not infer a conversion from visits,
  clicks, article submissions or email outreach.
- Fix provider-specific registration attribution only after an end-to-end
  auth test on Android and iOS and a consent/privacy review. Native Apple uses
  a custom-token bridge, so its "new user" status is not equivalent to a
  normal web `UserCredential` and must not be guessed from recent timestamps.

## Deutschland Decoded editorial candidate — 14 November 2026

- Its current `Write for Us` page explicitly welcomes collaboration ideas
  from like-minded brands and asks for a short introduction, concept and
  audience benefit at `deutschlanddecoded@gmail.com`:
  https://deutschlanddecoded.com/write-for-us/
- Its blog published guest posts by the founders of Job Badger (13 November)
  and Airpiv (9 November). Both use a disclosed founder byline and a linked
  author bio, so a transparent AMIA Technologies piece is plausible, though
  editorial acceptance, free placement, link rules and readership are **not**
  confirmed:
  https://deutschlanddecoded.com/2026/11/13/job-in-germany-without-german/
  https://deutschlanddecoded.com/2026/11/09/berlins-12-districts-arent-12-neighbourhoods-how-to-choose-a-kiez-before-you-move/
- Proposed original English topic: **"A German official letter arrived: five
  checks before you reply"** — sender and authenticity, file reference,
  requested action, every date/deadline, and when to seek qualified help.
  Cite the relevant public authority for any concrete deadline. Mention
  BriefAI only in a clearly identified AMIA author note if permitted; disclose
  paid options and say it is information, not legal advice. Do not invent a
  personal migration experience.
- No email, submission or article was sent or published. Seek fresh approval
  of the exact pitch and destination before outreach. Track any resulting
  link with a distinct short source label; do not treat a publication as a
  registration or subscription without verified data.

## Directory screening — 15 November 2026

- Expat.com explicitly offers a **basic free** business-directory listing:
  https://www.expat.com/en/faq.html (Business Directory FAQ). Its Germany
  directory is active: https://www.expat.com/en/business/europe/germany/.
  The FAQ also says listings may be rejected for an invalid physical address
  or poor fit. The `/en/business/add` entry redirected to the directory when
  viewed without a logged-in account, so the form, Germany eligibility for a
  Serbia-registered company, categories, and whether a mobile app can be
  listed are **not verified**. Do not invent a German address or submit a
  misleading category. If eligible, use a transparent AMIA/BriefAI listing
  that says it is a freemium information tool, not legal advice, and that
  requested AI analysis sends extracted text to the AI provider.
- FindEnglish.de calls itself a free directory in its footer, but its actual
  provider page says to choose a plan and pay through Stripe, with a flat
  annual fee. Exclude it from this no-paid-advertising campaign:
  https://www.findenglish.de/get-listed.
- InterNations content guidelines exclude articles written to advertise a
  specific product or service; do not pitch BriefAI as a guest article there:
  https://assets.in-cdn.net/guidelines/content.

## Reddit distribution correction — 15 November 2026

- The public Reddit API now returns `body: "[removed]"` and `author:
  "[deleted]"` for the previously approved r/sideprojects comment
  `19sn4mk78tt2c`:
  https://www.reddit.com/api/info.json?id=t1_19sn4mk78tt2c
- This supersedes the 14 November observation that the comment was visible.
  The public record does not establish why it was removed or whether it ever
  produced a visit. Do not re-post the same text, use another account to evade
  moderation, or count this as active distribution. Prioritise channels whose
  editorial policy explicitly accepts disclosed company-authored resources.

## Deutschland Decoded editorial pitch — 15 November 2026

- Its current `Write for Us` page still invites collaboration ideas from
  like-minded brands and asks for a short introduction, concept and audience
  value at `deutschlanddecoded@gmail.com`:
  https://deutschlanddecoded.com/write-for-us/
- A specific, unpaid editorial pitch was prepared and approved by the user.
  Article acceptance, link policy, audience size and no-cost placement remain
  unverified. Its reported delivery status is recorded below.

**To:** `deutschlanddecoded@gmail.com`

**Subject:** Guest guide idea: five checks before replying to a German official letter

> Hello Deutschland Decoded team,
>
> We are AMIA Technologies, the team behind BriefAI Germany. Your guide for
> people navigating life in Germany seems a good fit for a practical article:
> “A German official letter arrived: five checks before you reply.” It would
> help readers identify the sender and file reference, the action requested,
> every date or deadline, and when to seek qualified advice. We would cite
> relevant official sources and avoid giving case-specific legal advice.
>
> We can provide an original, non-promotional draft. We would disclose our
> connection to BriefAI in the byline and mention the app only in a short
> author note if your editorial rules permit it. BriefAI is an information
> tool with free and paid options, not legal advice.
>
> Would this topic fit your editorial calendar? If so, please let us know
> your length, attribution and link rules, and whether unpaid guest
> contributions from companies are accepted.
>
> Best regards,
>
> AMIA Technologies
>
> info@amia.rs

**Delivery status update, 15 November 2026:** The user reported sending this
pitch personally from the prepared Roundcube composer. Browser control was
stopped before the Sent folder could be checked, so mailbox submission is not
independently verified. Do not send a duplicate. Await a reply or verify the
existing Sent entry when access is available; do not count this as a published
article, visit, registration or subscription.

**Editorial preparation, 15 November 2026:** A 900-word, original English
guest-article draft is saved as `docs/EDITORIAL_OFFICIAL_LETTER_GUEST_DRAFT.md`.
It is based on current Federal Employment Agency and Bundesportal guidance,
uses a disclosed AMIA byline, and confines any BriefAI link to an optional
author note. This is an internal draft, **not** an accepted or published
placement. Wait for the editor's reply about cost, fit, length and links before
tailoring or submitting it; obtain approval for the final text and destination.

## Next-channel screening — 15 November 2026

- The newly published AMIA Bluesky Jobcenter video was present in the public
  `app.bsky.feed.getPosts` record with its intended link and video embed. At
  this early check it had 0 likes, reposts, replies and quotes. Those zeros
  measure only visible social engagement, not impressions, clicks or installs.
  Do not repeat a near-identical post merely because early engagement is zero.
- My Life in Germany accepts how-to guides about living in Germany but its
  guest policy asks for authentic personal stories, says no ads or sales
  pitches, and requires an outline before any full article. A company-authored
  BriefAI promotion is not a clean fit; do not pitch it as a personal story:
  https://www.mylifeingermany.com/guest-posting-guidelines/
- GermanPedia explicitly invites expat contributions and has a cooperation
  contact for services relevant to newcomers. Its editorial standards insist
  on independence, official sources and clear labelling of sponsorship. A
  *question* about a no-cost, disclosed company-authored educational article
  could be appropriate, but free placement, author-note link rules and reach
  are not verified. Do not submit through the contributor form or email a
  pitch without approval of exact content and destination:
  https://germanpedia.com/write-for-us/
  https://germanpedia.com/editorial-values/
  https://germanpedia.com/contact/
- FindEnglish remains excluded: its actual provider page requires an annual
  fee despite a footer describing the directory as free.

## Production measurement checkpoint — 15 November 2026, 01:16 Berlin time

- Production Firebase Authentication `briefai-germany` still showed `1–17 of
  17` users. Its newest listed account was created 26 October 2026. Thus no
  new Firebase Auth accounts are visible since the 14 November checkpoint;
  this does not establish whether anyone visited the landing pages or store.
- The verified Search Console URL-prefix property still reported that Search
  Performance and Page Indexing data were processing. Neither impressions
  nor clicks nor indexed-page counts can yet be claimed. The `/sitemap.xml`
  submission was marked `Successful`, last read 14 November 2026, with 19
  discovered pages. The public sitemap has since changed; this report is not
  proof that the newer pages have been processed.
- Next qualified outreach candidate: GermanPedia's
  `cooperation@germanpedia.com`, which explicitly invites partnership queries
  from services relevant to newcomers. Ask only whether an unpaid,
  source-based, disclosed AMIA educational contribution is eligible and what
  their author-note link rules are. Do not imply editorial approval or send a
  guest post. No email has been sent. Source:
  https://germanpedia.com/contact/

## Website funnel checkpoint — 15 November 2026, 01:27 Berlin time

- Production Firestore `productAnalyticsDaily/2026-11-14` recorded 1 page
  view, 1 unique visitor and 1 `install_click`, all attributed to `direct`.
  This click does **not** establish an app install or registration; the visit
  may have been an internal test.
- `productAnalyticsDaily/2026-11-15` recorded 1 page view and 1 unique
  visitor, attributed to `seo_de_landing`; no install-click field was present
  at this check. This source label describes page attribution, not verified
  Google Search traffic.
- These website events require analytics consent and therefore are not a
  complete measure of traffic. The present evidence is insufficient to
  estimate a page-to-registration conversion rate. Distribution to a relevant
  external audience remains the priority; the GermanPedia question is still
  awaiting exact user approval and must not be sent meanwhile.

## Channel response and screening — 15 November 2026, 01:30 Berlin time

- Search Console still displayed “data is processing” for both Search
  Performance and Page Indexing. No search reach or indexing count is
  available to evaluate yet.
- The public `r/sideprojects` introduction remains visible on
  `u/AMIA_Technologies`. Reddit's account view displayed **1 view** for the
  comment; its discussion displayed no reply to that comment at this check.
  This maker audience is not evidence of reach among people handling German
  administrative letters. Do not repeat the promotion in the same thread.
- The AMIA Roundcube webmail session had expired, so partner replies could
  not be checked. Do not infer no reply or send a follow-up from that state.
- Screened additional no-cost editorial candidates before outreach. PUGAT
  accepts sourced migration guides, but its editorial principles explicitly
  exclude advertising and promotional content; a BriefAI acquisition piece
  would conflict with that rule. Germany Update invites guest articles but
  currently presents broad commercial/link-oriented topics, not a verified
  newcomer audience. Newsakt routes company/partner content to sponsored
  placements, outside the no-paid-ads goal. Deutschland4U's site describes a
  relevant English-language newcomer audience but its contact URL returned
  404 and reach is unverified. None is a stronger immediate outreach target
  than the pending GermanPedia permission query.
  Sources: https://pugat.de/en/submit/ ;
  https://pugat.de/en/editorial-principles/ ;
  https://germanyupdate.de/schreiben-sie-fur-uns/ ;
  https://newsakt.de/gastbeitrag ; https://www.deutschland4u.com/ .

## Production checkpoint — 15 November 2026, about 01:33 Berlin time

- Firebase Authentication still displayed `1 – 17 of 17` accounts. Relative
  to the 14 November campaign baseline, verified new accounts are **0**.
- Firestore `subscriptions` still displayed “This collection has no
  documents.” This verifies zero recorded entitlements, not zero possible
  store transactions if a purchase-to-entitlement link failed.
- `adminMetrics/current` still displayed 62 lifetime analyses and four
  questionnaire analyses; its update timestamp remained 14 November 2026 at
  10:27:37 Berlin time. These are not first-analysis or unique-user metrics.
- The AMIA Roundcube tab in the existing Edge profile also redirected to
  `?_task=login&_err=session`; no partner reply check was possible without
  user sign-in. Do not infer that there were no replies.
- Recent public Reddit search results centred on individual Jobcenter or
  residence-status problems, often financially or legally sensitive. No
  fresh thread was sufficiently appropriate for a product mention; no
  comment or message was posted.

## Google indexing checkpoint — 15 November 2026, about 01:38 Berlin time

- Search Console URL Inspection for `https://briefai.salvesca.com/` reported
  **not on Google**, “Crawled – currently not indexed”; last crawl was
  14 November 2026 at 22:12:53 Berlin time. The live test said the URL is
  available and can be indexed. A fresh request for priority crawling was
  accepted. This does not promise indexing or search traffic.
- URL Inspection for `https://briefai.salvesca.com/de/` reported **not on
  Google**, “URL is unknown to Google”, with no recorded crawl. The live test
  said it can be indexed, and its priority-crawl request was accepted.
- The live site returns HTTP 200 for both homepages. Each page has a
  self-referencing canonical; the German page has German title and description.
  `robots.txt` allows crawling and references `/sitemap.xml`. The current
  public sitemap returns HTTP 200 and includes both homepages plus the new
  guide. Search Console still shows the sitemap as successful, last read
  14 November, with 19 discovered pages; the current sitemap has 22 URL
  entries. The URL-inspection “no referring sitemap” and temporary processing
  messages may reflect incomplete processing, not necessarily a malformed
  current sitemap. Do not change sitemap or claim an indexability fix without
  stronger evidence.
- Because even the German homepage has not yet been crawled, organic search
  cannot be counted as a near-term acquisition source. Qualified partner or
  community distribution is more urgent while Google processes the site.
