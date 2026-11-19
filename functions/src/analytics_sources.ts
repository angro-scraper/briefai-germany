/**
 * Historic analytics used literal Firestore keys such as
 * `sources.direct.page_view`. Newer records may contain a nested `sources`
 * map. Both are individual counters and must be included in reports.
 */
export function dailyAnalyticsSources(
  data: Record<string, unknown>,
): Record<string, {pageViews: number; installClicks: number; registrations: number}> {
  const result: Record<string, {pageViews: number; installClicks: number; registrations: number}> = {};
  const add = (source: string, event: string, raw: unknown) => {
    if (!/^[a-z0-9_-]{1,32}$/.test(source)) return;
    const metric = event === "page_view" ? "pageViews"
      : event === "install_click" ? "installClicks"
        : event === "registration" ? "registrations" : null;
    if (!metric) return;
    const count = Number(raw);
    if (!Number.isFinite(count) || count <= 0) return;
    const bucket = result[source] ??= {pageViews: 0, installClicks: 0, registrations: 0};
    bucket[metric] += count;
  };
  const nested = data.sources;
  if (nested && typeof nested === "object" && !Array.isArray(nested)) {
    for (const [source, raw] of Object.entries(nested as Record<string, unknown>)) {
      if (!raw || typeof raw !== "object" || Array.isArray(raw)) continue;
      for (const [event, value] of Object.entries(raw as Record<string, unknown>)) {
        add(source, event, value);
      }
    }
  }
  for (const [field, value] of Object.entries(data)) {
    const match = /^sources\.([a-z0-9_-]{1,32})\.([a-z_]+)$/.exec(field);
    if (match) add(match[1], match[2], value);
  }
  return result;
}
