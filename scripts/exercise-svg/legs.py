"""The seven Tuesday Legs A exercises as rig poses."""
import math
from rig import (
    FA, FAR, FLOOR, FRAME, INK, LIME, PAD, PLATE, SH, TH, TORSO, UA,
    add, draw_arm, draw_leg, dumbbell_side, ik, lerp, mul, norm, reach,
    side_body, sub, v,
)
from exercises import HIP_Z, SHOULDER_Z, plate, seated_frame

FOOT = 46


def deg(a):
    r = math.radians(a)
    return (math.cos(r), math.sin(r), 0.0)


def clamp(x):
    return max(0.0, min(1.0, x))


def smooth(x):
    x = clamp(x)
    return x * x * (3 - 2 * x)


def upright(hip, lean):
    """Shoulder above the hip, leaning forward (to the right) by lean degrees."""
    r = math.radians(lean)
    return add(hip, (TORSO * math.sin(r), -TORSO * math.cos(r), 0))


def hands_on(sc, shoulder, target, pole, layer_near=1):
    for side, z in (("f", -1), ("n", 1)):
        s = add(shoulder, v(0, 0, SHOULDER_Z * z))
        hand = reach(s, v(target[0], target[1], (SHOULDER_Z + 12) * z), UA, FA)
        draw_arm(sc, side, s, ik(s, hand, UA, FA, (pole[0], pole[1], pole[2] * z)), hand,
                 layer_near if z > 0 else -1.5)


def steps(*rows):
    return list(rows)


# ------------------------------------------------------------ 1 step-ups
def stepup_pose(sc, c):
    u = c["u"]
    top = 490
    sc.box("box", (600, top + (FLOOR - top) / 2), 200, FLOOR - top, 0, PAD, -3)
    sc.seg("boxedge", v(500, top), v(700, top), 6, FRAME, -2.9)
    tu = smooth((u - 0.55) / 0.45)
    hip = v(lerp(v(470, 0), v(555, 0), smooth(u) ** 0.8)[0], 318 + (170 - 318) * u)
    shoulder = upright(hip, 12 - 10 * u)
    # Barbell on the upper back: the far plate shows behind the head.
    bar = add(shoulder, v(-20, -6))
    plate(sc, "bar", bar, 46, -0.6)
    lead_ankle = v(560, top - 12, HIP_Z)
    draw_leg(sc, "n", v(hip[0], hip[1], HIP_Z), ik(v(hip[0], hip[1], HIP_Z), lead_ankle, TH, SH, (1, -0.2, 0)),
             lead_ankle, v(606, top - 4, HIP_Z), 0.5)
    trail = lerp(v(400, FLOOR - 18), v(536, top - 12), tu)
    trail = v(trail[0], trail[1] - 60 * math.sin(math.pi * tu), -HIP_Z)
    hip_f = v(hip[0], hip[1], -HIP_Z)
    draw_leg(sc, "f", hip_f, ik(hip_f, trail, TH, SH, (1, -0.2, 0)), trail,
             v(trail[0] + FOOT, trail[1] + 9, -HIP_Z), -1)
    side_body(sc, hip, shoulder)
    hands_on(sc, shoulder, add(bar, v(10, 6)), (-0.7, 1, 0.5))


STEPUP = {
    "slug": "barbell-step-ups", "name": "Barbell Step Ups", "muscles": "Quads · glutes · hamstrings",
    "desc": "A barbell rests on the upper back. With one foot flat on a box, drive through that heel to stand tall on the box, bring the other foot up, then step down trailing leg first.",
    "pose": stepup_pose, "start": {"u": 0}, "scale": 0.72,
    "steps": steps(
        (0.5, {}, "Lead foot flat on the box"),
        (1.3, {"u": 1}, "Drive through the front heel · 1 s"),
        (0.4, {}, "Stand tall on the box"),
        (2.0, {"u": 0}, "Step down under control · 2 s"),
        (0.5, {}, "Then switch legs"),
    ),
    "path": "u", "track": "head",
}


