#!/usr/bin/env python3
"""Synchronizes the Sleex Quickshell layer blur rule in ~/.config/fht/custom/rules.toml."""

import os
import re
import sys


def sync_blur_rule(disable: bool) -> None:
    """Updates or appends the managed SLEEX_BLUR_RULE block in ~/.config/fht/custom/rules.toml.

    Args:
        disable: True to disable layer blur on quickshell surfaces, False to enable it.
    """
    rules_path = os.path.expanduser("~/.config/fht/custom/rules.toml")
    os.makedirs(os.path.dirname(rules_path), exist_ok=True)

    existing = ""
    if os.path.exists(rules_path):
        with open(rules_path, "r", encoding="utf-8") as f:
            existing = f.read()

    disable_str = "true" if disable else "false"
    block = (
        "# BEGIN SLEEX_BLUR_RULE\n"
        "[[layer-rules]]\n"
        'match-namespace = "^quickshell:(bar|dock|dashboard|overview|cheatsheet|notificationPopup|wppselector|session|appmenu)$"\n'
        f"blur = {{ disable = {disable_str}, passes = 4, radius = 5, noise = 0.01 }}\n"
        "# END SLEEX_BLUR_RULE"
    )

    pattern = re.compile(r"# BEGIN SLEEX_BLUR_RULE.*?# END SLEEX_BLUR_RULE", re.DOTALL)
    if pattern.search(existing):
        updated = pattern.sub(block, existing)
    else:
        stripped = existing.rstrip()
        sep = "\n\n" if stripped else ""
        updated = f"{stripped}{sep}{block}\n"

    if updated != existing:
        with open(rules_path, "w", encoding="utf-8") as f:
            f.write(updated)


def main() -> None:
    """CLI entry point accepting '--disable' or 'true'/'false' for blur disable state."""
    arg = sys.argv[1].lower() if len(sys.argv) > 1 else "false"
    disable = arg in ("true", "1", "--disable", "disable")
    sync_blur_rule(disable)


if __name__ == "__main__":
    main()
