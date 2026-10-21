"""Thursday Upper B exercises (the lateral raise is shared with the core set)."""
import math
from rig import (
    FA, FAR, FLOOR, FRAME, INK, LIME, LINE, PAD, PLATE, SH, TH, TORSO, UA,
    add, draw_arm, draw_leg, dumbbell_end, ik, lerp, mul, norm, reach,
    side_body, slerp, sub, v,
)
from exercises import HIP_Z, SHOULDER_Z
from legs import deg
from core import GLOW, Camera, glow, shadow

CABLE = "#8a948d"
DUAL_FRONT = Camera(0, 4, 250, 606, 0.76)
DUAL_SIDE = Camera(90, 4, 660, 606, 0.76)
STAND_FRONT = Camera(0, 4, 250, 602, 0.7)
STAND_SIDE = Camera(90, 4, 640, 602, 0.7)


def dual_labels():
    return (
        f'<line x1="470" x2="470" y1="110" y2="612" stroke="{LINE}" stroke-width="3" stroke-dasharray="2 10" stroke-linecap="round"/>'
        '<text class="t" x="250" y="638" font-size="16" font-weight="700" text-anchor="middle" letter-spacing="2" style="fill:#59635d">FRONT</text>'
        '<text class="t" x="680" y="638" font-size="16" font-weight="700" text-anchor="middle" letter-spacing="2" style="fill:#59635d">SIDE</text>'
    )


def incline_bench(sc, hip, angle, layer=-2):
    """Seat plus a back pad behind a torso leaning back at `angle` from horizontal."""
    up = (-math.cos(math.radians(angle)), -math.sin(math.radians(angle)), 0)
    back = (-math.sin(math.radians(angle)), math.cos(math.radians(angle)), 0)
    sc.box("seat", (hip[0] + 10, hip[1] + 38), 130, 22, 0, PAD, layer)
    low, high = add(add(hip, mul(back, 42)), mul(up, -10)), add(add(hip, mul(back, 42)), mul(up, TORSO + 34))
    sc.seg("backpad", low, high, 30, PAD, layer)
    sc.seg("benchpost", v(hip[0] + 10, hip[1] + 50), v(hip[0] + 10, FLOOR - 6), 16, FRAME, layer - 0.5)
    sc.seg("benchbase", v(hip[0] - 120, FLOOR - 6), v(hip[0] + 110, FLOOR - 6), 12, FRAME, layer - 0.5)
    sc.seg("benchbrace", v(hip[0] - 110, FLOOR - 6), lerp(low, high, 0.5), 12, FRAME, layer - 0.5)
    return add(hip, mul(up, TORSO)), up


def seated_feet(sc, hip, knee_x=None):
    knee_x = knee_x or hip[0] + 150
    for side, z in (("f", -HIP_Z), ("n", HIP_Z)):
        h = v(hip[0], hip[1], z)
        ankle = v(knee_x + 28, FLOOR - 20, z)
        knee = ik(h, ankle, TH, SH, (1, -1, 0))
        draw_leg(sc, side, h, knee, ankle, v(ankle[0] + 46, FLOOR - 8, z), 0.5 if z > 0 else -1)


# ------------------------------------------------------- 1 incline dumbbell press
def incline_press_pose(sc, c):
    u = c["u"]
    hip = v(500, 470)
    shoulder, up = incline_bench(sc, hip, 40)
    chest = (-up[1], up[0], 0)  # normal out of the chest
    side_body(sc, hip, shoulder)
    seated_feet(sc, hip)
    for side, z in (("f", -1), ("n", 1)):
        s = add(shoulder, v(0, 0, SHOULDER_Z * z))
        low = add(add(shoulder, mul(chest, 26)), mul(up, -46))
        high = add(shoulder, v(4, -204, 0))
        hand = lerp(v(low[0], low[1], (SHOULDER_Z + 46) * z), v(high[0], high[1], (SHOULDER_Z + 6) * z), u)
        hand = reach(s, hand, UA, FA)
        elbow = ik(s, hand, UA, FA, (0.25, 1, 0.9 * z))
        layer = 1 if z > 0 else -1.5
        draw_arm(sc, side, s, elbow, hand, layer)
        dumbbell_end(sc, f"db{side}", hand, layer + 0.03)
    glow(sc, "chest", add(lerp(hip, shoulder, 0.7), mul(chest, 22)), add(lerp(hip, shoulder, 0.95), mul(chest, 22)))


