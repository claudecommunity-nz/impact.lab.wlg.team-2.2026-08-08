# Demo data & endpoints

**Live** feeds stay under `/v1/*`. **Curated mock** data lives under `/v1/demo/*`
so judges never confuse staged scenarios with production GIS.

Mock scenarios are defined in code (`server/Sources/App/Demo/`).

---

## Quick start

```bash
cd server && swift run App

curl -s localhost:8080/v1/demo/scenarios | jq .
curl -s 'localhost:8080/v1/demo/picture?scenario=southerly-storm&point=lyall-bay' | jq .summary
```

### Map layers (GeoJSON — key for presentation)

```bash
# Same storm polygon at both points
curl -s 'localhost:8080/v1/demo/warnings?scenario=southerly-storm&point=lyall-bay&format=geojson' | jq .
curl -s 'localhost:8080/v1/demo/warnings?scenario=southerly-storm&point=karori&format=geojson' | jq .

# Planning polygons: Lyall Bay has tsunami + coastal; Karori has none
curl -s 'localhost:8080/v1/demo/hazards?scenario=southerly-storm&point=lyall-bay&format=geojson' | jq '{n:(.features|length), ids:[.features[].properties.id]}'
curl -s 'localhost:8080/v1/demo/hazards?scenario=southerly-storm&point=karori&format=geojson' | jq '.features|length'

# Pins: gauges, outages, water faults, nearest hub
curl -s 'localhost:8080/v1/demo/conditions?scenario=southerly-storm&point=lyall-bay&format=geojson' | jq '{n:(.features|length), kinds:[.features[].properties.kind]}'
```

Drop any of those FeatureCollections straight into MapLibre / geojson.io.

---

## Demo endpoints

| Path | Params | Returns |
|---|---|---|
| `/v1/demo/scenarios` | — | Catalogue |
| `/v1/demo/picture` | `scenario`, `point` | Full `LocationPicture` |
| `/v1/demo/warnings` | `scenario`, `point`, `format?` | JSON section **or** **Polygon** GeoJSON |
| `/v1/demo/conditions` | `scenario`, `point`, `format?` | JSON section **or** **Point** GeoJSON |
| `/v1/demo/hazards` | `scenario`, `point`, `format?` | JSON section **or** **Polygon** GeoJSON |

`format=geojson` (default `json`). Unknown scenario/point → **404**.

### Points

| `point` | Place | Coords |
|---|---|---|
| `lyall-bay` | Lyall Bay | `-41.3286, 174.7947` |
| `karori` | Karori | `-41.2865, 174.7405` |

### Scenarios

| `scenario` | Intent |
|---|---|
| **`southerly-storm`** | Same Heavy Rain Warning polygon at both points; Lyall has tsunami + coastal **polygons** + pins; Karori has warning only (no coastal polygons), different pins. |
| **`calm-day`** | No warnings; planning polygons still differ by point. |
| **`degraded`** | Conditions unavailable; warnings (with polygon) + hazards still present. |

### Map polygons (real GIS only — never invented)

Demo **picture text** can be staged for pitch rehearsal. Demo **map GeoJSON**
always pulls live geometry:

| Layer | Source |
|---|---|
| Warning polygons | MetService + NEMA CAP FeatureServers (empty when CAP is calm) |
| Hazard polygons | WCC ArcGIS (tsunami, coastal inundation, stream corridor) at the demo point |

No schematic / 4-corner “boxes”. If the map has no warning polygon, CAP is calm
— that is correct for a real platform.

---

## Live API (unchanged)

`/healthz`, `/v1/hubs`, `/v1/warnings`, `/v1/conditions`, `/v1/hazards`, `/v1/picture`  

GeoJSON (real rings / points):

- `/v1/hubs?format=geojson` — WREMO hubs  
- `/v1/warnings?format=geojson` — CAP polygons  
- `/v1/hazards?lat&lng&format=geojson` — WCC planning polygons at point  

---

## Code

```
server/Sources/App/Demo/
  DemoModels.swift
  DemoScenarioData.swift   # scenarios + rings
  DemoService.swift
```
