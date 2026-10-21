"""The eight Monday Upper A exercises as rig poses."""
import math
from rig import (
    FA, FLOOR, FRAME, HEAD, NECK, PAD, PLATE, SH, TH, TORSO, UA, LIME, INK,
    add, arc, draw_arm, draw_leg, dumbbell_end, dumbbell_side, ik, lerp, mul,
    norm, pivot_for, reach, side_body, slerp, sub, v,
)

SHOULDER_Z, HIP_Z = 70, 45


def standard(press, hold_end, ret, end_label, start_label="Set up", press_label="", ret_label=""):
    return [
        (0.5, {}, start_label),
        (press, {"u": 1}, press_label),
        (hold_end, {}, end_label),
        (ret, {"u": 0}, ret_label),
        (0.35, {}, ""),
    ]


def seated_legs(sc, hip, knee_x, layer_near=0.5):
    for side, z in (("f", -HIP_Z), ("n", HIP_Z)):
        h = v(hip[0], hip[1], z)
        knee = v(knee_x, hip[1] - 4, z)
        ankle = v(knee_x + 40, knee[1] + 150, z)
        toe = v(ankle[0] + FOOT_LEN, FLOOR - 6, z)
        draw_leg(sc, side, h, knee, ankle, toe, layer_near if z > 0 else -1)


FOOT_LEN = 50


def plate(sc, key, center, r, layer):
    sc.dot(f"{key}o", center, r, PLATE, layer)
    sc.dot(f"{key}r", center, r * 0.62, "#3d4540", layer + 0.01)
    sc.dot(f"{key}i", center, r * 0.16, LIME, layer + 0.02)


def lever(sc, key, pivot, hand, horn, plate_r, layer):
    """Lever arm from pivot through the handle. A positive horn puts the plate
    past the pivot; a negative horn puts it that fraction along the arm."""
    direction = norm(sub(hand, pivot))
    end = add(pivot, mul(direction, -max(horn, 0)))
    sc.seg(f"{key}arm", end, add(hand, mul(direction, 18)), 16, FRAME, layer)
    if plate_r:
        at = end if horn >= 0 else lerp(pivot, hand, -horn)
        plate(sc, f"{key}p", at, plate_r, layer + 0.01)
    sc.dot(f"{key}pv", pivot, 11, "#7d877f", layer + 0.03)
    grip_dir = (-direction[1], direction[0], 0)
    sc.seg(f"{key}grip", add(hand, mul(grip_dir, -16)), add(hand, mul(grip_dir, 16)), 14, "#7d877f", layer + 0.02)


# --------------------------------------------------------------- 1 bench press
def bench_pose(sc, c):
    u = c["u"]
    pad_top = 430
    sc.box("benchpad", (390, pad_top + 13), 400, 26, 0, PAD, -2)
    for x in (235, 545):
        sc.seg(f"bleg{x}", v(x, pad_top + 26), v(x, FLOOR - 4), 14, FRAME, -2)
        sc.seg(f"bfoot{x}", v(x - 34, FLOOR - 4), v(x + 34, FLOOR - 4), 10, FRAME, -2)
    hip, shoulder = v(500, 401), v(310, 401)
    side_body(sc, hip, shoulder, head_dir=(-1, 0, 0))
    for side, z, ankle_x in (("f", -HIP_Z, 628), ("n", HIP_Z, 660)):
        h = v(500, 401, z)
        ankle = v(ankle_x, FLOOR - 26, z)
        knee = ik(h, ankle, TH, SH, (0.3, -1, 0))
        draw_leg(sc, side, h, knee, ankle, v(ankle_x + 46, FLOOR - 8, z), 0.5 if z > 0 else -1)
    # Bar path: lockout over the shoulders, touch on the lower chest.
    bar = v(318 + 36 * (1 - (1 - u) ** 2), 192 + (357 - 192) * u)
    for side, z in (("f", -1), ("n", 1)):
        s = v(310, 401, SHOULDER_Z * z)
        hand = reach(s, v(bar[0], bar[1], 92 * z), UA, FA)
        elbow = ik(s, hand, UA, FA, (0.15, 1, 0.9 * z))
        draw_arm(sc, side, s, elbow, hand, 1 if z > 0 else -1.5)
    sc.dot("barp", bar, 60, PLATE, 2)
    sc.dot("barr", bar, 38, "#3d4540", 2.01)
    sc.dot("bari", bar, 10, LIME, 2.02)


BENCH = {
    "slug": "barbell-bench-press",
    "name": "Barbell bench press",
    "muscles": "Chest · triceps · front shoulders",
    "desc": "Lying on a flat bench, feet planted, the bar lowers under control from over the shoulders to the lower chest, touches, then presses up and slightly back to lockout.",
    "pose": bench_pose,
    "start": {"u": 0},
    "steps": [
        (0.5, {}, "Lock out over the shoulders"),
        (2.0, {"u": 1}, "Lower to the lower chest · 2 s"),
        (0.35, {}, "Touch, stay tight"),
        (1.0, {"u": 0}, "Press up and slightly back · 1 s"),
        (0.45, {}, "Lockout, never to failure"),
    ],
    "path": "u",
    "track": "barp",
}


