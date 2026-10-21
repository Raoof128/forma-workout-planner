"""Animated SVG exercise demonstrations from a small 3D figure rig.

Joints live in 3D (x right, y down, z toward the viewer) and are projected
orthographically, so limbs keep their true length as they rotate. Each
exercise is a pose function of named channels (0 = start, 1 = end of the
working phase) plus a timeline. Poses are sampled at FPS and emitted as SMIL
<animate> values with linear interpolation between samples.
"""
import base64
import math
import re
from html import escape
from pathlib import Path

W, H = 960, 720
FPS = 15
FLOOR = 630
INK, FAR, MUTED, LINE = "#202522", "#a3aca6", "#59635d", "#dfe4dc"
FRAME, PAD, PLATE, PATH = "#4a524c", "#3a413c", "#2c332e", "#9bbb2c"
LIME = "#dff780"
TORSO, NECK, HEAD, UA, FA, TH, SH, FOOT = 190, 18, 30, 112, 100, 160, 155, 50
REPO = Path(__file__).resolve().parents[2]


# ---------------------------------------------------------------- vectors
def v(x, y, z=0.0):
    return (float(x), float(y), float(z))


def add(a, b):
    return tuple(p + q for p, q in zip(a, b))


def sub(a, b):
    return tuple(p - q for p, q in zip(a, b))


def mul(a, k):
    return tuple(p * k for p in a)


def dot(a, b):
    return sum(p * q for p, q in zip(a, b))


def norm(a):
    length = math.sqrt(dot(a, a)) or 1.0
    return mul(a, 1 / length)


def dist(a, b):
    return math.sqrt(dot(sub(a, b), sub(a, b)))


def lerp(a, b, u):
    return add(a, mul(sub(b, a), u))


def ik(root, target, l1, l2, pole):
    """Middle joint of a two-bone limb, bending toward the pole direction."""
    d = sub(target, root)
    length = min(math.sqrt(dot(d, d)), l1 + l2 - 0.5)
    direction = norm(d)
    a = (l1 * l1 - l2 * l2 + length * length) / (2 * length)
    h = math.sqrt(max(l1 * l1 - a * a, 0.0))
    p = norm(sub(pole, mul(direction, dot(pole, direction))))
    return add(add(root, mul(direction, a)), mul(p, h))


def reach(root, target, l1, l2):
    """Clamp a hand target to what the arm can reach (keeps elbows soft)."""
    d = sub(target, root)
    length = math.sqrt(dot(d, d))
    limit = l1 + l2 - 6
    return target if length <= limit else add(root, mul(norm(d), limit))


def slerp(a, b, u):
    a, b = norm(a), norm(b)
    angle = math.acos(max(-1.0, min(1.0, dot(a, b))))
    if angle < 1e-6:
        return a
    s = math.sin(angle)
    return add(mul(a, math.sin((1 - u) * angle) / s), mul(b, math.sin(u * angle) / s))


def arc(pivot, start, end, u):
    """Point on the circle about pivot, from start to end (a lever path)."""
    a0 = math.atan2(start[1] - pivot[1], start[0] - pivot[0])
    a1 = math.atan2(end[1] - pivot[1], end[0] - pivot[0])
    delta = (a1 - a0 + math.pi) % (2 * math.pi) - math.pi
    r0 = math.hypot(start[0] - pivot[0], start[1] - pivot[1])
    r1 = math.hypot(end[0] - pivot[0], end[1] - pivot[1])
    r, a = r0 + (r1 - r0) * u, a0 + delta * u
    return v(pivot[0] + r * math.cos(a), pivot[1] + r * math.sin(a), lerp(start, end, u)[2])


def pivot_for(start, end, offset):
    """A pivot on the perpendicular bisector of start-end (signed offset)."""
    mx, my = (start[0] + end[0]) / 2, (start[1] + end[1]) / 2
    dx, dy = end[0] - start[0], end[1] - start[1]
    n = math.hypot(dx, dy)
    return v(mx - dy / n * offset, my + dx / n * offset)


def ease(u):
    return u * u * (3 - 2 * u)


