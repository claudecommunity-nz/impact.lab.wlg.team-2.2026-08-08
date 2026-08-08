# Impact Lab Wellington — Team 2

**Location Picture** — a local Swift/Vapor API that answers: *what does this weather event mean here?*

Joins official CAP warnings, live conditions (gauges, electricity, water), and planning hazard layers for any lat/lng. Every fact carries `source` + `fetchedAt`. Information, not advice.

Wellington City Council Emergency Management × Claude Code Community NZ · 8 Aug 2026.

---

## Run

```bash
cd server
swift run App
# http://127.0.0.1:8080  (also binds LAN; see boot log)
```

Requires Swift 6 + macOS. Override bind with `HOST=` / `PORT=`.

---

## API (live)

| Path | Purpose |
|---|---|
| `GET /healthz` | Liveness |
| `GET /v1/hubs` | Community emergency hubs (+ `?format=geojson`) |
| `GET /v1/warnings` | CAP warnings (`?lat&lng` filters to point) |
| `GET /v1/conditions?lat&lng` | Nearest gauges, outages, water faults |
| `GET /v1/hazards?lat&lng` | Planning layers at point |
| `GET /v1/picture?lat&lng` | Full Location Picture (or `?hub=<id>`) |

Contract + example JSON: [`docs/02-api-contract.md`](docs/02-api-contract.md).

### Demo fixtures (offline / calm day)

Curated scenarios — **not** live feeds:

```bash
curl -s localhost:8080/v1/demo/scenarios | jq .
curl -s 'localhost:8080/v1/demo/picture?scenario=southerly-storm&point=lyall-bay' | jq .summary
curl -s 'localhost:8080/v1/demo/picture?scenario=southerly-storm&point=karori' | jq .summary

# Map layers (GeoJSON polygons + pins)
curl -s 'localhost:8080/v1/demo/warnings?scenario=southerly-storm&point=lyall-bay&format=geojson'
curl -s 'localhost:8080/v1/demo/hazards?scenario=southerly-storm&point=lyall-bay&format=geojson'
curl -s 'localhost:8080/v1/demo/conditions?scenario=southerly-storm&point=lyall-bay&format=geojson'
```

Details: [`docs/07-demo-data.md`](docs/07-demo-data.md).
**Demo anchors:** Lyall Bay `-41.3286, 174.7947` · Karori `-41.2865, 174.7405`.

---

## Data sources (wired)

| Category | Sources |
|---|---|
| Warnings | MetService CAP, NEMA CAP |
| Live | GW Hilltop gauges, NEMA electricity outages, Wellington Water faults |
| Hazards | WCC tsunami zones, coastal inundation (medium/high), stream corridor |
| Anchors | WREMO community emergency hubs |

GIS catalogue (74 layers, reference only — not vendored here):  
https://github.com/claudecommunity-nz/wcc-emergency-gis-data

---

## Layout

```
server/     Vapor app (Sources, Tests)
docs/       API contract + demo data notes
LICENSE     AGPL-3.0-or-later
```

---

## Licence

Code: **AGPL-3.0-or-later** ([`LICENSE`](LICENSE)).  
Data belongs to its publishers (WCC, GW, WREMO, NEMA, Wellington Water, MetService, NIWA) and is attributed in every response.

In an emergency call **111**.
