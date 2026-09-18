# Rutein

Turn a GPX file into a race-day plan.

Import a route, read its real numbers, enter a target finish time, and get a
checkpoint-by-checkpoint brief you can read at the trailhead or send to someone.

iOS 26, SwiftUI, Swift 6. Local only — no backend, no accounts, no network
layer, and it never asks for your location.

| | |
| --- | --- |
| Platform | iOS 26, iPhone. Swift 6 language mode, complete strict-concurrency checking |
| Tests | 178 across 26 suites, ~0.2s, no simulator |
| Size | 5,400 lines of Swift, 2,700 lines of tests |
| Localization | English and Bahasa Indonesia |
| Distribution | TestFlight, shipped from CI |

<!-- Screenshots: drop PNGs in docs/screenshots/ and fill the cells below.
     Library, route detail, brief. A short demo video is worth more than a sixth screenshot. -->

| Library | Route detail | Brief |
| --- | --- | --- |
| | | |

## Features

**Import.** GPX 1.1 and 1.0, tracks and routes, default and prefixed
namespaces. A file with several usable tracks opens a picker instead of
stitching them together. Parsing is cancellable and capped at 20 MiB, 100,000
points and 1,000 waypoints, checked while reading rather than after.

**Analysis.** Distance by Haversine at a fixed Earth radius. Ascent and descent
through a three-sample median filter with a 3 m reversal threshold, so GPS noise
does not inflate the climb. Coverage is reported as complete, partial or
unavailable, and partial coverage is labelled rather than quietly averaged.

**Elevation profile.** Swift Charts, draggable. The readout gives distance,
elevation and grade over a 100 m window. The line breaks at segment gaps and at
missing samples instead of drawing across them. VoiceOver gets one adjustable
value rather than 400 separate stops.

**Map.** The route as a polyline, start and finish distinguished by shape rather
than colour. Tapping opens a full-screen map with fit-to-route. Fits correctly
across the antimeridian.

**Planner.** Target duration from 1 minute to 48 hours. Average pace and every
checkpoint time come from `T × d / D`. Optional start time with an explicit IANA
zone, optional drink and fuel intervals in whole minutes.

**Brief.** Start, GPX checkpoints or generated 5 km markers, your intervals,
Finish. Waypoints more than 100 m off route get no estimate; waypoints sitting
on a section the track covers twice are flagged ambiguous instead of guessed.
Share as text or a rendered card, previewed first, never carrying coordinates or
the GPX itself.

**Storage.** SwiftData, with the source GPX copied into Application Support
under an app-owned filename. Rename, delete, duplicate detection by file
fingerprint, orphan file cleanup.

## Architecture

MVVM. `View ← ViewModel ← Repository ← Service`, one direction.

```
apps/ios/RuteinApp/
├── RuteinApp/                  app shell: project.yaml, xcconfig, Info.plist, icon
└── RuteinKit/                  one Swift package holding almost all the code
    └── Sources/RuteinKit/
        ├── App/                AppContainer, RootView
        ├── Core/
        │   ├── Domains/        value types, all Sendable
        │   ├── Repositories/   protocol, SwiftData impl, 3 schema versions
        │   ├── Services/       file store
        │   └── Utilities/      GPX parser, Haversine, elevation, checkpoints, formatting
        ├── DesignSystem/       AppColor, AppFont, Spacing, Radius, generated colour assets
        └── Features/           RouteLibrary, RouteDetail, RoutePlanner, RouteBrief
```

- ViewModels are `@MainActor @Observable`, owned by their view as
  `@State private`, injected through `AppContainer`. Never built in a view body.
- Async state is one `Loadable<T>`: `idle`, `loading(previous:)`, `loaded`,
  `failed(AppError, previous:)`. No `isLoading` + `data?` + `error?` triples.
  That is why a failed reload keeps the list on screen instead of blanking it.
- Parsing and geometry are `@concurrent async` over `Sendable` values. Not
  actors: they hold no mutable state, so an actor would serialize nothing.
- `DesignSystem/` cannot import `Core/` or `Features/`. A component promoted
  there takes primitives, not domain types.