# ------------------------------------------------------- 2 decline chest press
def seated_frame(sc, hip, lean, back_pad=True):
    up = (-math.sin(math.radians(lean)), -math.cos(math.radians(lean)), 0)
    shoulder = add(hip, mul(up, TORSO))
    sc.box("seat", (hip[0] - 8, hip[1] + 38), 150, 22, 0, PAD, -2)
    sc.seg("seatpost", v(hip[0] - 8, hip[1] + 50), v(hip[0] - 8, FLOOR - 4), 16, FRAME, -2)
    sc.seg("seatbase", v(hip[0] - 90, FLOOR - 4), v(hip[0] + 70, FLOOR - 4), 12, FRAME, -2)
    if back_pad:
        back = (-math.cos(math.radians(lean)), math.sin(math.radians(lean)), 0)
        low = add(add(hip, mul(back, 46)), mul(up, 20))
        high = add(add(hip, mul(back, 46)), mul(up, TORSO + 30))
        sc.seg("backpad", low, high, 30, PAD, -2)
    return shoulder


def press_machine(name, slug, muscles, desc, hip, lean, start_off, end_off, pivot_offset,
                  horn, labels, elbow_pole, stack=False, knee_pad=False, pull=False):
    def pose(sc, c):
        u = c["u"]
        torso_lean = lean + (6 * u if pull else 0)
        shoulder = seated_frame(sc, hip, torso_lean)
        h0 = add(seated_frame_shoulder(hip, lean), v(*start_off))
        h1 = add(seated_frame_shoulder(hip, lean), v(*end_off))
        pivot = pivot_for(h0, h1, pivot_offset)
        hand_c = arc(pivot, h0, h1, u)
        if stack:
            weight_stack(sc, u)
        side_body(sc, hip, shoulder)
        knee_x = hip[0] + 158
        seated_legs(sc, hip, knee_x)
        if knee_pad:
            sc.dot("kneepad", v(knee_x - 18, hip[1] - 44), 20, PAD, 0.6)
            sc.seg("kneepost", v(knee_x - 18, hip[1] - 44), v(knee_x + 60, hip[1] - 44), 12, FRAME, 0.55)
        for side, z in (("f", -1), ("n", 1)):
            s = add(shoulder, v(0, 0, SHOULDER_Z * z))
            hand = reach(s, v(hand_c[0], hand_c[1], (SHOULDER_Z + 30) * z), UA, FA)
            elbow = ik(s, hand, UA, FA, (elbow_pole[0], elbow_pole[1], elbow_pole[2] * z))
            draw_arm(sc, side, s, elbow, hand, 1 if z > 0 else -1.5)
        post_x = pivot[0] + (60 if pivot[0] > hip[0] else -40)
        sc.seg("post", v(post_x, FLOOR - 4), v(post_x, pivot[1]), 22, FRAME, -2.5)
        sc.seg("beam", v(post_x, pivot[1]), pivot, 16, FRAME, -2.5)
        lever(sc, "lv", pivot, hand_c, horn, 0 if stack else 46, -1.8)

    press_label, hold_label, ret_label = labels
    return {
        "slug": slug, "name": name, "muscles": muscles, "desc": desc, "pose": pose,
        "start": {"u": 0},
        "steps": [
            (0.5, {}, "Set up: shoulder blades back"),
            (1.1, {"u": 1}, press_label),
            (0.4, {}, hold_label),
            (2.0, {"u": 0}, ret_label),
            (0.35, {}, ""),
        ],
        "path": "u", "track": "lvgrip",
    }


def seated_frame_shoulder(hip, lean):
    up = (-math.sin(math.radians(lean)), -math.cos(math.radians(lean)), 0)
    return add(hip, mul(up, TORSO))


def weight_stack(sc, u):
    x = 150
    sc.seg("stkL", v(x - 40, 140), v(x - 40, FLOOR - 4), 8, "#7d877f", -3)
    sc.seg("stkR", v(x + 40, 140), v(x + 40, FLOOR - 4), 8, "#7d877f", -3)
    lift = 70 * u
    for i in range(10):
        y = FLOOR - 20 - i * 17 - (lift if i >= 6 else 0)
        sc.box(f"stk{i}", (x, y), 74, 13, 0, PLATE if i < 9 else "#3d4540", -2.9)
    sc.seg("cable", v(x, FLOOR - 20 - 9 * 17 - lift - 6), v(x, 140), 4, "#7d877f", -3)
    sc.dot("pulley", v(x, 132), 14, FRAME, -2.8)


