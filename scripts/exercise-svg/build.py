"""Build every exercise demonstration: python3 build.py

Writes public/exercise-animations/<slug>.svg (animated) and <slug>-still.svg
(the start pose, shown while paused or with reduced motion), then
src/catalog/animations.json mapping each FORMA exercise ID to its files.
Each exercise is built once even when several routines use it.
"""
import json
import subprocess
import sys
from pathlib import Path

import core
import exercises
import legs
import legs_b
import upper_b
from rig import render

ROOT = Path(__file__).resolve().parents[2]
SETS = {
    # Monday uses the two-view lateral raise from the core set.
    "upper-a": [core.LATERAL3 if ex["slug"] == "dumbbell-lateral-raise" else ex for ex in exercises.ALL],
    "legs-a": legs.ALL,
    "core": core.ALL,
    # Thursday's lateral raise is the same demo as core's, so it is not repeated.
    "upper-b": upper_b.ALL,
    # Saturday's seated leg curl (legs-a) and standing calf raise (core) are shared.
    "legs-b": legs_b.ALL,
}


def unique():
    seen = {}
    for items in SETS.values():
        for ex in items:
            seen.setdefault(ex["slug"], ex)
    return list(seen.values())


def resolve_ids(names):
    """Map exact FORMA exercise names to canonical guide IDs via the catalogue."""
    script = (
        'import("./src/data.js").then(({selectableExercises, guideExercise}) => {'
        "const names = JSON.parse(process.argv[1]); const out = {};"
        "for (const name of names) { const hit = selectableExercises.filter("
        "e => e.name.toLowerCase() === name.toLowerCase());"
        "if (hit.length !== 1) throw new Error(`No unique exercise named ${name}`);"
        "out[name] = guideExercise(hit[0].id).id; } console.log(JSON.stringify(out)); })"
    )
    result = subprocess.run(["node", "-e", script, json.dumps(names)], cwd=ROOT, check=True,
                            capture_output=True, text=True)
    return json.loads(result.stdout)


if __name__ == "__main__":
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "public/exercise-animations"
    out.mkdir(parents=True, exist_ok=True)
    items = unique()
    ids = resolve_ids([ex["name"] for ex in items])
    manifest = {}
    for ex in items:
        total, size = render(ex, out / f"{ex['slug']}.svg")
        render(ex, out / f"{ex['slug']}-still.svg", still=True)
        manifest[ids[ex["name"]]] = {
            "src": f"/exercise-animations/{ex['slug']}.svg",
            "still": f"/exercise-animations/{ex['slug']}-still.svg",
            "seconds": round(total, 2),
            "description": ex["desc"],
        }
        print(f"{ex['slug']:40} {total:4.1f}s {size // 1024:4} KB")
    if len(sys.argv) == 1:
        (ROOT / "src/catalog/animations.json").write_text(json.dumps(dict(sorted(manifest.items())), indent=2) + "\n")
    print(f"{len(items)} exercises")
