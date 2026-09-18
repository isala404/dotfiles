# Frontend (`@cairn/web`)

Source of truth is `sdk/web/README.md` and `sdk/web/src/`. The SDK is under 5 KB gzipped, has no dependencies, and never throws into the page.

## Minimal integration

```ts
import { cairn } from "@cairn/web";
cairn.init({ url: "https://cairn.example.com", key: "pk_…" });
```

That alone records `page.viewed` (including SPA `pushState`, `replaceState`, and `popstate`), Core Web Vitals as `vital.reported`, and uncaught errors as `error.captured`. There is no registry and no codegen.

## Custom events

```ts
cairn.track("checkout.completed", { plan: "pro", amount_cents: 2900 });
cairn.page({ section: "pricing" }); // manual page view, only with autoPage off
```

Names are dotted, max 128 chars: `onboarding.step_completed`, `search.submitted`, `player.started`. Use one name per real-world occurrence. The server stores what you send and never dedupes names.

Track one event per user action, and track the intent (`checkout.started`, `checkout.completed`) rather than the widget (`button.clicked`). Props carry the rest.

Props are free-form JSON. The server scrubs them (secrets redacted, values sanitized), but still never send passwords, tokens, card numbers, or full message bodies.

The SDK stamps `path` when the event happened, not when the batch flushes. Don't put user ids in props, use `identify`.

## Identity

```ts
cairn.identify("user-42"); // on login, and on every load where you know the user
cairn.reset();             // on logout only
```

`anon_id` is the device and is always present. `user_id` is your id and appears after identify. `session_id` rotates after 30 minutes of inactivity and is only a hint.

Pre-login events keep only `anon_id`. The server links both halves into one timeline at query time, so never rotate or clear anon state on login.

Name and email never come from the browser. POST them from the backend over the adapter route.

## Consent, sampling, reliability

```ts
cairn.init({ url, key, appVersion: "1.4.2", requireConsent: true, sampleRate: 0.2 });
cairn.consent({ analytics: true });
```

The default is analytics on: first-party, cookieless, no cross-site id. `requireConsent: true` holds everything until the banner says yes. Withdrawing consent drops the unsent buffer, and the server stores nothing attributable from a denied batch.

`sampleRate` is decided once per device, as a fraction of visitors, not per event. Use it for high-traffic sites, not to fix a noisy taxonomy.

Failed sends go to IndexedDB and retry on the next flush, next load, or `online`. Event ids are minted at occurrence time so retries dedupe server-side. A 4xx is dropped, not retried forever. `pagehide` flushes via beacon.

Always set `appVersion`. It is the only way to answer whether a release broke vitals, errors, or a funnel.

## Options

`url` and `key` are required. The rest: `appVersion`, `autoPage` (default true), `autoVitals` (true, covers LCP/INP/CLS/FCP/TTFB), `autoErrors` (true), `requireConsent` (false), `batchSize` (20), `flushInterval` (5000 ms), `sampleRate` (1).