- Code used by one feature stays in that feature. It moves to `Core/` when a
  second caller appears, not before.
- No networking layer, no `Infrastructure/` layer.

## Enforcement

`make ios-validate` runs format → lint → test → build. Ten checks fail the build
instead of relying on review:

| Check | Fails on |
| --- | --- |
| `unauthorized_comment` | any comment outside five allowed prefixes |
| `literal_design_token` | a literal colour, font, spacing, radius or shadow in a feature view |
| `no_parallel_logging` | a second `Logger`, `os_log`, `print` or `NSLog` outside `Core/Log.swift` |
| `localized_text_needs_bundle` | a `Text("…")` resolving against the wrong bundle |
| `no_any_view` / `no_untyped_dictionary` | `AnyView`, or `[String: Any]` in a domain API |
| `make ios-previews` | a `*View.swift` with no `#Preview` |
| `make ios-location-check` | `MapUserLocationButton`, `CLLocationManager`, an authorization request, an `NSLocation*` plist key |
| `make ios-concurrency-check` | `GPXParser.parse` or `RouteAnalyzer.analyse` losing `@concurrent` |
| `make ios-tokens-check` | a hand-edited colour asset, or one no design token generates |

Colour assets are generated from the Figma variables export by
`tools/generate-tokens.py`, which then verifies `Spacing`, `Radius` and the font
families against the same source. A colour that drifts from the design file
fails the build.

`Log` takes a stage, an `Int`, an `AppError` and an id it generates itself.
There is nowhere to put a route name, so route data cannot reach a log.

## Tests

178 tests in 26 suites, Swift Testing, run on the host with `swift test`. macOS
is a package platform purely so the suite needs no simulator; the whole run
finishes in about 0.2 seconds.

Expected values are calculated independently rather than read back from the code
under test. The Mount Agung fixture's 12,437.447 m was worked out in Python
before the Swift engine existed, and it is still what the suite asserts.

14 GPX fixtures: malformed XML, waypoint-only, missing and partial elevation,
two segments, two tracks, route-only, prefixed namespace, GPX 1.0, and a real
34 KB Wikiloc export of Mount Agung.

Two worth calling out:

- The SwiftData V1→V2 migration test writes a real V1 store to disk and reopens
  it through the migration plan. It runs as an exit test in a child process,
  because two schemas declaring the same entity name abort the whole run when
  both are live. The other 177 tests stay parallel.
- `OffMainExecutionTests` compares two functions differing only by
  `@concurrent`. Writing it showed the plain `nonisolated async` one also left
  the main actor, so `@concurrent` was doing nothing — SE-0461's caller-actor
  behaviour needs `NonisolatedNonsendingByDefault`, which was never enabled.
  It is now, so the annotation is load-bearing.

## Build and run

Needs Xcode 26.6 and:

```bash
brew install xcodegen swiftlint swiftformat
```

Then:

```bash
make ios-generate     # .xcodeproj is generated, never committed
make ios-test         # no simulator needed
make ios-run          # build, install, launch on the booted simulator
make help
```

A real route is committed at
`apps/ios/RuteinApp/RuteinKit/Tests/RuteinKitTests/Fixtures/wikiloc-mt-agung.gpx`
— Mount Agung via Pura Pengubengan. Copy it into the simulator's Files app and
import it. It reads 12.4 km and +1,872 m.

## Limits

- **No dark mode.** The app is locked to light. The design file has no dark
  column, and deriving one would have meant inventing values.
- **Basemap tile failure is not detected.** SwiftUI's `Map` exposes no failure
  signal. Offline, the polyline and endpoints still draw from vector data and
  every metric still reads.
- **An out-and-back can produce a short timeline.** Waypoints on a section
  covered twice are left out of timing by design. On the Mount Agung file that
  is 6 of 7 waypoints.
- **No measured performance figures.** Nothing here claims a launch time, frame
  rate or memory number.
- Out of scope: multiple plans per route, checkpoint editing, terrain-aware
  timing, offline basemaps, live tracking.

## Author

Wahyu Kurniawan. Built as a solo challenge at the Apple Developer Academy,
9–18 September 2026.
