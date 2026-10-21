"""The seven Wednesday Core exercises. Twisting moves use a 3D camera."""
import math
from rig import (
    FA, FAR, FLOOR, FRAME, INK, LIME, LINE, PAD, PLATE, SH, TH, TORSO, UA, W,
    add, draw_arm, draw_leg, dumbbell_end, dumbbell_side, ik, lerp, mul, norm,
    reach, side_body, slerp, sub, v,
)
from exercises import HIP_Z, SHOULDER_Z, plate
from legs import deg, upright

GLOW = "#c6e353"  # working-muscle highlight
WRONG = "#d4483b"
FOOT = 46


def glow(sc, key, a, b, layer=0.06, width=14):
    sc.seg(key, a, b, width, GLOW, layer)


def cross(x, y, size=16):
    return (f'<path d="M{x - size} {y - size}L{x + size} {y + size}M{x + size} {y - size}L{x - size} {y + size}" '
            f'stroke="{WRONG}" stroke-width="7" stroke-linecap="round"/>')


def ghost(points, curve=None):
    d = "M" + " L".join(f"{x:.0f} {y:.0f}" for x, y in points)
    return (f'<path d="{d}" fill="none" stroke="{WRONG}" stroke-width="12" stroke-linecap="round" '
            f'stroke-linejoin="round" stroke-dasharray="2 16" opacity=".75"/>')


# ----------------------------------------------------------------- camera
class Camera:
    """Orthographic camera: yaw about the vertical axis, then pitch down."""

    def __init__(self, yaw, pitch, cx, cy, scale=1.0):
        self.cy_, self.sy_ = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
        self.cp, self.sp = math.cos(math.radians(pitch)), math.sin(math.radians(pitch))
        self.cx, self.cyo, self.s = cx, cy, scale

    def __call__(self, p, near=None):
        x, y, z = p
        x1 = x * self.cy_ + z * self.sy_
        z1 = -x * self.sy_ + z * self.cy_
        y2 = y * self.cp + z1 * self.sp
        depth = -y * self.sp + z1 * self.cp
        tag = depth if near is None else (1.0 if near else -1.0)
        return (self.cx + self.s * x1, self.cyo + self.s * y2, tag)


def rotate_axis(vec, axis, degrees):
    """Rodrigues rotation of vec about a unit axis."""
    k = norm(axis)
    c, s = math.cos(math.radians(degrees)), math.sin(math.radians(degrees))
    kx, ky, kz = k
    x, y, z = vec
    cross_kv = (ky * z - kz * y, kz * x - kx * z, kx * y - ky * x)
    dot_kv = kx * x + ky * y + kz * z
    return tuple(vec[i] * c + cross_kv[i] * s + k[i] * dot_kv * (1 - c) for i in range(3))


def floor_quad(sc, cam, key, x0, x1, z0, z1, color="#f1f3ee", layer=-4):
    pts = [cam(v(x0, 0, z0)), cam(v(x1, 0, z0)), cam(v(x1, 0, z1)), cam(v(x0, 0, z1))]
    sc.poly(key, pts, color, layer)


def shadow(sc, cam, key, center, rx, rz, color="#eceee8"):
    pts = [cam(add(center, v(rx * math.cos(a), 0, rz * math.sin(a))))
           for a in (i * math.pi / 12 for i in range(24))]
    sc.poly(key, pts, color, -6)


# ---------------------------------------------------------------- 1 ab roller
KNEE = (330, 606)


def roller_body(u):
    thigh = lerp(v(-88, 0), v(-32, 0), u)[0]
    torso = lerp(v(-15, 0), v(-10, 0), u)[0]
    hip = add(v(*KNEE), mul(deg(thigh), TH))
    shoulder = add(hip, mul(deg(torso), TORSO))
    dy = (FLOOR - 28) - shoulder[1]
    r = UA + FA - 8
    wheel = v(shoulder[0] + math.sqrt(max(r * r - dy * dy, 0)), FLOOR - 28)
    return hip, shoulder, wheel, torso