INCLINE_PRESS = {
    "slug": "incline-dumbbell-press", "name": "Incline Dumbbell Press", "muscles": "Upper chest · front shoulders · triceps",
    "desc": "Lying back on an incline bench with a dumbbell in each hand at the upper chest, the dumbbells press up until the arms are long over the shoulders, then lower under control back to the chest.",
    "pose": incline_press_pose, "start": {"u": 0},
    "steps": [
        (0.5, {}, "Dumbbells at the upper chest, elbows under the wrists"),
        (1.0, {"u": 1}, "Press up over the shoulders · 1 s"),
        (0.4, {}, "Arms long, dumbbells don't touch"),
        (2.0, {"u": 0}, "Lower to the chest under control · 2 s"),
        (0.35, {}, ""),
    ],
    "path": "u", "track": "hdn",
}


# ------------------------------------------------------------ 3D skeleton views
def draw_skeleton(sc, cam, tag, j, near_side, extras=()):
    """Draw a 3D skeleton through one camera; near_side None means front view."""
    def col(side, base):
        if near_side is None or side == near_side:
            return INK, base
        return FAR, base - 2.5

    for key, a, b, width, color, layer in extras:
        sc.seg(f"{tag}{key}", cam(a), cam(b), width, color, layer)
    for side in ("r", "l"):
        color, layer = col(side, 0.5 if near_side else 0)
        sc.seg(f"{tag}th{side}", cam(j[f"hip{side}"]), cam(j[f"knee{side}"]), 44, color, layer)
        sc.seg(f"{tag}sh{side}", cam(j[f"knee{side}"]), cam(j[f"ankle{side}"]), 36, color, layer + 0.01)
        sc.seg(f"{tag}ft{side}", cam(j[f"ankle{side}"]), cam(j[f"toe{side}"]), 22, color, layer + 0.02)
    sc.seg(f"{tag}torso", cam(j["pelvis"]), cam(j["sh_c"]), 70, INK, 0.1)
    sc.seg(f"{tag}girdle", cam(j["shl"]), cam(j["shr"]), 34, INK, 0.11)
    sc.seg(f"{tag}neck", cam(j["sh_c"]), cam(j["neck"]), 26, INK, 0.12)
    sc.dot(f"{tag}head", cam(j["head"]), 32, INK, 0.13)
    for side in ("r", "l"):
        color, layer = col(side, 1)
        sc.seg(f"{tag}ua{side}", cam(j[f"sh{side}"]), cam(j[f"el{side}"]), 32, color, layer)
        sc.seg(f"{tag}fa{side}", cam(j[f"el{side}"]), cam(j[f"hd{side}"]), 26, color, layer + 0.01)
        sc.dot(f"{tag}hd{side}", cam(j[f"hd{side}"]), 12, color, layer + 0.02)


def torso_joints(pelvis, lean_back):
    r = math.radians(lean_back)
    spine = v(0, -math.cos(r), -math.sin(r))
    sh_c = add(pelvis, mul(spine, TORSO))
    return spine, {
        "pelvis": pelvis, "sh_c": sh_c, "neck": add(sh_c, mul(spine, 22)),
        "head": add(add(sh_c, mul(spine, 54)), v(0, 0, 6)),
        "shr": add(sh_c, v(76, 0, 0)), "shl": add(sh_c, v(-76, 0, 0)),
    }