# ------------------------------------------------------- seated knee machines
def knee_machine(sc, hip, lean, shin_angle, roller_side, pad_on_thighs=False):
    shoulder = seated_frame(sc, hip, lean)
    knee_x = hip[0] + 158
    pivot = v(knee_x, hip[1] - 4)
    shin = deg(shin_angle)
    roller = add(add(pivot, mul(shin, 0.86 * SH)), mul(deg(shin_angle + roller_side), 26))
    sc.seg("lvarm", pivot, roller, 16, FRAME, 0.7)
    sc.dot("roller", roller, 20, PAD, 0.72)
    sc.dot("cam", pivot, 22, FRAME, 0.71)
    sc.dot("camc", pivot, 8, LIME, 0.73)
    if pad_on_thighs:
        sc.dot("lappad", v(knee_x - 46, hip[1] - 50), 20, PAD, 0.74)
        sc.seg("lappost", v(knee_x - 46, hip[1] - 50), v(knee_x - 46, hip[1] - 120), 12, FRAME, 0.69)
    side_body(sc, hip, shoulder)
    for side, z in (("f", -HIP_Z), ("n", HIP_Z)):
        h = v(hip[0], hip[1], z)
        knee = v(knee_x, hip[1] - 4, z)
        ankle = add(knee, mul(shin, SH))
        toe = add(ankle, mul(deg(shin_angle - 90), FOOT))
        draw_leg(sc, side, h, knee, ankle, toe, 0.5 if z > 0 else -1)
    hands_on(sc, shoulder, v(hip[0] + 30, hip[1] + 30), (-0.3, 1, 0.6))


def extension_pose(sc, c):
    knee_machine(sc, v(400, 470), 6, 98 - 100 * c["u"], -90)


EXTENSION = {
    "slug": "leg-extensions", "name": "Leg Extensions", "muscles": "Quads",
    "desc": "Seated with the pad on the lower shins and knees in line with the machine pivot, the legs extend until straight, pause, then lower slowly back to about 90 degrees.",
    "pose": extension_pose, "start": {"u": 0},
    "steps": steps(
        (0.5, {}, "Pad on the lower shins, knees at the pivot"),
        (1.0, {"u": 1}, "Extend to straight legs · 1 s"),
        (0.5, {}, "Squeeze the quads"),
        (2.0, {"u": 0}, "Lower slowly to 90° · 2 s"),
        (0.35, {}, ""),
    ),
    "path": "u", "track": "roller",
}


def seated_curl_pose(sc, c):
    knee_machine(sc, v(380, 470), 14, -6 + 112 * c["u"], 90, pad_on_thighs=True)


SEATED_CURL = {
    "slug": "seated-leg-curl", "name": "Seated Leg Curl", "muscles": "Hamstrings",
    "desc": "Seated with the lap pad above the knees and the lever behind the lower calves, the heels curl down and back as far as possible, hold for a second, then return to straight legs.",
    "pose": seated_curl_pose, "start": {"u": 0},
    "steps": steps(
        (0.5, {}, "Lap pad snug above the knees"),
        (1.0, {"u": 1}, "Curl the heels down and back · 1 s"),
        (1.0, {}, "Hold the squeeze 1 s"),
        (2.0, {"u": 0}, "Return to straight legs · 2 s"),
        (0.35, {}, ""),
    ),
    "path": "u", "track": "roller",
}


# ------------------------------------------------------------ 3 leg press wide
RAIL = deg(-45)
FACE = deg(-135)  # along the platform, toward its top edge


def press_pose(sc, c):
    u = c["u"]
    hip = v(330, 500)
    up = (-math.cos(math.radians(35)), -math.sin(math.radians(35)), 0)
    shoulder = add(hip, mul(up, TORSO))
    back = (-math.sin(math.radians(35)), math.cos(math.radians(35)), 0)
    sc.seg("rail", v(250, FLOOR - 10), v(760, FLOOR - 10 - 510), 16, FRAME, -3)
    sc.seg("base", v(110, FLOOR - 6), v(760, FLOOR - 6), 14, FRAME, -3)
    sc.seg("backpad", add(add(hip, mul(back, 40)), mul(up, -10)), add(add(hip, mul(back, 40)), mul(up, TORSO + 40)), 30, PAD, -2)
    sc.box("seat", (hip[0] + 6, hip[1] + 40), 120, 22, math.radians(-12), PAD, -2)
    sc.seg("seatpost", v(hip[0] + 6, hip[1] + 50), v(hip[0] + 6, FLOOR - 6), 16, FRAME, -2.5)
    d = 225 + 80 * u
    ankle_c = add(hip, mul(RAIL, d))
    platform = add(ankle_c, mul(RAIL, 16))
    sc.box("platform", platform, 18, 200, math.radians(-45), FRAME, -1.8)
    sled = add(platform, mul(RAIL, 70))
    sc.seg("sled", platform, sled, 34, PAD, -1.9)
    plate(sc, "sp", add(sled, mul(deg(45), 40)), 50, -1.85)
    side_body(sc, hip, shoulder, head_dir=up)
    for side, z in (("f", -HIP_Z - 15), ("n", HIP_Z + 15)):
        h = v(hip[0], hip[1], z)
        ankle = v(ankle_c[0], ankle_c[1], z * 1.6)
        knee = ik(h, ankle, TH, SH, (-1, -1, z / 60))
        draw_leg(sc, "n" if z > 0 else "f", h, knee, ankle, add(ankle, mul(FACE, FOOT)), 0.5 if z > 0 else -1)
    hands_on(sc, shoulder, v(hip[0] + 34, hip[1] + 24), (0.2, 1, 0.6))