DECLINE = press_machine(
    "Leverage Decline Chest Press", "leverage-decline-chest-press", "Lower chest · triceps",
    "Seated on a plate-loaded lever machine, the handles press forward and slightly down from the chest until the arms are long with soft elbows, then return slowly.",
    v(400, 470), 12, (74, 56, 0), (192, 72, 0), -230, -0.3,
    ("Press forward and down · 1 s", "Arms long, elbows soft", "Return slowly to the chest · 2 s"),
    (-0.2, 1, 0.9),
)
MACHINE_BENCH = press_machine(
    "Machine Bench Press", "machine-bench-press", "Chest · triceps · front shoulders",
    "Seated upright on a selectorized chest press, the handles press straight out from chest height while the weight stack rises, then return under control.",
    v(430, 470), 6, (76, 62, 0), (200, 62, 0), -230, 30,
    ("Press straight out · 1 s", "Arms long, elbows soft", "Return under control · 2 s"),
    (-0.2, 1, 0.9), stack=True,
)
SHOULDER = press_machine(
    "Leverage Shoulder Press", "leverage-shoulder-press", "Shoulders · triceps",
    "Seated with the back supported, the lever handles press from shoulder height to overhead with soft elbows, then lower back to shoulder height.",
    v(430, 486), 10, (30, -24, 0), (50, -200, 0), -300, -0.22,
    ("Press overhead · 1 s", "Soft elbows at the top", "Lower to shoulder height · 2 s"),
    (0.35, 1, 0.8),
)
PULLDOWN = press_machine(
    "Plate-Loaded Lat Pulldown", "plate-loaded-lat-pulldown", "Lats · upper back · biceps",
    "Seated with thighs under the pad, the lever handles pull from arms overhead down to the upper chest as the elbows drive down and back, then rise slowly.",
    v(480, 470), 12, (44, -198, 0), (60, 12, 0), -300, 60,
    ("Pull elbows down to the ribs · 1 s", "Squeeze, chest up", "Let the arms rise slowly · 2 s"),
    (-0.7, 1, 0.55), knee_pad=True, pull=True,
)
PULLDOWN["steps"][0] = (0.5, {}, "Arms long, shoulders down")


# ------------------------------------------------------------ 6 one-arm row
def row_pose(sc, c):
    u = c["u"]
    top = 472
    sc.box("rbench", (330, top + 12), 420, 24, 0, PAD, -2)
    for x in (155, 505):
        sc.seg(f"rleg{x}", v(x, top + 24), v(x, FLOOR - 4), 14, FRAME, -2)
        sc.seg(f"rfoot{x}", v(x - 32, FLOOR - 4), v(x + 32, FLOOR - 4), 10, FRAME, -2)
    hip, shoulder = v(300, 302), v(488, 268)
    # Far side supports: knee and hand on the bench.
    hf = v(300, 302, -HIP_Z)
    kf = v(300, top - 12, -HIP_Z)
    draw_leg(sc, "f", hf, kf, v(150, top - 10, -HIP_Z), v(112, top - 4, -HIP_Z), -1)
    sf = v(488, 268, -SHOULDER_Z)
    hand_f = v(500, top - 12, -60)
    draw_arm(sc, "f", sf, ik(sf, hand_f, UA, FA, (0.4, 0, -0.2)), hand_f, -1.5)
    side_body(sc, hip, shoulder, head_dir=norm((1, 0.25, 0)))
    hn = v(300, 302, HIP_Z)
    ankle = v(262, FLOOR - 18, 60)
    draw_leg(sc, "n", hn, ik(hn, ankle, TH, SH, (1, 0, 0)), ankle, v(312, FLOOR - 6, 60), 0.5)
    # Working arm: from a long hang to the elbow driving up past the back.
    sn = v(488, 268, SHOULDER_Z)
    hand = lerp(v(494, 466, 80), v(384, 330, 84), u)
    hand = reach(sn, hand, UA, FA)
    elbow = ik(sn, hand, UA, FA, (-0.55, -1, 0.25))
    draw_arm(sc, "n", sn, elbow, hand, 1)
    dumbbell_side(sc, "db", hand, (1, 0.05, 0), 1.2)


ROW = {
    "slug": "one-arm-dumbbell-row", "name": "One-arm dumbbell row",
    "muscles": "Lats · upper back · rear shoulders",
    "desc": "One knee and one hand on a bench, back flat, the free arm rows the dumbbell from a long hang up toward the hip, elbow driving past the back, then lowers to a full stretch.",
    "pose": row_pose, "start": {"u": 0},
    "steps": [
        (0.5, {}, "Arm long, back flat"),
        (1.1, {"u": 1}, "Drive the elbow up to the hip · 1 s"),
        (0.4, {}, "Squeeze the shoulder blade"),
        (2.0, {"u": 0}, "Lower to a full stretch · 2 s"),
        (0.35, {}, ""),
    ],
    "path": "u", "track": "hdn",
}


