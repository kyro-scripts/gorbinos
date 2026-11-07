"""Level 1: GORBINO VILLAGE."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from levelkit import Map, Color, emit

OUT = dict(floor=0.0, ceil=9.0, ctex="SKY", light=0.95)
IN = dict(ceil=3.5, ctex="v_ceiling", light=0.6, side="v_timber", upper="v_plaster")
L = {
    "%": {"wall": "v_stonewall"},
    "#": {"wall": "v_brick"},
    "&": {"wall": "v_timber"},
    "n": {"wall": "v_window"},
    "H": {"wall": "v_hedge"},
    "P": {"wall": "v_planks"},
    "K": {"wall": "v_poster"},
    "G": {"wall": "v_sign"},
    ".": dict(OUT, ftex="v_grass"),
    ",": dict(OUT, ftex="v_dirt"),
    ":": dict(OUT, ftex="v_cobble"),
    ";": dict(OUT, ftex="v_flowers"),
    "7": dict(OUT, floor=1.0, ftex="v_flowers", side="v_stonewall"),
    "~": dict(OUT, floor=-0.4, liquid="liq_goo", damage=4, light=1.0, side="v_stonewall"),
    "z": dict(OUT, ftex="v_grass", secret=True),
    "_": dict(IN, floor=0.0, ftex="v_woodfloor"),
    "0": dict(IN, floor=0.0, ftex="v_woodfloor", secret=True, light=0.75, flicker=2),
    "^": dict(floor=0.5, ceil=6.0, ftex="v_cobble", ctex="v_ceiling", light=0.45, side="v_stonewall", upper="v_brick"),
    "8": dict(floor=1.0, ceil=6.0, ftex="v_cobble", ctex="v_ceiling", light=0.55, side="v_stonewall"),
    "9": dict(floor=1.5, ceil=6.0, ftex="v_cobble", ctex="v_ceiling", light=0.55, side="v_stonewall"),
    "j": dict(floor=2.0, ceil=6.0, ftex="v_flowers", ctex="v_ceiling", light=0.8, trigger=2, side="v_stonewall"),
    "a": dict(floor=0.5, ceil=4.0, ftex="v_dirt", ctex="v_ceiling", light=0.3, flicker=1),
    "-": dict(floor=0.0, ceil=5.0, ftex="v_woodfloor", ctex="v_ceiling", light=0.5, side="crate"),
    "u": dict(floor=1.0, ceil=5.0, ftex="crate", ctex="v_ceiling", light=0.5, side="crate"),
    "v": dict(floor=2.0, ceil=5.0, ftex="v_woodfloor", ctex="v_ceiling", light=0.6, side="v_planks", secret=True),
    "D": {"door": "door_metal"},
    "[": {"door": "door_red", "key": "red"},
    "]": {"door": "v_hedge", "secret_door": True},
    "{": {"door": "v_brick", "secret_door": True, "side": "v_timber"},
    "<": {"door": "v_brick", "remote": True, "tag": 2},
}

m = Map(64, 44, "%")
# the whole village is outdoors
m.rect(1, 1, 56, 42, ".")
# perimeter village wall with the gate, and the road out of town
m.vline(57, 1, 42, "%")
m.rect(58, 25, 62, 34, ":")
m.put(57, 29, "[")
m.put(57, 30, "[")
m.hline(58, 62, 25, "%")
m.hline(58, 62, 34, "%")
m.put(58, 25, "G")
m.put(60, 34, "G")
# main road
m.rect(1, 28, 56, 31, ",")

# --- start courtyard (south-west)
m.box(1, 33, 12, 42, "#", ":")
m.rect(5, 33, 7, 33, ":")
m.put(1, 33, "%")
m.puts(3, 35, ";;")
m.puts(9, 35, ";;")

# --- house A (north of road, west)
m.box(3, 17, 14, 25, "&", "_")
m.put(8, 25, "D")
for (x, y) in [(5, 25), (11, 25), (3, 20), (14, 21), (14, 19)]:
    m.put(x, y, "n")
m.rect(4, 18, 5, 19, "_")
# fireplace secret -> secret room
m.box(6, 12, 11, 17, "&", "0")
m.put(8, 17, "{")

# --- pond (north-west) and hidden hedge garden
m.rect(5, 5, 12, 9, "~")
m.hline(1, 17, 3, "H")
m.vline(18, 1, 3, "H")
m.rect(1, 1, 17, 2, "z")
m.put(9, 3, "]")

# --- plaza
m.rect(19, 13, 35, 25, ":")
m.rect(25, 17, 29, 21, "~")
m.rect(26, 18, 28, 20, ":")
for (x0, y0) in [(19, 13), (33, 13), (19, 23), (33, 23)]:
    m.rect(x0, y0, x0 + 2, y0 + 2, "7")

# --- temple (north-east)
m.box(39, 2, 53, 16, "#", "^")
m.put(46, 16, "D")
for (x, y) in [(42, 6), (42, 11), (50, 6), (50, 11)]:
    m.put(x, y, "#")
m.rect(44, 3, 48, 3, "j")
m.rect(44, 4, 48, 4, "9")
m.rect(44, 5, 48, 5, "8")
# monster closets behind remote doors
m.box(35, 5, 39, 11, "#", "a")
m.put(39, 7, "<")
m.put(39, 9, "<")
m.box(53, 5, 56, 11, "#", "a")
m.put(53, 7, "<")
m.put(53, 9, "<")

# --- barn (south-east) with crate climb to a secret loft
m.box(38, 33, 52, 42, "P", "-")
m.put(45, 33, "D")
m.rect(39, 34, 42, 36, "v")
m.put(43, 37, "u")
m.put(43, 36, "u")
m.rect(48, 39, 51, 41, "u")

# --- fenced flower field south of the road
m.box(15, 33, 31, 41, "H", ";")
m.put(23, 33, ";")
m.put(22, 33, ";")
for (x, y) in [(19, 37), (27, 37)]:
    m.put(x, y, "K")

# ================= entities
m.put(6, 39, "@")
m.puts(3, 40, "ii")
m.put(10, 40, "+")
# road
m.put(16, 29, "g"); m.put(30, 30, "g"); m.put(44, 29, "y")
m.put(52, 30, "g"); m.put(36, 28, "x"); m.put(13, 31, "x")
m.put(25, 30, "i")
# house A
m.put(10, 20, "2")
m.put(6, 21, "g"); m.put(12, 23, "g"); m.put(9, 19, "y")
m.put(4, 24, "h")
m.put(13, 18, "c")
# secret room
m.put(8, 14, "A"); m.put(10, 14, "C"); m.put(7, 15, "+")
# plaza
m.put(27, 19, "T")
for (x, y) in [(23, 15), (31, 15), (23, 23), (31, 23)]:
    m.put(x, y, "l")
m.put(20, 14, "y"); m.put(34, 24, "y")
m.put(22, 19, "g"); m.put(32, 18, "g"); m.put(27, 24, "g"); m.put(27, 14, "r")
m.put(24, 25, "c"); m.put(30, 13, "i")
m.put(21, 21, "x"); m.put(33, 21, "x")
# north of plaza: trees
for (x, y) in [(22, 4), (26, 8), (31, 5), (33, 9), (20, 10), (15, 14)]:
    m.put(x, y, "t")
m.put(28, 6, "g"); m.put(33, 3, "+")
# pond & garden
m.put(14, 7, "g"); m.put(3, 10, "g")
m.put(6, 1, "A"); m.put(14, 2, "+"); m.put(10, 1, "c")
# temple
m.put(46, 3, "R")
m.put(41, 13, "g"); m.put(51, 13, "g"); m.put(46, 9, "y"); m.put(45, 13, "h")
m.put(37, 7, "r"); m.put(37, 9, "g"); m.put(38, 8, "r")
m.put(55, 7, "g"); m.put(54, 9, "y"); m.put(55, 9, "g")
m.put(41, 3, "c"); m.put(51, 3, "i")
# barn
m.put(45, 38, "s"); m.put(49, 36, "s"); m.put(41, 39, "g"); m.put(47, 40, "s")
m.put(50, 35, "x"); m.put(39, 41, "x")
m.put(40, 35, "C"); m.put(41, 34, "h")
m.put(49, 40, "i")
# flower field
m.put(18, 36, "g"); m.put(25, 38, "g"); m.put(29, 35, "g")
m.put(17, 40, "+"); m.put(30, 40, "+"); m.put(23, 36, "c")
# exit
m.put(61, 29, "X")
m.put(59, 27, "l"); m.put(59, 32, "l")
m.put(54, 13, "+")

emit("level1_village", {
    "name": "GORBINO VILLAGE",
    "music": "village", "ambience": "amb_village", "sky": "sky_village",
    "fog": Color(0.85, 0.9, 0.55, 0.35), "fog_start": 25.0, "fog_end": 110.0,
    "light_boost": 1.4, "diminish": 0.018,
    "start_angle": 0.0, "par": 168,
    "wall": "v_stonewall", "side": "v_stonewall", "tree_tex": "v_hedge",
    "test_views": [[6, 37, 0, 0], [27, 27, 0, 5], [46, 18, 0, 0], [46, 10, 0, 10], [45, 31, 180, 0], [10, 27, 0, 0], [55, 29, -90, 0]],
}, L, m)
