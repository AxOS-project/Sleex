#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
import time
from pathlib import Path
from typing import Any
from urllib import error, request

from lxml import etree


DEFAULT_API_URL = "http://127.0.0.1:11434/api/chat"

# Qt placeholders such as %1, %2, %L1 and %n.
PLACEHOLDER_RE = re.compile(
    r"%(?:L?\d+|n)|\$\{[^{}]+\}|\{[A-Za-z_][^{}]*\}"
)

# HTML-like tags embedded inside translation strings.
TAG_RE = re.compile(r"</?[A-Za-z][^>]*>")


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Pre-translate a Qt TS catalog using a local Ollama model."
    )

    parser.add_argument(
        "ts_file",
        type=Path,
        help="Qt .ts translation file",
    )
    parser.add_argument(
        "--model",
        default="qwen3:8b",
        help="Ollama model name",
    )
    parser.add_argument(
        "--api-url",
        default=DEFAULT_API_URL,
        help="Ollama chat API URL",
    )
    parser.add_argument(
        "--glossary",
        type=Path,
        help="Optional JSON glossary",
    )
    parser.add_argument(
        "--batch-size",
        type=int,
        default=10,
        help="Number of strings sent in each request",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=0,
        help="Translate at most this many strings; 0 means no limit",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Replace existing unfinished translations",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Request translations without modifying the TS file",
    )

    return parser.parse_args()


def load_glossary(path: Path | None) -> dict[str, str]:
    if path is None:
        return {}

    if not path.exists():
        raise FileNotFoundError(f"Glossary not found: {path}")

    with path.open("r", encoding="utf-8") as file:
        data = json.load(file)

    if not isinstance(data, dict):
        raise ValueError("The glossary must be a JSON object.")

    return {
        str(source): str(translation)
        for source, translation in data.items()
    }


def element_text(element: etree._Element | None) -> str:
    if element is None:
        return ""

    return "".join(element.itertext())


def collect_candidates(
    tree: etree._ElementTree,
    overwrite: bool,
) -> list[dict[str, Any]]:
    candidates: list[dict[str, Any]] = []

    for context in tree.getroot().findall("context"):
        context_name = context.findtext("name", default="")

        for message in context.findall("message"):
            # Plural forms require separate handling and human review.
            if message.get("numerus") == "yes":
                continue

            source_element = message.find("source")
            if source_element is None:
                continue

            source = element_text(source_element)

            if not source.strip():
                continue

            translation_element = message.find("translation")

            if translation_element is None:
                translation_element = etree.SubElement(
                    message,
                    "translation",
                )
                translation_element.set("type", "unfinished")

            translation_type = translation_element.get("type", "")

            if translation_type in {"vanished", "obsolete"}:
                continue

            current_translation = element_text(
                translation_element
            )

            if current_translation.strip() and not overwrite:
                continue

            locations = []

            for location in message.findall("location"):
                filename = location.get("filename", "")
                line = location.get("line", "")

                if filename:
                    locations.append(f"{filename}:{line}")

            candidates.append(
                {
                    "id": len(candidates),
                    "source": source,
                    "context": context_name,
                    "locations": locations,
                    "_translation_element": translation_element,
                }
            )

    return candidates


def extract_tokens(text: str) -> list[str]:
    return sorted(PLACEHOLDER_RE.findall(text))


def extract_tags(text: str) -> list[str]:
    return TAG_RE.findall(text)


def validate_translation(
    source: str,
    translation: str,
) -> tuple[bool, str]:
    if not translation.strip():
        return False, "empty translation"

    if extract_tokens(source) != extract_tokens(translation):
        return False, "placeholders were changed"

    if extract_tags(source) != extract_tags(translation):
        return False, "HTML/XML tags were changed"

    if source.count("\n") != translation.count("\n"):
        return False, "explicit line breaks were changed"

    return True, ""


def build_schema() -> dict[str, Any]:
    return {
        "type": "object",
        "properties": {
            "translations": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "id": {
                            "type": "integer",
                        },
                        "translation": {
                            "type": "string",
                        },
                    },
                    "required": [
                        "id",
                        "translation",
                    ],
                },
            }
        },
        "required": ["translations"],
    }


