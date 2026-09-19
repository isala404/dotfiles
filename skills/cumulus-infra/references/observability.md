# Observability through Cairn

Cairn is the cluster's observability store. The collector agent DaemonSet tails `/var/log/pods` for every container, accepts OTLP on the node, and writes logs, traces, and metrics into TimescaleDB. `kubectl logs` shows one container since its last restart. The database has the whole cluster's history and answers filters `kubectl logs` cannot express: every namespace at once, any window, text search across all containers.

## Where the database lives

The prod Cairn database runs on the pod in the `timescale-dev` namespace, not `timescale`. The names mislead: `timescale` holds the app databases (enki, hearth, umami), `timescale-dev` holds the dev app databases plus `cairn`, which is prod. The collector connects to `timescale.timescale-dev.svc.cluster.local`.

Read it through the pod directly. No port-forward, no Grafana:

```bash
kubectl exec -n timescale-dev deploy/timescale -- psql -U postgres -d cairn
```

For more than a one-liner, pipe SQL in with a quoted heredoc so nothing expands locally:

```bash
kubectl exec -i -n timescale-dev deploy/timescale -- psql -U postgres -d cairn <<'SQL'
SELECT count(*) FROM obs.logs WHERE time > now() - interval '1 hour';
SQL
```

Read-only, always. This is the live prod database. Migrations run once from the one-shot runner and never through here.

## What is stored

Everything is scoped `(project_id, source_id)`. Two projects: `polaris` is the cluster itself, `isala-me` is the website's browser data.

| Signal | Table | Kept |
|---|---|---|
| Container logs | `obs.logs` | 7 days, 3h chunks |
| Spans | `obs.spans` | 14 days |
| Metric samples | `obs.metric_samples` joins `obs.metric_series` | 15 days |
| Metric histograms | `obs.metric_histograms` | 90 days |
| Errors | `errors.events`, `errors.groups` | events 90d, groups forever |
| Browser events and vitals | `web.events`, `web.vitals` | 90 days |
| Payments | `payments.events_safe` | forever |

`obs.logs` carries kube columns from the collector's Kubernetes metadata, not from the log line: `cluster`, `namespace`, `workload`, `pod`, `container`, `node`, `service`, `stream`, `severity`, `message`, `trace_id`, `span_id`, and a bounded `attributes` jsonb.

Full column lists, guarantees, and the `cairn_ui` contracts (`trace`, `timeline`, `record`) are in the `cairn-instrument` skill's `references/features.md`.

## How the indexes shape queries

Four btree indexes exist on `obs.logs` and every one leads with `project_id` and ends with `time`:

| Filter | Index |
|---|---|
| `(project_id, cluster, namespace, time)` | namespace questions |
| `(project_id, service, time)`, partial on `service IS NOT NULL` | service questions |
| `(project_id, environment, service, time)`, partial | service plus environment |
| `(project_id, trace_id, time)`, partial on `trace_id IS NOT NULL` | trace lookups |

Rules that follow:

- Resolve the project once and include it: `project_id = (SELECT id FROM cairn.projects WHERE slug = 'polaris')`. It leads every index.
- Always bound `time`. It closes the index range and lets TimescaleDB's ChunkAppend skip chunks outside the window. Chunks are 3h.
- `severity`, `pod`, `container`, `workload`, `message`, and `attributes` are on no index. They run as post-filters over whatever the index returned: cheap behind a tight index scan, slow over a wide window. A text search needs a namespace, service, or short window with it.
- Metrics query in two steps: resolve series ids from `obs.metric_series` by `(project_id, metric_name)`, then join samples on `series_id` with a time bound. Samples are indexed `(series_id, time)` only; there is no path from a label value to a sample except through the series table.
- Spans are indexed for exactly two questions: one trace's waterfall `(project_id, trace_id, time)` and slowest spans `(project_id, service, duration_ms DESC)`.

Run `EXPLAIN` when a query feels slow; the plan names the chunk index it picked.

## Queries

Errors and warnings in one namespace, the everyday query:

```sql
SELECT time, pod, severity, left(message, 120) AS message
FROM obs.logs
WHERE project_id = (SELECT id FROM cairn.projects WHERE slug = 'polaris')
  AND time > now() - interval '1 hour'
  AND namespace = 'hearth'
  AND severity IN ('error', 'warn')
ORDER BY time DESC
LIMIT 50;
```

