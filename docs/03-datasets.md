# Dataset Pull Checklist

Verified against the catalogue repo (`claudecommunity-nz/wcc-emergency-gis-data`,
cloned 8 Aug 2026 — vendor `catalogue.json` into `vendor/`). Feature counts are
from the catalogue's probe run; live counts will differ for live feeds.

**Universal rules**

1. Every ArcGIS query: `outSR=4326&f=json&outFields=*` (native CRS varies —
   2193, 3857, 4326 — `outSR=4326` normalises all of them).
2. Check `exceededTransferLimit` in every response; page with
   `resultOffset`/`resultRecordCount` if true.
3. Spatial filter for a point:
   `geometry=<lng>,<lat>&geometryType=esriGeometryPoint&inSR=4326&spatialRel=esriSpatialRelIntersects`
   — the server does the point-in-polygon for static layers.
4. Be polite: sequential requests per host, cache per TTL (`00-architecture.md`).
5. **"Minimal successful fetch"** below = the curl that proves the dataset is
   alive and understood. Run it before writing any code against the layer.
   `URL` means the endpoint in the table row.

## Official warnings

| | `metservice-warnings` | `nema-cap-alerts` |
|---|---|---|
| Endpoint | `https://services.arcgis.com/XTtANUDT8Va4DLwI/arcgis/rest/services/Metservice_Weather_Alerts/FeatureServer/0` | `https://services5.arcgis.com/cJn6oR1QqErYBL5d/arcgis/rest/services/NZ_CAP_Alerts_(Read_only)/FeatureServer/0` |
| Publisher | MetService via Eagle Technology | NEMA (Emergency Mobile Alert broadcast polygons) |
| Geometry / CRS | Polygon / **EPSG:3857** | Polygon / **EPSG:3857** |
| Max records | 1000 | 2000 |
| Key fields | `identifier, info_event, info_headline, info_severity, info_urgency, info_certainty, info_area_areaDesc, onset(Date), validto(Date), info_description, info_instruction, info_web, status, sent` | `identifier, event, headline, severity, urgency, certainty, sent(Date), effective(Date), expires(Date), description, status, msg_type, historic(Int)` |
| Freshness filter | `where=status='Actual'` + client-side `validto > now` | `where=historic=0 AND status='Actual'` + `expires > now` |
| Minimal fetch | `curl 'URL/query?where=1%3D1&outFields=*&outSR=4326&resultRecordCount=2&f=json'` → ≥0 features, each with `info_event` and polygon rings | same shape, expect `event`, `severity` |
| Trap | field names carry the `info_` prefix; **note `(Read_only)` with parens must be URL-encoded `%28Read_only%29` in some HTTP clients** | `sent/effective/expires` are epoch-ms numbers in `f=json` |

## Live local conditions

| | `hilltop` (river/rain telemetry) | `electricity-outages` | `water-network-faults` |
|---|---|---|---|
| Endpoint | `https://hilltop.gw.govt.nz/Telemetry.hts` | `https://services5.arcgis.com/cJn6oR1QqErYBL5d/arcgis/rest/services/electricity_outages_read_only/FeatureServer/0` | `https://services7.arcgis.com/2ECs938g489DMWjt/arcgis/rest/services/Job_Status_Public_View/FeatureServer/5` |
| Publisher | Greater Wellington | NEMA (aggregating lines companies) | Wellington Water |
| Geometry / CRS | Points, **already WGS84** | Point / **EPSG:4326** | Point / **EPSG:2193** |
| Format | **Hilltop XML, not JSON** | ArcGIS JSON | ArcGIS JSON |
| Volume | 3,339 sites (2,787 with coords) | ~42 live (max 2000/req) | **~1,509 live** (max 2000/req — near cap, watch paging) |
| Key fields | `SiteList→lat/lng`; `GetData→<T> time + <I1>/<Value>`; units from `<Units>` | `locationname, numaffected(Int), status, outagetype, distributor, startdate(Date), enddate(Date), details, link` | `wonum, description, wtypedesc, status/StatusDescription, priority, reportdate(Date), wsadd_formattedaddress, watertype, location` |
| Minimal fetch | `curl 'https://hilltop.gw.govt.nz/Telemetry.hts?service=Hilltop&request=GetData&Site=Hutt%20River%20at%20Taita%20Gorge&Measurement=Stage&TimeInterval=PT6H'` → XML with `<Units>mm</Units>` and recent `<T>` timestamps | `curl 'URL/query?where=1%3D1&outFields=*&outSR=4326&f=json&resultRecordCount=5'` | same; add `&geometry=174.6,-41.4,175.0,-41.1&geometryType=esriGeometryEnvelope&inSR=4326` to clip to Wellington |
| Traps | **spaces must be `%20`, never `+`** (a `+` returns `<Error>No data…` with HTTP 200); errors arrive as HTTP 200 + `<Error>`; units differ per measurement — `Stage` is **mm** (24613 = 24.6 m), `Flow` is **m³/s**, `Rainfall` mm — read `<Units>`, never assume; not every site records every measurement (`MeasurementList` per site) | national feed — always bbox-filter to Wellington | large + noisy; filter `where=status NOT IN ('COMP','CLOSED')` after inspecting live status values |

