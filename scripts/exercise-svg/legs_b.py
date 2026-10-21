"""Saturday Legs B exercises (seated leg curl and standing calf raise are shared)."""
import math
from rig import (
    FA, FAR, FLOOR, FRAME, INK, LIME, PAD, PLATE, SH, TH, TORSO, UA,
    add, draw_arm, draw_leg, dumbbell_side, ik, lerp, mul, norm, reach,
    side_body, sub, v,
)
from exercises import HIP_Z, SHOULDER_Z, plate
from legs import PRESS, deg, smooth
from core import GLOW, cross, ghost, glow, shadow
from upper_b import DUAL_FRONT, DUAL_SIDE, STAND_FRONT, STAND_SIDE, dual_labels, draw_skeleton, torso_joints

FOOT = 46


# ------------------------------------------------------------ 1 goblet squat
def goblet_skeleton(u):
    pelvis = v(0, -335 + 172 * u, -78 * u)
    spine, j = torso_joints(pelvis, -(8 + 22 * u))
    for side, sgn in (("r", 1), ("l", -1)):
        hip = add(pelvis, v(32 * sgn, 0, 0))
        ankle = v(62 * sgn, -24, 0)
        j[f"hip{side}"], j[f"ankle{side}"] = hip, ankle
        j[f"knee{side}"] = ik(hip, ankle, TH, SH, v(0.35 * sgn, 0, 1))
        j[f"toe{side}"] = add(ankle, v(16 * sgn, 14, 44))
    bell = add(add(j["sh_c"], mul(spine, -54)), v(0, 0, 0))
    bell = add(bell, mul(norm(v(0, 0, 1)), 46))
    for side, sgn in (("r", 1), ("l", -1)):
        s = j[f"sh{side}"]
        hand = reach(s, add(bell, v(14 * sgn, -18, 0)), UA, FA)
        j[f"el{side}"] = ik(s, hand, UA, FA, v(0.5 * sgn, 1, 0.2))
        j[f"hd{side}"] = hand
    j["bell"] = bell
    return j


def goblet_pose(sc, c):
    j = goblet_skeleton(c["u"])
    for cam, tag, near in ((STAND_FRONT, "F", None), (STAND_SIDE, "S", "l")):
        shadow(sc, cam, f"{tag}shadow", v(0, 0, 20), 120, 100)
        draw_skeleton(sc, cam, tag, j, near)
        top, bottom = add(j["bell"], v(0, -30, 0)), add(j["bell"], v(0, 40, 0))
        sc.seg(f"{tag}dbh", cam(top), cam(bottom), 10, PLATE, 1.03)
        sc.box(f"{tag}dbt", cam(top), 46, 20, 0, PLATE, 1.04)
        sc.box(f"{tag}dbb", cam(bottom), 46, 20, 0, PLATE, 1.05)
        for side in ("r", "l"):
            if near is None or side == near:
                knee, hip = j[f"knee{side}"], j[f"hip{side}"]
                glow(sc, f"{tag}quad{side}", cam(lerp(hip, knee, 0.25)), cam(lerp(hip, knee, 0.75)), 0.6 if near else 0.06, 11)


GOBLET = {
    "slug": "dumbbell-goblet-squat", "name": "Dumbbell Goblet Squat", "muscles": "Quads · glutes · adductors",
    "desc": "Shown from the front and side: holding a dumbbell upright against the chest with the feet about shoulder width, the hips sit down and back until the thighs are parallel, knees tracking over the toes and chest up, then drive up through the heels.",
    "pose": goblet_pose, "start": {"u": 0}, "floor": False,
    "steps": [
        (0.5, {}, "Dumbbell at the chest, feet shoulder width"),
        (2.0, {"u": 1}, "Sit down and back · 2 s"),
        (0.35, {}, "Thighs parallel, knees over the toes"),
        (1.0, {"u": 0}, "Drive up through the heels · 1 s"),
        (0.4, {}, "Knees stay soft at the top"),
    ],
    "path": None, "track": None,
    "overlays": [(dual_labels(), None)],
}