# ------------------------------------------------------------ front view rig
CX = 480


def front_body(sc):
    sc.dot("fhead", v(CX, 116), 36, INK, 0)
    sc.seg("fneck", v(CX, 150), v(CX, 176), 30, INK, 0)
    sc.poly("ftorso", [(CX - 78, 172), (CX + 78, 172), (CX + 52, 350), (CX + 58, 384),
                       (CX - 58, 384), (CX - 52, 350)], INK, 0.1)
    for side, sgn in (("l", -1), ("r", 1)):
        hip = v(CX + 30 * sgn, 380)
        knee = v(CX + 34 * sgn, 505)
        ankle = v(CX + 36 * sgn, FLOOR - 22)
        sc.seg(f"fth{side}", hip, knee, 46, INK, 0)
        sc.seg(f"fsh{side}", knee, ankle, 38, INK, 0)
        sc.seg(f"fft{side}", ankle, v(CX + 62 * sgn, FLOOR - 8), 22, INK, 0)


def lateral_pose(sc, c):
    u = c["u"]
    front_body(sc)
    for side, sgn in (("l", -1), ("r", 1)):
        s = v(CX + 76 * sgn, 182)
        theta = math.radians(10 + 78 * u)
        elbow = add(s, v(sgn * UA * math.sin(theta), UA * math.cos(theta)))
        phi = math.radians(10 + 78 * u - 14)
        hand = add(elbow, v(sgn * FA * math.sin(phi), FA * math.cos(phi)))
        sc.seg(f"fua{side}", s, elbow, 34, INK, 1)
        sc.seg(f"ffa{side}", elbow, hand, 28, INK, 1.01)
        sc.dot(f"fhd{side}", hand, 14, INK, 1.02)
        dumbbell_end(sc, f"fdb{side}", hand, 1.03)


LATERAL = {
    "slug": "dumbbell-lateral-raise", "name": "Dumbbell lateral raise",
    "muscles": "Side shoulders",
    "desc": "Standing tall with a dumbbell in each hand, elbows slightly bent, the arms raise out to the sides to shoulder height leading with the elbows, without shrugging, then lower slowly.",
    "pose": lateral_pose, "start": {"u": 0},
    "steps": [
        (0.5, {}, "Slight forward lean, elbows soft"),
        (1.1, {"u": 1}, "Raise to shoulder height · 1 s"),
        (0.4, {}, "Lead with the elbows, no shrug"),
        (2.0, {"u": 0}, "Lower slowly · 2 s"),
        (0.35, {}, ""),
    ],
    "path": "u", "track": "fhdr",
}


def hammer_pose(sc, c):
    front_body(sc)
    for side, sgn, ch in (("l", -1, "a"), ("r", 1, "b")):
        u = c[ch]
        s = v(CX + 76 * sgn, 182)
        elbow = v(CX + 82 * sgn, 182 + UA)
        target = v(CX - 30 * sgn, 250, 25)
        direction = slerp((0, 1, 0), norm(sub(target, elbow)), u)
        hand = add(elbow, mul(direction, FA))
        layer = 1 + (0.1 if sgn > 0 else 0)
        sc.seg(f"fua{side}", s, elbow, 34, INK, layer)
        sc.seg(f"ffa{side}", elbow, hand, 28, INK, layer + 0.01)
        sc.dot(f"fhd{side}", hand, 14, INK, layer + 0.02)
        dumbbell_end(sc, f"fdb{side}", hand, layer + 0.03)


HAMMER = {
    "slug": "cross-body-hammer-curl", "name": "Cross Body Hammer Curl",
    "muscles": "Biceps · brachialis · forearms",
    "desc": "Standing with dumbbells at the sides in a neutral grip, one arm at a time curls the dumbbell up and across the body toward the opposite chest with the elbow at the side, then lowers under control.",
    "pose": hammer_pose, "start": {"a": 0, "b": 0},
    "steps": [
        (0.5, {}, "Neutral grip, elbows at your sides"),
        (1.0, {"a": 1}, "Curl across to the opposite chest · 1 s"),
        (0.3, {}, "Elbow stays put"),
        (1.8, {"a": 0}, "Lower under control · 2 s"),
        (0.3, {}, "Switch arms"),
        (1.0, {"b": 1}, "Curl across to the opposite chest · 1 s"),
        (0.3, {}, "Elbow stays put"),
        (1.8, {"b": 0}, "Lower under control · 2 s"),
        (0.35, {}, ""),
    ],
    "path": None, "track": None,
}

ALL = [BENCH, DECLINE, MACHINE_BENCH, SHOULDER, PULLDOWN, ROW, LATERAL, HAMMER]
