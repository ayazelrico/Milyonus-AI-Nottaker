#!/usr/bin/env python3
"""Generate SwiftPM-compatible resources from the app's English String Catalogs."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys


REPOSITORY_DIRECTORY = Path(__file__).resolve().parent.parent
CATALOG_PATHS = (
    REPOSITORY_DIRECTORY / "app/Sources/Shared/Resources/Localizable.xcstrings",
    REPOSITORY_DIRECTORY / "app/Support/InfoPlist.xcstrings",
)
LANGUAGES = ("en", "tr")


def quoted(value: str) -> str:
    """JSON and .strings share quoting rules for our UTF-8 text entries."""
    if any(ord(character) < 32 and character not in "\n\r\t" for character in value):
        raise ValueError("Catalog strings must not contain unsupported control characters")
    return json.dumps(value, ensure_ascii=False)


def string_value(entry: dict, language: str, fallback: str) -> str:
    localization = entry.get("localizations", {}).get(language)
    if localization is None:
        return fallback
    # Fail explicitly for plurals/substitutions rather than silently losing catalog semantics.
    if set(localization) != {"stringUnit"}:
        raise ValueError(f"Unsupported localization structure for {language}")
    unit = localization["stringUnit"]
    value = unit.get("value")
    if not isinstance(value, str):
        raise ValueError(f"Expected a string value for {language}")
    return value


def render_catalog(catalog: dict, catalog_name: str = "Localizable.xcstrings") -> dict[str, str]:
    if catalog.get("sourceLanguage") != "en":
        raise ValueError("The String Catalog source language must be English (en)")
    entries = catalog.get("strings")
    if not isinstance(entries, dict):
        raise ValueError("The String Catalog must contain a strings object")
    output = {language: [f"/* Generated from {catalog_name}. Do not edit. */"] for language in LANGUAGES}
    for key in sorted(entries):
        entry = entries[key]
        if not isinstance(entry, dict):
            raise ValueError("Each catalog entry must be an object")
        english = string_value(entry, "en", key)
        for language in LANGUAGES:
            value = english if language == "en" else string_value(entry, language, english)
            output[language].append(f"{quoted(key)} = {quoted(value)};")
    return {language: "\n".join(lines) + "\n" for language, lines in output.items()}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Fail when generated resources have drifted")
    options = parser.parse_args()
    try:
        artifacts = []
        for catalog_path in CATALOG_PATHS:
            catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
            rendered = render_catalog(catalog, catalog_path.name)
            for language, contents in rendered.items():
                path = catalog_path.parent / f"{language}.lproj/{catalog_path.stem}.strings"
                artifacts.append((path, contents))
        stale_paths = []
        for path, contents in artifacts:
            current = path.read_text(encoding="utf-8") if path.exists() else None
            if current == contents:
                continue
            if options.check:
                stale_paths.append(path.relative_to(REPOSITORY_DIRECTORY).as_posix())
            else:
                path.parent.mkdir(parents=True, exist_ok=True)
                with path.open("w", encoding="utf-8", newline="\n") as output_file:
                    output_file.write(contents)
        if stale_paths:
            print("Localization resources are stale: " + ", ".join(stale_paths), file=sys.stderr)
            print("Run python3 scripts/generate-localizations.py", file=sys.stderr)
            return 1
    except (OSError, ValueError, TypeError, AttributeError) as error:
        print(f"Localization generation failed: {error}", file=sys.stderr)
        return 1
    print("Localization resources verified." if options.check else "Localization resources generated.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