# ------------------------------------------------------------ 2 Romanian deadlift
ANKLE = v(520, FLOOR - 20)
ARM = UA + FA - 6  # arms stay straight


def leg_front(hip, knee):
    """Polyline down the front of the thigh and shin, where the bar rides."""
    return [add(hip, v(26, 24)), add(knee, v(27, 0)), add(ANKLE, v(22, -26))]


def bar_on_legs(shoulder, hip, knee):
    """First point down the leg front that straight arms reach from the shoulder."""
    pts = leg_front(hip, knee)
    best = pts[-1]
    for a, b in zip(pts, pts[1:]):
        for i in range(101):
            p = lerp(a, b, i / 100)
            if math.hypot(p[0] - shoulder[0], p[1] - shoulder[1]) >= ARM:
                return p
    return best


def rdl_body(u):
    shin = math.radians(4 + 3 * u)
    knee = add(ANKLE, v(SH * math.sin(shin), -SH * math.cos(shin)))
    thigh = math.radians(2 + 19 * u)
    hip = add(knee, v(-TH * math.sin(thigh), -TH * math.cos(thigh)))
    torso = math.radians(3 + 74 * u)
    shoulder = add(hip, v(TORSO * math.sin(torso), -TORSO * math.cos(torso)))
    return knee, hip, shoulder, bar_on_legs(shoulder, hip, knee), torso


def rdl_pose(sc, c):
    knee, hip, shoulder, bar, torso = rdl_body(c["u"])
    for side, z in (("f", -HIP_Z), ("n", HIP_Z)):
        draw_leg(sc, side, v(hip[0], hip[1], z), v(knee[0], knee[1], z), v(ANKLE[0], ANKLE[1], z),
                 v(ANKLE[0] + FOOT, FLOOR - 8, z), 0.5 if z > 0 else -1)
    side_body(sc, hip, shoulder, head_dir=norm((math.sin(torso + 0.12), -math.cos(torso + 0.12), 0)))
    glow(sc, "hams", add(lerp(hip, knee, 0.18), v(-19, 4)), add(lerp(hip, knee, 0.82), v(-17, 2)), 0.56, 12)
    glow(sc, "glute", add(hip, v(-26, -4)), add(hip, v(-22, 18)), 0.57, 12)
    plate(sc, "bar", bar, 56, 0.8)
    sc.dot("barend", bar, 9, "#9aa39c", 0.83)
    for side, z in (("f", -1), ("n", 1)):
        s = add(shoulder, v(0, 0, SHOULDER_Z * z))
        hand = reach(s, v(bar[0], bar[1], 64 * z), UA, FA)
        draw_arm(sc, side, s, ik(s, hand, UA, FA, (-0.3, 0, 0.3 * z)), hand, 1 if z > 0 else -1.5)


def rdl_back_guide():
    _, hip, shoulder, _, torso = rdl_body(1)
    up = (-math.cos(torso), -math.sin(torso))
    a = (hip[0] + up[0] * 40, hip[1] + up[1] * 40)
    b = (shoulder[0] + up[0] * 40 + 30 * math.sin(torso), shoulder[1] + up[1] * 40 - 30 * math.cos(torso))
    return (f'<path d="M{a[0]:.0f} {a[1]:.0f}L{b[0]:.0f} {b[1]:.0f}" stroke="#9bbb2c" stroke-width="5" '
            'stroke-linecap="round" stroke-dasharray="1 12"/>')


def rdl_rounded():
    _, hip, shoulder, _, torso = rdl_body(1)
    up = (-math.cos(torso), -math.sin(torso))
    mid = lerp(hip, shoulder, 0.55)
    hump = (mid[0] + up[0] * 46, mid[1] + up[1] * 46)
    low = (shoulder[0] + 6, shoulder[1] + 40)
    return ghost([hip[:2], hump, low]) + cross(hump[0], hump[1] - 44)