def roller_pose(sc, c):
    hip, shoulder, wheel, torso = roller_body(c["u"])
    for side, z in (("f", -HIP_Z), ("n", HIP_Z)):
        knee = v(KNEE[0], KNEE[1], z)
        ankle = v(178, FLOOR - 16, z)
        draw_leg(sc, side, v(hip[0], hip[1], z), knee, ankle, v(150, FLOOR - 4, z), 0.5 if z > 0 else -1)
    side_body(sc, hip, shoulder, head_dir=norm(deg(torso + 28)))
    down = (-math.sin(math.radians(torso)), math.cos(math.radians(torso)), 0)
    glow(sc, "abs", add(lerp(hip, shoulder, 0.12), mul(down, 18)), add(lerp(hip, shoulder, 0.62), mul(down, 18)))
    for side, z in (("f", -1), ("n", 1)):
        s = add(shoulder, v(0, 0, SHOULDER_Z * z))
        hand = reach(s, v(wheel[0], wheel[1], 50 * z), UA, FA)
        draw_arm(sc, side, s, ik(s, hand, UA, FA, (0, -1, 0)), hand, 1 if z > 0 else -1.5)
    sc.dot("wheel", wheel, 28, PLATE, 1.5)
    sc.dot("wheelr", wheel, 17, "#3d4540", 1.51)
    sc.dot("wheelh", wheel, 6, LIME, 1.52)


def roller_ghost():
    hip, shoulder, wheel, _ = roller_body(1)
    sag = (hip[0] + 20, hip[1] + 46)
    return ghost([KNEE, sag, (shoulder[0] - 40, shoulder[1] + 34), (shoulder[0], shoulder[1] + 12)]) + cross(sag[0] + 10, sag[1] + 46)


ROLLER = {
    "slug": "ab-roller", "name": "Ab Roller", "muscles": "Abs · obliques · lats",
    "desc": "Kneeling with the hands on an ab wheel under the shoulders and the hips tucked, the wheel rolls slowly forward until the body is long, stopping before the lower back sags, then the abs pull it back.",
    "pose": roller_pose, "start": {"u": 0}, "scale": 1.12,
    "steps": [
        (0.6, {}, "Kneel, hips tucked, hands under shoulders"),
        (2.2, {"u": 1}, "Roll out slowly, hips stay tucked · 2 s"),
        (1.0, {}, "Stop before the lower back sags"),
        (1.5, {"u": 0}, "Pull back with the abs · 1–2 s"),
        (0.4, {}, ""),
    ],
    "path": "u", "track": "wheel",
    "overlays": [(roller_ghost(), [2])],
}


# ------------------------------------------------------------ 2 bicycle crunch
BIKE = Camera(0, 16, 500, 560, 1.3)
PELVIS = v(0, -26, 0)
MID = v(-92, -30, 0)