PRESS = {
    "slug": "leg-presses-wide", "name": "Leg Presses (wide)", "muscles": "Quads · glutes · adductors",
    "desc": "On a 45-degree leg press with the feet a little wider than the shoulders and turned out slightly, the platform lowers until the knees reach a right angle, then presses straight back up without a pause.",
    "pose": press_pose, "start": {"u": 1},
    "steps": steps(
        (0.5, {}, "Feet wider than shoulders, toes slightly out"),
        (2.0, {"u": 0}, "Lower until the knees reach 90° · 2 s"),
        (1.0, {"u": 1}, "Press straight back up, no pause · 1 s"),
        (0.6, {}, "Knees soft at the top, tracking over the toes"),
    ),
    "path": "u", "track": "platform",
}


# ------------------------------------------------------------ 4 lying leg curl
def lying_curl_pose(sc, c):
    u = c["u"]
    top = 446
    sc.box("lpad", (410, top + 13), 460, 26, 0, PAD, -2)
    for x in (220, 600):
        sc.seg(f"lleg{x}", v(x, top + 26), v(x, FLOOR - 4), 14, FRAME, -2)
        sc.seg(f"lfoot{x}", v(x - 34, FLOOR - 4), v(x + 34, FLOOR - 4), 10, FRAME, -2)
    shoulder, hip = v(290, 416), v(480, 416)
    knee = v(640, 420)
    a = -126 * u
    shin = deg(a)
    roller = add(add(knee, mul(shin, 0.86 * SH)), mul(deg(a - 90), 26))
    sc.seg("lvarm", knee, roller, 16, FRAME, 0.7)
    sc.dot("roller", roller, 20, PAD, 0.72)
    sc.dot("cam", knee, 22, FRAME, 0.71)
    sc.dot("camc", knee, 8, LIME, 0.73)
    side_body(sc, hip, shoulder, head_dir=norm((-1, 0.2, 0)))
    for side, z in (("f", -HIP_Z), ("n", HIP_Z)):
        k = v(knee[0], knee[1], z)
        ankle = add(k, mul(shin, SH))
        draw_leg(sc, side, v(hip[0], hip[1], z), k, ankle, add(ankle, mul(deg(a + 90), FOOT)), 0.5 if z > 0 else -1)
    hands_on(sc, shoulder, v(212, 478), (0.1, 1, 0.5))


LYING_CURL = {
    "slug": "lying-leg-curls", "name": "Lying Leg Curls", "muscles": "Hamstrings",
    "desc": "Lying face down with the lever pad just above the heels, the heels curl up toward the glutes as far as possible while the hips stay on the pad, then lower back to straight legs.",
    "pose": lying_curl_pose, "start": {"u": 0},
    "steps": steps(
        (0.5, {}, "Hips pressed into the pad"),
        (1.0, {"u": 1}, "Curl the heels toward the glutes · 1 s"),
        (0.4, {}, "Squeeze, hips stay down"),
        (2.0, {"u": 0}, "Lower to straight legs · 2 s"),
        (0.35, {}, ""),
    ),
    "path": "u", "track": "roller",
}