RDL = {
    "slug": "romanian-deadlift", "name": "Romanian deadlift", "muscles": "Hamstrings · glutes · lower back",
    "desc": "Standing with straight arms and the bar against the thighs, knees slightly bent, the hips push back and the bar slides down the front of the legs with a flat back until a comfortable hamstring stretch around the knees, then the hips drive forward to stand tall. The back never rounds.",
    "pose": rdl_pose, "start": {"u": 0}, "scale": 0.9,
    "steps": [
        (0.5, {}, "Arms straight, bar against the thighs, knees soft"),
        (2.0, {"u": 1}, "Push the hips back, bar slides down the legs · 2 s"),
        (0.6, {}, "Stop at a hamstring stretch, back flat"),
        (0.8, {}, "Never let the back round"),
        (1.0, {"u": 0}, "Drive the hips forward to stand · 1 s"),
        (0.4, {}, "Squeeze the glutes, never to failure"),
    ],
    "path": "u", "track": "baro",
    "overlays": [(rdl_back_guide(), [2]), (rdl_rounded(), [3])],
}


# ------------------------------------------------------------ 3 leg press
LEGPRESS = dict(PRESS)
LEGPRESS.update({
    "slug": "leg-press", "name": "Leg press", "muscles": "Quads · glutes",
    "desc": "On a 45-degree leg press with the back supported and feet about hip width on the platform, the platform lowers only as far as the hips stay down on the seat, then presses back up evenly through the whole foot without locking the knees.",
    "steps": [
        (0.5, {}, "Back supported, feet hip width"),
        (2.0, {"u": 0}, "Lower while the hips stay down · 2 s"),
        (1.0, {"u": 1}, "Push evenly through the whole foot · 1 s"),
        (0.6, {}, "Don't lock the knees at the top"),
    ],
})


# ------------------------------------------------------------ 4 reverse lunge
FRONT = v(540, FLOOR - 20)


def lunge_pose(sc, c):
    s_, d = c["s"], c["d"]
    hip = v(528 - 40 * s_ - 30 * d, 300 + 6 * s_ + 150 * d)
    shoulder = add(hip, v(TORSO * math.sin(math.radians(5)), -TORSO * math.cos(math.radians(5))))
    rear = lerp(v(522, FLOOR - 20), v(312, FLOOR - 40), smooth(s_))
    rear = v(rear[0], rear[1] - 46 * math.sin(math.pi * s_), -HIP_Z)
    rear_toe = lerp(v(rear[0] + FOOT, FLOOR - 8), v(rear[0] + 34, FLOOR - 6), smooth(s_))
    hf = v(hip[0], hip[1], -HIP_Z)
    draw_leg(sc, "f", hf, ik(hf, rear, TH, SH, (0.4, 1, 0)), rear, v(rear_toe[0], rear_toe[1], -HIP_Z), -1)
    side_body(sc, hip, shoulder)
    hn = v(hip[0], hip[1], HIP_Z)
    front = v(FRONT[0], FRONT[1], HIP_Z)
    knee = ik(hn, front, TH, SH, (1, 0, 0))
    draw_leg(sc, "n", hn, knee, front, v(FRONT[0] + FOOT, FLOOR - 8, HIP_Z), 0.5)
    glow(sc, "quad", lerp(hn, knee, 0.25), lerp(hn, knee, 0.8), 0.56, 11)
    for side, z in (("f", -1), ("n", 1)):
        s = add(shoulder, v(0, 0, SHOULDER_Z * z))
        hand = reach(s, add(s, v(4, 205, 8 * z)), UA, FA)
        draw_arm(sc, side, s, ik(s, hand, UA, FA, (0.3, 0, 0.2 * z)), hand, 1 if z > 0 else -1.5)
        dumbbell_side(sc, f"db{side}", hand, (1, 0, 0), 1.2 if z > 0 else -1.4)


