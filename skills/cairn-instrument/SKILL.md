---
name: cairn-instrument
description: Instrument an app for Cairn and build its Grafana dashboards.
---

# Cairn instrument

Cairn is a self-hosted observability stack. One Rust ingest service writes logs, traces, metrics, browser events, errors, and payment facts into TimescaleDB. Grafana is the only UI. There is no Cairn UI, no query API, no admin daemon.

This skill covers what is true because of how Cairn is built. It assumes you already know OpenTelemetry, Grafana, and SQL.

## How it fits together

One project is one product. Every fact row carries `(project_id, source_id)`, resolved server-side from the credential. The client body never decides ownership.

Sources have a kind: `browser`, `collector`, `sentry`, `stripe`, or `adapter`. A key belongs to one source. Browser keys are public and revocable. Adapter keys stay on private networks. Stripe authenticates by signature, not by key.

Grafana connects as `cairn_grafana` and reads through `cairn_ui.*` contracts and safe views. It cannot see key digests or raw payment payloads.

Every route commits before it answers 2xx. Delivery is at-least-once with stable retry keys, so a retried batch is a no-op rather than a double count.

## Routes

| Signal | Route | Sender |
|---|---|---|
| Browser batch | `POST /v1/ingest` | `@cairn/web` SDK |
| Crash envelope | `POST /v1/errors`, `POST /api/{project}/envelope[/]` | Sentry SDK via `cairn.dsn()` |
| Payment webhook | `POST /v1/webhooks/stripe/{source_id}` | Stripe, signature-verified |
| Private facts | `POST /v1/adapters/{source_id}/facts` | Your backend adapter |
| Traces, metrics, logs | `POST /v1/traces`, `/v1/metrics`, `/v1/logs` | OTel Collector, never the browser |

## Workflow

Decide the questions first: acquisition, activation, performance, errors, money. A panel that answers none of them does not ship.

Then read the reference for the piece you are working on:

- `references/frontend.md` for the browser SDK, custom events, consent, sampling.
- `references/backend.md` for the Collector, Sentry DSN, Stripe webhook, adapter facts.
- `references/events-identity.md` for event names, props, identify and reset, shared devices. Get this right before writing any dashboard.
- `references/features.md` for every signal, table, guarantee, and panel. Check it before inventing a new event or query.
- `references/dashboards.md` for Grafana dashboards. Copy `dashboards/samples/static-web-nginx.json` for a web product or `ios-backend.json` for mobile plus backend. Never copy `cairn.json` or `kubernetes.json`, they monitor the stack itself.

## Gotchas

Project, source, and environment come from the credential row, never from the client. The body only carries business data.

The browser never sets name or email. Only the adapter route writes `display_name` and `email`. A browser batch touches identity links only.

`identify()` without `reset()` is a normal login. The timeline resolves the device owner at query time, so clients must not rotate anon ids on login.

Event times are producer times and are kept verbatim. Anything older than 7 days or more than 1 hour ahead is rejected with a reason, never clamped. Retries land on the original time.

Consent denied stores nothing attributable. The batch still counts as traffic but writes no rows.

Record ids carry time: `error:<id>:<micros>`, `web:<uuid>:<micros>`, `payment:<provider>:<event>`, `measurement:<source>:<micros>:<id>`. A stale link renders nothing rather than the wrong fact.

Never filter on `environment` alone. Dashboard queries scope `(project, environment, ...)` together or skip environment. See `dashboards.md`.

The pre-GA schema has no migration path. A database that ran an older `migrations/0001_initial.sql` gets rebuilt with `make reset-dev`, not migrated.