def bike_pose(sc, c):
    cam = BIKE
    t = c["c"]  # +1: right elbow to left knee; -1: the opposite
    floor_quad(sc, cam, "mat", -360, 330, -120, 120, "#e7ebe2", -4)
    axis = norm(v(-math.cos(math.radians(34)), -math.sin(math.radians(34)), 0))
    sc_c = add(MID, mul(axis, 108))
    twist = 44 * t
    lateral = rotate_axis(v(0, 0, 1), axis, twist)
    s_r, s_l = add(sc_c, mul(lateral, 70)), add(sc_c, mul(lateral, -70))
    head = add(sc_c, mul(norm(add(axis, v(0, -0.25, 0))), 46))
    front = (-axis[1], axis[0], 0)  # chest normal, facing the ceiling
    sc.seg("lumbar", cam(PELVIS), cam(MID), 62, INK, 0)
    sc.seg("thorax", cam(MID), cam(sc_c), 64, INK, 0.01)
    sc.seg("neck", cam(sc_c), cam(add(sc_c, mul(axis, 20))), 24, INK, 0.02)
    sc.dot("head", cam(head), 30, INK, 0.03)
    glow(sc, "abs", cam(add(PELVIS, v(-8, -22, 0))), cam(add(lerp(MID, sc_c, 0.45), mul(front, 22))))
    sc.seg("girdle", cam(s_l), cam(s_r), 30, INK, 0.015)
    for side, sgn, s in (("n", 1, s_r), ("f", -1, s_l)):
        hand = add(head, add(mul(lateral, 26 * sgn), mul(axis, -14)))
        pole = add(mul(lateral, sgn * 0.55), v(1.0, -0.15, 0))
        elbow = ik(s, hand, UA, FA, pole)
        near = sgn > 0
        layer = 1 if near else -1.5
        color = INK if near else FAR
        sc.seg(f"ua{side}", cam(s, near), cam(elbow, near), 34, color, layer)
        sc.seg(f"fa{side}", cam(elbow, near), cam(hand, near), 28, color, layer + 0.01)
    for side, sgn, s_in in (("n", 1, (1 - t) / 2), ("f", -1, (1 + t) / 2)):
        # s_in = 1 means the knee is pulled in; 0 means the leg is long.
        hip = add(PELVIS, v(0, 0, 45 * sgn))
        tucked, long_ = v(56, -158, -34 * sgn), v(240, -170, 6 * sgn)
        ankle = add(hip, lerp(long_, tucked, s_in))
        knee = ik(hip, ankle, TH, SH, v(-0.5, -1, -0.5 * sgn * s_in))
        toe = add(ankle, v(40, -22, 0))
        near = sgn > 0
        layer = 0.5 if near else -1
        color = INK if near else FAR
        sc.seg(f"th{side}", cam(hip, near), cam(knee, near), 44, color, layer)
        sc.seg(f"sh{side}", cam(knee, near), cam(ankle, near), 36, color, layer + 0.01)
        sc.seg(f"ft{side}", cam(ankle, near), cam(toe, near), 22, color, layer + 0.02)


BICYCLE = {
    "slug": "bicycle-crunch", "name": "Bicycle crunch", "muscles": "Abs · obliques",
    "desc": "Lying on the back with the lower back pressed down, shoulders lifted and hands lightly beside the head, one elbow twists toward the opposite knee as that knee pulls in and the other leg extends, then the sides switch in a slow pedalling motion.",
    "pose": bike_pose, "start": {"c": 0}, "floor": False,
    "steps": [
        (0.6, {}, "Lower back pressed down, shoulders up"),
        (1.1, {"c": 1}, "Right elbow toward left knee · 1 s"),
        (0.4, {}, "Twist from the ribs, don't pull the neck"),
        (1.6, {"c": -1}, "Switch: left elbow toward right knee"),
        (0.4, {}, "Slow and controlled"),
        (0.9, {"c": 0}, ""),
    ],
    "path": None, "track": None,
}


# ------------------------------------------------------- 3 seated barbell twist
TWIST = Camera(0, 22, W / 2, 560, 1.0)


