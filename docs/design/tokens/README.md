# Design token exports

Two Figma variable exports, committed so `tools/generate-colors.py` has an input
anyone can reproduce. Exported 14 September 2026.

| File | Figma file |
| --- | --- |
| `rutein.json` | Rutein — Product Design |
| `untitled-ui.json` | Untitled UI, the kit Rutein's variables were built from |

## Why both are needed

`rutein.json`'s `1. Color modes` collection carries **one** mode. Comparing all
273 semantic tokens by the primitive each references:

| Rutein's single mode equals | Count |
| --- | --- |
| Untitled UI **Dark mode** | 258 |
| Untitled UI **Light mode** | 13 |
| neither | 2 |

So the collection is Untitled UI's dark column; the light column was lost when
the collection was collapsed to one mode. The generator therefore takes the
**semantic-token → primitive mapping for both appearances from Untitled UI**,
and resolves it through **Rutein's primitives**.

That works because only 13 of 343 primitives differ, and 11 of those are the
complete Brand ramp — replaced with a warm tan/cream ramp where `Brand.100` is
`#F4F1E8`, the ground every frame is painted with. It is well-formed: zero
monotonic breaks, evenly stepped chroma.

## The two primitives the generator overrides

The remaining two differences are not part of any ramp:

| Slot | Untitled UI | Rutein | Why it is overridden |
| --- | --- | --- | --- |
| `Neutral.50` | `#FAFAFA` | `#3F3E38` | luminance 0.048 — darker than `Neutral.700`, in the ramp's **lightest** slot |
| `Neutral.400` | `#A3A3A3` | `#C95F32` | chroma 151 in a ramp whose every other step has chroma 0 |

Untitled UI maps dark `text-primary` to `Neutral.50`, so taken literally this
export renders dark primary text at **1.85:1** — unreadable. Every other ramp in
the file (Gray, Stone, Brand) is monotonic and low-chroma, which is what marks
these two as misplaced rather than deliberate.

**These overrides live in the generator, not in the export.** The Figma file
still has the original values; fixing it there is a separate task, after which
the overrides can be deleted.

## The one mapping override

Untitled UI's light `bg-primary` is `Base.white`. Every Rutein frame paints the
screen `Brand.100`, and no white appears anywhere in the design, so the
generator substitutes it. This is the app's only departure from Untitled UI's
semantic mapping.

## Naming

Leaf token names are unique across all 273 tokens and each already carries its
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

## Re-exporting

Figma → the variables plugin → export both files here under the same names, then
`rtk make ios-tokens`. `AppColorTests` re-resolves every colour set from these
files, so a stale regeneration or a hand-edited asset fails the test run.
