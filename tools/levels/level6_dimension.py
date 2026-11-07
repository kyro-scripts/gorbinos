"""Level 6: SNIRBY DIMENSION (final level, boss: THE GREAT SNIRBY)."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from levelkit import Map, Color, emit


def out(f, **kw):
    d = dict(floor=f, ceil=24.0, ctex="SKY", ftex="d_flesh", light=0.85, side="d_meat")
    d.update(kw)
    return d


def ind(f, c, **kw):
    d = dict(floor=f, ceil=c, ctex="d_flesh", ftex="d_flesh", light=0.5, side="d_meat", upper="d_flesh")
    d.update(kw)
    return d


L = {
    "%": {"wall": "d_void"},
    "#": {"wall": "d_flesh"},
    "n": {"wall": "d_eyes"},
    "K": {"wall": "d_glyph"},
    "G": {"wall": "d_snirbface"},
    "H": {"wall": "d_static"},
    "v": {"wall": "d_swirl"},
    "~": out(-1.0, liquid="liq_ooze", damage=6, light=0.8),
    ".": out(0.0),
    ",": out(0.0, ftex="d_checker"),
    "7": out(0.5, ftex="d_checker"),
    ":": out(0.5, ftex="d_swirl"),
    ";": out(1.0, ftex="d_meat"),
    "1": out(1.0, ftex="d_teeth"),
    "8": out(1.0, ftex="d_meat"),
    "J": out(1.0, ftex="d_glyph", trigger=2, flicker=3),
    "z": out(1.0, ftex="d_ooze", secret=True, light=1.0),
    "^": out(0.5, ftex="d_checker", light=0.9),
    "9": out(1.5, ftex="d_meat", light=0.9),
    "j": ind(1.0, 4.0, light=0.25, flicker=1),
    "d": ind(0.5, 3.0, light=0.8, secret=True, flicker=2),
    "=": ind(0.5, 6.0, light=0.55, flicker=2, ftex="d_teeth"),
    "a": ind(0.5, 3.0, light=0.85, secret=True),
    "0": ind(0.5, 5.0, light=1.0, flicker=2, ftex="d_swirl", ctex="d_swirl"),
    "(": {"door": "door_red", "key": "red", "side": "d_flesh"},
    ")": {"door": "door_blue", "key": "blue", "side": "d_flesh"},
    "[": {"door": "d_eyes", "secret_door": True, "side": "d_flesh"},
    "]": {"door": "d_flesh", "secret_door": True, "side": "d_flesh"},
    "<": {"door": "d_snirbface", "remote": True, "tag": 2},
    ">": {"door": "d_glyph", "remote": True, "tag": 99},
}

m = Map(64, 64, "%")
m.rect(1, 1, 62, 62, "~")
# ---- start island and bridge north
m.rect(26, 53, 38, 61, ".")
m.rect(31, 49, 33, 52, ",")
# ---- central island with the altar
m.rect(22, 34, 42, 48, ":")
m.rect(29, 37, 35, 41, ";")
m.box(22, 44, 27, 48, "n", "d")
m.put(25, 44, "[")
for (x, y) in [(23, 35), (41, 35), (41, 47)]:
    m.put(x, y, "G")
# ---- west island (red key) and bridge
m.rect(4, 36, 16, 50, "1")
m.rect(19, 41, 21, 42, ",")
m.rect(17, 41, 18, 42, "7")
m.rect(7, 44, 8, 45, "n"); m.rect(12, 38, 13, 39, "n")
# hidden islet (teleporter secret)
m.rect(2, 55, 7, 60, "z")
# ---- east island (blue key, flesh pods) and bridge
m.rect(48, 36, 60, 50, "8")
m.rect(43, 41, 45, 42, ",")
m.rect(46, 41, 47, 42, "7")
m.rect(55, 42, 57, 44, "J")
m.box(50, 46, 54, 50, "#", "j")
m.put(52, 46, "<")
m.box(56, 46, 60, 50, "#", "j")
m.put(58, 46, "<")
# ---- antechamber with the two gates
m.box(26, 26, 38, 33, "#", "=")
m.put(32, 33, "(")
m.put(32, 26, ")")
for (x, y) in [(26, 29), (38, 29)]:
    m.put(x, y, "n")
# ---- the arena
m.box(12, 4, 52, 26, "#", "^")
m.put(32, 26, ")")
for (x, y) in [(18, 9), (44, 9), (18, 20), (44, 20)]:
    m.rect(x, y, x + 1, y + 1, "v")
m.rect(13, 5, 16, 7, "9"); m.rect(48, 5, 51, 7, "9")
m.rect(13, 23, 16, 25, "9"); m.rect(48, 23, 51, 25, "9")
for x in range(14, 52, 6):
    m.put(x, 4, "K")
m.put(12, 15, "]")
m.rect(9, 13, 11, 17, "a")
m.vline(8, 12, 18, "#"); m.hline(8, 11, 12, "#"); m.hline(8, 11, 18, "#")
# exit portal room
m.box(27, 0, 37, 4, "#", "0")
m.put(32, 4, ">")

# ================= entities
m.put(32, 59, "@")
m.put(28, 55, "e"); m.put(36, 55, "e"); m.put(30, 60, "h"); m.put(35, 60, "C")
m.put(32, 50, "s")
# central island
m.put(32, 39, "M")
m.put(25, 37, "s"); m.put(39, 37, "s"); m.put(26, 42, "y"); m.put(38, 45, "s"); m.put(36, 35, "p"); m.put(28, 46, "s")
m.put(32, 43, "f"); m.put(24, 40, "f")
m.put(24, 46, "B"); m.put(26, 47, "O"); m.put(23, 45, "e")
m.put(40, 42, "h"); m.put(30, 35, "c")
# west island
m.put(6, 39, "R")
m.put(10, 42, "s"); m.put(14, 47, "s"); m.put(5, 46, "r"); m.put(9, 37, "k"); m.put(15, 38, "f")
m.put(4, 49, "w")
m.put(4, 56, "W"); m.put(6, 58, "V"); m.put(3, 59, "E"); m.put(5, 60, "q")
m.put(10, 48, "Q")
m.put(13, 44, "O"); m.put(4, 41, "h")
# east island
m.put(56, 43, "U")
m.put(50, 39, "s"); m.put(58, 38, "s"); m.put(54, 41, "y"); m.put(59, 44, "p"); m.put(49, 48, "f")
m.put(51, 48, "s"); m.put(52, 49, "s"); m.put(57, 48, "s"); m.put(59, 49, "f")
m.put(60, 36, "e"); m.put(48, 37, "h")
# antechamber
m.put(28, 31, "s"); m.put(36, 31, "s"); m.put(32, 29, "k")
m.put(27, 27, "h"); m.put(37, 27, "C"); m.put(37, 32, "E")
# arena
m.put(32, 12, "Z")
m.put(14, 6, "M"); m.put(50, 6, "E"); m.put(14, 24, "O"); m.put(50, 24, "C")
m.put(20, 15, "h"); m.put(44, 15, "h"); m.put(32, 22, "e")
m.put(10, 15, "V"); m.put(10, 14, "E")
m.put(32, 2, "X")

emit("level6_dimension", {
    "name": "SNIRBY DIMENSION",
    "music": "dimension", "ambience": "amb_dimension", "sky": "sky_void",
    "fog": Color(0.45, 0.0, 0.5, 0.45), "fog_start": 20.0, "fog_end": 110.0,
    "light_boost": 1.35, "diminish": 0.015,
    "start_angle": 0.0, "par": 294,
    "wall": "d_void", "side": "d_meat", "tree_tex": "d_flesh",
    "test_views": [[32, 58, 0, 5], [32, 46, 0, 0], [10, 44, 90, 0], [54, 44, -90, 0], [32, 30, 0, 0], [32, 22, 0, 8]],
}, L, m)