# ------------------------------------------------------- 2 wide-grip lat pulldown
def pulldown_skeleton(u):
    pelvis = v(0, -176, 0)
    spine, j = torso_joints(pelvis, 8 + 8 * u)
    for side, sgn in (("r", 1), ("l", -1)):
        j[f"hip{side}"] = add(pelvis, v(40 * sgn, 0, 0))
        j[f"knee{side}"] = v(42 * sgn, -184, 158)
        j[f"ankle{side}"] = v(44 * sgn, -30, 168)
        j[f"toe{side}"] = v(46 * sgn, -14, 214)
    top_y = -176 - 190 - 196
    bar_y = top_y + (j["sh_c"][1] + 26 - top_y) * u
    bar_z = 18 + (j["sh_c"][2] + 44 - 18) * u
    for side, sgn in (("r", 1), ("l", -1)):
        s = j[f"sh{side}"]
        hand = reach(s, v(118 * sgn, bar_y, bar_z), UA, FA)
        j[f"el{side}"] = ik(s, hand, UA, FA, v(1.2 * sgn, 1, -0.5))
        j[f"hd{side}"] = hand
    j["bar"] = (v(-158, bar_y, bar_z), v(158, bar_y, bar_z))
    return j


def pulldown_pose(sc, c):
    j = pulldown_skeleton(c["u"])
    pulley = v(0, -612, 24)
    bar_c = lerp(j["bar"][0], j["bar"][1], 0.5)
    extras = [
        ("frame", v(0, 0, -110), v(0, -632, -110), 18, FRAME, -4),
        ("beam", v(0, -632, -110), v(0, -632, 24), 14, FRAME, -4),
        ("seatx", v(-70, -150, -10), v(70, -150, -10), 24, PAD, -3),
        ("seatz", v(0, -150, -70), v(0, -150, 70), 24, PAD, -3),
        ("seatpost", v(0, -150, -10), v(0, 0, -10), 14, FRAME, -3.5),
        ("cable", bar_c, pulley, 4, CABLE, -0.5),
        ("kneepad", v(-70, -214, 150), v(70, -214, 150), 32, PAD, 0.7),
    ]
    for cam, tag, near in ((DUAL_FRONT, "F", None), (DUAL_SIDE, "S", "l")):
        shadow(sc, cam, f"{tag}shadow", v(0, 0, 60), 120, 110)
        draw_skeleton(sc, cam, tag, j, near, extras)
        sc.dot(f"{tag}pulley", cam(pulley), 18, FRAME, -0.4)
        sc.seg(f"{tag}bar", cam(j["bar"][0]), cam(j["bar"][1]), 12, CABLE, 1.5)
        for side in ("r", "l"):
            if near is None or side == near:
                sc.dot(f"{tag}lat{side}", cam(add(lerp(j["pelvis"], j[f"sh{side}"], 0.62), v(0, 0, -20))), 12, GLOW, 0.15)


PULLDOWN = {
    "slug": "wide-grip-lat-pulldown", "name": "Wide-Grip Lat Pulldown", "muscles": "Lats · upper back · biceps",
    "desc": "Shown from the front and side: seated with the thighs under the pad and a wide overhand grip, the bar pulls down to the upper chest as the elbows drive down to the sides and the chest lifts, then rises slowly until the arms are long.",
    "pose": pulldown_pose, "start": {"u": 0}, "floor": False,
    "steps": [
        (0.5, {}, "Wide overhand grip, thighs under the pad"),
        (1.1, {"u": 1}, "Pull the bar to the upper chest · 1 s"),
        (0.45, {}, "Elbows down to your sides, chest up"),
        (2.0, {"u": 0}, "Let the bar rise, arms long · 2 s"),
        (0.35, {}, ""),
    ],
    "path": None, "track": None,
    "overlays": [(dual_labels(), None)],
}


