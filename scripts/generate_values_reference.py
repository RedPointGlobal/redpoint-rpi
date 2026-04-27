#!/usr/bin/env python3
"""
Regenerate docs/values_reference.yaml from chart/values.yaml + chart/templates/_defaults.tpl.

Why this exists
---------------
The Helm Assistant Reference tab parses values_reference.yaml and shows each
top-level YAML key as an expandable block. For per-service blocks (callbackapi,
interactionapi, etc.) the chart pulls overridable defaults from _defaults.tpl
at template time, so customers don't see those knobs unless we duplicate them
into the reference doc.

This script keeps both surfaces in sync automatically:

  - Top-level non-service sections (global, ingress, databases, etc.) are
    copied verbatim from chart/values.yaml.
  - Each per-service section gets its values.yaml block, then the matching
    `rpi.defaults.<service>` block from _defaults.tpl, emitted as commented
    lines under a "Per-service overridable defaults" header. Customers
    uncomment any line to override.

Run from the repo root:

    python3 scripts/generate_values_reference.py

The script is idempotent and deterministic. CI should fail if the regenerated
file differs from what's checked in (drift detection).
"""

from __future__ import annotations

import re
import sys
from pathlib import Path
from typing import Generator

REPO_ROOT = Path(__file__).resolve().parent.parent
VALUES_PATH = REPO_ROOT / "chart" / "values.yaml"
DEFAULTS_PATH = REPO_ROOT / "chart" / "templates" / "_defaults.tpl"
OUTPUT_PATH = REPO_ROOT / "docs" / "values_reference.yaml"

TOP_LEVEL_KEY_RE = re.compile(r"^[a-zA-Z][\w]*\s*:")
DEFAULTS_BLOCK_RE = re.compile(
    r'{{- define "rpi\.defaults\.([\w-]+)" -}}\s*\n(.*?){{- end -}}',
    re.DOTALL,
)

DEFAULTS_HEADER = (
    "  # === Per-service overridable defaults (from _defaults.tpl) ===\n"
    "  # Uncomment and modify any of the lines below to override the\n"
    "  # chart's per-service default."
)


def parse_defaults() -> dict[str, str]:
    """Extract `rpi.defaults.<service>` blocks from _defaults.tpl.

    Returns a mapping of service-name -> raw YAML body (no leading indent
    adjustments). The raw body has the formatting the chart uses internally;
    the reference doc shows it as commented lines so customers can read it
    even though it's not real YAML in the customer's file.
    """
    text = DEFAULTS_PATH.read_text(encoding="utf-8")
    return {
        name: body.rstrip()
        for name, body in DEFAULTS_BLOCK_RE.findall(text)
    }


def split_into_blocks(text: str) -> Generator[tuple, None, None]:
    """Walk values.yaml and yield ('preamble', line) or ('section', key, key_line, body_lines).

    Comments and blank lines that appear immediately ABOVE a top-level key
    are treated as headers for the NEXT section (they're emitted as preamble
    items between the previous section's content and the next section's key).
    """
    lines = text.splitlines()
    i = 0
    n = len(lines)

    # Preamble: everything before the first top-level key.
    while i < n and not TOP_LEVEL_KEY_RE.match(lines[i]):
        yield ("preamble", lines[i])
        i += 1

    while i < n:
        key_line = lines[i]
        key = key_line.split(":", 1)[0].strip()
        body: list[str] = []
        i += 1
        while i < n and not TOP_LEVEL_KEY_RE.match(lines[i]):
            body.append(lines[i])
            i += 1
        # Move trailing blank/comment lines off the body — they belong as
        # the header of whatever section comes next.
        trailing_header: list[str] = []
        while body and (body[-1].strip() == "" or body[-1].lstrip().startswith("#")):
            trailing_header.insert(0, body.pop())
        yield ("section", key, key_line, body)
        for line in trailing_header:
            yield ("preamble", line)


def render_defaults_block(defaults_yaml: str) -> list[str]:
    """Convert raw defaults YAML text into commented reference lines.

    Each non-blank line gets a `  # ` prefix; blank lines become bare `  #`
    to keep the comment block visually contiguous.
    """
    out: list[str] = []
    out.append("")
    out.extend(DEFAULTS_HEADER.splitlines())
    for line in defaults_yaml.splitlines():
        if line.strip():
            out.append("  # " + line)
        else:
            out.append("  #")
    out.append("")
    return out


def generate(values_text: str, defaults: dict[str, str]) -> str:
    out: list[str] = []
    for item in split_into_blocks(values_text):
        if item[0] == "preamble":
            out.append(item[1])
            continue
        _, key, key_line, body = item
        out.append(key_line)
        out.extend(body)
        if key in defaults:
            # Strip a trailing blank from `body` so we don't double-space
            # before the defaults header.
            while out and out[-1].strip() == "":
                out.pop()
            out.extend(render_defaults_block(defaults[key]))
    return "\n".join(out).rstrip() + "\n"


def main(argv: list[str]) -> int:
    check = "--check" in argv

    defaults = parse_defaults()
    values_text = VALUES_PATH.read_text(encoding="utf-8")
    rendered = generate(values_text, defaults)

    if check:
        existing = OUTPUT_PATH.read_text(encoding="utf-8") if OUTPUT_PATH.exists() else ""
        if existing != rendered:
            sys.stderr.write(
                f"{OUTPUT_PATH} is out of date. Run scripts/generate_values_reference.py to regenerate.\n"
            )
            return 1
        return 0

    OUTPUT_PATH.write_text(rendered, encoding="utf-8")
    print(f"wrote {OUTPUT_PATH} ({len(rendered.splitlines())} lines, {len(defaults)} services with defaults)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
