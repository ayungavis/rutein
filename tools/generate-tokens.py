#!/usr/bin/env python3
"""Generate and verify design tokens from the Figma varzip exports.

Colours come straight from Rutein's own export, single mode, no overrides.

That works because the app ships light appearance only. Rutein's colour
collection carries one mode; borrowing Untitled UI's light/dark mapping was only
ever needed to invent the *dark* half. With dark deferred, that one mode is the
light column, and the four exported tokens resolve to exactly what the hi-fi
frames draw. Untitled UI stays committed alongside as the reference the file was
built from — see docs/design/tokens/README.md.

Spacing, radius and the two font families come straight from Rutein's export and
are *checked* against the hand-written Swift rather than generated into it.

    make ios-tokens         regenerate Colors.xcassets
    make ios-tokens-check   verify everything, write nothing
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
KIT = ROOT / "apps/ios/RuteinApp/RuteinKit/Sources/RuteinKit"
CATALOG = KIT / "DesignSystem/Resources/Colors.xcassets"
SPACING_SWIFT = KIT / "DesignSystem/Spacing.swift"
RADIUS_SWIFT = KIT / "DesignSystem/Radius.swift"

LIGHT, DARK = "Light mode", "Dark mode"

# Figma leaf names, verbatim. Leaf names are unique across all 273 colour
# tokens, so the group path ("Colors/Background/" and friends) carries nothing.
EXPORTED = [
    "bg-brand-primary",
    "bg-primary",
    "text-primary (900)",
    "text-secondary (700)",
]

# Two slots in Rutein's Neutral ramp hold colours that are neither neutral nor
# in lightness order: Neutral.50 is darker than Neutral.700 while occupying the
# ramp's lightest slot, and Neutral.400 carries chroma 151 where every other
# step has chroma 0. None of the four exported tokens reaches them today; these
# stay as a guard for the next token that does.
PRIMITIVE_OVERRIDES = {
    "Colors/Neutral/50": "#FAFAFA",
    "Colors/Neutral/400": "#A3A3A3",
}

# Swift constant -> Figma leaf name. Only tokens with a consumer.
SPACING = {
    "xxs": "spacing-xxs",
    "xs": "spacing-xs",
    "md": "spacing-md",
    "xl": "spacing-xl",
    "xl2": "spacing-2xl",
    "xl3": "spacing-3xl",
    "xl4": "spacing-4xl",
    "xl6": "spacing-6xl",
}

RADIUS = {
    "md": "radius-md",
    "xl": "radius-xl",
    "full": "radius-full",
}

# The families AppFont uses: Cormorant Garamond for display, the system font —
# which on iOS is SF Pro — for body.
FONT_FAMILIES = {
    "font-family-display": "Cormorant Garamond",
    "font-family-body": "SF Pro",
}


class Varzip:
    """One Figma variable export, indexed for lookup by name and by id."""

    def __init__(self, path: Path):
        document = json.loads(path.read_text())
        self.path = path
        self.by_id = {v["sourceId"]: v for v in document["variables"]}
        self.modes = {
            m["sourceId"]: m["name"]
            for c in document["collections"]
            for m in c["modes"]
        }
        collection = {c["sourceId"]: c["name"] for c in document["collections"]}
        self.by_name = {}
        self.by_leaf = {}
        for variable in document["variables"]:
            name = variable["name"]
            self.by_name[name] = variable
            self.by_leaf.setdefault(name.split("/")[-1], []).append(variable)
        self.collection_of = {
            v["sourceId"]: collection[v["collectionSourceId"]]
            for v in document["variables"]
        }

    def leaf(self, name):
        matches = self.by_leaf.get(name, [])
        if len(matches) != 1:
            sys.exit(f"{name!r} matched {len(matches)} variables in {self.path.name}, expected 1")
        return matches[0]

    def resolve(self, variable, mode, depth=0):
        if depth > 12:
            sys.exit(f"reference cycle at {variable['name']!r}")

        entry = self._entry(variable, mode)
        if entry is None:
            sys.exit(f"{variable['name']!r} has no value for {mode!r}")

        if entry["kind"] == "VALUE":
            value = entry["value"]
            return rgb_hex(value) if isinstance(value, dict) else value

        target = self.by_id.get(entry["targetSourceVariableId"])
        if target is None:
            sys.exit(f"{variable['name']!r} aliases a variable missing from {self.path.name}")

        override = PRIMITIVE_OVERRIDES.get(target["name"])
        if override is not None:
            return override

        return self.resolve(target, mode, depth + 1)

    def _entry(self, variable, mode):
        for source_id, entry in variable["valuesByMode"].items():
            if self.modes.get(source_id) == mode:
                return entry
        # A single-mode collection — primitives, spacing, radius — is reached
        # from either appearance and answers with its only value.
        values = list(variable["valuesByMode"].values())
        return values[0] if len(values) == 1 else None


def rgb_hex(colour):
    return "#%02X%02X%02X" % tuple(round(colour[k] * 255) for k in "rgb")


def asset_name(token):
    stripped = re.sub(r"\s*\(\d+\)$", "", token).strip()
    head, *tail = re.split(r"[-_]", stripped)
    return head + "".join(word[:1].upper() + word[1:] for word in tail)


def components(hex_value):
    digits = hex_value.lstrip("#")
    if len(digits) != 6:
        sys.exit(f"unexpected colour {hex_value!r}")
    return {
        "alpha": "1.000",
        "red": f"0x{digits[0:2].upper()}",
        "green": f"0x{digits[2:4].upper()}",
        "blue": f"0x{digits[4:6].upper()}",
    }


def colorset(light):
    return {
        "colors": [
            {
                "color": {"color-space": "srgb", "components": components(light)},
                "idiom": "universal",
            },
        ],
        "info": {"author": "xcode", "version": 1},
    }


def colours(rutein):
    return {
        asset_name(token): (token, rutein.resolve(rutein.leaf(token), LIGHT))
        for token in EXPORTED
    }


def swift_constants(path):
    if not path.exists():
        return None
    pattern = re.compile(r"public static let (\w+): CGFloat = ([\d.]+)")
    return {m.group(1): float(m.group(2)) for m in pattern.finditer(path.read_text())}


def check_scale(problems, path, label, mapping, rutein, mode):
    found = swift_constants(path)
    if found is None:
        problems.append(f"{path.relative_to(ROOT)} is missing")
        return

    for constant, token in mapping.items():
        want = float(rutein.resolve(rutein.leaf(token), mode))
        if constant not in found:
            problems.append(f"{label}.{constant} is missing — token {token} is {want:g}")
        elif found[constant] != want:
            problems.append(
                f"{label}.{constant} is {found[constant]:g}, token {token} is {want:g}"
            )

    scale = {
        float(rutein.resolve(v, mode))
        for v in rutein.by_id.values()
        if rutein.collection_of[v["sourceId"]] == mode_collection(label)
    }
    for constant, value in found.items():
        if constant not in mapping:
            problems.append(
                f"{label}.{constant} = {value:g} is not in the token map"
                + ("" if value in scale else f" and {value:g} is on no Figma scale")
            )


def mode_collection(label):
    return "3. Spacing" if label == "Spacing" else "2. Radius"


def check_fonts(problems, rutein):
    for token, want in FONT_FAMILIES.items():
        found = rutein.resolve(rutein.leaf(token), "Mode 1")
        if found != want:
            problems.append(f"{token} is {found!r}, AppFont expects {want!r}")


def check(expected, rutein):
    problems = []

    present = {p.name[: -len(".colorset")] for p in CATALOG.glob("*.colorset")}
    for extra in sorted(present - set(expected)):
        problems.append(f"{extra}.colorset is not generated from any token")

    for name, (token, light) in expected.items():
        path = CATALOG / f"{name}.colorset" / "Contents.json"
        if not path.exists():
            problems.append(f"{name}.colorset is missing — token {token!r}")
            continue
        found = json.loads(path.read_text())
        if any(entry.get("appearances") for entry in found.get("colors", [])):
            problems.append(f"{name}.colorset carries a dark appearance; the app ships light only")
        elif found != colorset(light):
            problems.append(f"{name}.colorset does not match {token!r} ({light})")

    check_scale(problems, SPACING_SWIFT, "Spacing", SPACING, rutein, "Mode 1")
    check_scale(problems, RADIUS_SWIFT, "Radius", RADIUS, rutein, "Mode 1")
    check_fonts(problems, rutein)

    if problems:
        print("Design tokens are out of date with docs/design/tokens:")
        for problem in problems:
            print(f"  {problem}")
        print("Run `make ios-tokens` for colours; edit the Swift for spacing and radius.")
        sys.exit(1)

    print(
        f"tokens OK — {len(expected)} colour sets (light only), "
        f"{len(SPACING)} spacing, {len(RADIUS)} radius, {len(FONT_FAMILIES)} font families"
    )


def write(expected):
    for stale in CATALOG.glob("*.colorset"):
        shutil.rmtree(stale)

    CATALOG.mkdir(parents=True, exist_ok=True)
    (CATALOG / "Contents.json").write_text(
        json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n"
    )

    for name, (token, light) in expected.items():
        target = CATALOG / f"{name}.colorset"
        target.mkdir()
        (target / "Contents.json").write_text(
            json.dumps(colorset(light), indent=2) + "\n"
        )
        print(f"  {name:<20} {token:<22} {light}")

    print(f"{len(expected)} colour sets written to {CATALOG.relative_to(ROOT)}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="verify the committed tokens match the exports; write nothing",
    )
    args = parser.parse_args()

    rutein = Varzip(TOKENS / "rutein.figvars.json")
    expected = colours(rutein)

    if args.check:
        check(expected, rutein)
    else:
        write(expected)


if __name__ == "__main__":
    main()