Useful subsets of Hilltop sites for demo: south-coast-relevant gauges
(`Karori Stream…`, `Owhiro Stream…`, rainfall at `Berhampore at Nursery`).
Pick nearest-N by haversine at request time, don't hardcode.

## Static hazard context (all planning data — label as such)

| Dataset id | Endpoint (layer) | Geometry / CRS | Key fields | Note |
|---|---|---|---|---|
| `tsunami-evacuation-zones` | `https://gis.wcc.govt.nz/arcgis/rest/services/Environment/TsunamiEvacuationZones/MapServer/1` | Polygon / 2193 | `Evac_Zone, Zone_Class(SmallInt), Col_Code, Location, Info, Heights` | **G4 starter layer.** `Col_Code` is the public colour (Red/Orange/Yellow) |
| `stream-corridor` | `https://gis.wcc.govt.nz/arcgis/rest/services/DistrictPlanProposed/DistrictPlanProposed/MapServer/53` | Polygon / 2193 | district-plan flood layer (from WW hydraulic models) | same host as next three — share client + politeness budget |
| `overland-flowpath` | `…DistrictPlanProposed/MapServer/51` | Polyline / 2193 | | use *intersects small buffer* not point-in-poly (lines) — stretch, skip if tight |
| `ponding-areas` | `…DistrictPlanProposed/MapServer/52` | Polygon / 2193 | | |
| `coastal-inundation-medium` | `…DistrictPlanProposed/MapServer/39` | Polygon / 2193 | NIWA 2021, prepared for WCC | |
| `coastal-inundation-high` | `…DistrictPlanProposed/MapServer/40` | Polygon / 2193 | NIWA 2021 | |

Minimal fetch (point-in-polygon at Lyall Bay — proves the whole G4 pattern):

```bash
curl 'https://gis.wcc.govt.nz/arcgis/rest/services/Environment/TsunamiEvacuationZones/MapServer/1/query?geometry=174.7947,-41.3286&geometryType=esriGeometryPoint&inSR=4326&spatialRel=esriSpatialRelIntersects&outFields=*&outSR=4326&f=json'
```

Pass: ≥1 feature with an `Evac_Zone` attribute. Then the same URL with Karori
(`174.7405,-41.2865`) should return 0 features.

## Place anchors

| | `community-emergency-hubs` |
|---|---|
| Endpoint | `https://mapping.gw.govt.nz/arcgis/rest/services/GW/Emergencies_P/MapServer/2` |
| Publisher | WREMO |
| Geometry / CRS | Point / EPSG:2193 → `outSR=4326` |
| Count | **126** (fits one request; max 1000) |
| Key fields | `NAME, TYPE, ADDRESS, SUBURB, TOWN, TA_NAME` (+ `X, Y` — ignore, NZTM; use returned geometry) |
| Minimal fetch | `curl 'URL/query?where=1%3D1&outFields=*&outSR=4326&f=json' \| jq '.features \| length'` → 126 |

## Explicitly out (today)

- `storm-surge` (GW) — **raster-only**; advertises query, refuses to answer.
  Ask for a PNG export if the frontend wants it as a visual layer only.
- `flood-depths` / `flood-hazard-areas` — MapServer *roots* (no layer id in
  catalogue); enumerating sublayers costs time we spend elsewhere. Revisit
  post-G5 if hazard context feels thin.
- Raw MetService CAP XML (`alerts.metservice.com/cap/`) — superseded by the
  Eagle FeatureServer, which is the same alerts already as query-able polygons.
  Stretch: cross-check `identifier`s between the two.
- Social media / community reports — out per problem constraints; `trust`
  enum reserves the slot.

## Licence note

Data belongs to its publishers (WCC, GW, WREMO, NEMA, Wellington Water,
MetService/Eagle, NIWA). **Our code is AGPLv3; the data is not covered by our
licence.** Attribute the publisher on every rendered item (the `source` object
carries this — the frontend must show it).