def twist_pose(sc, c):
    cam = TWIST
    phi = c["p"]
    shadow(sc, cam, "shadow", v(0, 0, -40), 230, 190)
    sc.poly("bench", [cam(v(-62, -150, 30)), cam(v(62, -150, 30)), cam(v(62, -150, -260)), cam(v(-62, -150, -260))], PAD, -4)
    sc.poly("benchf", [cam(v(-62, -150, 30)), cam(v(62, -150, 30)), cam(v(62, -126, 30)), cam(v(-62, -126, 30))], "#2f3632", -3.9)
    sc.seg("benchleg", cam(v(0, -126, 0)), cam(v(0, 0, 0)), 18, FRAME, -3.8)
    pelvis = v(0, -172, -10)
    shoulder_c = add(pelvis, v(0, -190, 0))
    r = math.radians(phi)
    lat = v(math.cos(r), 0, -math.sin(r))
    back = v(math.sin(r), 0, math.cos(r))
    s_a, s_b = add(shoulder_c, mul(lat, 74)), add(shoulder_c, mul(lat, -74))
    bar_c = add(add(shoulder_c, v(0, -4, 0)), mul(back, -22))
    hand_a, hand_b = add(bar_c, mul(lat, 108)), add(bar_c, mul(lat, -108))
    end_a, end_b = add(bar_c, mul(lat, 196)), add(bar_c, mul(lat, -196))
    sc.seg("barmid", cam(hand_b), cam(hand_a), 10, "#7d877f", -0.5)
    for side, sgn in (("a", 1), ("b", -1)):
        hip = add(pelvis, v(44 * sgn, 0, 0))
        knee = add(hip, v(16 * sgn, 0, 156))
        ankle = add(knee, v(2 * sgn, 150, 10))
        sc.seg(f"th{side}", cam(hip), cam(knee), 44, INK, 0.5)
        sc.seg(f"sh{side}", cam(knee), cam(ankle), 36, INK, 0.51)
        sc.seg(f"ft{side}", cam(ankle), cam(add(ankle, v(4 * sgn, 6, 44))), 22, INK, 0.52)
    sc.seg("hips", cam(add(pelvis, v(-44, 0, 0))), cam(add(pelvis, v(44, 0, 0))), 48, INK, 0)
    sc.seg("torso", cam(pelvis), cam(shoulder_c), 76, INK, 0.01)
    sc.seg("girdle", cam(s_b), cam(s_a), 34, INK, 0.02)
    head = add(shoulder_c, v(0, -52, 6))
    sc.seg("neck", cam(shoulder_c), cam(add(shoulder_c, v(0, -22, 2))), 26, INK, 0.03)
    sc.dot("head", cam(head), 32, INK, 0.04)
    for side, sgn in (("a", 1), ("b", -1)):
        low = add(pelvis, v(30 * sgn, -24, 24))
        high = add(add(add(pelvis, v(0, -112, 0)), mul(lat, 26 * sgn)), mul(back, -34))
        glow(sc, f"obl{side}", cam(low), cam(high), 0.05, 12)
    for side, sgn, s, hand, end in (("a", 1, s_a, hand_a, end_a), ("b", -1, s_b, hand_b, end_b)):
        sc.seg(f"bar{side}", cam(hand), cam(end), 10, "#7d877f", 0.8)
        sc.seg(f"col{side}", cam(add(end, mul(lat, -10 * sgn))), cam(end), 18, PLATE, 0.81)
        pole = add(add(mul(lat, sgn), v(0, 1.2, 0)), mul(back, -0.3))
        elbow = ik(s, hand, UA, FA, pole)
        sc.seg(f"ua{side}", cam(s), cam(elbow), 34, INK, 1)
        sc.seg(f"fa{side}", cam(elbow), cam(hand), 28, INK, 1.01)
        sc.dot(f"hd{side}", cam(hand), 14, INK, 1.02)


TWIST_EX = {
    "slug": "seated-barbell-twist", "name": "Seated Barbell Twist", "muscles": "Obliques · abs",
    "desc": "Seated at the end of a bench with feet planted, a light bar or stick rests across the upper back. The torso turns slowly side to side through a comfortable range while the hips and head stay still.",
    "pose": twist_pose, "start": {"p": 0}, "floor": False,
    "steps": [
        (0.6, {}, "Bar across the upper back, not the neck"),
        (1.1, {"p": 38}, "Turn to one side · 1 s"),
        (0.4, {}, "Hips and head stay still"),
        (1.8, {"p": -38}, "Turn to the other side"),
        (0.4, {}, "Only as far as is comfortable"),
        (0.9, {"p": 0}, ""),
    ],
    "path": None, "track": None,
}


# ------------------------------------------------------------------ 4 plank
SHOULDER_P = v(560, 498)
ANKLE_P = add(SHOULDER_P, mul(norm(v(-487, 108)), TORSO + TH + SH - 6))


