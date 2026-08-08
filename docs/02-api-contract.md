# API Contract — Location Picture service

Base URL (dev): `http://localhost:8080`. All endpoints `GET`, no auth,
CORS `*`. This is the contract the frontend builds against — **breaking it
after G5 requires telling the frontend workstream first.**

## Conventions

- All coordinates WGS84. `lat`/`lng` as decimal degrees.
- Every data item carries `source` (see `SourceMeta`) — no orphan facts.
- Timestamps: ISO 8601 UTC (`2026-08-08T02:15:00Z`). Clients render age.
- `trust` is one of `official` | `lifeline` | `planning` | `community-unverified`
  (last one unused in v1, reserved).
- Errors are JSON: `{"error": true, "reason": "…"}` with proper status codes.
- `?format=geojson` on list endpoints returns a `FeatureCollection` instead of
  the JSON envelope — this is how the shared COP map consumes us.

## Endpoints

| Path | Params | Returns |
|---|---|---|
| `/healthz` | — | `{"status":"ok","uptime":…}` |
| `/v1/hubs` | `bbox?` (w,s,e,n), `format?` | all community emergency hubs (126) |
| `/v1/warnings` | `lat?`, `lng?`, `format?` | active CAP warnings; filtered to those covering the point if given |
| `/v1/conditions` | `lat`, `lng`, `n?`=5, `radiusKm?`=10 | nearest live signals: gauges, outages, water faults |
| `/v1/hazards` | `lat`, `lng` | static hazard layers containing the point |
| `/v1/picture` | `lat`+`lng` **or** `hub=<id>` | the full Location Picture (below) |
| `/v1/hotspots` | — | (G7, optional) clustered elevated live points |

## Shared objects

```jsonc
// SourceMeta — attached to every item
{
  "name": "MetService (via Eagle CAP feed)",   // human label, includes publisher
  "id": "metservice-warnings",                 // catalogue id
  "trust": "official",
  "fetchedAt": "2026-08-08T02:14:30Z",         // when WE pulled it
  "url": "https://services.arcgis.com/XTtANUDT8Va4DLwI/arcgis/rest/services/Metservice_Weather_Alerts/FeatureServer/0"
}
```

## `GET /v1/picture?lat=-41.3286&lng=174.7947` — full example