LUNGE = {
    "slug": "dumbbell-reverse-lunge", "name": "Dumbbell reverse lunge", "muscles": "Quads · glutes",
    "desc": "Standing tall with a dumbbell in each hand, one foot steps back and both knees lower under control with the front knee tracking over the toes, then the front foot drives the body back to standing. The legs alternate.",
    "pose": lunge_pose, "start": {"s": 0, "d": 0}, "scale": 0.86,
    "steps": [
        (0.45, {}, "Stand tall, dumbbells at your sides"),
        (0.9, {"s": 1}, "Step one foot back"),
        (1.6, {"d": 1}, "Lower both knees · 2 s"),
        (0.35, {}, "Front knee tracks over the toes"),
        (0.9, {"d": 0}, "Push through the front foot"),
        (0.8, {"s": 0}, "Return to standing"),
        (0.35, {}, "Alternate legs"),
    ],
    "path": None, "track": None,
}


# ------------------------------------------------------------ 5 barbell hip thrust
SHOULDER_HT = v(300, 462)
ANKLE_HT = v(650, FLOOR - 20)


def thrust_pose(sc, c):
    u = c["u"]
    sc.box("htbench", (205, 490), 210, 26, 0, PAD, -2)
    for x in (130, 280):
        sc.seg(f"htleg{x}", v(x, 503), v(x, FLOOR - 4), 14, FRAME, -2)
    angle = math.radians(40 - 41 * u)  # torso below horizontal, shoulders on the bench
    shoulder = add(SHOULDER_HT, v(0, -4 * u))
    hip = add(shoulder, v(TORSO * math.cos(angle), TORSO * math.sin(angle)))
    for side, z in (("f", -HIP_Z), ("n", HIP_Z)):
        h = v(hip[0], hip[1], z)
        ankle = v(ANKLE_HT[0], ANKLE_HT[1], z)
        knee = ik(h, ankle, TH, SH, (0.2, -1, 0))
        draw_leg(sc, side, h, knee, ankle, v(ANKLE_HT[0] + FOOT, FLOOR - 8, z), 0.5 if z > 0 else -1)
    side_body(sc, hip, shoulder, head_dir=norm((-0.5, -0.86, 0)))
    glow(sc, "glute", add(hip, v(-24, 22)), add(hip, v(24, 24)), 0.57, 13)
    bar = add(hip, v(8, -40))
    plate(sc, "bar", bar, 54, 0.8)
    for side, z in (("f", -1), ("n", 1)):
        s = add(shoulder, v(0, 0, SHOULDER_Z * z))
        hand = reach(s, v(bar[0] - 4, bar[1], 66 * z), UA, FA)
        draw_arm(sc, side, s, ik(s, hand, UA, FA, (0, -1, 0.3 * z)), hand, 1 if z > 0 else -1.5)


THRUST = {
    "slug": "barbell-hip-thrust", "name": "Barbell Hip Thrust", "muscles": "Glutes · hamstrings",
    "desc": "With the shoulder blades on the edge of a bench, the feet flat and a barbell over the hips, the heels drive the hips up until the body is flat from shoulders to knees with the shins vertical and chin tucked, the glutes squeeze for a second, then the hips lower under control.",
    "pose": thrust_pose, "start": {"u": 0},
    "steps": [
        (0.5, {}, "Shoulder blades on the bench, bar over the hips"),
        (1.0, {"u": 1}, "Drive through the heels, hips up · 1 s"),
        (1.0, {}, "Chin tucked, squeeze 1 s at the top"),
        (1.6, {"u": 0}, "Lower the hips under control"),
        (0.35, {}, ""),
    ],
    "path": "u", "track": "baro",
}

ALL = [GOBLET, RDL, LEGPRESS, LUNGE, THRUST]
