#!/usr/bin/env python3
"""Rasterize FORMA's simple SVG facets. Requires Pillow 12.3.0; no network.

Run from any directory:
  python3 ios/design/build-icon.py --check
  python3 ios/design/build-icon.py --output /tmp/forma-icon.png

Only the current absolute M/L/H/V/Z polygon paths and translate/scale transform
are supported. A changed vector outside that subset fails rather than silently
producing a different logo. The original 4x/Lanczos rasterization is retained.
"""

import argparse
import hashlib
from pathlib import Path
import re
import xml.etree.ElementTree as ET

from PIL import Image, ImageChops, ImageDraw

DESIGN = Path(__file__).resolve().parent
SOURCE = DESIGN / "app-icon.svg"
DEFAULT_OUTPUT = DESIGN.parent / "FORMA/Resources/Assets.xcassets/AppIcon.appiconset/app-icon.png"
NS = {"svg": "http://www.w3.org/2000/svg"}


def polygon(data):
    tokens = re.findall(r"[A-Za-z]|[-+]?(?:\d*\.)?\d+", data)
    points = []
    x = y = 0.0
    cursor = 0
    while cursor < len(tokens):
        command = tokens[cursor]
        cursor += 1
        if command in ("M", "L"):
            x, y = map(float, tokens[cursor : cursor + 2])
            cursor += 2
        elif command == "H":
            x = float(tokens[cursor])
            cursor += 1
        elif command == "V":
            y = float(tokens[cursor])
            cursor += 1
        elif command == "Z":
            if cursor != len(tokens):
                raise ValueError("Multiple subpaths are not supported.")
            break
        else:
            raise ValueError(f"Unsupported SVG path command: {command}")
        points.append((x, y))
    if len(points) < 3:
        raise ValueError("An icon facet needs at least three points.")
    return points


def render():
    root = ET.parse(SOURCE).getroot()
    if root.attrib.get("viewBox") != "0 0 1024 1024":
        raise ValueError("Review rasterization before changing the icon viewBox.")
    background = root.find("svg:rect", NS)
    group = root.find("svg:g", NS)
    if background is None or group is None:
        raise ValueError("Missing icon background or facet group.")
    transform = re.fullmatch(
        r"translate\(([\d.]+)\s+([\d.]+)\)\s+scale\(([\d.]+)\)",
        group.attrib["transform"],
    )
    if transform is None:
        raise ValueError("Unsupported icon transform.")
    tx, ty, scale = map(float, transform.groups())
    supersampling = 4
    image = Image.new("RGB", (1024 * supersampling, 1024 * supersampling), background.attrib["fill"])
    draw = ImageDraw.Draw(image)
    for path in group.findall("svg:path", NS):
        points = [
            ((tx + scale * x) * supersampling, (ty + scale * y) * supersampling)
            for x, y in polygon(path.attrib["d"])
        ]
        draw.polygon(points, fill=path.attrib.get("fill", group.attrib["fill"]))
    return image.resize((1024, 1024), Image.Resampling.LANCZOS)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Check pixels without writing any file")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    arguments = parser.parse_args()
    image = render()
    if arguments.check:
        with Image.open(arguments.output) as existing:
            if existing.mode != "RGB" or existing.size != image.size or ImageChops.difference(existing, image).getbbox():
                raise SystemExit("Icon pixels differ from the source SVG rasterization.")
        print("Icon pixels match the source SVG; no file changed.")
    else:
        arguments.output.parent.mkdir(parents=True, exist_ok=True)
        image.save(arguments.output, format="PNG")
        print("Wrote", arguments.output)
    print("PNG SHA-256:", hashlib.sha256(arguments.output.read_bytes()).hexdigest())


if __name__ == "__main__":
    main()
