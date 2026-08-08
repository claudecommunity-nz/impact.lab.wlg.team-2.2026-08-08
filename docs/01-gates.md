# Gate Plan — build order with pass/fail tests

Rules of engagement:

- **A gate is passed when its test command succeeds against the running
  server** (or test suite). Not before. Commit at every gate pass.
- Later gates assume earlier ones passed. **Do not start G5 until G2–G4 each
  pass.**
- Every gate's output is demoable on its own — if the day ends early, we demo
  the last passed gate.
- Times are a budget against the 09:30–16:00 build window, not promises.

| # | Gate | Input | Work | Output artefact | Test method | Pass criteria |
|---|------|-------|------|-----------------|-------------|---------------|
| G0 | Skeleton | empty `server/` | `swift package init` → Vapor app, `/healthz`, JSON error middleware, CORS on | running server on `:8080` | `curl -s localhost:8080/healthz` | `{"status":"ok"}`, HTTP 200, server survives unknown route with JSON 404 |
| G1 | Hubs | `community-emergency-hubs` layer | ArcGISClient generic `query()` (`outSR=4326`, paging via `exceededTransferLimit`); Hub domain model; `/v1/hubs` | `/v1/hubs` (JSON + `?format=geojson`) | `curl -s 'localhost:8080/v1/hubs' \| jq '.items \| length'` | count = **126**; every hub has non-zero lat/lng **inside bbox (174.6..175.0, -41.4..-41.1)**; GeoJSON variant loads in geojson.io |
| G2 | Warnings | `metservice-warnings` + `nema-cap-alerts` FeatureServers | decode CAP fields; point-in-polygon (winding number) in `GeoMath`; `/v1/warnings?lat&lng`; 60 s cache | `/v1/warnings` | unit test: synthetic polygon around Lyall Bay → point inside returns it, point in Karori doesn't; live: `curl '…/v1/warnings?lat=-41.3286&lng=174.7947'` | unit tests green; live call returns array (possibly empty — calm day is a pass) where each item has `event, severity, urgency, certainty, headline, onset, expires, source, fetchedAt`; no-params call returns all active NZ-wide |
| G3 | Conditions | Hilltop (`SiteList`, `GetData`) + `electricity-outages` + `water-network-faults` | HilltopClient (XML!, `%20` not `+`); nearest-N by haversine; `/v1/conditions?lat&lng&n&radiusKm`; 120 s cache | `/v1/conditions` | `curl '…/v1/conditions?lat=-41.3286&lng=174.7947&n=5'` | ≥1 gauge with a reading ≤6 h old, correct **units from server** (`Stage` mm, `Flow` m³/s, `Rainfall` mm); each item has `distanceKm`, `observedAt`, `source`; outages/faults sections present (empty ok) |
| G4 | Hazard context | 1+ static layer: start `tsunami-evacuation-zones`, then `stream-corridor`, `coastal-inundation-medium/high` | per-point layer query (server-side `geometry=` point intersect — the ArcGIS server does the join); `/v1/hazards?lat&lng`; 1 h cache | `/v1/hazards` | Lyall Bay `(-41.3286, 174.7947)` vs Karori `(-41.2865, 174.7405)` | Lyall Bay returns a tsunami zone (with `Evac_Zone`, `Col_Code`); Karori returns none/different; response labels layers as `planning` data, each with publisher attribution |
| G5 | Picture synthesis | G2 + G3 + G4 services | `PictureService` fans out concurrently (async let), tolerates any single-source failure; factual `summary` builder; `/v1/picture?lat&lng` and `?hub=<id>` | `/v1/picture` | `curl '…/v1/picture?lat=-41.3286&lng=174.7947' \| jq` matches `02-api-contract.md` schema; kill-switch test: point one source at a bad URL | full JSON per contract; `sources[]` lists every upstream with `fetchedAt`; with one source down, HTTP still 200, section `status:"unavailable"`, rest intact; summary contains **zero advice words** (no "should", "must", "evacuate") |
| G6 | Web UI | `/v1/hubs` geojson + `/v1/picture` | *frontend workstream* — map + click-anywhere → picture cards; **every card shows source + age** | public web page | judge-eyes test on two demo locations (`05-demo-script.md`) | click coastal point → warnings/conditions/hazards cards with source+age chips; click hill suburb → visibly different picture |
| G7 *(optional)* | Hotspots | elevated live points (gauges over threshold, outage clusters) | CPU grid-cluster (Pulse-inspired, see `04-pulse-reuse.md`); k-anonymity floor ≥3; `/v1/hotspots` | `/v1/hotspots` | synthetic: 10 points in 2 spatial groups → 2 hotspots; each hotspot carries member count + severity bucket | only build after G6 demos clean end-to-end |

## Dependency graph

```
G0 ─ G1 ─┬─ G2 ─┐
         ├─ G3 ─┼─ G5 ─ G6 ─ (G7)
         └─ G4 ─┘
```

G2, G3, G4 are independent once G1's `ArcGISClient` exists — **three agents
can build them in parallel** on separate branches (`gate-2-warnings`,
`gate-3-conditions`, `gate-4-hazards`), merging into `main` behind their
passing tests.

## Time budget (build window 09:30–16:00, lunch 12:30)

| Window | Target |
|---|---|
| 09:30–10:15 | G0 + G1 passed |
| 10:15–12:30 | G2, G3, G4 in parallel |
| 13:00–14:00 | stragglers from G2–G4; all three passed |
| 14:00–15:00 | G5 passed; frontend integrating live |
| 15:00–16:00 | G6 polish, demo rehearsal against `05-demo-script.md`; G7 only if bored |

Submission closes 16:00. **The repo is the submission — commit at every gate.**
