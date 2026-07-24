#!/usr/bin/env python3
from __future__ import annotations

import argparse
import difflib
import json
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import Any
from urllib import error, request

DEFAULT_API_URL = "http://127.0.0.1:11434/api/chat"

UI_PROPERTY_RE = re.compile(
    r"\b(text|title|subtitle|placeholderText|description|"
    r"tooltip|toolTipText|label|message)\s*:"
)

SIMPLE_LITERAL_RE = re.compile(
    r"""^\s*
    (?:text|title|subtitle|placeholderText|description|
       tooltip|toolTipText|label|message)
    \s*:\s*
    (?P<quote>["'])
    (?P<value>.*)
    (?P=quote)
    \s*;?\s*$
    """,
    re.VERBOSE,
)

ICON_NAME_RE = re.compile(r"^[a-z0-9]+(?:_[a-z0-9]+)+$")

COMMON_ICON_NAMES = {
    "add",
    "apps",
    "backspace",
    "bedtime",
    "bluetooth",
    "bolt",
    "cancel",
    "check",
    "close",
    "cloud",
    "delete",
    "edit",
    "error",
    "fingerprint",
    "info",
    "keep",
    "lock",
    "logout",
    "lyrics",
    "menu",
    "monitor",
    "pause",
    "percent",
    "play_arrow",
    "refresh",
    "remove",
    "restart_alt",
    "schedule",
    "search",
    "settings",
    "sync",
    "terminal",
    "visibility",
    "volume_up",
}

NON_LANGUAGE_VALUES = {
    "",
    "AM",
    "PM",
    "AxOS",
    "KDE",
    "Qt",
    "Sleex",
    "Wayland",
}


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Use a local Ollama model to mark hard-coded, user-facing "
            "QML strings with qsTr(). Dry-run is the default."
        )
    )
    parser.add_argument("paths", nargs="+", type=Path)
    parser.add_argument("--model", default="qwen3:8b")
    parser.add_argument("--api-url", default=DEFAULT_API_URL)
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Write accepted changes. Without this flag, only show diffs.",
    )
    parser.add_argument("--min-confidence", type=float, default=0.90)
    parser.add_argument("--batch-size", type=int, default=25)
    parser.add_argument("--limit-files", type=int, default=0)
    parser.add_argument(
        "--report",
        type=Path,
        default=Path("/tmp/sleex-qml-i18n-report.json"),
    )
    return parser.parse_args()


def discover_qml_files(paths: list[Path]) -> list[Path]:
    files: set[Path] = set()

    for supplied in paths:
        path = supplied.expanduser().resolve()

        if path.is_file() and path.suffix == ".qml":
            files.add(path)
            continue

        if path.is_dir():
            for item in path.rglob("*.qml"):
                if not any(
                    part in {".git", "build", "_build", "node_modules"}
                    for part in item.parts
                ):
                    files.add(item.resolve())
            continue

        print(f"[WARN] Ignoring invalid path: {path}", file=sys.stderr)

    return sorted(files)


def is_comment_line(line: str) -> bool:
    stripped = line.lstrip()
    return stripped.startswith(("//", "/*", "*", "*/"))


def is_non_language_literal(line: str) -> bool:
    match = SIMPLE_LITERAL_RE.match(line)

    if not match:
        return False

    value = match.group("value").strip()

    if value in NON_LANGUAGE_VALUES:
        return True

    if value.startswith(("http://", "https://", "/", "~/")):
        return True

    if ICON_NAME_RE.fullmatch(value) or value in COMMON_ICON_NAMES:
        return True

    if re.fullmatch(r"[\d\s%•→←‹›:+\-*/=.,_]+", value):
        return True

    return False


def extract_candidates(source: str) -> list[dict[str, Any]]:
    lines = source.splitlines()
    candidates: list[dict[str, Any]] = []

    for index, line in enumerate(lines):
        if is_comment_line(line):
            continue

        if not UI_PROPERTY_RE.search(line):
            continue

        if "qsTr(" in line or "qsTranslate(" in line:
            continue

        # Only send lines containing a literal string/template. Purely dynamic
        # values such as text: device.name should not be translated here.
        if not any(token in line for token in ('"', "'", "`")):
            continue

        property_match = UI_PROPERTY_RE.search(line)

        if property_match is None:
            continue

        expression = line[property_match.end():].strip()

        # A runtime expression without a complete same-line ternary is
        # probably the beginning of a multiline QML binding.
        if (
            expression
            and not expression.startswith(('"', "'", "`"))
            and "?" not in expression
        ):
            continue

        if "MaterialSymbol" in line:
            continue

        if is_non_language_literal(line):
            continue

        previous_line = lines[index - 1] if index > 0 else ""
        next_line = lines[index + 1] if index + 1 < len(lines) else ""

        candidates.append(
            {
                "id": len(candidates),
                "line_number": index + 1,
                "code": line,
                "context_before": previous_line,
                "context_after": next_line,
            }
        )

    return candidates


