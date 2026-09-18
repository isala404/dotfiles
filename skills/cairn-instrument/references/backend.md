# Backend: Collector, Sentry, Stripe, adapters

Cairn never collects. Your backend and the OTel Collector produce, Cairn validates, normalizes, and writes. Pick the narrowest route that carries your signal.

## OTLP via the Collector (logs, metrics, traces)

This is the only path into `obs.*`. Apps export OTLP to the Collector. The Collector scrubs, batches, and exports to `POST /v1/traces`, `/v1/metrics`, and `/v1/logs` with its source key. Project, environment, and cluster come from the source row plus trusted exporter headers, never from telemetry attributes.

Deploy with `deploy/collector/agent-values.yaml` (DaemonSet, node logs and own metrics, key from a Secret) and `cluster-values.yaml` (one cluster Collector for workload state and warning Events). `make check-collector` validates both against the pinned image.

Spans keep typed columns: service, name, kind, duration, status, scope, events and links as bounded arrays with truncation flags, and `dropped_*_count` for loss accounting. Trace ids are 32 lowercase hex chars and span ids are 16. Anything else is rejected.

Metrics become `obs.metric_series` (stable `(resource, scope, metric, labels)` identity, hash-verified) plus `obs.metric_samples` and `obs.metric_histograms`. The 250,000-series budget is an alert threshold, not an ingest gate.

Browser traffic never touches OTLP routes. Backend business numbers don't go through OTLP either, they go through the adapter route below.

## Errors via the Sentry SDK

Don't hand-roll crash capture. Point the official Sentry SDK at Cairn:

```python
sentry_sdk.init(dsn=cairn.dsn(), release="api-1.4.2", traces_sample_rate=0.1)
```

The `{project}` segment in `/api/{project}/envelope/` is Sentry's scheme and means nothing here. The key in the DSN selects the source. Both `/v1/errors` and both envelope spellings are accepted, but only the envelope paths are reachable from the browser through the edge.

Grouping is a pure fingerprint over normalized frames, or the SDK fingerprint if set. There is no LLM involved. A browser `error.captured` and a Sentry crash from the same bug land in the same `errors.groups` row.

Attachments, replay, profiles, sessions, and transactions are counted and dropped. The `user` object is stripped before storage, so Sentry occurrences carry no `user_id` or `anon_id`. Join them by `trace_id` or `release`, not by user.

Set `release` on every SDK. `latest_release` follows event time and drives every "did this ship break it" panel.

## Money via the Stripe webhook

`POST /v1/webhooks/stripe/{source_id}`. The source id in the path picks the signing secret. Not CORSed, never browser-reachable.

Verification runs on raw bytes (`t,v1` scheme, 5-minute replay window). A bad signature stores nothing and answers 401.

Every authentic event is stored in `payments.events` and kept forever, including types no dashboard counts. The verified payload stays for audit. Grafana reads `payments.events_safe`, never the raw payload.

To tie money to your user, set Stripe metadata `cairn_user` (or `client_reference_id`) to your `user_id`. That fills `user_ref` and joins charges to the per-user timeline. `customer_id` is provider identity and never matches an app user.

## Private adapter facts

`POST /v1/adapters/{source_id}/facts` with `x-cairn-key`, private network only. The envelope is explicit, `(version: 1, signal_kind)`, and unknown kinds are rejected before any sink runs.

A measurement is a scalar domain fact, for example health, usage, or a billing counter:

```json
{"version": 1, "signal_kind": "measurement", "measurement_id": "meter-9f3a",
 "time": "2026-09-18T10:00:00Z", "domain": "health", "name": "health.heart_rate",
 "value": 72, "unit": "bpm", "subject_id": "user-42", "tags": {}, "attributes": {}}
```

The retry identity is `(project, source, time, measurement_id)`, so resend both unchanged on retry. Historical timestamps are kept verbatim, which makes backfill safe. Only future drift is rejected. The value must be finite. Use one dotted `domain` plus `name` per real-world measure, and don't fan one reading into five names.

A user profile adds context to an id that is already tracked:

```json
{"version": 1, "signal_kind": "user_profile", "user_id": "user-42",
 "name": "Ada", "email": "ada@example.com", "anon_ids": ["<uuid>"],
 "attributes": {"plan": "pro"}, "updated_at": "2026-09-18T10:00:00Z"}
```

A missing field leaves the stored value alone. An explicit `null` clears it. `updated_at` orders writers so a stale fact never overwrites newer state, and browser-created rows start at `-infinity` so any adapter fact wins. `anon_ids` appends link rows to `web.user_identities`. Email must contain `@`, and an empty string after trim clears it.

## Ops

`GET /healthz`, `/readyz`, and `/metrics`. Every protocol route checks body size before authenticating, so floods never cost a DB round trip.

Sources are provisioned by `scripts/source.sh`. The key is generated locally and only its SHA-256 reaches the DB. There is no admin API on purpose.