# ------------------------------------------------------------ 3 seated cable row
def stack(sc, x, u, top=330):
    sc.seg("stkL", v(x - 36, top), v(x - 36, FLOOR - 4), 8, "#7d877f", -3)
    sc.seg("stkR", v(x + 36, top), v(x + 36, FLOOR - 4), 8, "#7d877f", -3)
    for i in range(8):
        y = FLOOR - 18 - i * 16 - (54 * u if i >= 5 else 0)
        sc.box(f"stk{i}", (x, y), 66, 12, 0, PLATE, -2.9)


def row_pose(sc, c):
    u = c["u"]
    hip = v(340, 520)
    sc.box("rowseat", (330, 556), 170, 22, 0, PAD, -2)
    sc.seg("rowrail", v(200, FLOOR - 6), v(760, FLOOR - 6), 14, FRAME, -2.5)
    sc.seg("rowpost", v(330, 566), v(330, FLOOR - 6), 16, FRAME, -2.5)
    sc.box("footplate", (642, 572), 18, 92, math.radians(-12), FRAME, -2)
    pulley = v(668, 548)
    sc.seg("column", v(700, FLOOR - 6), v(700, 300), 22, FRAME, -3.2)
    stack(sc, 790, u)
    lean = 10 - 10 * u
    shoulder = add(hip, v(TORSO * math.sin(math.radians(lean)), -TORSO * math.cos(math.radians(lean))))
    for side, z in (("f", -HIP_Z), ("n", HIP_Z)):
        h = v(hip[0], hip[1], z)
        ankle = v(624, 566, z)
        knee = ik(h, ankle, TH, SH, (0, -1, 0))
        draw_leg(sc, side, h, knee, ankle, v(640, 524, z), 0.5 if z > 0 else -1)
    side_body(sc, hip, shoulder)
    start = add(shoulder, v(198, 46))
    end = v(hip[0] + 52, hip[1] - 82)
    handle = lerp(start, end, u)
    sc.seg("cable", handle, pulley, 4, CABLE, 0.8)
    sc.dot("pulley", pulley, 14, FRAME, 0.81)
    for side, z in (("f", -1), ("n", 1)):
        s = add(shoulder, v(0, 0, SHOULDER_Z * z))
        hand = reach(s, v(handle[0], handle[1], 14 * z), UA, FA)
        draw_arm(sc, side, s, ik(s, hand, UA, FA, (-1, 0.35, 0.5 * z)), hand, 1 if z > 0 else -1.5)
    sc.seg("vgrip", add(handle, v(-4, -14)), add(handle, v(4, 14)), 12, PLATE, 1.1)
    glow(sc, "lats", add(lerp(hip, shoulder, 0.45), v(-20, 0)), add(lerp(hip, shoulder, 0.85), v(-20, 0)))


ROW = {
    "slug": "seated-cable-row", "name": "Seated Cable Row", "muscles": "Mid back · lats · biceps",
    "desc": "Seated with the feet on the platform and knees soft, the torso stays upright while the handle rows back to just above the belly button, the shoulder blades squeeze for a moment, then the arms return long without rounding forward.",
    "pose": row_pose, "start": {"u": 0},
    "steps": [
        (0.5, {}, "Sit tall, knees soft, arms long"),
        (1.0, {"u": 1}, "Row to just above the belly button · 1 s"),
        (0.6, {}, "Pause, squeeze the shoulder blades"),
        (1.8, {"u": 0}, "Return, torso stays upright · 2 s"),
        (0.35, {}, ""),
    ],
    "path": "u", "track": "vgrip",
}


# ------------------------------------------------------------------ 5 face pull
def facepull_skeleton(u):
    pelvis = v(0, -335, 0)
    spine, j = torso_joints(pelvis, 4)
    for side, sgn in (("r", 1), ("l", -1)):
        j[f"hip{side}"] = add(pelvis, v(30 * sgn, 0, 0))
        j[f"knee{side}"] = v(34 * sgn, -178, 4)
        j[f"ankle{side}"] = v(36 * sgn, -24, 0)
        j[f"toe{side}"] = v(42 * sgn, -10, 46)
    for side, sgn in (("r", 1), ("l", -1)):
        s = j[f"sh{side}"]
        # Far: arms long toward the pulley. Near: hands by the ears, elbows high.
        reach_pt = v(26 * sgn, j["sh_c"][1] - 30, 200)
        face_pt = v(148 * sgn, j["sh_c"][1] - 96, -6)
        hand = reach(s, lerp(reach_pt, face_pt, u), UA, FA)
        j[f"el{side}"] = ik(s, hand, UA, FA, v(1.4 * sgn, 0.7, -0.6))
        j[f"hd{side}"] = hand
    return j


