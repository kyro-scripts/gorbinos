"""Level 2: SNIRBY INDUSTRIAL COMPLEX."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from levelkit import Map, Color, emit

YARD = dict(floor=0.0, ceil=10.0, ctex="SKY", ftex="i_floor", light=0.85, side="i_hazard")
HALL = dict(floor=0.0, ceil=5.0, ctex="i_ceiling", ftex="i_floor", light=0.6, side="i_hazard", upper="i_concrete")
PROC = dict(floor=0.0, ceil=8.0, ctex="i_ceiling", ftex="i_floor", light=0.55, side="i_hazard", upper="i_rust")
L = {
    "%": {"wall": "i_concrete"},
    "#": {"wall": "i_rust"},
    "&": {"wall": "i_corrugated"},
    "|": {"wall": "i_pipes"},
    "=": {"wall": "i_teal"},
    "n": {"wall": "i_machine"},
    "K": {"wall": "i_warning"},
    "G": {"wall": "i_sign"},
    "S": {"wall": "exit_panel", "use": "exit", "above": "i_teal"},
    "N": {"wall": "switch_off", "use": "switch", "tag": 4, "above": "i_teal", "msg": "ARMORY OPEN"},
    ".": dict(YARD),
    ",": dict(HALL),
    "F": dict(HALL, ctex="i_light", light=0.85),
    ":": dict(HALL, ftex="i_grate"),
    ";": dict(HALL, ftex="i_conveyor"),
    "1": dict(HALL, floor=0.5, ftex="metal_floor"),
    "7": dict(HALL, floor=1.0, ftex="metal_floor"),
    "_": dict(HALL, floor=1.5, ftex="metal_floor"),
    "u": dict(HALL, floor=1.0, ftex="crate", side="crate"),
    "j": dict(HALL, floor=2.0, ftex="crate", side="crate", secret=True, light=0.75),
    "a": dict(PROC),
    "^": dict(PROC, floor=1.5, ftex="i_grate"),
    "8": dict(PROC, floor=1.0, ftex="metal_floor"),
    "9": dict(PROC, floor=0.5, ftex="metal_floor"),
    "~": dict(PROC, floor=-0.8, liquid="liq_sludge", damage=5, light=0.8),
    "d": dict(HALL, floor=-0.8, liquid="liq_sludge", damage=5, light=0.8),
    "J": dict(HALL, floor=1.5, ftex="metal_floor", trigger=2),
    "z": dict(floor=0.0, ceil=4.0, ftex="metal_floor", ctex="i_light", light=0.75, side="i_hazard", upper="i_teal"),
    "0": dict(floor=0.0, ceil=2.5, ftex="i_grate", ctex="i_ceiling", light=0.4, secret=True),
    "v": dict(floor=0.0, ceil=4.0, ftex="i_floor", ctex="i_ceiling", light=0.35, flicker=1),
    "w": None,
    "L": {"lift": True, "floor": 0.0, "top": 1.5, "ftex": "metal_floor", "side": "i_hazard", "ceil": 5.0, "ctex": "i_ceiling", "light": 0.6},
    "D": {"door": "door_metal", "side": "i_concrete"},
    "(": {"door": "door_blue", "key": "blue", "side": "i_concrete"},
    ")": {"door": "door_yellow", "key": "yellow", "side": "i_concrete"},
    "[": {"door": "i_vent", "secret_door": True, "side": "i_concrete"},
    "]": {"door": "i_warning", "secret_door": True, "side": "i_concrete"},
    "<": {"door": "i_corrugated", "remote": True, "tag": 2},
    ">": {"door": "i_grate", "remote": True, "tag": 4},
}
del L["w"]

m = Map(66, 54, "%")
# ---- outdoor yards
m.rect(1, 40, 64, 52, ".")
m.rect(3, 42, 6, 44, "&")
m.rect(14, 47, 15, 48, "u")
m.rect(18, 43, 19, 44, "u")
for (x, y) in [(30, 44), (38, 48), (46, 43), (54, 47)]:
    m.rect(x, y, x + 2, y + 2, "n")
m.vline(24, 40, 46, "%")
m.hline(1, 64, 39, "%")
m.put(12, 39, "D")
m.put(36, 39, "D")
m.put(20, 39, "G")
m.put(44, 39, "G")
# ---- receiving hall
m.box(1, 25, 24, 39, "%", ",")
m.put(12, 39, "D"); m.put(20, 39, "G")
m.rect(2, 30, 23, 30, "F")
m.rect(2, 26, 6, 27, "_")
m.rect(7, 26, 7, 27, "7")
m.rect(8, 26, 8, 27, "1")
m.rect(4, 32, 6, 34, "u")
m.rect(15, 33, 17, 34, "u")
m.rect(9, 35, 10, 36, "u")
m.rect(19, 28, 21, 29, "u")
m.rect(21, 26, 22, 27, "j")
m.put(24, 32, "D")
# ---- vat room (north-west)
m.box(1, 2, 22, 25, "%", ",")
m.put(12, 25, "D")
for x0 in (4, 10, 16):
    m.rect(x0, 4, x0 + 2, 7, "n")
m.rect(2, 11, 21, 12, "d")
m.rect(11, 11, 12, 12, ":")
m.rect(8, 15, 13, 18, "_")
m.rect(10, 15, 11, 15, "J")
m.put(10, 19, "L")
m.rect(2, 20, 21, 20, "F")
# monster closet east of the vat room
m.box(22, 13, 24, 19, "%", "v")
m.put(22, 15, "<")
m.put(22, 17, "<")
# ---- processing hall
m.box(24, 14, 47, 39, "#", "a")
m.put(36, 39, "D"); m.put(44, 39, "G")
m.put(24, 32, "D")
m.put(22, 15, "<"); m.put(22, 17, "<")
m.rect(29, 20, 42, 33, "~")
m.rect(25, 26, 46, 27, "^")
m.rect(35, 15, 36, 38, "^")
m.rect(25, 28, 26, 28, "8"); m.rect(25, 29, 26, 29, "9")
m.rect(45, 28, 46, 28, "8"); m.rect(45, 29, 46, 29, "9")
m.rect(35, 15, 36, 15, "8"); m.rect(35, 16, 36, 16, "^")
m.rect(33, 38, 34, 38, "9"); m.rect(37, 38, 38, 38, "9")
m.rect(35, 37, 36, 37, "^"); m.rect(35, 38, 36, 38, "8")
m.put(36, 14, "D")
m.put(47, 20, "(")
# secret behind the warning sign in the east wall
m.box(47, 33, 51, 38, "%", "0")
m.put(47, 36, "]")
# ---- packaging line (north-east) + office
m.box(24, 2, 52, 14, "%", ";")
m.put(36, 14, "D")
m.rect(25, 7, 51, 9, ",")
m.rect(28, 4, 40, 4, "u")
m.rect(28, 12, 40, 12, "u")
m.rect(44, 4, 46, 5, "u")
m.box(52, 2, 64, 14, "%", "z")
m.put(52, 8, "D")
m.rect(55, 4, 57, 4, "n")
m.rect(60, 4, 62, 4, "n")
m.rect(55, 11, 62, 11, "n")
# vent crawlspace secret above the line
m.rect(30, 1, 41, 1, "0")
m.put(35, 2, "[")
# ---- control room + armory + exit
m.box(47, 16, 64, 30, "=", "z")
m.put(47, 20, "(")
m.rect(50, 18, 53, 18, "n"); m.rect(57, 18, 60, 18, "n")
m.rect(50, 24, 51, 25, "n")
m.put(55, 16, "N")
m.box(58, 23, 63, 29, "=", "v")
m.put(58, 25, ">"); m.put(58, 27, ">")
m.put(55, 16, "N")
m.box(47, 30, 64, 38, "%", "z")
m.put(47, 33, "%"); m.put(47, 34, "%"); m.put(47, 35, "%"); m.put(47, 37, "%")
m.box(47, 33, 51, 38, "%", "0")
m.put(47, 36, "]")
m.put(54, 30, ")")
m.put(64, 34, "S")

# ================= entities
m.put(6, 50, "@")
m.put(8, 47, "i"); m.put(16, 50, "+"); m.put(22, 45, "c")
m.put(20, 48, "x"); m.put(21, 48, "x"); m.put(10, 42, "x")
m.put(28, 47, "g"); m.put(42, 45, "g"); m.put(50, 50, "s"); m.put(58, 42, "s"); m.put(62, 50, "y")
m.put(34, 50, "x"); m.put(52, 45, "x"); m.put(40, 42, "C")
# receiving hall
m.put(3, 26, "4"); m.put(5, 27, "i")
m.put(12, 28, "g"); m.put(18, 36, "s"); m.put(8, 32, "s"); m.put(20, 31, "g"); m.put(3, 37, "y")
m.put(21, 26, "C"); m.put(22, 27, "A")
m.put(13, 37, "x"); m.put(2, 38, "h")
# vat room
m.put(10, 16, "U")
m.put(5, 14, "g"); m.put(17, 14, "g"); m.put(14, 22, "s"); m.put(4, 22, "s"); m.put(19, 9, "y")
m.put(23, 14, "g"); m.put(23, 16, "r"); m.put(23, 18, "s")
m.put(2, 3, "c"); m.put(21, 3, "i"); m.put(13, 9, "h")
# processing hall
m.put(35, 26, "b")
m.put(28, 17, "g"); m.put(44, 17, "g"); m.put(28, 36, "s"); m.put(44, 36, "s"); m.put(40, 35, "s")
m.put(32, 24, "f"); m.put(39, 30, "f")
m.put(25, 26, "y"); m.put(46, 27, "y")
m.put(30, 37, "x"); m.put(42, 16, "x")
m.put(26, 37, "h"); m.put(45, 16, "c"); m.put(36, 20, "i")
m.put(49, 35, "V"); m.put(50, 37, "+")
# packaging line & office
m.put(30, 8, "s"); m.put(38, 6, "s"); m.put(46, 10, "s"); m.put(42, 8, "g"); m.put(49, 4, "y"); m.put(26, 11, "g")
m.put(33, 11, "x"); m.put(48, 12, "i")
m.put(62, 8, "Y")
m.put(56, 7, "y"); m.put(60, 10, "g"); m.put(58, 13, "r")
m.put(32, 1, "B"); m.put(40, 1, "+"); m.put(37, 1, "+")
# control room / armory / exit room
m.put(55, 21, "y"); m.put(61, 20, "g"); m.put(52, 27, "s"); m.put(49, 22, "+")
m.put(60, 25, "C"); m.put(61, 27, "A"); m.put(62, 25, "e")
m.put(57, 33, "g"); m.put(60, 36, "g"); m.put(55, 36, "s")
m.put(62, 32, "h")

emit("level2_industrial", {
    "name": "SNIRBY INDUSTRIAL COMPLEX",
    "music": "industrial", "ambience": "amb_industrial", "sky": "sky_smog",
    "fog": Color(0.45, 0.28, 0.15, 0.55), "fog_start": 14.0, "fog_end": 70.0,
    "light_boost": 1.5, "diminish": 0.028,
    "start_angle": 0.0, "par": 210,
    "wall": "i_concrete", "side": "i_hazard",
    "test_views": [[6, 48, 0, 0], [12, 34, 0, 0], [36, 30, 0, -10], [30, 26, 90, 0], [10, 21, 0, 10], [38, 8, 90, 0], [55, 25, 90, 0]],
}, L, m)
