#!/usr/bin/env python3
"""Check repository boundaries without reading ignored secret files."""

import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
paths = subprocess.check_output(
    ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"], cwd=ROOT
).decode().split("\0")
errors = []
source_extensions = {".swift", ".ts", ".py", ".sh", ".yml", ".yaml", ".md", ".json"}
legacy_references = {"design.md"}
for relative in sorted(set(filter(None, paths))):
    path = ROOT / relative
    if not path.is_file():
        continue
    if (path.name.startswith(".env") and path.name != ".env.example") or path.suffix in {
        ".pem", ".p12", ".p8", ".key", ".mobileprovision"
    }:
        errors.append(f"Secret-like file must not be tracked: {relative}")
        continue
    if path.suffix not in source_extensions or relative in legacy_references:
        continue
    text = path.read_text(encoding="utf-8")
    if "\u2014" in text:
        errors.append(f"Use a short hyphen or colon: {relative}")
    if relative.startswith("app/Sources/") and path.suffix == ".swift":
        target = pathlib.PurePosixPath(relative).parts[2]
        imports = re.findall(r"^import\s+(\w+)", text, flags=re.MULTILINE)
        if target == "Shared" and any(value in {"SwiftUI", "AppKit", "DesignSystem", "MilyonusApp"} for value in imports):
            errors.append(f"Shared must not depend on UI: {relative}")
        forbidden = {"AudioCapture", "Transcription", "InsightEngine", "KnowledgeBase", "PostMeeting", "CalendarIntegration", "Persistence", "Authentication", "Billing"}
        if target != "MilyonusApp" and any(value in forbidden for value in imports):
            errors.append(f"Feature-to-feature dependency: {relative}")
    if relative.startswith(("app/Sources/", "backend/src/")):
        if re.search(r"\bsk-ant-[A-Za-z0-9_-]{12,}|\bsk_(?:live|test)_[A-Za-z0-9]{12,}", text):
            errors.append(f"Credential-like literal found: {relative}")

if errors:
    print("\n".join(errors), file=sys.stderr)
    sys.exit(1)
print("Repository boundaries and source hygiene passed.")
