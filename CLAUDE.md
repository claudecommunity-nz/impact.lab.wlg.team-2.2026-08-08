# Impact Lab Wellington — Team 2

Context for Claude Code working in this repo.

## The event

A one-day build with Wellington City Council Emergency Management, Saturday
8 August 2026, at the Waimanga Room, Wellington City Council. Ten teams, five
problem statements, two teams per statement. Each team ships one working
prototype and demos it for four minutes.

## Timeline for the day

| Time | What |
|---|---|
| 08:00 | Arrival and mingle |
| 09:00 | Opening address & problem briefing |
| 09:30 | Build begins |
| 12:30 | Lunch + lightning talks |
| 16:00 | Submissions close |
| 16:30 | Demos + judging |
| 17:45 | Awards + next steps |

Build time is roughly six and a half hours, minus lunch. Scope accordingly:
a narrow thing that works beats a broad thing that doesn't demo.

## This team's problem — 01: Bring official warnings and local conditions into one clear community view

> How might we give people a clear, location-specific picture of an emerging weather event by bringing together official warnings, Council information and trusted reports of local conditions?

South coast events are often forecast by MetService and communicated through official channels. However, those sources do not always show what is happening at street or neighbourhood level — for example, the condition of roads, waves crossing the road, surface flooding or access becoming unsafe.

Residents may monitor MetService, WCC, WREMO, news media and local Facebook groups, without knowing which source to rely on or how the information fits together. A prototype could bring those sources into one view, identify the source and time of each item, and clearly distinguish official advice from unverified community reports.

**Desired outcome:** People can quickly understand what is forecast, what is happening locally, and where to find authoritative advice.

All five statements sit inside one frame: the common theme is improving the flow and use of information between communities and Council before and during an event.

## What success looks like

Each prototype is a module in a shared **common operating picture**: a live map
of emergency signals. Prefer outputs that compose — GeoJSON, a feed, an
endpoint — over a self-contained UI that nothing else can read.

Judging is on a four-minute demo. Something running and pointed at real
Wellington data will land better than architecture that isn't finished.

## Data

The public GIS datasets Wellington City Council Emergency Management shared are
catalogued, checked and made queryable here:

- **Catalogue + SDK** — https://github.com/claudecommunity-nz/wcc-emergency-gis-data
- **Browse the datasets** — https://claudecommunity-nz.github.io/wcc-emergency-gis-data/

74 datasets: flood, landslide, earthquake, tsunami, coastal inundation and
climate layers, plus emergency hubs, post-quake road reopening order, water
tanks, deprivation by area, and live river-level and rainfall telemetry.
`wcc_gis.py` is a single file with no dependencies — copy it and
`catalogue.json` into your project.

```python
import wcc_gis

wcc_gis.ids("tsunami")                                    # find datasets
wcc_gis.features("tsunami-evacuation-zones", at=(-41.2790, 174.7804))
wcc_gis.geojson("footpaths", bbox=wcc_gis.WELLINGTON)     # straight into MapLibre
wcc_gis.hilltop_data("Hutt River at Taita Gorge", "Flow")[-1]
```

Three traps worth knowing before you lose an hour to them:

- Everything is published in **NZTM2000, not lat/lng**. Request raw and your
  pins land off the coast of Africa. Always ask for `outSR=4326`.
- **A quarter of the layers are rasters** that advertise a query capability,
  then refuse to answer. Ask them for a PNG instead.
- **One query is silently capped** (`footpaths` has 8,130 features; a request
  returns 2,000). Page properly, or check `exceededTransferLimit`.

## Constraints that matter here

- **Hazard-planning data, not live emergency information.** Nothing built today
  should be presented as an operational emergency source. In an emergency, 111.
- **Show reliability, don't hide it.** Several of these problem statements are
  explicitly about making limitations visible. If the prototype infers or
  aggregates, say so in the interface. Never present an unverified public post
  as confirmed fact.
- **This repo is public and must stay free of personal information** — no
  participant names, contact details, or anything from the application process.
- **Attribution.** Data belongs to its publishers and licences vary per dataset.
  Check before publishing anything derived.

## How this team builds — read before writing code

The working brief lives in `docs/` — read `00-architecture.md` and
`01-gates.md` first, always. The short version:

- **What we build:** the Location Picture service — Swift 6 + Vapor 4, runs
  locally on a Mac (`swift run App` from `server/`), no database, no Docker.
  It answers `/v1/picture?lat&lng`: official warnings + live conditions +
  hazard context for that point, every item with `source` and `fetchedAt`.
- **Gate discipline:** work proceeds G0→G7 per `docs/01-gates.md`. A gate is
  done when its test command passes against the running server. Commit at
  every gate pass. Do not start G5 before G2, G3 and G4 each pass. G2/G3/G4
  parallelise on branches `gate-2-warnings` / `gate-3-conditions` /
  `gate-4-hazards`.
- **API contract:** `docs/02-api-contract.md` is frozen for the frontend
  workstream — breaking it after G5 requires telling them first.
- **Dataset access:** exactly as specified in `docs/03-datasets.md`. Every
  ArcGIS query sends `outSR=4326`. Hilltop is XML, spaces are `%20` never
  `+`, units come from the server's `<Units>` element. Check
  `exceededTransferLimit`. Be polite to council hosts — sequential per host,
  respect the cache TTLs.
- **Architecture rules:** routes → services → clients, never routes →
  upstream. Wire structs (`…Raw`) mirror upstream field names; domain
  structs are clean; nothing downstream sees an upstream field name.
  Everything crossing an actor boundary is `Sendable`. All geometry is
  WGS84 end-to-end.
- **Pulse reuse:** per `docs/04-pulse-reuse.md`. ConcaveHull and the GeoMath
  helpers may be vendored verbatim (AGPL↔AGPL, keep headers); everything
  touching Metal/MapKit/SwiftData stays out.
- **Voice:** information, not advice. The summary builder never emits
  "should / must / evacuate / safe" — there's a test for it. Empty states
  are stated, not hidden. Planning layers are labelled as planning data.
- **Licence:** everything we write is AGPL-3.0-or-later. New source files
  get the SPDX header:
  `// SPDX-License-Identifier: AGPL-3.0-or-later`

## Conventions

- Keep the README's problem statement in sync if the scope shifts during the day.
- Commit early and often — the repo is the submission.