def facepull_pose(sc, c):
    j = facepull_skeleton(c["u"])
    pulley = v(0, -600, 292)
    knot = lerp(j["hdr"], j["hdl"], 0.5)
    knot = add(knot, v(0, 6, 34))
    extras = [
        ("column", v(0, 0, 310), v(0, -660, 310), 22, FRAME, -4),
        ("cable", pulley, knot, 4, CABLE, 1.4),
        ("roper", knot, j["hdr"], 10, "#c9b48a", 1.45),
        ("ropel", knot, j["hdl"], 10, "#c9b48a", 1.46),
    ]
    for cam, tag, near in ((STAND_FRONT, "F", None), (STAND_SIDE, "S", "l")):
        shadow(sc, cam, f"{tag}shadow", v(0, 0, 60), 120, 150)
        draw_skeleton(sc, cam, tag, j, near, extras)
        sc.dot(f"{tag}pulley", cam(pulley), 16, FRAME, -3.9)
        for side in ("r", "l"):
            if near is None or side == near:
                sc.dot(f"{tag}rd{side}", cam(add(j[f"sh{side}"], v(0, 0, -16))), 12, GLOW, 1.03)


FACEPULL = {
    "slug": "face-pull", "name": "Face Pull", "muscles": "Rear shoulders · upper back · rotator cuff",
    "desc": "Shown from the front and side: facing a high pulley with a rope, a light weight pulls toward the face as the hands separate and the elbows stay high, finishing with the knuckles turned up beside the ears for a one-second squeeze.",
    "pose": facepull_pose, "start": {"u": 0}, "floor": False,
    "steps": [
        (0.5, {}, "Light weight, rope at face height"),
        (1.0, {"u": 1}, "Pull to your face, hands apart · 1 s"),
        (1.0, {}, "Knuckles to the ceiling, squeeze 1 s"),
        (1.6, {"u": 0}, "Arms long under control"),
        (0.35, {}, ""),
    ],
    "path": None, "track": None,
    "overlays": [(dual_labels(), None)],
}


# ------------------------------------------- 6 cable rope overhead triceps extension
def overhead_pose(sc, c):
    u = c["u"]
    pulley = v(214, FLOOR - 26)
    sc.seg("column", v(184, FLOOR - 4), v(184, 210), 22, FRAME, -3.2)
    sc.dot("pulley", pulley, 14, FRAME, -2.8)
    hip = v(470, 300)
    shoulder = add(hip, v(TORSO * math.sin(math.radians(6)), -TORSO * math.cos(math.radians(6))))
    for side, z, ankle_x in (("f", -HIP_Z, 420), ("n", HIP_Z, 540)):
        h = v(hip[0], hip[1], z)
        ankle = v(ankle_x, FLOOR - 20, z)
        knee = ik(h, ankle, TH, SH, (1, 0, 0))
        draw_leg(sc, side, h, knee, ankle, v(ankle_x + 46, FLOOR - 8, z), 0.5 if z > 0 else -1)
    side_body(sc, hip, shoulder)
    angle = -84 + 202 * u  # forearm: up (extended) to down behind the head
    hands = []
    for side, z in (("f", -1), ("n", 1)):
        s = add(shoulder, v(0, 0, SHOULDER_Z * z))
        elbow = add(s, v(-8, -UA + 4, -26 * z))
        hand = add(elbow, mul(deg(angle), FA))
        hand = v(hand[0], hand[1], elbow[2])
        layer = 1 if z > 0 else -1.5
        color = INK if z > 0 else FAR
        sc.seg(f"ua{side}", s, elbow, 32, color, layer)
        sc.seg(f"fa{side}", elbow, hand, 26, color, layer + 0.01)
        sc.dot(f"hd{side}", hand, 12, color, layer + 0.02)
        hands.append(hand)
        if z > 0:
            glow(sc, "tri", add(lerp(s, elbow, 0.2), v(-15, 0)), add(lerp(s, elbow, 0.8), v(-15, 0)), 1.03, 11)
    knot = lerp(hands[0], hands[1], 0.5)
    sc.seg("cable", pulley, knot, 4, CABLE, -2.6)
    sc.seg("rope", hands[0], hands[1], 10, "#c9b48a", 1.04)


