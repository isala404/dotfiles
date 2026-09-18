# Cairn dashboards

A good dashboard answers a handful of questions and nothing else. Copy the matching sample first, then delete before you add.

## Structure

One row per question, in this order. Four rows is the maximum for a product dashboard.

Traffic: Visitors (distinct `anon_id`), Visits (distinct `session_id`), Views (`page.viewed` count), Bounce rate, Visit duration. Five stats, each with a percent change against the previous window of equal length.

Performance: LCP, INP, CLS, FCP, and TTFB as p75 stats with good, needs-improvement, and poor threshold colors, one p75-over-time timeseries, and one slowest-pages table (`HAVING count(*) >= 5`, top 12).

Pages and sources: two tables side by side. Pages has `path`, Views, Visitors, Share. Sources has Referrer, Channel (Direct, Search, Social, Referral), Visitors, Share.

Audience: Browsers, OS, Devices, and Country tables with Visitors and Share and a thin gauge on the count column. Ten rows max each.

Behind those, and only if the app has a backend and money: an error groups table, a trace waterfall link, a funnel, and payments (MRR-ish sums from `events_safe`, never the raw payload).

Start from `static-web-nginx.json` for web and `ios-backend.json` for app plus API. Both already carry `$project` (and `$service`) variables, UTC timezone, and this row order. Never start from `cairn.json` or `kubernetes.json`, those monitor the stack, not the product.

## SQL that stays fast

Always scope `(project_id = (SELECT id FROM cairn.projects WHERE slug = ${project:sqlstring}))` first. Add `environment` only together with project, never on its own in second position. A lone environment predicate demotes the index and costs 2-6x the buffers.

Use `$__timeFilter(col)` on raw tables and `$__timeGroup(col, $__interval)` for bars. Cap bars around 32 via `maxDataPoints` with a 5m floor. Tables take `LIMIT 10..12`, logs `LIMIT 100` with a note in the description to use Explore for pagination.

Headline numbers are `lastNotNull`, never an average of averages. Latency and vitals use `percentile_cont(0.75)`, and the label says p75 so nobody reads it as a mean.

Deltas compare equal windows: `UNION ALL` the current window against the previous window of identical length, then let Grafana compute percent change. Bounce rate is inverted (`percentChangeColorMode: inverted`), everything else is standard.

Use the `web.events_by_name_5m` rollup for Views and raw `web.events` for distincts. Counter metrics reduce per series with reset and gap handling before summing. Don't `sum(value)` raw counters.

Every panel gets a one-line description that says what it counts and what it excludes ("Distinct anonymous devices that viewed a page", "Sessions rotate after 30 min inactivity"). If you can't write that sentence, delete the panel.

## Visualization

Stats: no graphs inside (`graphMode: none`), no background colors (`colorMode: none`, `fixedColor: text`). Thresholds only where a human has to act, so vitals green, amber, red and queue pressure at 80%. Everything else stays text-colored.

Timeseries: one unit per panel, smooth thin lines (`lineWidth 2`, `fillOpacity 8`), bottom legend, multi-tooltip sorted descending. Barcharts only for Views against Visitors, with a muted fixed palette (`#3d7dd8` views, `#4bbfa6` visitors), `barWidth 0.8`, no stacking.

Tables: `cellHeight md/sm`, visible header, right-aligned numbers, Share as `percent` with 1 decimal, gauge only on the primary count column. Channel, browser, and OS cells may carry a small emoji prefix because it scans faster than a legend. Never more than one icon per row.

Rows are collapsible section headers (Traffic, Performance, Pages and sources, Audience). No two panels share a title. No panel without a time filter. Refresh `60s`, `graphTooltip: 1` for the shared crosshair.

Funnel and journey panels take the full row width and answer one conversion question each. Record inspector, timeline, and waterfall belong on a separate Investigate dashboard driven by `$trace_id` or `$record_id`, not under the overview.

## What to leave out

No pie charts, no world maps, no per-second sparklines in stat panels, no lifetime `occurrence_count` in a windowed panel (count `errors.events` in the window instead), no raw `payload` columns, no environment-only filters, no more than six headline stats. When in doubt ship four stats and one table, and add the second chart only after someone asks for it twice.