# ---------------------------------------------------------------- drawing
class Scene:
    """One sampled frame: an ordered list of drawable primitives."""

    def __init__(self):
        self.items = []

    def seg(self, key, a, b, width, color, layer=0.0):
        self.items.append((layer, key, "seg", (a[0], a[1], b[0], b[1]), (width, color)))

    def dot(self, key, c, r, color, layer=0.0):
        self.items.append((layer, key, "dot", (c[0], c[1], r), color))

    def poly(self, key, points, color, layer=0.0, stroke=None):
        flat = tuple(coord for p in points for coord in p[:2])
        self.items.append((layer, key, "poly", flat, (color, stroke)))

    def box(self, key, center, w, h, angle, color, layer=0.0):
        c, s = math.cos(angle), math.sin(angle)
        pts = [(center[0] + x * c - y * s, center[1] + x * s + y * c)
               for x, y in ((-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2))]
        self.poly(key, pts, color, layer)


def limb_color(z):
    return INK if z >= 0 else FAR


def draw_arm(sc, side, shoulder, elbow, hand, layer):
    color = limb_color(shoulder[2])
    sc.seg(f"ua{side}", shoulder, elbow, 34, color, layer)
    sc.seg(f"fa{side}", elbow, hand, 28, color, layer + 0.01)
    sc.dot(f"hd{side}", hand, 14, color, layer + 0.02)


def draw_leg(sc, side, hip, knee, ankle, toe, layer):
    color = limb_color(hip[2])
    sc.seg(f"th{side}", hip, knee, 44, color, layer)
    sc.seg(f"sh{side}", knee, ankle, 36, color, layer + 0.01)
    sc.seg(f"ft{side}", ankle, toe, 22, color, layer + 0.02)


def side_body(sc, hip, shoulder, head_dir=None):
    """Torso, neck and head for a side view, drawn at depth 0."""
    up = norm(sub(shoulder, hip))
    head_dir = head_dir or up
    neck_end = add(shoulder, mul(head_dir, NECK))
    sc.seg("torso", hip, shoulder, 64, INK, 0)
    sc.seg("neck", shoulder, neck_end, 24, INK, 0.01)
    sc.dot("head", add(neck_end, mul(head_dir, HEAD - 4)), HEAD, INK, 0.02)


def dumbbell_side(sc, key, hand, axis, layer):
    a = norm((axis[0], axis[1], 0))
    sc.seg(f"{key}h", add(hand, mul(a, -34)), add(hand, mul(a, 34)), 10, PLATE, layer)
    angle = math.atan2(a[1], a[0])
    for k, sgn in (("a", -1), ("b", 1)):
        sc.box(f"{key}{k}", add(hand, mul(a, 40 * sgn)), 22, 44, angle, PLATE, layer + 0.01)


def dumbbell_end(sc, key, hand, layer):
    sc.dot(f"{key}o", hand, 20, PLATE, layer)
    sc.dot(f"{key}i", hand, 8, "#6b746e", layer + 0.01)


# ---------------------------------------------------------------- timeline
def build_timeline(steps):
    """steps: (seconds, {channel: target}, label). Channels hold otherwise."""
    total = sum(s for s, _, _ in steps)
    return total, steps


def channels_at(t, steps, start):
    state = dict(start)
    elapsed = 0.0
    for seconds, targets, _ in steps:
        if t <= elapsed + seconds:
            u = ease((t - elapsed) / seconds) if seconds else 1
            return {k: state[k] + (targets.get(k, state[k]) - state[k]) * u for k in state}
        state.update(targets)
        elapsed += seconds
    return state


def fmt(n):
    return f"{n:.1f}".rstrip("0").rstrip(".")


