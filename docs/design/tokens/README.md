# Design token exports

Two Figma variable exports in **varzip** format, committed so
`tools/generate-tokens.py` has an input anyone can reproduce.

| File | Figma file | Exported |
| --- | --- | --- |
| `rutein.figvars.json` | Rutein — Product Design | 16 September 2026 |
| `untitled-ui.figvars.json` | Untitled UI, the kit Rutein's variables were built from | 15 September 2026 |

Both carry 691 variables across the same seven collections, and every value
resolves — **0 of 964 mode values unresolved**.

## The shape

A flat `variables` list. Each entry has a `sourceId`, a slash-separated `name`,
its `collectionSourceId`, a `type`, and `valuesByMode` keyed by mode id:

```json
"valuesByMode": {
  "5256:0": { "kind": "VALUE", "value": { "r": 1, "g": 1, "b": 1, "a": 1 } },
  "5353:0": { "kind": "ALIAS", "targetSourceVariableId": "VariableID:5248:377696" }
}
```

An `ALIAS` points at another variable by id, which may sit in a **single-mode**
collection — every spacing and radius token aliases into `_Primitives` that way.
`spacing-4xl` is not the number 32; it is an alias to `Spacing/8 (32px)`, which
is. Anything reading these files has to follow the alias rather than look for a
`value` key.

Each entry also carries `scopes` — Figma's own statement of what the variable
may fill (`TEXT_FILL`, `FRAME_FILL`, `CORNER_RADIUS`, `GAP`) — plus
`description` and `codeSyntax`.

## Why both files are needed

`rutein.figvars.json`'s `1. Color modes` collection has **one** mode, labelled
`Light mode`. But **225 of its 273 tokens still carry Untitled UI's *dark*
mapping**: `bg-primary` resolves to `#0A0A0A`. Read literally, the light
appearance would be a black screen — the opposite of every hi-fi frame.

So the generator takes the **semantic-token → primitive mapping for both
appearances from Untitled UI**, and resolves every primitive through
**Rutein's** export. Untitled UI states *which* primitive a token points at;
the colour of that primitive is Rutein's to define. Following Untitled UI's own
primitives would paint the app purple.

That works because outside `1. Color modes` the two files barely differ:

| Collection | Rutein | Differs from Untitled UI |
| --- | --- | --- |
| `3. Spacing` | 17 | 0 |
| `2. Radius` | 11 | 0 |
| `5. Containers` | 3 | 0 |
| `4. Widths` | 12 | 0 |
| `6. Typography` | 32 | 2 — the font families |

## The overrides, and why each exists

**`Colors/Neutral/50` → `#FAFAFA`, `Colors/Neutral/400` → `#A3A3A3`.**
Rutein's ramp holds `#3F3E38` and `#C95F32` in those slots. Neither is neutral
nor in lightness order: `Neutral.50` is darker than `Neutral.700` while
occupying the ramp's *lightest* slot, and `Neutral.400` carries chroma 151 where
every other step has chroma 0. Untitled UI maps dark `text-primary` to
`Neutral.50`, so taken literally the file renders dark primary text at
**1.85:1**. Every other ramp in the file — Gray, Stone, and Rutein's own Brand —
is monotonic and, where neutral, zero-chroma, which is what marks these two as
misplaced rather than chosen.

**`bg-primary` light → `Colors/Brand/100`.** Untitled UI's light `bg-primary` is
`Base.white`. Every Rutein frame paints the screen `Brand.100` (`#F4F1E8`) and
no white appears anywhere in the design. This is the app's only departure from
Untitled UI's semantic mapping.

**These overrides live in the generator, not in the exports.** The exports stay
faithful copies of the Figma files; fixing Figma is a separate task, after which
the overrides can be deleted.

## Naming

Leaf names are unique across all 273 colour tokens and each already carries its
group as a prefix (`bg-`, `text-`, `border-`, `fg-`, `utility-`), so the group
path is dropped. The trailing ` (NNN)` annotates the light-mode primitive step
and is not part of the name.

```
Figma        bg-primary          text-primary (900)
colour set   bgPrimary           textPrimary
Swift        AppColor.bgPrimary  AppColor.textPrimary
```

The colour-set name and the Swift property name are the same string, so they
cannot drift apart.

## What is generated and what is checked

| Tokens | Treatment |
| --- | --- |
| Colours | **generated** into `Colors.xcassets` |
| Spacing, radius | **checked** against hand-written `Spacing.swift` and `Radius.swift` |
| `font-family-display`, `font-family-body` | **checked** against what `AppFont` uses |

Spacing and radius are checked rather than generated because the owner writes
the Swift; a generated `.swift` would take that away, and a checker gives the
same drift protection. A constant that is not in the token map fails, and one
whose value is on no Figma scale is named as such — which is what retired
`Spacing.section = 36`.

The font check confirms Figma still expects Cormorant Garamond for display and
SF Pro for body. It cannot bind the code to SF Pro, and should not:
`Font.headline` is SF Pro because it is the *system* font, and that indirection
is what makes Dynamic Type work.

## Re-exporting

Export both files from Figma into this directory under the same names, then
`rtk make ios-tokens`. `rtk make ios-tokens-check` runs inside `ios-lint`, so a
stale regeneration or a hand-edited colour set fails `ios-validate`.

## Still to fix in Figma

- `1. Color modes` needs a real `Dark mode` column, and its `Light mode` values
  corrected to actually be light. Then the borrowed Untitled UI mapping goes.
- `Neutral.50` → `#FAFAFA` and `Neutral.400` → `#A3A3A3`, so the file stops
  rendering its own dark primary text at 1.85:1.