def plank_pose(sc, c):
    b = c["b"]
    shoulder = add(SHOULDER_P, v(0, -1.5 * b))
    line = norm(sub(ANKLE_P, SHOULDER_P))
    hip = add(add(SHOULDER_P, mul(line, TORSO)), v(0, -3 * b))
    knee = add(SHOULDER_P, mul(line, TORSO + TH))
    for side, z in (("f", -HIP_Z), ("n", HIP_Z)):
        draw_leg(sc, side, v(hip[0], hip[1], z), v(knee[0], knee[1], z), v(ANKLE_P[0], ANKLE_P[1], z),
                 v(ANKLE_P[0] - 18, FLOOR - 6, z), 0.5 if z > 0 else -1)
    side_body(sc, hip, shoulder, head_dir=norm((1, 0.32, 0)))
    up = (line[1], -line[0], 0)
    glow(sc, "abs", add(lerp(hip, shoulder, 0.08), mul(up, -18)), add(lerp(hip, shoulder, 0.62), mul(up, -18)))
    glow(sc, "glute", add(hip, mul(up, 20)), add(lerp(hip, knee, 0.25), mul(up, 18)), 0.07, 12)
    for side, z in (("f", -1), ("n", 1)):
        s = add(shoulder, v(0, 0, SHOULDER_Z * z))
        elbow = v(SHOULDER_P[0], FLOOR - 20, SHOULDER_Z * z)
        hand = v(SHOULDER_P[0] + 104, FLOOR - 16, SHOULDER_Z * z)
        draw_arm(sc, side, s, elbow, hand, 1 if z > 0 else -1.5)


def plank_line():
    a = add(SHOULDER_P, v(0, -34))
    b = add(ANKLE_P, v(0, -30))
    return (f'<path d="M{a[0]:.0f} {a[1]:.0f}L{b[0]:.0f} {b[1]:.0f}" stroke="#9bbb2c" stroke-width="5" '
            'stroke-linecap="round" stroke-dasharray="1 12"/>')


def plank_sag():
    line = norm(sub(ANKLE_P, SHOULDER_P))
    hip = add(SHOULDER_P, mul(line, TORSO))
    knee = add(SHOULDER_P, mul(line, TORSO + TH))
    sag = (hip[0], hip[1] + 48)
    return ghost([SHOULDER_P[:2], sag, (knee[0], knee[1] + 18), ANKLE_P[:2]]) + cross(sag[0], sag[1] + 50)


def plank_timer(total, steps):
    cx, cy, r = 872, 160, 36
    circ = 2 * math.pi * r
    return (
        f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="{LINE}" stroke-width="8"/>'
        f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="{INK}" stroke-width="8" stroke-linecap="round" '
        f'stroke-dasharray="{circ:.1f}" stroke-dashoffset="{circ:.1f}" transform="rotate(-90 {cx} {cy})">'
        f'<animate attributeName="stroke-dashoffset" values="{circ:.1f};0" dur="{total:.2f}s" repeatCount="indefinite"/></circle>'
        f'<text class="h" x="{cx}" y="{cy + 10}" font-size="28" text-anchor="middle">60 s</text>'
        f'<text class="t" x="{cx}" y="{cy + 64}" font-size="16" text-anchor="middle" style="fill:#59635d">hold</text>'
    )


PLANK = {
    "slug": "plank", "name": "Plank", "muscles": "Abs · deep core · glutes",
    "desc": "Forearms on the floor with the elbows under the shoulders and the body in one straight line from head to heels, the glutes and abs stay tight and the breathing steady for 60 seconds. The set ends if the hips sag.",
    "pose": plank_pose, "start": {"b": 0},
    "steps": [
        (1.5, {"b": 1}, "Elbows under shoulders, one straight line"),
        (1.5, {"b": 0}, "Squeeze the glutes, brace, breathe"),
        (1.5, {"b": 1}, "Eyes to the floor, neck long"),
        (1.9, {"b": 0}, "End the set if the hips sag"),
    ],
    "path": None, "track": None,
    "overlays": [(plank_timer, None), (plank_line(), [0, 1, 2]), (plank_sag(), [3])],
}


# ------------------------------------------------------------ 5 side bend
CX, WAIST = 480, v(480, 334)


def rot(p, center, degrees):
    r = math.radians(degrees)
    dx, dy = p[0] - center[0], p[1] - center[1]
    return v(center[0] + dx * math.cos(r) - dy * math.sin(r), center[1] + dx * math.sin(r) + dy * math.cos(r))


