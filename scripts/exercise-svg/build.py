"""Build every exercise demo set: python3 build.py <output folder>

Writes <output>/<set>/<slug>.svg for each routine set. The committed copies
live in assets/exercise-svg/.
"""
import sys
from pathlib import Path

import core
import exercises
import legs
from rig import render

SETS = {
    # Monday uses the two-view lateral raise from the core set.
    "upper-a": [core.LATERAL3 if ex["slug"] == "dumbbell-lateral-raise" else ex for ex in exercises.ALL],
    "legs-a": legs.ALL,
    "core": core.ALL,
}

if __name__ == "__main__":
    root = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parents[2] / "assets/exercise-svg")
    for name, items in SETS.items():
        (root / name).mkdir(parents=True, exist_ok=True)
        for ex in items:
            total, size = render(ex, root / name / f"{ex['slug']}.svg")
            print(f"{name}/{ex['slug']:34} {total:4.1f}s {size // 1024:4} KB")
