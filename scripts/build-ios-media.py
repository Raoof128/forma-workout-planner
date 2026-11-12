#!/usr/bin/env python3
"""Bring the website's exercise media and display font into the native app.

Run from the repository root on macOS (it uses `sips` and fontTools):

    python3 scripts/build-ios-media.py          # regenerate
    python3 scripts/build-ios-media.py --check  # fail on drift, never write

Generated paths (do not hand-edit):

    ios/FORMA/Media/media.json          what the app reads: per exercise, its
                                        sheet, crop and caption; demos; credits
    ios/FORMA/Media/sheets/*.heic       the web's original illustration sheets,
                                        full resolution, as HEIC
    ios/FORMA/Media/demos/*.mp4, *.jpg  the web's demo clips and posters, copied
    ios/FORMA/Media/animations/*.mp4    the web's animated SVG demonstrations,
                                        recorded frame by frame (see
                                        scripts/render-ios-animations.mjs), and
             *.heic                     their still start poses
    ios/FORMA/Media/photos/*.heic       the web's hero photo and its three
                                        routine photos, split from one strip
    ios/FORMA/Resources/Fonts/*.ttf     the web's display font, from its WOFF2

The web catalogues (src/catalog/media.json, demos.json) stay authoritative.
The manifest is deterministic and checked in CI. HEIC encoding is not
byte-stable across macOS releases, so `--check` verifies each sheet exists and
has the source's pixel size rather than comparing bytes; a sheet is re-encoded
only when its source checksum changes.
"""

from __future__ import annotations