def sidebend_pose(sc, c):
    lam = c["l"]
    sc.poly("lower", [(CX - 56, 322), (CX + 56, 322), (CX + 58, 384), (CX - 58, 384)], INK, 0.1)
    for side, sgn in (("l", -1), ("r", 1)):
        hip = v(CX + 30 * sgn, 380)
        knee = v(CX + 38 * sgn, 505)
        ankle = v(CX + 44 * sgn, FLOOR - 22)
        sc.seg(f"fth{side}", hip, knee, 46, INK, 0)
        sc.seg(f"fsh{side}", knee, ankle, 38, INK, 0)
        sc.seg(f"fft{side}", ankle, v(CX + 70 * sgn, FLOOR - 8), 22, INK, 0)
    upper = [rot(v(*p), WAIST, lam) for p in ((CX - 78, 172), (CX + 78, 172), (CX + 56, 336), (CX - 56, 336))]
    sc.poly("upper", upper, INK, 0.11)
    neck_a, neck_b = rot(v(CX, 176), WAIST, lam), rot(v(CX, 148), WAIST, lam)
    sc.seg("fneck", neck_a, neck_b, 30, INK, 0.12)
    sc.dot("fhead", rot(v(CX, 114), WAIST, lam), 36, INK, 0.13)
    glow(sc, "obl", rot(v(CX - 46, 250), WAIST, lam), v(CX - 50, 360), 0.14, 14)
    # Dumbbell side (figure's left, viewer's right): the arm hangs with gravity.
    s = rot(v(CX + 76, 184), WAIST, lam)
    elbow = add(s, v(5, UA))
    hand = add(elbow, v(3, FA))
    sc.seg("fuar", s, elbow, 34, INK, 1)
    sc.seg("ffar", elbow, hand, 28, INK, 1.01)
    sc.dot("fhdr", hand, 14, INK, 1.02)
    dumbbell_end(sc, "fdb", hand, 1.03)
    # Free hand rests on the hip.
    s2 = rot(v(CX - 76, 184), WAIST, lam)
    hip_hand = v(CX - 60, 350)
    elbow2 = ik(v(s2[0], s2[1], 0), hip_hand, UA, FA, (-1, 0.2, 0))
    sc.seg("fual", s2, elbow2, 34, INK, 1)
    sc.seg("ffal", elbow2, hip_hand, 28, INK, 1.01)
    sc.dot("fhdl", hip_hand, 14, INK, 1.02)


SIDEBEND = {
    "slug": "dumbbell-side-bend", "name": "Dumbbell Side Bend", "muscles": "Obliques · quadratus lumborum",
    "desc": "Standing tall with a dumbbell in one hand and the other hand on the hip, the torso bends straight sideways toward the dumbbell, which slides down the outside of the leg, then the opposite obliques pull the body back upright.",
    "pose": sidebend_pose, "start": {"l": 0},
    "steps": [
        (0.6, {}, "Dumbbell in one hand, other hand on the hip"),
        (1.6, {"l": 21}, "Bend sideways toward the dumbbell · 2 s"),
        (0.4, {}, "Straight sideways, no twisting"),
        (1.1, {"l": -5}, "Pull up with the other side · 1 s"),
        (0.4, {}, "Squeeze"),
        (0.6, {"l": 0}, "All reps, then switch hands"),
    ],
    "path": None, "track": None,
}


# ------------------------------------------------------------ 6 standing calf raise
BALL = v(484, 556)