def render(ex, out, still=False):
    """Write the animated SVG, or with still=True a frozen start pose."""
    total, steps = build_timeline(ex["steps"])
    frames = max(2, round(total * FPS))
    times = [total * i / frames for i in range(frames + 1)]
    if still:
        times = [0.0, 0.0]
    scenes = []
    for t in times:
        sc = Scene()
        ex["pose"](sc, channels_at(t, steps, ex["start"]))
        scenes.append(sorted(sc.items, key=lambda item: item[0]))
    order = [item[1] for item in scenes[0]]
    for scene in scenes:
        assert [item[1] for item in scene] == order, "draw order changed between frames"
    key_times = ";".join(f"{i / frames:.4f}" for i in range(frames + 1))
    anim = f'dur="{total:.2f}s" repeatCount="indefinite" keyTimes="{key_times}"'

    parts = []
    # Motion path of the tracked point across the working phase.
    if ex.get("path"):
        pts = []
        for i in range(25):
            sc = Scene()
            state = dict(ex["start"])
            state.update({ex["path"]: i / 24})
            ex["pose"](sc, state)
            tracked = next(item for item in sc.items if item[1] == ex["track"])
            g = tracked[3]
            if tracked[2] == "seg":
                pts.append(((g[0] + g[2]) / 2, (g[1] + g[3]) / 2))
            elif tracked[2] == "poly":
                pts.append((sum(g[0::2]) / (len(g) / 2), sum(g[1::2]) / (len(g) / 2)))
            else:
                pts.append(g[:2])
        d = "M" + " L".join(f"{fmt(x)} {fmt(y)}" for x, y in pts)
        parts.append(
            f'<path d="{d}" fill="none" stroke="{PATH}" stroke-width="5" stroke-linecap="round" '
            f'stroke-dasharray="1 12" opacity=".9"/>'
        )
    for index, key in enumerate(order):
        kind = scenes[0][index][2]
        style = scenes[0][index][4]
        geoms = [scene[index][3] for scene in scenes]
        static = all(g == geoms[0] for g in geoms)
        if kind == "seg":
            width, color = style
            ds = [f"M{fmt(g[0])} {fmt(g[1])}L{fmt(g[2])} {fmt(g[3])}" for g in geoms]
            attrs = f'stroke="{color}" stroke-width="{width}" stroke-linecap="round" fill="none"'
            # Body segments get a white outline so overlapping limbs stay readable.
            layers = [(f'stroke="#fff" stroke-width="{width + 8}" stroke-linecap="round" fill="none"')] if color in (INK, FAR) else []
            for a in layers + [attrs]:
                if static:
                    parts.append(f'<path d="{ds[0]}" {a}/>')
                else:
                    parts.append(f'<path d="{ds[0]}" {a}><animate attributeName="d" values="{";".join(ds)}" {anim}/></path>')
        elif kind == "dot":
            outline = ' stroke="#fff" stroke-width="5"' if style in (INK, FAR) else ""
            if static:
                g = geoms[0]
                parts.append(f'<circle cx="{fmt(g[0])}" cy="{fmt(g[1])}" r="{fmt(g[2])}" fill="{style}"{outline}/>')
            else:
                g = geoms[0]
                cx = ";".join(fmt(x[0]) for x in geoms)
                cy = ";".join(fmt(x[1]) for x in geoms)
                parts.append(
                    f'<circle cx="{fmt(g[0])}" cy="{fmt(g[1])}" r="{fmt(g[2])}" fill="{style}"{outline}>'
                    f'<animate attributeName="cx" values="{cx}" {anim}/>'
                    f'<animate attributeName="cy" values="{cy}" {anim}/></circle>'
                )
        else:
            color, stroke = style
            ds = ["M" + " L".join(f"{fmt(g[i])} {fmt(g[i + 1])}" for i in range(0, len(g), 2)) + "Z" for g in geoms]
            extra = f' stroke="{stroke}" stroke-width="3"' if stroke else ""
            if static:
                parts.append(f'<path d="{ds[0]}" fill="{color}"{extra}/>')
            else:
                parts.append(f'<path d="{ds[0]}" fill="{color}"{extra}><animate attributeName="d" values="{";".join(ds)}" {anim}/></path>')

    # Phase captions and the progress bar.
    captions = []
    elapsed = 0.0
    for seconds, _, label in steps:
        start, end = elapsed / total, (elapsed + seconds) / total
        elapsed += seconds
        if not label:
            continue
        if start == 0:
            values, kt = "1;0", f"0;{end:.4f}"
        elif end >= 1:
            values, kt = "0;1", f"0;{start:.4f}"
        else:
            values, kt = "0;1;0", f"0;{start:.4f};{end:.4f}"
        if still:
            if start == 0:
                captions.append(f'<text class="t" x="40" y="680" font-size="24" font-weight="600">{escape(label)}</text>')
            continue
        captions.append(
            f'<text class="t" x="40" y="680" font-size="24" font-weight="600" opacity="{values[0]}">{escape(label)}'
            f'<animate attributeName="opacity" calcMode="discrete" values="{values}" keyTimes="{kt}" dur="{total:.2f}s" repeatCount="indefinite"/></text>'
        )

    overlays = []
    bounds, elapsed = [], 0.0
    for seconds, _, _ in steps:
        bounds.append((elapsed / total, (elapsed + seconds) / total))
        elapsed += seconds
    for markup, indices in ex.get("overlays", []):
        if callable(markup):
            markup = markup(total, steps)
        if still:
            if indices is None or 0 in indices:
                overlays.append(re.sub(r"<animate [^>]*/>", "", markup))
            continue
        if indices is None:
            overlays.append(markup)
            continue
        values, kt = ["0"], ["0"]
        for i in sorted(indices):
            a, b = bounds[i]
            if a == 0:
                values[0] = "1"
            else:
                values.append("1"); kt.append(f"{a:.4f}")
            if b < 1:
                values.append("0"); kt.append(f"{b:.4f}")
        overlays.append(
            f'<g opacity="{values[0]}">{markup}<animate attributeName="opacity" calcMode="discrete" '
            f'values="{";".join(values)}" keyTimes="{";".join(kt)}" dur="{total:.2f}s" repeatCount="indefinite"/></g>'
        )

    fonts = (
        "@font-face{font-family:'DM Sans';src:url(data:font/woff2;base64,"
        + base64.b64encode((REPO / "public/fonts/dm-sans-variable.woff2").read_bytes()).decode()
        + ") format('woff2');font-weight:100 1000}"
        "@font-face{font-family:'Barlow Condensed';src:url(data:font/woff2;base64,"
        + base64.b64encode((REPO / "public/fonts/barlow-condensed-700.woff2").read_bytes()).decode()
        + ") format('woff2');font-weight:700}"
    )
    svg = (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}" role="img" aria-labelledby="t d">'
        f'<title id="t">{escape(ex["name"])}: how to perform</title>'
        f'<desc id="d">{escape(ex["desc"])}</desc>'
        f"<style>{fonts}.t{{font-family:'DM Sans',system-ui,sans-serif;fill:{INK}}}"
        f".h{{font-family:'Barlow Condensed','Arial Narrow',sans-serif;font-weight:700;fill:{INK}}}</style>"
        f'<rect width="{W}" height="{H}" fill="#fff"/>'
        + (f'<rect x="0" y="{FLOOR}" width="{W}" height="{H - FLOOR}" fill="#f5f6f3"/>'
           f'<line x1="0" x2="{W}" y1="{FLOOR}" y2="{FLOOR}" stroke="{LINE}" stroke-width="3"/>'
           if ex.get("floor", True) else f'<rect x="0" y="650" width="{W}" height="{H - 650}" fill="#f5f6f3"/>')
        + f'<text class="h" x="40" y="62" font-size="40">{escape(ex["name"])}</text>'
        f'<text class="t" x="40" y="94" font-size="19" fill="{MUTED}" style="fill:{MUTED}">{escape(ex["muscles"])}</text>'
        f'<text class="t" x="{W - 40}" y="62" font-size="18" text-anchor="end" style="fill:{MUTED}">FORMA · how to perform</text>'
        + (f'<g transform="translate({W / 2 * (1 - ex["scale"]):.1f} {FLOOR * (1 - ex["scale"]):.1f}) scale({ex["scale"]})">' if ex.get("scale") else "")
        + "".join(parts)
        + "".join(overlays)
        + ("</g>" if ex.get("scale") else "")
        + f'<rect x="40" y="698" width="{W - 80}" height="6" rx="3" fill="{LINE}"/>'
        + ("" if still else f'<rect x="40" y="698" width="0" height="6" rx="3" fill="{INK}"><animate attributeName="width" values="0;{W - 80}" dur="{total:.2f}s" repeatCount="indefinite"/></rect>')
        + "".join(captions)
        + "</svg>"
    )
    Path(out).write_text(svg)
    return total, len(svg)
