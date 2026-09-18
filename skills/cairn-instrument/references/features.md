# Cairn feature catalog

Everything Cairn stores and serves. Check here before adding a signal or a panel. The answer is usually to query what is already there.

## Signals and where they land

Browser events go to `web.events` (`event_name`, `path`, `app_version`, `browser`, `os`, `device_type`, `country`, `referrer_host`, `props`, `attributes`). Retry key `(project, event_id, time)`. 90-day retention, 6h chunks.

Core Web Vitals go to `web.vitals` (`LCP`, `INP`, `CLS`, `TTFB`, `FCP`, with `value` and a `rating` of good, needs-improvement, or poor). Same retry key and retention as events.

Browser and Sentry errors go to `errors.events` and `errors.groups`. Groups use a deterministic fingerprint, keep a lifetime `occurrence_count` while event rows expire at 90 days, and track `latest_release` by event time. Retry key `(project, event_id, time)`. Daily chunks.

Logs (Collector filelog and OTLP) go to `obs.logs` with kube columns plus `service`, `severity`, `message`, `trace_id`, `span_id`. Append-only and explicitly at-least-once. 7-day retention, 3h chunks.

Metrics (OTLP) go to `obs.metric_series` plus `obs.metric_samples` (gauge or sum, one of `value_double` or `value_int`, `time_nanos` identity) and `obs.metric_histograms` (bounds, counts, sum, min, max, corruption-checked). Samples keep 15 days, histograms 90 days, 3h and 6h chunks.

Adapter measurements go to `obs.measurements` (`domain`, `name`, `value`, `unit`, `subject_id`, `tags`). Retry key `(project, source, time, measurement_id)`. 90 days, daily chunks.

Spans (OTLP) go to `obs.spans` with typed hierarchy columns, bounded events and links arrays with truncation flags, and `dropped_*_count`. Retry key `(project, trace, span, nanos)`. 14 days, 3h chunks.

Payments (Stripe) go to `payments.events`. Every authentic event, verified payload, kept forever, regular table. Grafana reads `payments.events_safe` only.

Identity lives in `web.users` and `web.user_identities`. These never expire. Deletion is a written privacy decision.

## Guarantees

Commit before ack on every route. At-least-once everywhere, except that logs are rows, so identical lines are separate rows. Consent denied stores nothing. The event window rejects anything older than 7 days or newer than +1h, with a reason. Adapter backfill keeps historical times verbatim. A metric request commits samples and histograms in one transaction. Series and profile writes never block on a missing dimension row.

## Rendering contracts (`cairn_ui`, stable and unversioned)

`record(record_id, project)` returns one record by prefixed id. It is SECURITY DEFINER so panels can show approved error and payment fields that Grafana cannot select directly. Panels dispatch on `(kind, version)`.

`timeline(project, from, to, max_rows, environment, service, release)` returns errors, web events, logs, and payments in one ordered stream. A NULL filter preserves all values.

`trace(project, trace_id)` returns typed span rows for the waterfall. A malformed trace id matches nothing.

`funnel(...)` computes step conversion over `web.events`. `user_timeline(...)` plus the internal `device_owner` give the per-user view with shared-device episodes handled correctly. `user_profile(...)` returns the rich context.

Safe operational summaries: `obs.series_cardinality`, `obs.budget`, `obs.cardinality_by_project`, the `web.events_by_name_5m` rollup, and `cairn.source_catalog` (which never exposes `key_hash`).

## Grafana panels

The private panel pack is the only custom viz: record inspector (renders `record` by kind), timeline, trace waterfall (hierarchy from columns plus dropped-count detail), funnel, and journey. Funnel and journey render no links. Record, timeline, and waterfall use `linksOnly` field config so data links reach `field.getLinks`. A `PanelPlugin` without `.useFieldConfig()` silently drops dashboard data links.

## Sample dashboards

These are templates, not live state.

`dashboards/samples/static-web-nginx.json` (`cairn-static-web`) is the product template: project-parameterized Traffic, Vitals, Pages and sources, Audience. Copy this for web apps.

`dashboards/samples/ios-backend.json` (`cairn-ios-backend`) is the mobile plus backend template with `project` and `service` variables. Copy this for app plus API products.

`dashboards/samples/cairn.json` and `kubernetes.json` are ops dashboards for the stack itself. Don't copy their queries into product dashboards.

Live cluster exports belong in the ignored `dashboards/deployed/`, never in `samples/`.

## Provisioning and roles

`scripts/source.sh add-project|add|origins|revoke` is the only writer of credentials. The key is generated locally (mode 0600) and only its SHA-256 reaches the DB. Revocation lands within the 60s source-cache TTL. `origins` replaces the allowlist, and an empty list means no origin check.

`cairn_ingest` writes facts. `cairn_grafana` calls contracts and reads safe views. Neither is superuser and neither runs DDL. Migrations run once from the one-shot runner as the owner.

The checks that prove it: `make check` (lint, migrations, collector, panels), `make smoke` (every fixture through its real route, asserted as Grafana's role, panels rendered under Playwright), `make capacity`, `make health`.
