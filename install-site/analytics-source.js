// Classify a visit without sending the referrer URL, query, or page content.
// A missing referrer is unknown, not proof that someone typed the URL.
function campaignSource(search) {
  const campaign = new URLSearchParams(search).get('utm_source')?.trim().toLowerCase();
  return campaign && /^[a-z0-9_-]{1,32}$/.test(campaign) ? campaign : null;
}

export function resolveLandingSource(search, referrer, siteOrigin) {
  const campaign = campaignSource(search);
  if (campaign) return campaign;

  if (!referrer) return 'unknown';
  try {
    const referringHost = new URL(referrer).hostname.toLowerCase().replace(/^www\./, '');
    const siteHost = new URL(siteOrigin).hostname.toLowerCase().replace(/^www\./, '');
    if (referringHost === siteHost) return 'internal';
    if (/^google\.(?:com|de|at|ch|co\.uk|fr|nl|pl|ro|com\.tr|com\.ua)$/.test(referringHost)) return 'ref_google';
    if (referringHost === 'bing.com') return 'ref_bing';
    if (referringHost === 'duckduckgo.com') return 'ref_duckduckgo';
    if (referringHost === 'ecosia.org') return 'ref_ecosia';
    if (referringHost === 'search.yahoo.com' || referringHost === 'yahoo.com') return 'ref_yahoo';
    if (referringHost === 'search.brave.com') return 'ref_brave';
    if (referringHost === 'deutschlanddecoded.com') return 'ref_deutschlanddecoded';
    if (referringHost === 'adriaveza.de') return 'ref_adriaveza';
    return 'ref_external';
  } catch {
    return 'unknown';
  }
}

// One short, stable page code plus one observed referral category fits the
// server's 32-character source limit. The old seo_* labels were page names,
// not evidence of a search-engine visit; several exceeded that limit and
// silently became "direct" in the dashboard.
const guideCodes = Object.freeze({
  seo_de_behoerdenbrief: 'g_de_letter',
  seo_tr_resmi_mektup: 'g_tr_letter',
  seo_de_alg_bescheid: 'g_de_alg',
  seo_de_familienkasse_kindergeld: 'g_de_kind',
  seo_de_auslaenderbehoerde_schreiben: 'g_de_abh',
  seo_de_finanzamt_steuerbescheid: 'g_de_tax',
  seo_de_jobcenter_mitwirkung: 'g_de_mitw',
  seo_de_jobcenter_anhoerung: 'g_de_hear',
  seo_de_jobcenter_termin: 'g_de_jcterm',
  seo_de_krankenkasse_bescheid: 'g_de_health',
  seo_de_jobcenter_veraenderungsmitteilung: 'g_de_change',
  seo_de_jobcenter_frist: 'g_de_jcfrist',
  seo_bg_sluzhebno_pismo: 'g_bg_letter',
  seo_en_official_letter: 'g_en_letter',
  seo_en_jobcenter_documents: 'g_en_jcdocs',
  seo_ru_nemetskoe_pismo: 'g_ru_letter',
  seo_de_rundfunkbeitrag_gez: 'g_de_gez',
  seo_ro_scrisoare: 'g_ro_letter',
  seo_uk_nimetske_pysmo: 'g_uk_letter',
});

export function resolveGuideSource(guideLabel, search, referrer, siteOrigin) {
  const campaign = campaignSource(search);
  if (campaign) return campaign;
  const guide = Object.hasOwn(guideCodes, guideLabel) ? guideCodes[guideLabel] : 'g_other';
  const referral = resolveLandingSource('', referrer, siteOrigin);
  // The long publisher label would make several combined guide sources exceed
  // the backend's 32-character limit and silently turn into "direct".
  const guideReferral = referral === 'ref_deutschlanddecoded' ? 'ref_dd' : referral;
  return `${guide}_${guideReferral}`;
}