def calf_pose(sc, c):
    u = c["u"]
    sc.box("step", (545, 595), 190, 70, 0, PAD, -3)
    sc.seg("stepedge", v(450, 560), v(640, 560), 6, FRAME, -2.9)
    sc.seg("rail", v(690, FLOOR - 4), v(690, 112), 16, FRAME, -3)
    sc.seg("railtop", v(690, 118), v(646, 118), 14, FRAME, -3)
    theta = -150 + 46 * u
    for side, z in (("f", -HIP_Z), ("n", HIP_Z)):
        ankle = add(v(BALL[0], BALL[1], z), mul(deg(theta), 52))
        knee = add(ankle, v(3, -SH, 0))
        hip = add(knee, v(2, -TH, 0))
        draw_leg(sc, side, hip, knee, ankle, v(BALL[0] + 8, BALL[1], z), 0.5 if z > 0 else -1)
        if z > 0:
            hip_c = v(hip[0], hip[1])
            glow(sc, "calf", add(lerp(knee, ankle, 0.12), v(-14, 0)), add(lerp(knee, ankle, 0.6), v(-12, 0)), 0.56, 12)
    shoulder = upright(hip_c, 2)
    side_body(sc, hip_c, shoulder)
    sn = add(shoulder, v(0, 0, SHOULDER_Z))
    hand = reach(sn, add(sn, v(4, 205, 6)), UA, FA)
    draw_arm(sc, "n", sn, ik(sn, hand, UA, FA, (0.3, 0, 0.2)), hand, 1)
    dumbbell_side(sc, "db", hand, (1, 0, 0), 1.2)
    sf = add(shoulder, v(0, 0, -SHOULDER_Z))
    rail_hand = reach(sf, v(652, 122, -60), UA, FA)
    draw_arm(sc, "f", sf, ik(sf, rail_hand, UA, FA, (0, 1, -0.3)), rail_hand, -1.5)


CALF_STAND = {
    "slug": "standing-calf-raise", "name": "Standing calf raise", "muscles": "Calves (gastrocnemius · soleus)",
    "desc": "Standing tall on the edge of a step with a dumbbell at one side and a light hand on a rail for balance, the heels lower into a full stretch below the step, then rise as high as possible and pause.",
    "pose": calf_pose, "start": {"u": 1}, "scale": 0.78,
    "steps": [
        (0.4, {}, "Balls of the feet on the edge, knees straight"),
        (1.8, {"u": 0}, "Lower into a full stretch · 2 s"),
        (0.7, {}, "Full stretch at the bottom"),
        (1.0, {"u": 1}, "Rise as high as you can · 1 s"),
        (0.6, {}, "Pause and squeeze at the top"),
    ],
    "path": "u", "track": "head",
}


# ------------------------------------------------- 7 lateral raise (front + side)
LAT_FRONT = Camera(0, 4, 250, 606, 0.76)
LAT_SIDE = Camera(90, 4, 690, 606, 0.76)


def lateral_skeleton(u):
    """One 3D pose: facing +z, slight forward lean, arms in the scapular plane."""
    pelvis = v(0, -335, 0)
    lean = math.radians(10)
    spine = v(0, -math.cos(lean), math.sin(lean))
    sh_c = add(pelvis, mul(spine, TORSO))
    joints = {"pelvis": pelvis, "sh_c": sh_c, "neck": add(sh_c, mul(spine, 22)),
              "head": add(add(sh_c, mul(spine, 54)), v(0, 0, 6))}
    for side, sgn in (("r", 1), ("l", -1)):
        joints[f"hip{side}"] = add(pelvis, v(30 * sgn, 0, 0))
        joints[f"knee{side}"] = v(32 * sgn, -178, 2)
        joints[f"ankle{side}"] = v(34 * sgn, -24, 0)
        joints[f"toe{side}"] = v(40 * sgn, -10, 46)
        s = add(sh_c, v(76 * sgn, 0, 0))
        plane = v(math.cos(math.radians(30)) * sgn, 0, math.sin(math.radians(30)))
        d0 = norm(v(0.12 * sgn, 1, 0.1))
        d1 = norm(add(plane, v(0, 0.03, 0)))
        elbow = add(s, mul(slerp(d0, d1, u), UA))
        hand = add(elbow, mul(slerp(d0, d1, u * 0.86), FA))
        joints[f"sh{side}"], joints[f"el{side}"], joints[f"hd{side}"] = s, elbow, hand
    return joints