Text search across every container in a namespace, bounded so the post-filter walks few rows:

```sql
SELECT time, namespace, pod, left(message, 120) AS message
FROM obs.logs
WHERE project_id = (SELECT id FROM cairn.projects WHERE slug = 'polaris')
  AND time > now() - interval '3 hours'
  AND namespace = 'registry'
  AND message ILIKE '%unauthorized%'
ORDER BY time DESC
LIMIT 100;
```

One workload across pod restarts. Filter `workload`, not `pod`: a rescheduled pod gets a new name. Bind a namespace too, since `workload` is a post-filter:

```sql
SELECT time, pod, severity, left(message, 120) AS message
FROM obs.logs
WHERE project_id = (SELECT id FROM cairn.projects WHERE slug = 'polaris')
  AND time > now() - interval '24 hours'
  AND namespace = 'external-secrets'
  AND workload = 'external-secrets'
ORDER BY time DESC
LIMIT 100;
```

Volume by namespace over a window:

```sql
SELECT namespace, count(*)
FROM obs.logs
WHERE project_id = (SELECT id FROM cairn.projects WHERE slug = 'polaris')
  AND time > now() - interval '6 hours'
GROUP BY 1 ORDER BY 2 DESC;
```

Metric discovery first, by `(project_id, metric_name)`:

```sql
SELECT metric_name, instrument_type, unit, count(*) AS series
FROM obs.metric_series
WHERE project_id = (SELECT id FROM cairn.projects WHERE slug = 'polaris')
GROUP BY 1, 2, 3 ORDER BY 1;
```

Latest value per series, two-step with a lateral so each series touches one index row:

```sql
SELECT s.metric_name, s.labels, m.time,
       coalesce(m.value_double, m.value_int) AS value
FROM obs.metric_series s
JOIN LATERAL (
  SELECT * FROM obs.metric_samples
  WHERE series_id = s.id AND time > now() - interval '1 hour'
  ORDER BY time DESC LIMIT 1
) m ON true
WHERE s.project_id = (SELECT id FROM cairn.projects WHERE slug = 'polaris')
  AND s.metric_name = 'cairn.database.size_bytes';
```

Counters: check `instrument_type` and `temporality` on the series. A rate is the delta between samples over the interval, never `sum(value)`.

One trace's waterfall, or the `cairn_ui` contract, which takes the project uuid rather than the slug:

```sql
SELECT span_id, parent_span_id, service, name, kind, duration_ms, status
FROM obs.spans
WHERE project_id = (SELECT id FROM cairn.projects WHERE slug = 'polaris')
  AND trace_id = '<trace_id>'
ORDER BY time;

SELECT * FROM cairn_ui.trace(
  (SELECT id FROM cairn.projects WHERE slug = 'polaris'), '<trace_id>');
```

Slowest spans for a service:

```sql
SELECT service, name, duration_ms, time
FROM obs.spans
WHERE project_id = (SELECT id FROM cairn.projects WHERE slug = 'polaris')
  AND time > now() - interval '24 hours'
  AND service = 'hearth'
ORDER BY duration_ms DESC
LIMIT 10;
```

## Gotchas

- Cluster logs are text-tailed from `/var/log/pods`, so `trace_id` is NULL on effectively every row. It fills only when a workload sends OTLP logs carrying trace context. Trace correlation lives in `obs.spans`, which is empty until a workload emits OTLP traces to the node agent on 4317 or 4318. An empty `obs.spans` means nothing emits traces, not that the pipeline broke.
- `severity` is not reliable. It is whatever the collector could parse off the line, most images log everything at `info`, and lines with no parseable level read `unknown`. Filter on it as a hint, never as the definition of what went wrong; text-search the `message` instead.
- `time` is the producer time, kept verbatim; `ingested_at` is arrival. Query on `time`.
- Do not select from `cairn.sources` (key digests) or `payments.events` (raw payloads). The safe paths, which Grafana uses, are `cairn.source_catalog` and `payments.events_safe`.
- Live tailing is still `kubectl logs -f`. The database wins for history, cross-namespace search, and aggregates.