OVERHEAD = {
    "slug": "cable-rope-overhead-triceps-extension", "name": "Cable Rope Overhead Triceps Extension",
    "muscles": "Triceps (long head)",
    "desc": "Facing away from a low pulley with a rope held overhead, the upper arms stay still beside the head while the rope lowers behind the head to a full triceps stretch, then the elbows extend to straighten the arms overhead.",
    "pose": overhead_pose, "start": {"u": 0}, "scale": 0.66,
    "steps": [
        (0.5, {}, "Arms overhead, elbows close to the head"),
        (2.0, {"u": 1}, "Lower behind the head to a full stretch · 2 s"),
        (0.45, {}, "Upper arms stay still"),
        (1.0, {"u": 0}, "Extend overhead · 1 s"),
        (0.4, {}, "Squeeze the triceps"),
    ],
    "path": "u", "track": "hdn",
}


# ------------------------------------------------------------ 7 incline dumbbell curl
def incline_curl_pose(sc, c):
    u = c["u"]
    hip = v(500, 470)
    shoulder, up = incline_bench(sc, hip, 47)
    side_body(sc, hip, shoulder)
    seated_feet(sc, hip, hip[0] + 130)
    angle = 90 - 166 * u  # forearm: hanging down to up toward the shoulder
    for side, z in (("f", -1), ("n", 1)):
        s = add(shoulder, v(0, 0, SHOULDER_Z * z))
        elbow = add(s, v(-2, UA, 6 * z))
        hand = add(elbow, mul(deg(angle), FA))
        hand = v(hand[0], hand[1], elbow[2])
        layer = 1 if z > 0 else -1.5
        color = INK if z > 0 else FAR
        sc.seg(f"ua{side}", s, elbow, 32, color, layer)
        sc.seg(f"fa{side}", elbow, hand, 26, color, layer + 0.01)
        sc.dot(f"hd{side}", hand, 12, color, layer + 0.02)
        dumbbell_end(sc, f"db{side}", hand, layer + 0.03)
        if z > 0:
            glow(sc, "bicep", add(lerp(s, elbow, 0.2), v(15, 0)), add(lerp(s, elbow, 0.8), v(15, 0)), 1.04, 11)


INCLINE_CURL = {
    "slug": "incline-dumbbell-curl", "name": "Incline Dumbbell Curl", "muscles": "Biceps (long head)",
    "desc": "Sitting back on an incline bench with the arms hanging straight down and palms forward, the dumbbells curl up toward the shoulders while the upper arms stay still, hold for a second, then lower slowly to a full stretch.",
    "pose": incline_curl_pose, "start": {"u": 0},
    "steps": [
        (0.5, {}, "Arms hang straight down, palms forward"),
        (1.0, {"u": 1}, "Curl up, upper arms stay still · 1 s"),
        (1.0, {}, "Squeeze 1 s"),
        (2.0, {"u": 0}, "Lower to a full stretch · 2 s"),
        (0.35, {}, ""),
    ],
    "path": "u", "track": "hdn",
}

ALL = [INCLINE_PRESS, PULLDOWN, ROW, FACEPULL, OVERHEAD, INCLINE_CURL]