def draw_lateral(sc, cam, tag, j, near_side):
    """Draw the skeleton through one camera. near_side: 'r', 'l' or None (front)."""
    def col(side, base):
        if near_side is None or side == near_side:
            return INK, base
        return FAR, base - 2.5

    for side in ("r", "l"):
        color, layer = col(side, 0.5 if near_side else 0)
        sc.seg(f"{tag}th{side}", cam(j[f"hip{side}"]), cam(j[f"knee{side}"]), 44, color, layer)
        sc.seg(f"{tag}sh{side}", cam(j[f"knee{side}"]), cam(j[f"ankle{side}"]), 36, color, layer + 0.01)
        sc.seg(f"{tag}ft{side}", cam(j[f"ankle{side}"]), cam(j[f"toe{side}"]), 22, color, layer + 0.02)
    sc.seg(f"{tag}torso", cam(j["pelvis"]), cam(j["sh_c"]), 70, INK, 0.1)
    sc.seg(f"{tag}girdle", cam(j["shl"]), cam(j["shr"]), 34, INK, 0.11)
    sc.seg(f"{tag}neck", cam(j["sh_c"]), cam(j["neck"]), 26, INK, 0.12)
    sc.dot(f"{tag}head", cam(j["head"]), 32, INK, 0.13)
    forward = v(0, 0, 1)
    for side in ("r", "l"):
        color, layer = col(side, 1)
        sc.seg(f"{tag}ua{side}", cam(j[f"sh{side}"]), cam(j[f"el{side}"]), 32, color, layer)
        sc.seg(f"{tag}fa{side}", cam(j[f"el{side}"]), cam(j[f"hd{side}"]), 26, color, layer + 0.01)
        hand = j[f"hd{side}"]
        a, b = add(hand, mul(forward, -30)), add(hand, mul(forward, 30))
        sc.dot(f"{tag}hd{side}", cam(hand), 12, color, layer + 0.02)
        sc.seg(f"{tag}dbh{side}", cam(a), cam(b), 9, PLATE, layer + 0.03)
        sc.dot(f"{tag}dba{side}", cam(a), 15, PLATE, layer + 0.04)
        sc.dot(f"{tag}dbb{side}", cam(b), 15, PLATE, layer + 0.05)
        sc.dot(f"{tag}dbi{side}", cam(b), 6, "#6b746e", layer + 0.055)
        if color == INK:
            sc.dot(f"{tag}delt{side}", cam(j[f"sh{side}"]), 12, GLOW, layer + 0.06)


def lateral_pose(sc, c):
    j = lateral_skeleton(c["u"])
    for cam, key in ((LAT_FRONT, "F"), (LAT_SIDE, "S")):
        shadow(sc, cam, f"{key}shadow", v(0, 0, 12), 95, 80)
    draw_lateral(sc, LAT_FRONT, "F", j, None)
    draw_lateral(sc, LAT_SIDE, "S", j, "l")


def lateral_labels():
    return (
        f'<line x1="480" x2="480" y1="120" y2="610" stroke="{LINE}" stroke-width="3" stroke-dasharray="2 10" stroke-linecap="round"/>'
        '<text class="t" x="250" y="132" font-size="18" font-weight="700" text-anchor="middle" letter-spacing="2" style="fill:#59635d">FRONT</text>'
        '<text class="t" x="700" y="132" font-size="18" font-weight="700" text-anchor="middle" letter-spacing="2" style="fill:#59635d">SIDE</text>'
    )


LATERAL3 = {
    "slug": "dumbbell-lateral-raise", "name": "Dumbbell lateral raise", "muscles": "Side shoulders",
    "desc": "Shown from the front and the side at once: standing with a slight forward lean and soft elbows, the dumbbells rise out to the sides, a little in front of the body, to shoulder height, leading with the elbows and without shrugging, then lower slowly.",
    "pose": lateral_pose, "start": {"u": 0}, "floor": False,
    "steps": [
        (0.6, {}, "Slight forward lean, elbows soft"),
        (1.1, {"u": 1}, "Raise to shoulder height · 1 s"),
        (0.45, {}, "Lead with the elbows, no shrug"),
        (2.0, {"u": 0}, "Lower slowly · 2 s"),
        (0.35, {}, ""),
    ],
    "path": None, "track": None,
    "overlays": [(lateral_labels(), None)],
}

ALL = [ROLLER, BICYCLE, TWIST_EX, PLANK, SIDEBEND, CALF_STAND, LATERAL3]