```jsonc
{
  "location": {
    "lat": -41.3286, "lng": 174.7947,
    "nearestHub": {
      "id": 87, "name": "Lyall Bay Community Centre",
      "address": "36 Freyberg Street", "suburb": "Lyall Bay",
      "lat": -41.3271, "lng": 174.7960, "distanceKm": 0.2,
      "source": { "name": "WREMO Community Emergency Hubs", "id": "community-emergency-hubs", "trust": "official", "fetchedAt": "2026-08-08T01:30:00Z" }
    }
  },

  "officialWarnings": {
    "status": "ok",
    "items": [
      {
        "id": "urn:oid:2.49.0.1.554.0.…",          // CAP identifier
        "event": "Heavy Rain Warning",
        "headline": "Heavy Rain Warning for Wellington",
        "severity": "Moderate",                     // CAP enum, verbatim
        "urgency": "Expected",
        "certainty": "Likely",
        "areaDesc": "Wellington",
        "onset": "2026-08-08T06:00:00Z",
        "expires": "2026-08-08T18:00:00Z",
        "description": "Periods of heavy rain. Expect 80 to 100 mm…",  // verbatim from source
        "web": "https://www.metservice.com/warnings",
        "source": { "name": "MetService (via Eagle CAP feed)", "id": "metservice-warnings", "trust": "official", "fetchedAt": "2026-08-08T02:14:30Z" }
      }
    ]
  },

  "localConditions": {
    "status": "ok",
    "gauges": [
      {
        "site": "Karori Stream at Makara Peak",
        "lat": -41.2957, "lng": 174.7275, "distanceKm": 5.9,
        "measurement": "Stage", "value": 24613, "units": "mm",
        "observedAt": "2026-08-08T02:10:00Z",
        "trend": "rising",                          // omit if <2 readings
        "source": { "name": "Greater Wellington Hilltop telemetry", "id": "hilltop", "trust": "official", "fetchedAt": "2026-08-08T02:14:45Z" }
      }
    ],
    "electricityOutages": [
      {
        "locationName": "Kilbirnie", "distanceKm": 1.4,
        "numAffected": 120, "status": "Active", "outageType": "Unplanned",
        "distributor": "Wellington Electricity",
        "startedAt": "2026-08-08T01:05:00Z", "link": "https://…",
        "source": { "name": "NEMA national electricity outages", "id": "electricity-outages", "trust": "lifeline", "fetchedAt": "2026-08-08T02:14:50Z" }
      }
    ],
    "waterFaults": [
      {
        "description": "No water — burst main", "address": "Onepu Road, Lyall Bay",
        "distanceKm": 0.6, "status": "In Progress", "priority": "P2",
        "reportedAt": "2026-08-07T22:40:00Z",
        "source": { "name": "Wellington Water network faults", "id": "water-network-faults", "trust": "lifeline", "fetchedAt": "2026-08-08T02:14:55Z" }
      }
    ]
  },

  "hazardContext": {
    "status": "ok",
    "note": "Planning layers — where hazards CAN occur, not live conditions.",
    "items": [
      {
        "layer": "Tsunami Evacuation Zones", "id": "tsunami-evacuation-zones",
        "value": "Red Zone", "detail": "Zone_Class 1 — evacuation zone closest to shore",
        "publisher": "Wellington City Council",
        "source": { "name": "WCC Tsunami Evacuation Zones", "id": "tsunami-evacuation-zones", "trust": "planning", "fetchedAt": "2026-08-08T01:30:10Z" }
      },
      {
        "layer": "Coastal Inundation (Medium)", "id": "coastal-inundation-medium",
        "value": "inside", "publisher": "Wellington City Council / NIWA (2021)",
        "source": { "name": "WCC Proposed District Plan", "id": "coastal-inundation-medium", "trust": "planning", "fetchedAt": "2026-08-08T01:30:12Z" }
      }
    ]
  },

  "summary": [
    "1 official warning covers this location: Heavy Rain Warning (Moderate), in force until 6:00 am Sunday 9 Aug (NZST).",
    "Nearest river gauge (Karori Stream, 5.9 km) last read 24.6 m stage at 02:10 UTC, rising.",
    "1 electricity outage within 10 km: Kilbirnie, ~120 customers, since 01:05 UTC.",
    "1 water fault within 10 km: burst main on Onepu Road, in progress.",
    "This location is inside the WCC tsunami evacuation zone (Red) and medium coastal inundation planning area.",
    "Nearest community emergency hub: Lyall Bay Community Centre, 200 m."
  ],

  "generatedAt": "2026-08-08T02:15:00Z",
  "sources": [
    { "id": "metservice-warnings", "fetchedAt": "2026-08-08T02:14:30Z", "status": "ok" },
    { "id": "nema-cap-alerts",     "fetchedAt": "2026-08-08T02:14:32Z", "status": "ok" },
    { "id": "hilltop",             "fetchedAt": "2026-08-08T02:14:45Z", "status": "ok" },
    { "id": "electricity-outages", "fetchedAt": "2026-08-08T02:14:50Z", "status": "ok" },
    { "id": "water-network-faults","fetchedAt": "2026-08-08T02:14:55Z", "status": "ok" },
    { "id": "tsunami-evacuation-zones", "fetchedAt": "2026-08-08T01:30:10Z", "status": "ok" },
    { "id": "community-emergency-hubs", "fetchedAt": "2026-08-08T01:30:00Z", "status": "ok" }
  ],
  "disclaimer": "Information, not advice. Hazard layers are planning data, not live conditions. In an emergency call 111."
}
```

### Summary rules (enforced in `PictureService`)

- Facts only, one sentence per fact, each traceable to an item in the payload.
- Numbers verbatim from source (converted units allowed if labelled).
- **Banned words:** should, must, evacuate, immediately, do not, safe, unsafe.
  A unit test greps the summary builder's output for these.
- Empty is honest: "No official warnings currently cover this location."

### Degraded-source shape

Any section whose upstream failed:

```jsonc
"localConditions": {
  "status": "unavailable",
  "reason": "hilltop.gw.govt.nz timed out",
  "lastGood": { …previous payload… },       // omitted if never fetched
  "lastGoodAt": "2026-08-08T01:58:00Z"
}
```

HTTP status stays 200 — a partial picture is still a picture.

## `GET /v1/hubs` envelope (pattern for all list endpoints)

```jsonc
{
  "items": [ { "id": 87, "name": "Lyall Bay Community Centre", "type": "Community Centre",
               "address": "36 Freyberg Street", "suburb": "Lyall Bay", "town": "Wellington",
               "lat": -41.3271, "lng": 174.7960 } ],
  "count": 126,
  "source": { "name": "WREMO Community Emergency Hubs", "id": "community-emergency-hubs", "trust": "official", "fetchedAt": "…" },
  "generatedAt": "…"
}
```

`?format=geojson` → `FeatureCollection` of Points, properties = the same
fields minus lat/lng. Same rule for `/v1/warnings` (Polygons).
