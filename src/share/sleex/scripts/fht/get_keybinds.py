#!/usr/bin/env python3
"""Parses fht-compositor TOML keybind configurations into Cheatsheet-compatible JSON."""

import argparse
import json
import os
import re
from typing import Any, Dict, List

import toml

TITLE_REGEX = re.compile(r"^#+!")
PSEUDO_BIND_REGEX = re.compile(r"^#/#!?\s*([A-Za-z0-9_\-\[\]]+)\s*=\s*(.+?)(?:\s+#\s*(.+))?$")
HIDE_COMMENT = "[hidden]"

MOD_BITS = {
    "shift": 1 << 0,
    "caps": 1 << 1,
    "ctrl": 1 << 2,
    "control": 1 << 2,
    "alt": 1 << 3,
    "mod1": 1 << 3,
    "mod2": 1 << 4,
    "mod3": 1 << 5,
    "super": 1 << 6,
    "mod4": 1 << 6,
    "win": 1 << 6,
    "logo": 1 << 6,
    "mod5": 1 << 7,
}


def compute_modmask(mods: List[str]) -> int:
    """Computes the bitmask expected by CheatsheetKeybindsCategory.qml for a list of modifier names."""
    mask = 0
    for mod in mods:
        mask |= MOD_BITS.get(mod.lower(), 0)
    return mask


def parse_toml_config(path: str) -> Dict[str, Any]:
    """Parses a TOML file containing a [keybinds] table and #! category comments."""
    expanded_path = os.path.expanduser(os.path.expandvars(path))
    if not os.access(expanded_path, os.R_OK):
        return {"categories": [], "keybinds": []}

    with open(expanded_path, "r", encoding="utf-8") as f:
        lines = f.readlines()

    try:
        full_data = toml.loads("".join(lines))
    except Exception:
        full_data = {}

    keybinds_data = full_data.get("keybinds", {})
    if not isinstance(keybinds_data, dict):
        keybinds_data = {}

    default_category = "Applications" if os.path.basename(expanded_path) == "apps.toml" else ""
    current_category = default_category
    categories: List[str] = []
    keybinds: List[Dict[str, Any]] = []
    seen_combos = set()

    for raw_line in lines:
        clean_line = raw_line.strip()
        if not clean_line:
            continue

        if TITLE_REGEX.match(clean_line):
            name = clean_line.replace("!", "").replace("#", "").strip()
            if name:
                current_category = name
                if name not in categories:
                    categories.append(name)
            continue

        # Support #/# summary comment lines for range keybinds (e.g. Super-[1-9])
        pseudo_match = PSEUDO_BIND_REGEX.match(clean_line)
        if pseudo_match:
            combo, _rhs, comment = pseudo_match.groups()
            comment = (comment or "").strip()
            if not comment or HIDE_COMMENT in comment:
                continue
            parts = combo.split("-")
            actual_key = parts.pop()
            if actual_key in ("[1", "9]") and "[1-9]" in combo:
                parts = [p for p in combo.replace("[1-9]", "").rstrip("-").split("-") if p]
                actual_key = "1"
            modmask = compute_modmask(parts)
            desc = f"{current_category}: {comment}" if current_category and ":" not in comment else comment
            if current_category and current_category not in categories:
                categories.append(current_category)
            keybinds.append({
                "mods": parts,
                "modmask": modmask,
                "key": actual_key,
                "description": desc,
            })
            continue

        if HIDE_COMMENT in raw_line or clean_line.startswith("#") or clean_line.startswith("["):
            continue

        if "=" in clean_line:
            key_part = clean_line.split("=", 1)[0].strip()
            base_key = key_part.split(".")[0].strip().strip('"').strip("'")

            if base_key in keybinds_data and base_key not in seen_combos:
                comment = ""
                if "#" in raw_line:
                    comment = raw_line.split("#", 1)[-1].strip()
                if not comment:
                    continue

                seen_combos.add(base_key)
                parts = base_key.split("-")
                actual_key = parts.pop() if parts else base_key
                modmask = compute_modmask(parts)

                cat = current_category
                if ":" in comment:
                    prefix = comment.split(":", 1)[0].strip()
                    if prefix and prefix not in categories:
                        categories.append(prefix)
                    desc = comment
                elif cat:
                    if cat not in categories:
                        categories.append(cat)
                    desc = f"{cat}: {comment}"
                else:
                    desc = comment

                keybinds.append({
                    "mods": parts,
                    "modmask": modmask,
                    "key": actual_key,
                    "description": desc,
                })

    return {
        "categories": categories,
        "keybinds": keybinds,
    }


def main() -> None:
    """CLI entry point."""
    parser = argparse.ArgumentParser(description="Sleex fht-compositor TOML keybind reader")
    parser.add_argument(
        "--path",
        type=str,
        default="/etc/sleex/compositor/keybinds.toml",
        help="Path to keybind TOML config file",
    )
    args = parser.parse_args()
    print(json.dumps(parse_toml_config(args.path)))


if __name__ == "__main__":
    main()
