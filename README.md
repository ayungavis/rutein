# Rutein

**Turn every route into a plan.**

An iOS app for trail runners. Import a GPX file and Rutein reads the route —
distance, climbing, the key climb, the elevation profile, the line on a map —
then turns a target finish time into a checkpoint-by-checkpoint brief you can
read at the trailhead or send to a friend.

Local only. No backend, no accounts, no network layer, no location permission.

| | |
| --- | --- |
| **Platform** | iOS 26, iPhone · SwiftUI · Swift 6.3 in Swift 6 language mode, complete strict-concurrency checking |
| **Built** | 9–18 September 2026 — seven build days plus a submission day, as an Apple Developer Academy solo challenge |
| **Status** | All ten functional requirements implemented; shipped to TestFlight from CI. Dark mode is deliberately deferred — see [Known limits](#known-limits) |
| **Scale** | 5,417 lines of Swift across 77 files · 2,763 lines of tests · **178 tests in 26 suites**, running in ~0.2 s with no simulator |
| **Languages** | English and Bahasa Indonesia, 135 String Catalog keys |

---

## Screens

> **Fill me in.** Capture these from the simulator or a device and drop them in
> `docs/screenshots/`. Six is plenty; put the library, the route detail and the
> brief first.

| Library | Route detail | Brief |
| --- | --- | --- |
| _screenshot_ | _screenshot_ | _screenshot_ |

> A 60–90 second demo video is the single highest-value thing to add here.

---

## What it does

**Import** — Pick a GPX from Files. Rutein supports GPX 1.1 and 1.0, tracks and
routes, default and prefixed namespaces. If a file holds more than one usable
track it asks which one rather than stitching them together. Parsing is
cancellable and bounded: 20 MiB, 100,000 geometry points, 1,000 waypoints,
enforced *while reading* rather than after.

**Understand the route** — Distance and ascent/descent from a documented
Haversine + median-filter pipeline, an elevation profile you can drag to inspect
any point (distance, elevation, and grade over a 100 m window), the route drawn
on a map, and the key sustained climb named with its range, gain and average
grade.

**Plan it** — Enter a target elapsed time. Rutein derives average pace and, from
`T × d / D`, an estimated time at every checkpoint. Optional start time with an
explicit time zone; optional drink and fuel intervals.

**Read and share the brief** — An ordered timeline of Start, GPX checkpoints or
generated distance markers, your intervals, and Finish. Share it as plain text
or as a rendered card. The payload is previewed with a disclosure before any
share sheet opens, and never contains a coordinate or the GPX itself.

**Keep it** — Routes and plans persist locally. The source GPX is copied into
Application Support under an app-owned filename; reopening reparses it. Rename,
delete, and duplicate detection by file fingerprint.

---

## Why this repo might be worth five minutes

This was a learning challenge, so the interesting part is not that the app
works — it is what the repository does to *keep* it working.

### Rules are build failures, not conventions

`make ios-validate` runs format → lint → test → build. Six custom SwiftLint
rules and four shell gates encode requirements that a reviewer would otherwise
have to remember:

| Gate | What it refuses to let through |
| --- | --- |
| `unauthorized_comment` | Any comment without one of five allowed prefixes. The codebase has no explanatory comments by design; reasoning lives in the decision notes. |
| `literal_design_token` | A literal colour, font, spacing value, corner radius or shadow in a feature view. Tokens are defined in `DesignSystem/` and nowhere else. |
| `no_parallel_logging` | A second `Logger`, `os_log`, `print` or `NSLog` outside `Core/Log.swift`. `Log` accepts only a stage, an `Int`, an `AppError` and an id it generates — so a route name cannot reach a log through it. |
| `localized_text_needs_bundle` | A `Text("…")` that would resolve against the wrong bundle inside the package. |
| `no_any_view` | `AnyView`. Type erasure for routine branching hides structure; use generics or `@ViewBuilder`. |
| `no_untyped_dictionary` | `[String: Any]` in a domain API. |
| `make ios-previews` | A `*View.swift` with no `#Preview`. SwiftLint cannot express it: custom rules flag matches, and this rule is about absence. |
| `make ios-location-check` | `MapUserLocationButton`, a `CLLocationManager`, an authorization request, or an `NSLocation*UsageDescription` key. The app must never ask for location. |
| `make ios-concurrency-check` | `GPXParser.parse` or `RouteAnalyzer.analyse` losing `@concurrent`. |
| `make ios-tokens-check` | A hand-edited colour asset, a stale regeneration, or a colour set no design token generates. |

Most of these were broken on purpose to confirm they fail before being trusted,
and the mutation is recorded in the step note that added them. Two earned their
keep immediately: the token check caught a colour copied from the wrong design
file, and the design-token rule turned out not to be running at all because
SwiftLint had served a cached result — which is why `ios-lint` passes
`--no-cache`.

### Design tokens are generated from the Figma export

`tools/generate-tokens.py` reads the Figma variables export committed in
`docs/design/tokens/` and generates `Colors.xcassets`, then verifies the
hand-written `Spacing`, `Radius` and font families against the same source.
A colour that drifts from the design file fails the build rather than the
review.

### A concurrency rule that turned out to be false

The project documentation asserted that since SE-0461 a plain `nonisolated async`
function runs on the caller's actor, so `@concurrent` was what kept GPX parsing
off the main thread. Writing the test the architecture demanded — two functions
differing only by the annotation — showed the plain one hopping off-main too:
SE-0461's behaviour needs the `NonisolatedNonsendingByDefault` upcoming feature,
which was never enabled. For twenty-nine steps `@concurrent` had been
decorative. The feature is enabled now, so the rule is load-bearing, and the
documentation records what it depends on.

[Step 30](docs/steps/30-observability.md) has the measurement.

### Persistence with real schema versions

Three `VersionedSchema` versions and two lightweight migration stages, versioned
from the first persisted schema rather than retrofitted once a migration hurt. The V1→V2 migration test writes a genuine
V1 store to disk and reopens it through the plan — and it runs as a **Swift
Testing exit test**, in its own child process, because two SwiftData schemas
declaring the same entity name abort the whole test run when they are live
concurrently. That keeps the other 177 tests parallel.

### Decisions are written down while they are being made

[`docs/steps/`](docs/steps/) holds **31 notes**, one per implementation step,
each recording what changed, which PRD requirement demanded it, *what was
rejected and on what evidence*, the code, and how to verify it. They exist for
the part git cannot hold. A few that show the shape:

- [08 — Distance, and the analysis boundary](docs/steps/08-distance-engine.md)
- [17 — Import a GPX and read its numbers](docs/steps/17-import-to-detail.md) — the
  step that caught `Measurement.formatted` silently rendering 12 437 m as
  **7.7 mi** under a US locale
- [23 — Waypoints, and what a real out-and-back does to them](docs/steps/23-checkpoints.md) — where
  the spec met a real Wikiloc export and produced a thin timeline, recorded
  rather than worked around
- [26 — Point inspection, and a chart that stopped lying about gaps](docs/steps/26-point-inspection.md)

---

## Architecture

MVVM with a single Swift package. `View ← ViewModel ← Repository ← Service`,
one direction only.

```
apps/ios/RuteinApp/
├── RuteinApp/              iOS app shell — project.yaml, xcconfig, Info.plist, app icon
└── RuteinKit/              one Swift package, where almost all the code lives
    └── Sources/RuteinKit/
        ├── App/            AppContainer (composition root), RootView
        ├── Core/           AppError, Loadable, Log
        │   ├── Domains/    domain value types, all Sendable — no reference semantics here
        │   ├── Repositories/  protocol + SwiftData implementation + 3 schema versions
        │   ├── Services/   file store
        │   └── Utilities/  GPX parser, Haversine, elevation analysis, checkpoints, formatting
        ├── DesignSystem/   AppColor, AppFont, Spacing, Radius, generated Colors.xcassets
        └── Features/       RouteLibrary, RouteDetail, RoutePlanner, RouteBrief
```

Binding rules the code is held to:

- Every feature is `<Name>View.swift` + `<Name>ViewModel.swift`. ViewModels are
  `@MainActor @Observable`, owned by their view as `@State private`, and
  injected — never constructed in a view body.
- Async state is one `Loadable<T>` (`idle` / `loading(previous:)` / `loaded` /
  `failed(AppError, previous:)`), never an `isLoading` + `data?` + `error?`
  triple. That is why a failed reload keeps the list already on screen instead
  of blanking it.
- Parsing and geometry are `@concurrent async` functions over `Sendable` values
  — not actors, because they hold no mutable state.
- `DesignSystem/` may not import `Core/` or `Features/`, so a component promoted
  there takes primitives, never domain types.
- **Placement follows use.** Code used by one feature lives in that feature;
  code with a second caller moves to `Core/`. It moves when the second caller
  appears, not in anticipation.
- No `Infrastructure/` layer and no networking layer. Building one to mirror a
  reference diagram is explicitly forbidden.

---

## How correctness is checked

```bash
make ios-validate     # format → lint (+ 4 gates) → test → build
```

**178 tests in 26 suites**, written with Swift Testing and running on the host
via `swift test` — no simulator boot, so the whole suite finishes in about
0.2 seconds. `macOS` is declared as a package platform for exactly that reason.

Numbers in tests are independently calculated, not read back from the code they
check. The Mt Agung fixture's 12,437.447 m was computed in Python before the
Swift engine existed, and it is still the number the suite asserts. 14 GPX
fixtures cover malformed XML, waypoint-only files, missing and partial
elevation, two segments, two tracks, a route-only file, a prefixed namespace,
GPX 1.0, and one real 34 KB Wikiloc export of Mount Agung.

CI runs the same validation on every push and ships to TestFlight from
`main` ([`.github/workflows/`](.github/workflows/)).

---

## Running it

Requires Xcode 26.6, Swift 6.3.3, and [XcodeGen](https://github.com/yonaskolb/XcodeGen),
[SwiftLint](https://github.com/realm/SwiftLint), [SwiftFormat](https://github.com/nicklockwood/SwiftFormat).

```bash
brew install xcodegen swiftlint swiftformat
make ios-generate     # RuteinApp.xcodeproj is generated, never committed
make ios-test         # unit tests, no simulator needed
make ios-run          # build, install and launch on the booted simulator
make help             # everything else
```

There is a real GPX committed at
`apps/ios/RuteinApp/RuteinKit/Tests/RuteinKitTests/Fixtures/wikiloc-mt-agung.gpx`
— a public Wikiloc export of Mount Agung via Pura Pengubengan. Copy it into the
simulator's Files app and import it; it should read 12.4 km and +1,872 m.

---

## Known limits

Stated plainly, because the PRD requires deferred scope to be explicit rather
than implied.

- **Dark mode is deferred.** The app is locked to light and the release check is
  that it *stays* light with the device set to dark — not that a dark palette
  reads well. The design file has no dark column, and deriving one would have
  meant inventing values. [Step 16](docs/steps/16-light-only-palette.md) records
  the reasoning and the PRD amendment.
- **Basemap tile failure is not detected.** SwiftUI's `Map` exposes no failure
  signal. Offline, the route polyline and its endpoints still draw from vector
  data and every metric still reads; the fallback block appears when a route has
  no plottable coordinates. The upgrade path is an `MKMapView` wrapper.
- **An out-and-back can produce a thin timeline.** Waypoints on a section the
  track covers twice are marked ambiguous and omitted from timing, per the
  analysis contract. On the Mount Agung export that is 6 of 7 waypoints.
  [Step 23](docs/steps/23-checkpoints.md) measures it and proposes an amendment.
- **Performance budgets are targets, not results.** Nothing in this repository
  claims a measured launch time, frame rate or memory figure.
- No multiple plans per route, no checkpoint editing, no terrain-aware timing,
  no offline basemaps, no live tracking. Those are scoped out, not missing.

---

## Repository map

| Path | What it holds |
| --- | --- |
| [`docs/prd.md`](docs/prd.md) | The product requirements document — the behavioural source of truth. When code and PRD disagree, the PRD wins and the stale side gets fixed. |
| [`docs/steps/`](docs/steps/) | 31 implementation notes: what changed, why, what was rejected, and how to verify |
| [`docs/design/tokens/`](docs/design/tokens/) | Figma variable exports the design tokens are generated from |
| [`tools/generate-tokens.py`](tools/generate-tokens.py) | Generates and verifies `Colors.xcassets`, spacing, radius and fonts |
| [`Makefile`](Makefile) | Every command, including the build gates |
| [`.swiftlint.yml`](.swiftlint.yml) | Six custom rules encoding PRD requirements |
| [`CLAUDE.md`](CLAUDE.md) | Working conventions for this repository |

---

## Context

Rutein was built as a solo challenge at the Apple Developer Academy, from a
written PRD accepted before any code existed. The PRD, the decision notes, and
the build gates are the deliverable as much as the app is: the exercise was to
find out whether writing the requirement down first, and then making the
requirement mechanically enforceable, actually changes what gets built.

It did. Several of the notes record the PRD catching the implementation —
including one where a formatter would have shown a 12 km route as 7.7 miles to
every American user, and one where the chart was drawing terrain that was not in
the file.

**Author** — Wahyu Kurniawan · [`docs/prd.md`](docs/prd.md) for the full
specification.
