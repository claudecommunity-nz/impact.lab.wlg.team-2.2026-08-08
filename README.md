# Impact Lab Wellington — Team 2

**Wellington City Council Emergency Management × Claude Code Community NZ**
Saturday 8 August 2026 · Waimanga Room, Wellington City Council

---

## Problem 01 — Bring official warnings and local conditions into one clear community view

> How might we give people a clear, location-specific picture of an emerging weather event by bringing together official warnings, Council information and trusted reports of local conditions?

South coast events are often forecast by MetService and communicated through official channels. However, those sources do not always show what is happening at street or neighbourhood level — for example, the condition of roads, waves crossing the road, surface flooding or access becoming unsafe.

Residents may monitor MetService, WCC, WREMO, news media and local Facebook groups, without knowing which source to rely on or how the information fits together. A prototype could bring those sources into one view, identify the source and time of each item, and clearly distinguish official advice from unverified community reports.

**Desired outcome:** People can quickly understand what is forecast, what is happening locally, and where to find authoritative advice.

*The common theme is improving the flow and use of information between communities and Council before and during an event.*

---

## What we're building

One working prototype, demoed in four minutes at 16:30.

Each team's module is meant to slot into a shared **common operating picture** —
a live map of emergency signals that the ten prototypes feed together. Aim for
something that can be pointed at a map, a feed or an API, rather than a
closed-off demo.

Two teams work each problem statement independently. That's deliberate: two
honest attempts at the same problem tell WCC more than one.

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

## What we're building it as — the Location Picture

A Swift (Vapor) service running locally on a Mac that answers one question
for any lat/lng or community emergency hub: **what does this weather event
mean here?** It joins official CAP warnings, live conditions (river gauges,
electricity outages, water faults) and static hazard context (tsunami zones,
coastal inundation, flood layers) into one `/v1/picture` response — every
item carrying its source and age. Information, not advice. A separate
workstream builds the public web map on the same API.

Read the docs in order — they are the working brief:

| Doc | What |
|---|---|
| [`docs/00-architecture.md`](docs/00-architecture.md) | problem, principles, system shape, stack ADR, repo layout |
| [`docs/01-gates.md`](docs/01-gates.md) | build order G0–G7 with pass/fail tests — **the plan for the day** |
| [`docs/02-api-contract.md`](docs/02-api-contract.md) | endpoints + example `/v1/picture` JSON (frontend builds against this) |
| [`docs/03-datasets.md`](docs/03-datasets.md) | per-dataset endpoints, CRS rules, fields, minimal fetches, traps |
| [`docs/04-pulse-reuse.md`](docs/04-pulse-reuse.md) | what we vendor/reimplement/skip from Omega's Pulse |
| [`docs/05-demo-script.md`](docs/05-demo-script.md) | the 4-minute demo, two fixed locations |

## Schedule

| Time | What |
|---|---|
| 08:00 | Arrival and mingle |
| 09:00 | Opening address & problem briefing |
| 09:30 | Build begins |
| 12:30 | Lunch + lightning talks |
| 16:00 | Submissions close |
| 16:30 | Demos + judging |
| 17:45 | Awards + next steps |

## Ground rules

- These are **hazard-planning layers, not live emergency information**.
  In an emergency, call 111.
- **The data is not ours.** Each dataset belongs to its publisher — WCC, Greater
  Wellington, GNS Science, NIWA, Wellington Water, MBIE, NZTA, MetService.
  Licence terms vary per dataset; check the dataset's page before publishing
  anything derived from it, and credit the publisher.
- Be considerate with request rates. These are council servers, and at least one
  host throttles under concurrent load.
- **Keep personal details out of this repo.** It is public. No participant
  names, contact details or application material.
- Treat public social content as a *signal to investigate*, never as verified
  fact — surfacing something unverified as confirmed is the failure mode these
  problem statements are most wary of.

## Licence

**All code in this repository is licensed under the GNU Affero General
Public License v3.0 or later** (see [`LICENSE`](LICENSE)) — this repo states
otherwise from the event default. AGPLv3 also makes us licence-compatible
with [Omega Networks' Pulse](https://github.com/Omega-Networks/Pulse)
(AGPL-3.0), whose spatial code we reuse where noted.

The data is not covered by our licence. Each dataset belongs to its
publisher — WCC, Greater Wellington, WREMO, NEMA, Wellington Water,
MetService/Eagle, NIWA — and is attributed in every API response.
