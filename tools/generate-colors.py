#!/usr/bin/env python3
"""Generate Colors.xcassets from the exported Figma design tokens.

Untitled UI supplies the semantic-token -> primitive mapping for both
appearances. Rutein supplies the primitives. See docs/design/tokens/README.md
for why it is split that way and what the two overrides below are for.

Run with `make ios-tokens`.
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOKENS = ROOT / "docs" / "design" / "tokens"
CATALOG = (
    ROOT
    / "apps/ios/RuteinApp/RuteinKit/Sources/RuteinKit/DesignSystem/Resources/Colors.xcassets"
)

# Figma leaf names, verbatim. Leaf names are unique across all 273 tokens, so
# the group path ("Colors.Background." and friends) carries no information.
EXPORTED = [
    "bg-primary",
    "text-primary (900)",
    "text-secondary (700)",
]

# Two slots in Rutein's Neutral ramp hold colours that are not neutral and not
# in lightness order: Neutral.50 is darker than Neutral.700 while occupying the
# ramp's lightest slot, and Neutral.400 carries chroma 151 where every other
# step has chroma 0. Untitled UI maps dark `text-primary` to Neutral.50, so
# taken literally the file renders dark primary text at 1.85:1.
PRIMITIVE_OVERRIDES = {
    "_Primitives.Colors.Neutral.50": "#fafafa",
    "_Primitives.Colors.Neutral.400": "#a3a3a3",
}

# The one place the app departs from Untitled UI's mapping. Untitled UI's light
# `bg-primary` is Base.white; every Rutein frame paints the screen Brand.100,
# and no white appears anywhere in the design.
MAPPING_OVERRIDES = {
    ("bg-primary", "Light mode"): "{_Primitives.Colors.Brand.100}",
}

LIGHT, DARK = "Light mode", "Dark mode"


def leaves(node, path="", out=None):
    out = {} if out is None else out
    if isinstance(node, dict):
        if "$value" in node:
            out[path] = node["$value"]
        else:
            for key, value in node.items():
                if not key.startswith("$"):
                    leaves(value, f"{path}.{key}" if path else key, out)
    return out


def resolve(ref, primitives, depth=0):
    if depth > 8 or not isinstance(ref, str):
        raise ValueError(f"unresolvable reference: {ref!r}")
    match = re.fullmatch(r"\{(.+)\}", ref.strip())
    if not match:
        return ref
    name = match.group(1)
    if name not in primitives:
        raise KeyError(f"missing primitive {name}")
    return resolve(primitives[name], primitives, depth + 1)


def asset_name(token):
    stripped = re.sub(r"\s*\(\d+\)$", "", token).strip()
    head, *tail = re.split(r"[-_]", stripped)
    return head + "".join(word[:1].upper() + word[1:] for word in tail)


def components(hex_value):
    digits = hex_value.lstrip("#")
    if len(digits) not in (6, 8):
        raise ValueError(f"unexpected colour {hex_value!r}")
    return {
        "alpha": "1.000",
        "red": f"0x{digits[0:2].upper()}",
        "green": f"0x{digits[2:4].upper()}",
        "blue": f"0x{digits[4:6].upper()}",
    }


def colorset(light, dark):
    return {
        "colors": [
            {
                "color": {"color-space": "srgb", "components": components(light)},
                "idiom": "universal",
            },
            {
                "appearances": [{"appearance": "luminosity", "value": "dark"}],
                "color": {"color-space": "srgb", "components": components(dark)},
                "idiom": "universal",
            },
        ],
        "info": {"author": "xcode", "version": 1},
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="verify the committed catalogue matches the tokens; write nothing",
    )
    args = parser.parse_args()

    rutein = json.loads((TOKENS / "rutein.json").read_text())
    untitled = json.loads((TOKENS / "untitled-ui.json").read_text())

    primitives = leaves(rutein["_Primitives"], "_Primitives")
    primitives.update(PRIMITIVE_OVERRIDES)

    semantic = leaves(untitled["1. Color modes"])
    by_leaf = {}
    for path, value in semantic.items():
        by_leaf.setdefault(path.split(".")[-1], []).append(value)

    expected = {}

    for token in EXPORTED:
        matches = by_leaf.get(token, [])
        if len(matches) != 1:
            sys.exit(f"{token!r} matched {len(matches)} tokens, expected exactly 1")

        modes = matches[0]
        if not isinstance(modes, dict) or LIGHT not in modes or DARK not in modes:
            sys.exit(f"{token!r} does not carry both appearances")

        refs = {
            mode: MAPPING_OVERRIDES.get((token, mode), modes[mode])
            for mode in (LIGHT, DARK)
        }
        light = resolve(refs[LIGHT], primitives)
        dark = resolve(refs[DARK], primitives)

        expected[asset_name(token)] = (token, light, dark)

    if args.check:
        return check(expected)

    for stale in CATALOG.glob("*.colorset"):
        shutil.rmtree(stale)

    CATALOG.mkdir(parents=True, exist_ok=True)
    (CATALOG / "Contents.json").write_text(
        json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n"
    )

    for name, (token, light, dark) in expected.items():
        target = CATALOG / f"{name}.colorset"
        target.mkdir()
        (target / "Contents.json").write_text(
            json.dumps(colorset(light, dark), indent=2) + "\n"
        )
        note = "  (light overridden)" if (token, LIGHT) in MAPPING_OVERRIDES else ""
        print(f"  {name:<16} {token:<22} {light}  {dark}{note}")

    print(f"{len(expected)} colour sets written to {CATALOG.relative_to(ROOT)}")


def check(expected):
    """Fail when the committed catalogue disagrees with the tokens.

    Catches both a hand-edited colour set and a re-export that was never
    regenerated, which a contrast test cannot tell apart from a deliberate
    change.
    """
    problems = []
    found = {path.name[: -len(".colorset")] for path in CATALOG.glob("*.colorset")}

    for extra in sorted(found - set(expected)):
        problems.append(f"{extra}.colorset is not generated from any token")

    for name, (token, light, dark) in expected.items():
        path = CATALOG / f"{name}.colorset" / "Contents.json"
        if not path.exists():
            problems.append(f"{name}.colorset is missing — token {token!r}")
            continue
        if json.loads(path.read_text()) != colorset(light, dark):
            problems.append(
                f"{name}.colorset does not match token {token!r} ({light} / {dark})"
            )

    if problems:
        print("Colour catalogue is out of date with docs/design/tokens:")
        for problem in problems:
            print(f"  {problem}")
        print("Run `make ios-tokens` to regenerate.")
        sys.exit(1)

    print(f"tokens OK — {len(expected)} colour sets match docs/design/tokens")


if __name__ == "__main__":
    main()
