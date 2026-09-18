# User context, events, and behaviors

Read this before naming any event or writing any user query. Most bad Cairn dashboards come from a bad taxonomy, not bad SQL.

## Identity model

Every browser row carries `anon_id` (the device, always present) and `user_id` (your id, present after `identify`). `session_id` is a 30-minute inactivity hint, never auth.

`web.users` holds one profile row per `(project, user_id)`. `web.user_identities` holds one link row per `(project, user, device)` with `first_seen` and `last_seen`. The link table is the system of record, so history survives without rewriting the profile.

The browser owns the link between `anon_id` and `user_id`. The adapter owns PII (`display_name`, `email`). These never cross.

A device is a browser installation, not a person, and there is no unique constraint on `anon_id`. Timelines attach anonymous events (`user_id IS NULL`) by link window, so a shared device never leaks one user's attributed rows into another's timeline.

`identify()` without `reset()` is a normal login. Never rotate anon ids on login. `cairn_ui.device_owner` resolves the owner at query time (the latest identified fact on the device at or before the event), which handles Alice, then Bob, then Alice again on one machine. `reset()` is for logout only, to get back to the pre-login view.

## Event names

Use verb-first dotted names in past tense: `page.viewed`, `signup.started`, `signup.completed`, `checkout.started`, `checkout.completed`, `search.submitted`, `invite.accepted`.

Funnel steps are a subset of these real events, in order, with no branching names. If two names describe one occurrence the funnel is already lying. Fix the taxonomy, not the query.

`page.viewed` is automatic, don't re-emit it by hand. `vital.reported` and `error.captured` are diverted server-side into `web.vitals` and `errors.events`, so never give your own events those names.

Props describe the occurrence (`plan`, `amount_cents`, `query`, `step`), never the user. User context lives in `identify`, the adapter profile, and `attributes`, not in a prop you have to remember on every call.

Keep one canonical path per page (`/products/…`, not the full URL with `?utm_*`). The server normalizes, but query-string-per-campaign paths still fragment the slowest-pages table. Put the campaign in `referrer_host` or props, not in the path.

## Behavior queries

For a per-user timeline use `cairn_ui.user_timeline(project, user_id, anon_ids)` and `cairn_ui.user_profile(project, user_id)`. Start from a device id and it keeps working after login. Don't hand-roll the union over events, vitals, and errors.

For a funnel use `cairn_ui.funnel(...)` over `web.events` only. All steps share one session or user scope and one time window, otherwise the conversion rate means nothing. The journey panel (path between two events) follows the same scope rule.

For a user's errors query `errors.events` by `user_id`, plus pre-login rows by `anon_id`. Sentry rows have neither, so join those by `trace_id` or `release`.

For a user's money query `payments.events_safe` by `user_ref`. Never match `customer_id` to an app user.

## What not to do

Don't put PII in `props` or `attributes` to make support search easy. Support search is `web.users.email` plus the timeline. Props are scrubbed and sanitized but they are still the wrong home for PII.

Don't use `session_id` as a user key, a billing key, or a funnel identity. It is an analytics hint with a 30-minute rotation.

Don't backfill identity by rewriting history. Append link rows via identify or the adapter. Reclaim jobs (`web.reclaim_stale_links`, `obs.reclaim_abandoned_series`) only delete links and series that no retained fact references.
