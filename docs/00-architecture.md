# Location Picture — Architecture Brief

**Impact Lab Wellington, Team 2 · Problem 01 · 8 August 2026**
Licence: AGPL-3.0-or-later (see `/LICENSE`). Data belongs to its publishers.

## Problem (fixed)

> How might we give people a clear, location-specific picture of an emerging
> weather event by bringing together official warnings, Council information
> and trusted reports of local conditions?

The same national warning means different things on a river street than on a
hill. Residents currently stitch together MetService, WCC, WREMO, news and
Facebook themselves. We give them one view, per location, with every item
carrying its **source** and **age**.

## Product principles

1. **Information, not advice.** Facts + source + timestamp. People decide.
   No "evacuate now". In an emergency, 111.
2. **Location-first.** Everything is answered for a point (lat/lng) or a
   community emergency hub.
3. **One place.** The digital equivalent of a leaflet drop.
4. **No overload.** Only signals that touch *this* location.
5. **Composable.** GeoJSON + JSON endpoints any client can read — this module
   slots into the shared common operating picture the other nine teams feed.
6. **Show reliability, don't hide it.** Official vs unverified is always
   labelled. Stale data says it is stale.

## System shape

```
 Upstream sources                    Location Picture service (Swift, Mac-local)
┌──────────────────────┐            ┌──────────────────────────────────────────┐
│ ArcGIS FeatureServers│            │  SourceClients   (fetch, decode, outSR)  │
│  · metservice-warnings ──────────▶│       │                                  │
│  · nema-cap-alerts   │  HTTPS/JSON│  SourceCache     (actor, TTL, fetchedAt) │
│  · electricity-outages│           │       │                                  │
│  · water-network-faults│          │  Spatial         (point-in-poly, nearest)│
│  · hazard layers (WCC/GW)│        │       │                                  │
│  · community-emergency-hubs│      │  PictureService  (join + synthesise)     │
├──────────────────────┤            │       │                                  │
│ Hilltop XML (GW)     ──────────▶  │  Routes  /hubs /warnings /conditions     │
│  · Stage, Flow, Rainfall │        │          /hazards /picture /healthz      │
└──────────────────────┘            └──────────────┬───────────────────────────┘
                                                   │ JSON / GeoJSON over HTTP
                                    ┌──────────────▼───────────────────────────┐
                                    │ Public web frontend (MapLibre — separate │
                                    │ workstream) + any COP client / device    │
                                    └──────────────────────────────────────────┘
```

**Core product object — `LocationPicture`** for a lat/lng or hub id:

- `officialWarnings` — CAP-derived polygons covering the point (MetService
  severe weather + NEMA Emergency Mobile Alerts)
- `localConditions` — nearest live signals: river gauges / rainfall (Hilltop),
  electricity outages, water network faults
- `hazardContext` — static planning layers the point sits inside (flood /
  stream corridor, coastal inundation, tsunami evacuation zone)
- `summary` — plain-language, strictly factual, assembled from the above
- `generatedAt` + `sources[]` — provenance for every item

## Stack decision (ADR-001)

**Decision: Swift 6 + Vapor 4, running locally on macOS.**

- Team is a Swift shop (Pulse); Claude Code agents write idiomatic Vapor well.
- Vapor is MIT-licensed, community-governed, no vendor lock-in — compatible
  with our AGPLv3 release.
- SwiftNIO gives us async URLSession-style fetching and a production-grade
  HTTP server with zero external infrastructure. `swift run` is the deploy.
- **Alternative considered:** Hummingbird (lighter, same NIO core). Rejected
  only because Vapor has more training-data coverage for agent-written code —
  at hackathon pace, boring and well-trodden wins.
- **Rejected:** raw XML CAP parsing as the primary warnings path. The Eagle/
  MetService ArcGIS FeatureServer already publishes the same CAP alerts as
  spatially-queryable polygons with all CAP fields (severity, urgency,
  certainty, onset, expiry). We query that; raw CAP XML is a stretch goal.

**Persistence: none.** In-memory per-source cache (actor) with TTL and
`fetchedAt` stamps. A hackathon service that restarts in one second does not
need a database. The cache IS the provenance layer: every response carries
the upstream fetch time.

## Coordinate rules (memorise)

| Source | Native CRS | Rule |
|---|---|---|
| WCC / GW ArcGIS layers | EPSG:2193 (NZTM2000) | always send `outSR=4326` |
| Eagle MetService warnings, NEMA CAP | EPSG:3857 | always send `outSR=4326` |
| NEMA electricity outages | EPSG:4326 | send `outSR=4326` anyway (uniform) |
| Hilltop telemetry | WGS84 already | no reprojection |

One rule everywhere: **every ArcGIS query carries `outSR=4326`; everything
inside the service is WGS84 lat/lng.** All distance maths is haversine (or
local equirectangular approximation — fine at city scale).

## Non-goals (today)

- No advice, no evacuation instructions, no severity *interpretation* beyond
  what the source publishes.
- No social-media scraping. No unverified community reports in v1 — the data
  model has a `trust` field so verified community reports can be added later.
- No accounts, no push notifications, no offline mode.
- No MapKit/Metal/GPU anything — that is Pulse's territory (see
  `04-pulse-reuse.md`). CPU point-in-polygon over a city's worth of polygons
  is milliseconds.
- No database, no Docker, no cloud. `swift run App` on a Mac.

## Failure posture

Every upstream is assumed to flake (council servers, throttling). Rules:

- Each source is fetched independently; one dead source never empties the
  picture. Missing sections are reported as `"status": "unavailable"` with
  the last-good data + its age if we have it.
- Cache TTLs: warnings 60 s, live conditions 120 s, static hazard layers 1 h
  (they change never), hubs 1 h.
- Be polite: never fan out concurrent requests to the same host; the catalogue
  README warns at least one host throttles.

## Repo layout

```
├── LICENSE                  AGPL-3.0 (whole repo — supersedes event default)
├── README.md                problem statement (keep in sync)
├── CLAUDE.md                agent working conventions
├── docs/                    ← you are here; read 00→05 in order
├── server/                  Swift package (Vapor app) — see 01-gates.md G0
│   ├── Package.swift
│   ├── Sources/App/
│   │   ├── entrypoint.swift, routes.swift, configure.swift
│   │   ├── Domain/          LocationPicture, Warning, LiveCondition,
│   │   │                    HazardContext, Hub, SourceMeta, Trust
│   │   ├── Clients/         ArcGISClient, HilltopClient
│   │   ├── Services/        WarningsService, ConditionsService,
│   │   │                    HazardsService, HubsService, PictureService
│   │   ├── Spatial/         GeoMath (point-in-polygon, haversine, bbox)
│   │   └── Cache/           SourceCache (actor, TTL)
│   └── Tests/AppTests/      gate tests live here
├── vendor/wcc-emergency-gis-data/   catalogue.json (+ wcc_gis.py for humans
│                                    poking at data — server never calls it)
└── web/                     frontend workstream (not ours; builds against
                             docs/02-api-contract.md)
```

Omega conventions apply (service-layer separation, extensions in
`Extensions/`, VO/DTO split where a wire model differs from the domain model):
routes never call upstream APIs directly — routes → services → clients.
