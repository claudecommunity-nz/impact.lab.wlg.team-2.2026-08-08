# Location Picture — SwiftUI client

Multiplatform **SwiftUI** app (macOS + iOS) that visualises the Team 2 Location Picture API.

Not a replacement for the Vite/React web UI in `frontend/`. Client only — backend stays open-source Vapor.

## Requirements

- Xcode 16+ (SwiftUI)
- macOS 14+ and/or iOS 17+ Simulator
- Backend: `cd server && swift run App` → `http://127.0.0.1:8080`

## Run

```bash
open LocationPicture.xcodeproj
```

In Xcode, pick a destination:

- **My Mac** — native macOS SwiftUI window  
- **iPhone Simulator** — iOS  

Default API base URL: `http://127.0.0.1:8080` (editable in-app for LAN devices).

Info.plist allows local cleartext HTTP for lab demos.

## Features

| Mode | Behaviour |
|---|---|
| **Demo** | `/v1/demo/scenarios`, picture + GeoJSON map layers |
| **Live** | `/v1/picture` for Lyall Bay / Karori / CBD / custom lat·lng |

Map: warning & hazard polygons, condition pins, hub + query point.  
Panels: summary, warnings, conditions, hazards, sources, disclaimer.

## Layout

```
LocationPicture/
  API/        URLSession client
  Models/     Codable DTOs (API contract)
  Services/   PictureStore
  Views/      Demo/Live, map, picture detail
  Support/    GeoJSON → MapKit, theme
```

## Licence

AGPL-3.0-or-later
