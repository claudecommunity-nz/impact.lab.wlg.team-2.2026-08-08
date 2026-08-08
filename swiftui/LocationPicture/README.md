# Location Picture — SwiftUI client

Multiplatform **SwiftUI** map-first COP for the Team 2 Location Picture API.

**UX inspiration:** [Omega-Networks/Pulse](https://github.com/Omega-Networks/Pulse) interaction patterns (map-first shell, place selection, floating map chrome). This is **not** a Pulse fork and does **not** include NetBox/Zabbix/SSH.

Not a replacement for the Vite/React web UI in `frontend/`. Client only — backend stays open-source Vapor.

## Requirements

- Xcode 16+ (SwiftUI)
- macOS 14+ and/or iOS 17+ Simulator
- Backend: `cd server && swift run App` → `http://127.0.0.1:8080`

## Run

```bash
open LocationPicture.xcodeproj
```

| Destination | Shell |
|---|---|
| **My Mac** | `NavigationSplitView`: Places \| Map \| Picture inspector |
| **iPhone Simulator** | Full-bleed map + places sheet + picture sheet |

Default API base URL: `http://127.0.0.1:8080` (Settings gear). Info.plist allows local cleartext HTTP for lab demos.

## Features

| Mode | Behaviour |
|---|---|
| **Demo** | Scenario + Lyall Bay / Karori · picture + GeoJSON layers |
| **Live** | Presets · `/v1/picture` |

Map is primary. Select a place → camera + overlays + inspector update.

## Layout

```
LocationPicture/
  API/             URLSession client
  Models/          Place + API DTOs
  Services/        PictureStore (@Observable)
  DesignSystem/    tokens + chrome components
  Views/
    Places/        sidebar / sheet list
    Map/           MapKit canvas + layer chrome
    Picture/       inspector + detail sections
    Settings/      API base URL
  Support/         GeoJSON → overlays
```

## Licence

AGPL-3.0-or-later
