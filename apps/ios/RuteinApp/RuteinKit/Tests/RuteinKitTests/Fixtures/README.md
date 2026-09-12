# Test fixtures

Two kinds, kept apart on purpose.

## Synthetic

`minimal.gpx`, `malformed.gpx`, `waypoints-only.gpx`

Hand-written, minimal, and deterministic. Each exists to pin one shape — a valid single track, XML that cannot be parsed, a file whose only points are standalone waypoints. They make failures precise: when one breaks, the cause is the line that changed, not the file.

## Real exporter

`wikiloc-mt-agung.gpx` — Mt. Agung via Pura Pengubengan, exported by Wikiloc.

**Provenance:** published public trail, not a private recording. The file carries its own source URL in `<metadata><link>`, which is how it stays traceable. Recorded here because §20 lists repository visibility and licence as undecided — if this repo is ever published, redistribution of user-contributed Wikiloc content is the question to answer, and the answer needs to know where the file came from.

This is the fixture that covers §16's standing risk, *"GPX is inconsistent across exporters."* Synthetic files only prove the parser handles what we imagined; this one proves it handles what a real tool emitted.

What it exercises that the synthetic files cannot:

| Property | Why it matters |
| --- | --- |
| 256 track points in one segment | real volume, not three hand-placed rows |
| 7 waypoints before the track, two pairs sharing coordinates | rule that standalone waypoints form no route; ambiguity rules later |
| Elevation 1197.4 m to 3070.767 m, with real sensor noise | 3 m reversal threshold and median filter need noise to be meaningful |
| Latitude negative, longitude positive | a dropped minus sign survives any northern-hemisphere fixture |
| Timestamps spanning 29–30 September | midnight-rollover criterion has real data |
| `<metadata>`, `<link>`, `<cmt>`, `<desc>` present | elements the parser must ignore without tripping |

## Adding a real file of your own

Recorded runs are **private traces** and keeps them out of the repository; they are a log of where someone actually was. Keep them outside the repo and use them in the manual pass. A published trail with a public source URL is a different thing, and belongs here with its provenance written down.
