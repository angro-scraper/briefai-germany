import assert from "node:assert/strict";
import test from "node:test";
import {dailyAnalyticsSources} from "../lib/analytics_sources.js";

test("combines historic dotted keys and nested source counters", () => {
  assert.deepEqual(dailyAnalyticsSources({
    pageViews: 3,
    "sources.direct.page_view": 2,
    "sources.direct.install_click": 1,
    sources: {direct: {page_view: 1}, seo_de_landing: {page_view: 1}},
  }), {
    direct: {pageViews: 3, installClicks: 1, registrations: 0},
    seo_de_landing: {pageViews: 1, installClicks: 0, registrations: 0},
  });
});

test("rejects invalid event keys and nonpositive counters", () => {
  assert.deepEqual(dailyAnalyticsSources({
    "sources.direct.purchase": 2,
    "sources.direct.page_view": -1,
    "sources.bad.name.page_view": 5,
    sources: {direct: {registration: "not a number"}},
  }), {});
});