def response_schema() -> dict[str, Any]:
    return {
        "type": "object",
        "properties": {
            "changes": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "id": {"type": "integer"},
                        "replacement": {"type": "string"},
                        "reason": {"type": "string"},
                        "confidence": {
                            "type": "number",
                            "minimum": 0,
                            "maximum": 1,
                        },
                    },
                    "required": [
                        "id",
                        "replacement",
                        "reason",
                        "confidence",
                    ],
                },
            }
        },
        "required": ["changes"],
    }


def request_changes(
    *,
    path: Path,
    candidates: list[dict[str, Any]],
    model: str,
    api_url: str,
) -> list[dict[str, Any]]:
    system_prompt = """
You are a conservative QML internationalization refactoring assistant.

Your task is NOT to translate into another language. Keep source messages
in English and add Qt translation markers only where needed.

You receive preselected candidate lines. Return ONLY candidates that need
a real code change. Never return an unchanged line.

Rules:
- Refer to a candidate only by its numeric id.
- replacement must contain the complete replacement for candidate.code.
- Preserve the original indentation and all unrelated code.
- Add qsTr() only to genuine user-facing interface language.
- Skip Material Symbols and icon identifiers.
- Skip URLs, paths, commands, IDs, enum values, filenames and technical data.
- Skip external/dynamic content such as application names, device names,
  Wi-Fi SSIDs, usernames, song titles, artists, lyrics, window titles,
  notification content and calendar event content.
- Do not wrap runtime-generated values in qsTr().
- For a ternary, wrap each visible literal separately.
- For concatenation or template literals, use Qt placeholders and .arg().
- Preserve every variable and expression.
- Do not change wording, spelling or capitalization.
- Do not add imports.
- Prefer returning no change when uncertain.

Examples:

Candidate:
text: "Back"
Replacement:
text: qsTr("Back")

Candidate:
text: enabled ? "Enabled" : "Disabled"
Replacement:
text: enabled ? qsTr("Enabled") : qsTr("Disabled")

Candidate:
text: `${count} notifications`
Replacement:
text: qsTr("%1 notifications").arg(count)

Candidate:
text: "Uptime: " + DateTime.uptime
Replacement:
text: qsTr("Uptime: %1").arg(DateTime.uptime)

Do not change:
text: device.name
text: DateTime.time
MaterialSymbol { text: "close" }
""".strip()

    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": system_prompt},
            {
                "role": "user",
                "content": json.dumps(
                    {
                        "file": str(path),
                        "candidates": candidates,
                    },
                    ensure_ascii=False,
                    indent=2,
                ),
            },
        ],
        "stream": False,
        "think": False,
        "format": response_schema(),
        "options": {"temperature": 0.0},
        "keep_alive": "10m",
    }

    encoded = json.dumps(payload).encode("utf-8")
    http_request = request.Request(
        api_url,
        data=encoded,
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    last_exception: Exception | None = None

    for attempt in range(1, 4):
        try:
            with request.urlopen(http_request, timeout=900) as response:
                response_data = json.load(response)

            content = response_data["message"]["content"]
            parsed = json.loads(content)
            return parsed["changes"]

        except (
            error.URLError,
            TimeoutError,
            KeyError,
            ValueError,
            TypeError,
            json.JSONDecodeError,
        ) as exception:
            last_exception = exception
            print(
                f"[WARN] Attempt {attempt}/3 failed for {path}: "
                f"{exception}",
                file=sys.stderr,
            )
            time.sleep(attempt * 2)

    raise RuntimeError(
        f"Ollama request failed after three attempts: {last_exception}"
    )


def validate_change(
    *,
    change: dict[str, Any],
    candidate_by_id: dict[int, dict[str, Any]],
    minimum_confidence: float,
) -> tuple[bool, str]:
    candidate_id = change.get("id")
    replacement = change.get("replacement")
    confidence = change.get("confidence")

    if not isinstance(candidate_id, int):
        return False, "invalid candidate id"

    candidate = candidate_by_id.get(candidate_id)

    if candidate is None:
        return False, "unknown candidate id"

    if not isinstance(replacement, str):
        return False, "replacement is not text"

    if not isinstance(confidence, (int, float)):
        return False, "confidence is not numeric"

    if confidence < minimum_confidence:
        return False, "low confidence"

    original = candidate["code"]

    if replacement == original:
        return False, "unchanged proposal"

    if "qsTr(" not in replacement and "qsTranslate(" not in replacement:
        return False, "replacement has no translation helper"

    if re.search(r"""\bqsTr\(\s*(?!["'])""", replacement):
        return False, "qsTr() argument is not a string literal"

    if "MaterialSymbol" in replacement:
        return False, "Material Symbol line"

    translated_literals = re.findall(
        r"""qsTr\(\s*["']([^"']+)["']\s*\)""",
        replacement,
    )

    for literal in translated_literals:
        if (
            ICON_NAME_RE.fullmatch(literal)
            or literal in COMMON_ICON_NAMES
        ):
            return False, f"icon name passed to qsTr(): {literal}"

    if re.search(
        r"""qsTr\([^)]*\)\s*\+""",
        replacement,
    ):
        return False, (
            "translated fragment concatenated with runtime data"
        )

    original_indent = original[: len(original) - len(original.lstrip())]
    replacement_first_line = replacement.splitlines()[0]
    replacement_indent = replacement_first_line[
        : len(replacement_first_line) - len(replacement_first_line.lstrip())
    ]

    if replacement_indent != original_indent:
        return False, "indentation changed"

    return True, ""


def apply_line_changes(
    source: str,
    accepted: list[dict[str, Any]],
    candidate_by_id: dict[int, dict[str, Any]],
) -> str:
    lines = source.splitlines(keepends=True)

    replacements: list[tuple[int, str]] = []

    for change in accepted:
        candidate = candidate_by_id[change["id"]]
        line_index = candidate["line_number"] - 1
        current = lines[line_index]
        newline = "\n" if current.endswith("\n") else ""

        if current.rstrip("\n") != candidate["code"]:
            raise RuntimeError(
                f"Source changed while processing line "
                f"{candidate['line_number']}"
            )

        replacement = change["replacement"].rstrip("\n") + newline
        replacements.append((line_index, replacement))

    for line_index, replacement in sorted(replacements, reverse=True):
        lines[line_index] = replacement

    return "".join(lines)


def find_qmlformat() -> str | None:
    candidates = [
        shutil.which("qmlformat"),
        "/usr/lib/qt6/bin/qmlformat",
    ]

    for candidate in candidates:
        if candidate and Path(candidate).is_file():
            return str(candidate)

    return None


def validate_qml(source: str, formatter: str | None) -> tuple[bool, str]:
    if formatter is None:
        return True, "qmlformat unavailable"

    with tempfile.NamedTemporaryFile(
        "w",
        suffix=".qml",
        encoding="utf-8",
        delete=False,
    ) as handle:
        handle.write(source)
        temp_path = Path(handle.name)

    try:
        result = subprocess.run(
            [formatter, str(temp_path)],
            capture_output=True,
            text=True,
            timeout=60,
        )
    finally:
        temp_path.unlink(missing_ok=True)

    if result.returncode != 0:
        return False, (result.stderr or result.stdout).strip()

    return True, ""


def create_backup(path: Path, stamp: str) -> Path:
    try:
        root = Path(
            subprocess.run(
                ["git", "rev-parse", "--show-toplevel"],
                check=True,
                capture_output=True,
                text=True,
            ).stdout.strip()
        )
        relative = path.relative_to(root)
        destination = (
            root / ".git" / "ai-i18n-backups" / stamp / relative
        )
    except (OSError, ValueError, subprocess.CalledProcessError):
        destination = Path("/tmp") / f"sleex-i18n-{stamp}" / path.name

    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(path, destination)
    return destination


def print_diff(path: Path, before: str, after: str) -> None:
    sys.stdout.writelines(
        difflib.unified_diff(
            before.splitlines(keepends=True),
            after.splitlines(keepends=True),
            fromfile=f"a/{path}",
            tofile=f"b/{path}",
        )
    )


def main() -> int:
    args = parse_arguments()

    if args.batch_size < 1:
        print("--batch-size must be at least 1", file=sys.stderr)
        return 1

    files = discover_qml_files(args.paths)

    if args.limit_files:
        files = files[: args.limit_files]

    if not files:
        print("No QML files found.", file=sys.stderr)
        return 1

    formatter = find_qmlformat()
    stamp = time.strftime("%Y%m%d-%H%M%S")
    report: dict[str, Any] = {
        "mode": "apply" if args.apply else "dry-run",
        "model": args.model,
        "files": [],
    }

    for file_index, path in enumerate(files, 1):
        print(f"\n[{file_index}/{len(files)}] {path}")

        source = path.read_text(encoding="utf-8")
        candidates = extract_candidates(source)

        if not candidates:
            print("[SKIP] No unmarked literal UI candidates")
            report["files"].append(
                {
                    "path": str(path),
                    "candidate_count": 0,
                    "accepted": [],
                    "rejected": [],
                }
            )
            continue

        print(f"[CANDIDATES] {len(candidates)}")

        candidate_by_id = {
            candidate["id"]: candidate for candidate in candidates
        }

        proposals: list[dict[str, Any]] = []

        for start in range(0, len(candidates), args.batch_size):
            batch = candidates[start : start + args.batch_size]

            try:
                proposals.extend(
                    request_changes(
                        path=path,
                        candidates=batch,
                        model=args.model,
                        api_url=args.api_url,
                    )
                )
            except RuntimeError as exception:
                print(f"[ERROR] {exception}", file=sys.stderr)

        accepted: list[dict[str, Any]] = []
        rejected: list[dict[str, Any]] = []
        seen_ids: set[int] = set()

        for proposal in proposals:
            proposal_id = proposal.get("id")

            if isinstance(proposal_id, int) and proposal_id in seen_ids:
                rejected.append(
                    {
                        **proposal,
                        "rejected_reason": "duplicate candidate id",
                    }
                )
                continue

            valid, reason = validate_change(
                change=proposal,
                candidate_by_id=candidate_by_id,
                minimum_confidence=args.min_confidence,
            )

            if valid:
                accepted.append(proposal)
                seen_ids.add(proposal_id)
            else:
                rejected.append(
                    {
                        **proposal,
                        "rejected_reason": reason,
                    }
                )

        updated = source

        baseline_valid, baseline_error = validate_qml(
            source,
            formatter,
        )

        if not baseline_valid:
            print(
                "[WARN] The original file already fails qmlformat; "
                "the whole-file validation gate will be skipped."
            )

        if accepted:
            updated = apply_line_changes(
                source,
                accepted,
                candidate_by_id,
            )

            if baseline_valid:
                syntax_valid, syntax_error = validate_qml(
                    updated,
                    formatter,
                )

                if not syntax_valid:
                    rejected.extend(
                        {
                            **change,
                            "rejected_reason": (
                                "whole-file QML syntax validation failed"
                            ),
                        }
                        for change in accepted
                    )
                    accepted = []
                    updated = source
                    print(
                        f"[REJECT FILE] qmlformat: {syntax_error}"
                    )

        if accepted:
            print(
                f"[READY] {len(accepted)} accepted, "
                f"{len(rejected)} rejected"
            )

            if args.apply:
                backup_path = create_backup(path, stamp)
                path.write_text(updated, encoding="utf-8")
                print(f"[APPLIED] Backup: {backup_path}")
            else:
                print_diff(path, source, updated)
        else:
            print(
                f"[NO CHANGE] {len(candidates)} candidates, "
                f"{len(rejected)} rejected proposals"
            )

        report["files"].append(
            {
                "path": str(path),
                "candidate_count": len(candidates),
                "accepted": [
                    {
                        **change,
                        "line_number": candidate_by_id[change["id"]][
                            "line_number"
                        ],
                        "original": candidate_by_id[change["id"]]["code"],
                    }
                    for change in accepted
                ],
                "rejected": rejected,
            }
        )

    args.report.write_text(
        json.dumps(report, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    print(f"\nReport: {args.report}")

    if not args.apply:
        print("Dry-run complete: no QML files were modified.")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