def request_translation(
    api_url: str,
    model: str,
    items: list[dict[str, Any]],
    glossary: dict[str, str],
) -> dict[int, str]:
    clean_items = []

    for item in items:
        clean_items.append(
            {
                "id": item["id"],
                "source": item["source"],
                "context": item["context"],
                "locations": item["locations"],
            }
        )

    system_prompt = f"""
You are translating a Linux desktop interface from English
to natural Brazilian Portuguese.

Rules:
- Return only data matching the supplied JSON schema.
- Translate only user-facing text.
- Use concise and natural Brazilian Portuguese.
- Preserve Qt placeholders exactly, including %1, %2, %L1 and %n.
- Preserve variables such as ${{name}} and {{name}} exactly.
- Preserve HTML/XML tags exactly.
- Preserve explicit line breaks.
- Do not translate commands, paths or file names.
- Do not translate product and technology names such as:
  Sleex, AxOS, Hyprland, Quickshell, Wayland, PipeWire,
  KDE, Qt, Wi-Fi, Bluetooth, GitHub and Ollama.
- Use the component context to resolve ambiguous words.
- Do not add explanations or translator notes.

Preferred glossary:
{json.dumps(glossary, ensure_ascii=False, indent=2)}
""".strip()

    user_prompt = json.dumps(
        {"items": clean_items},
        ensure_ascii=False,
        indent=2,
    )

    payload = {
        "model": model,
        "messages": [
            {
                "role": "system",
                "content": system_prompt,
            },
            {
                "role": "user",
                "content": user_prompt,
            },
        ],
        "stream": False,
        "think": False,
        "format": build_schema(),
        "options": {
            "temperature": 0.0,
        },
        "keep_alive": "10m",
    }

    encoded_payload = json.dumps(payload).encode("utf-8")

    http_request = request.Request(
        api_url,
        data=encoded_payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    last_exception: Exception | None = None

    for attempt in range(1, 4):
        try:
            with request.urlopen(
                http_request,
                timeout=600,
            ) as response:
                response_data = json.load(response)

            content = response_data["message"]["content"]
            parsed_content = json.loads(content)

            translations: dict[int, str] = {}

            for result in parsed_content["translations"]:
                translations[int(result["id"])] = str(
                    result["translation"]
                )

            return translations

        except (
            error.URLError,
            TimeoutError,
            KeyError,
            ValueError,
            json.JSONDecodeError,
        ) as exception:
            last_exception = exception

            print(
                f"Request attempt {attempt}/3 failed: "
                f"{exception}",
                file=sys.stderr,
            )

            time.sleep(attempt * 2)

    raise RuntimeError(
        f"Ollama request failed after three attempts: "
        f"{last_exception}"
    )


def save_tree(
    tree: etree._ElementTree,
    path: Path,
) -> None:
    doctype = tree.docinfo.doctype or "<!DOCTYPE TS>"

    tree.write(
        str(path),
        encoding="utf-8",
        xml_declaration=True,
        pretty_print=False,
        doctype=doctype,
    )


def main() -> int:
    args = parse_arguments()

    if not args.ts_file.exists():
        print(
            f"TS file not found: {args.ts_file}",
            file=sys.stderr,
        )
        return 1

    if args.batch_size < 1:
        print(
            "--batch-size must be at least 1",
            file=sys.stderr,
        )
        return 1

    glossary = load_glossary(args.glossary)

    parser = etree.XMLParser(
        remove_blank_text=False,
        recover=False,
    )

    tree = etree.parse(
        str(args.ts_file),
        parser,
    )

    candidates = collect_candidates(
        tree,
        overwrite=args.overwrite,
    )

    if args.limit > 0:
        candidates = candidates[: args.limit]

    if not candidates:
        print("No untranslated strings found.")
        return 0

    print(
        f"Selected {len(candidates)} strings "
        f"for translation."
    )

    if not args.dry_run:
        timestamp = time.strftime("%Y%m%d-%H%M%S")
        backup_path = args.ts_file.with_name(
            f"{args.ts_file.name}.backup-{timestamp}"
        )

        shutil.copy2(
            args.ts_file,
            backup_path,
        )

        print(f"Backup created: {backup_path}")

    accepted = 0
    rejected = 0

    for start in range(
        0,
        len(candidates),
        args.batch_size,
    ):
        batch = candidates[
            start : start + args.batch_size
        ]

        print(
            f"\nBatch {start + 1}-"
            f"{start + len(batch)}"
        )

        translations = request_translation(
            api_url=args.api_url,
            model=args.model,
            items=batch,
            glossary=glossary,
        )

        for item in batch:
            item_id = item["id"]
            source = item["source"]
            translated = translations.get(item_id, "")

            valid, reason = validate_translation(
                source,
                translated,
            )

            if not valid:
                rejected += 1

                print(
                    f"[REJECTED] {source!r}: {reason}"
                )
                continue

            accepted += 1

            print(
                f"[OK] {source!r} -> "
                f"{translated!r}"
            )

            if args.dry_run:
                continue

            translation_element = item[
                "_translation_element"
            ]

            translation_element.clear()
            translation_element.set(
                "type",
                "unfinished",
            )
            translation_element.text = translated

        if not args.dry_run:
            save_tree(
                tree,
                args.ts_file,
            )

    print(
        f"\nFinished: {accepted} accepted, "
        f"{rejected} rejected."
    )

    if args.dry_run:
        print("Dry run: no files were modified.")
    else:
        print(
            "Translations remain marked as unfinished "
            "for human review."
        )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