# ------------------------------------------------------------ 5 seated calf raise
def calf_pose(sc, c):
    u = c["u"]
    hip = v(380, 404)
    shoulder = upright(hip, 4)
    sc.box("cseat", (hip[0] - 6, hip[1] + 38), 150, 22, 0, PAD, -2)
    sc.seg("cpost", v(hip[0] - 6, hip[1] + 50), v(hip[0] - 6, FLOOR - 4), 16, FRAME, -2)
    sc.seg("cbase", v(hip[0] - 90, FLOOR - 4), v(760, FLOOR - 4), 12, FRAME, -2)
    ball = v(566, 592)
    sc.box("step", (575, 611), 70, 38, 0, PAD, -2)
    theta = -160 + 36 * u  # foot angle about the ball: heel low to heel high
    sc_knee = None
    for side, z in (("f", -HIP_Z), ("n", HIP_Z)):
        ankle = add(v(ball[0], ball[1], z), mul(deg(theta), 52))
        h = v(hip[0], hip[1], z)
        knee = ik(h, ankle, TH, SH, (0.2, -1, 0))
        sc_knee = sc_knee or knee
        draw_leg(sc, side, h, knee, ankle, v(ball[0] + 6, ball[1], z), 0.5 if z > 0 else -1)
    pad = add(sc_knee, v(-30, -34))
    pivot = v(730, 330)
    direction = norm(sub(pad, pivot))
    sc.seg("cpostf", v(730, FLOOR - 4), pivot, 20, FRAME, -2.5)
    sc.seg("clever", add(pivot, mul(direction, -60)), pad, 16, FRAME, 0.7)
    plate(sc, "cp", add(pivot, mul(direction, -60)), 44, 0.71)
    sc.dot("cpv", pivot, 11, "#7d877f", 0.74)
    sc.dot("cpad", pad, 22, PAD, 0.75)
    side_body(sc, hip, shoulder)
    hands_on(sc, shoulder, add(pad, v(0, -18)), (-0.3, 1, 0.5), layer_near=1)


CALF = {
    "slug": "seated-calf-raise", "name": "Seated Calf Raise", "muscles": "Calves (soleus)",
    "desc": "Seated with the knee pad on the lower thighs and the balls of the feet on the edge of the step, the heels lower into a deep stretch, pause for one second, then rise as high as possible.",
    "pose": calf_pose, "start": {"u": 1},
    "steps": steps(
        (0.4, {}, "Balls of the feet on the edge"),
        (1.6, {"u": 0}, "Lower the heels into a deep stretch"),
        (1.0, {}, "Pause 1 s at the bottom"),
        (1.0, {"u": 1}, "Rise as high as you can · 1 s"),
        (0.5, {}, "Squeeze at the top"),
    ),
    "path": None, "track": None,
}


# ------------------------------------------------------------ 7 split squat
def split_pose(sc, c):
    u = c["u"]
    top = 480
    sc.box("rbench", (235, top + 12), 190, 24, 0, PAD, -3)
    for x in (165, 305):
        sc.seg(f"sleg{x}", v(x, top + 24), v(x, FLOOR - 4), 14, FRAME, -3)
    hip = lerp(v(485, 330), v(468, 456), u)
    shoulder = upright(hip, 6)
    rear_ankle = v(300, top - 14, -HIP_Z)
    hip_f = v(hip[0], hip[1], -HIP_Z)
    draw_leg(sc, "f", hip_f, ik(hip_f, rear_ankle, TH, SH, (0.4, 1, 0)), rear_ankle,
             v(252, top - 4, -HIP_Z), -1)
    side_body(sc, hip, shoulder)
    front_ankle = v(600, FLOOR - 18, HIP_Z)
    hip_n = v(hip[0], hip[1], HIP_Z)
    draw_leg(sc, "n", hip_n, ik(hip_n, front_ankle, TH, SH, (1, -0.1, 0)), front_ankle,
             v(648, FLOOR - 8, HIP_Z), 0.5)
    for side, z in (("f", -1), ("n", 1)):
        s = add(shoulder, v(0, 0, SHOULDER_Z * z))
        hand = reach(s, add(s, v(6, 205, 8 * z)), UA, FA)
        draw_arm(sc, side, s, ik(s, hand, UA, FA, (0.3, 0, 0.2 * z)), hand, 1 if z > 0 else -1.5)
        dumbbell_side(sc, f"db{side}", hand, (1, 0, 0), 1.2 if z > 0 else -1.4)


SPLIT = {
    "slug": "split-squat-with-dumbbells", "name": "Split Squat with Dumbbells", "muscles": "Quads · glutes",
    "desc": "Holding a dumbbell in each hand with the rear foot raised on a bench, the body lowers straight down by bending the front knee and hip, then drives up through the front heel.",
    "pose": split_pose, "start": {"u": 0},
    "steps": steps(
        (0.5, {}, "Rear foot on the bench, torso tall"),
        (2.0, {"u": 1}, "Lower straight down · 2 s"),
        (0.35, {}, "Front knee in line with the foot"),
        (1.0, {"u": 0}, "Drive up through the front heel · 1 s"),
        (0.5, {}, "Then switch legs"),
    ),
    "path": "u", "track": "head",
}

ALL = [STEPUP, EXTENSION, PRESS, LYING_CURL, CALF, SEATED_CURL, SPLIT]