import hashlib
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PUBLIC = ROOT / "public"
MEDIA = ROOT / "ios" / "FORMA" / "Media"
FONTS = ROOT / "ios" / "FORMA" / "Resources" / "Fonts"
# Which source each generated file was made from. Kept outside the bundled
# folder: it is build bookkeeping, not app data.
STAMPS = ROOT / "ios" / "media-sources.json"
# HEIC quality. 0.5 keeps a 1536x1024 sheet near 90 KB, against 1.9 MB as PNG,
# with no visible loss at the sizes the guide shows a cell.
HEIC_QUALITY = "50"
# The web shows routine photo N as the Nth third of one strip, positioned
# vertically at these percentages (src/styles.css .photo-0 to .photo-2).
ROUTINE_PHOTO_FOCUS = [0.30, 0.57, 0.35]
FONT_SOURCES = {
    # web file -> (bundled file, licence copied beside it)
    "barlow-condensed-700.woff2": ("BarlowCondensed-Bold.ttf", "barlowcondensed-OFL.txt"),
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def public_file(src: str) -> Path:
    return PUBLIC / src.split("?", 1)[0].lstrip("/")


def manifest() -> tuple[dict, dict[str, Path], dict[str, Path]]:
    media = json.loads((ROOT / "src/catalog/media.json").read_text())
    demos = json.loads((ROOT / "src/catalog/demos.json").read_text())

    sheet_files: dict[str, Path] = {}
    sheets: dict[str, dict] = {}
    for asset in media["assets"].values():
        source = public_file(asset["src"])
        name = source.stem
        if name not in sheets:
            sheet_files[name] = source
            sheets[name] = {
                "width": asset["width"],
                "height": asset["height"],
                "sha256": asset["sha256"],
            }

    images: dict[str, dict] = {}
    for exercise_id in sorted(media["exercises"]):
        entry = media["exercises"][exercise_id]
        asset = media["assets"][entry["assetId"]]
        region = asset["region"]
        bounds = region.get("bounds") or {
            "x": region["column"] * asset["width"] / region["columns"],
            "y": region["row"] * asset["height"] / region["rows"],
            "width": asset["width"] / region["columns"],
            "height": asset["height"] / region["rows"],
        }
        images[exercise_id] = {
            "sheet": public_file(asset["src"]).stem,
            "x": round(bounds["x"], 2),
            "y": round(bounds["y"], 2),
            "width": round(bounds["width"], 2),
            "height": round(bounds["height"], 2),
            "title": asset["title"],
            "equipment": "equipment" in asset["kind"],
            "caption": entry.get("caption", ""),
        }

    clip_files: dict[str, Path] = {}
    clips: dict[str, dict] = {}
    for clip_id in sorted(demos["clips"]):
        clip = demos["clips"][clip_id]
        clip_files[f"{clip_id}.mp4"] = public_file(clip["src"])
        clip_files[f"{clip_id}.jpg"] = public_file(clip["poster"])
        clips[clip_id] = {
            "width": clip["width"],
            "height": clip["height"],
            "source": clip["sourceId"],
            "title": clip["title"],
            "author": clip.get("author", ""),
            "url": clip.get("url", ""),
            "sha256": clip["sha256"],
        }
    demo_exercises = {
        exercise_id: {"clip": entry["clipId"], "caption": entry.get("caption", "")}
        for exercise_id, entry in sorted(demos["exercises"].items())
    }

    animations_catalog = json.loads((ROOT / "src/catalog/animations.json").read_text())
    animations = {
        exercise_id: {
            "seconds": entry["seconds"],
            "description": entry["description"],
            "width": 960,
            "height": 720,
            "sha256": hashlib.sha256(
                public_file(entry["src"]).read_bytes() + public_file(entry["still"]).read_bytes()
            ).hexdigest(),
        }
        for exercise_id, entry in sorted(animations_catalog.items())
    }
    photos = {
        "hero": {"file": "training-hero", "sha256": sha256(PUBLIC / "images/training-hero.webp")},
        "routines": [
            {"file": f"routine-{index}", "focusY": focus}
            for index, focus in enumerate(ROUTINE_PHOTO_FOCUS)
        ],
        "routinesSha256": sha256(PUBLIC / "images/routine-photos.webp"),
    }

    document = {
        "schemaVersion": 1,
        "generatedFrom": [
            "src/catalog/media.json", "src/catalog/demos.json", "src/catalog/animations.json",
            "public/images/training-hero.webp", "public/images/routine-photos.webp",
        ],
        "sheets": dict(sorted(sheets.items())),
        "images": images,
        "clips": clips,
        "demos": demo_exercises,
        "sources": demos["sources"],
        "animations": animations,
        "photos": photos,
    }
    return document, sheet_files, clip_files


def pixel_size(path: Path) -> tuple[int, int]:
    output = subprocess.run(
        ["sips", "-g", "pixelWidth", "-g", "pixelHeight", str(path)],
        check=True, capture_output=True, text=True,
    ).stdout
    values = [int(line.split(":")[1]) for line in output.splitlines() if "pixel" in line]
    return values[0], values[1]


def convert_font(source: Path, target: Path) -> None:
    from fontTools.ttLib import TTFont

    font = TTFont(source, recalcTimestamp=False)
    font.flavor = None
    font.save(target)


def build(check: bool) -> int:
    document, sheet_files, clip_files = manifest()
    text = json.dumps(document, indent=2, ensure_ascii=False) + "\n"
    target = MEDIA / "media.json"
    problems: list[str] = []

    if check:
        if not target.exists() or target.read_text() != text:
            problems.append(f"{target.relative_to(ROOT)} is out of date")
        for name, meta in document["sheets"].items():
            sheet = MEDIA / "sheets" / f"{name}.heic"
            if not sheet.exists():
                problems.append(f"missing {sheet.relative_to(ROOT)}")
            elif pixel_size(sheet) != (meta["width"], meta["height"]):
                problems.append(f"{sheet.relative_to(ROOT)} is not {meta['width']}x{meta['height']}")
        for name, source in clip_files.items():
            copy = MEDIA / "demos" / name
            if not copy.exists() or sha256(copy) != sha256(source):
                problems.append(f"{copy.relative_to(ROOT)} differs from {source.relative_to(ROOT)}")
        for web, (bundled, licence) in FONT_SOURCES.items():
            for name in (bundled, licence):
                if not (FONTS / name).exists():
                    problems.append(f"missing {(FONTS / name).relative_to(ROOT)}")
        stamps = json.loads(STAMPS.read_text()) if STAMPS.exists() else {}
        for exercise_id, meta in document["animations"].items():
            for ext in ("mp4", "heic"):
                if not (MEDIA / "animations" / f"{exercise_id}.{ext}").exists():
                    problems.append(f"missing Media/animations/{exercise_id}.{ext}")
            if stamps.get(f"animation:{exercise_id}") != meta["sha256"]:
                problems.append(f"Media/animations/{exercise_id} was recorded from an older SVG")
        photo_names = [document["photos"]["hero"]["file"]] + [
            photo["file"] for photo in document["photos"]["routines"]
        ]
        for name in photo_names:
            if not (MEDIA / "photos" / f"{name}.heic").exists():
                problems.append(f"missing Media/photos/{name}.heic")
        if stamps.get("photo:training-hero") != document["photos"]["hero"]["sha256"] or stamps.get(
            "photo:routines"
        ) != document["photos"]["routinesSha256"]:
            problems.append("Media/photos were made from older web photos")
        for problem in problems:
            print(problem, file=sys.stderr)
        return 1 if problems else 0

    (MEDIA / "sheets").mkdir(parents=True, exist_ok=True)
    (MEDIA / "demos").mkdir(parents=True, exist_ok=True)
    FONTS.mkdir(parents=True, exist_ok=True)

    # Re-encode a sheet only when its source changed, so unchanged sheets keep
    # their bytes and the diff shows real media changes only.
    stamps_path = STAMPS
    stamps = json.loads(stamps_path.read_text()) if stamps_path.exists() else {}
    with tempfile.TemporaryDirectory() as scratch:
        for name, source in sorted(sheet_files.items()):
            sheet = MEDIA / "sheets" / f"{name}.heic"
            digest = document["sheets"][name]["sha256"]
            if sheet.exists() and stamps.get(name) == digest:
                continue
            if sha256(source) != digest:
                raise SystemExit(f"{source} does not match its catalogue checksum")
            temporary = Path(scratch) / f"{name}.heic"
            subprocess.run(
                ["sips", "-s", "format", "heic", "-s", "formatOptions", HEIC_QUALITY,
                 str(source), "--out", str(temporary)],
                check=True, capture_output=True,
            )
            shutil.move(temporary, sheet)
            stamps[name] = digest
    for stale in (MEDIA / "sheets").glob("*.heic"):
        if stale.stem not in sheet_files:
            stale.unlink()
            stamps.pop(stale.stem, None)

    # Animations: re-record only those whose SVG changed (about 4 s each).
    (MEDIA / "animations").mkdir(parents=True, exist_ok=True)
    pending = [
        exercise_id
        for exercise_id, meta in document["animations"].items()
        if stamps.get(f"animation:{exercise_id}") != meta["sha256"]
        or not (MEDIA / "animations" / f"{exercise_id}.mp4").exists()
    ]
    if pending:
        with tempfile.TemporaryDirectory() as scratch:
            subprocess.run(
                ["node", str(ROOT / "scripts/render-ios-animations.mjs"), scratch, *pending],
                check=True,
            )
            for exercise_id in pending:
                shutil.move(Path(scratch) / f"{exercise_id}.mp4",
                            MEDIA / "animations" / f"{exercise_id}.mp4")
                subprocess.run(
                    ["sips", "-s", "format", "heic", "-s", "formatOptions", HEIC_QUALITY,
                     str(Path(scratch) / f"{exercise_id}.png"),
                     "--out", str(MEDIA / "animations" / f"{exercise_id}.heic")],
                    check=True, capture_output=True,
                )
                stamps[f"animation:{exercise_id}"] = document["animations"][exercise_id]["sha256"]
    for stale in (MEDIA / "animations").iterdir():
        if stale.stem not in document["animations"]:
            stale.unlink()
            stamps.pop(f"animation:{stale.stem}", None)

    # Photos: the hero as it is; the routine strip cut into its three panels.
    photos_dir = MEDIA / "photos"
    photos_dir.mkdir(parents=True, exist_ok=True)
    hero = document["photos"]["hero"]
    if stamps.get("photo:training-hero") != hero["sha256"]:
        subprocess.run(
            ["sips", "-s", "format", "heic", "-s", "formatOptions", HEIC_QUALITY,
             str(PUBLIC / "images/training-hero.webp"), "--out", str(photos_dir / "training-hero.heic")],
            check=True, capture_output=True,
        )
        stamps["photo:training-hero"] = hero["sha256"]
    if stamps.get("photo:routines") != document["photos"]["routinesSha256"]:
        width, height = pixel_size(PUBLIC / "images/routine-photos.webp")
        panel = width // 3
        with tempfile.TemporaryDirectory() as scratch:
            strip = Path(scratch) / "strip.png"
            subprocess.run(["sips", "-s", "format", "png", str(PUBLIC / "images/routine-photos.webp"),
                            "--out", str(strip)], check=True, capture_output=True)
            from PIL import Image  # sips crops around the centre, not from a corner

            with Image.open(strip) as whole:
                for index, photo in enumerate(document["photos"]["routines"]):
                    part = Path(scratch) / f"{index}.png"
                    whole.crop((index * panel, 0, (index + 1) * panel, height)).save(part)
                    subprocess.run(["sips", "-s", "format", "heic", "-s", "formatOptions", HEIC_QUALITY,
                                    str(part), "--out", str(photos_dir / f"{photo['file']}.heic")],
                                   check=True, capture_output=True)
        stamps["photo:routines"] = document["photos"]["routinesSha256"]

    stamps_path.write_text(json.dumps(dict(sorted(stamps.items())), indent=2) + "\n")

    for name, source in clip_files.items():
        copy = MEDIA / "demos" / name
        if not copy.exists() or sha256(copy) != sha256(source):
            shutil.copyfile(source, copy)
    for stale in (MEDIA / "demos").iterdir():
        if stale.name not in clip_files:
            stale.unlink()

    for web, (bundled, licence) in FONT_SOURCES.items():
        convert_font(PUBLIC / "fonts" / web, FONTS / bundled)
        shutil.copyfile(PUBLIC / "fonts" / licence, FONTS / licence)

    target.write_text(text)
    return 0


if __name__ == "__main__":
    sys.exit(build("--check" in sys.argv[1:]))
