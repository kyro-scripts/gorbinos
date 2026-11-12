"""Episode 2, level 2: THE MAGENTA THROAT.

A long switchback gullet stepping down at every turn, swelling into
pillared ribs along the way, then the stomach: a big chamber round a pool of
acid ooze with raised gristle platforms, closets that burst open as you come
in, and the way out at the bottom. Graded to magenta and cyan.
"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from levelkit import Map, Color, emit


def room(floor, ceil, ftex, ctex="fv_grid_c", light=0.8, **kw):
    d = dict(floor=floor, ceil=ceil, ftex=ftex, ctex=ctex, light=light, side="fv_sweat", upper="fv_brick_m")
    d.update(kw)
    return d


L = {
    "%": {"wall": "fv_brick_m"},
    "#": {"wall": "fv_glow_c"},
    "n": {"wall": "fv_sweat"},
    "G": {"wall": "fv_sign_gorb"},
    "K": {"wall": "fv_sign_down"},
    "H": {"wall": "d_eyes"},
    ".": room(0.0, 4.0, "fv_grid_m", light=0.9),
    ",": room(0.0, 3.5, "fv_mesh", light=0.75),
    ";": room(-0.5, 3.0, "fv_mesh", light=0.75),
    ":": room(-1.0, 2.5, "fv_mesh", light=0.75),
    "7": room(-1.5, 2.0, "fv_mesh", light=0.75),
    "8": room(-2.0, 1.5, "fv_grid_m", light=0.75),
    "b0": None,
    "d": room(-2.5, 6.0, "fv_grid_m", ctex="fv_brick_m", light=0.85, flicker=2),
    "v": room(-2.5, 6.0, "fv_grid_m", ctex="fv_brick_m", light=0.85, trigger=4),
    "j": room(-2.0, 6.0, "d_meat", ctex="fv_brick_m", light=0.9),
    "~": room(-3.0, 6.0, "d_ooze", ctex="fv_brick_m", light=1.0, liquid="liq_ooze", damage=3),
    "u": room(-2.5, 1.0, "fv_mesh", light=0.3, flicker=1),
    "a": room(-2.5, 1.5, "fv_grid_m", light=1.0),
    "z": room(-1.0, 2.0, "fv_grid_m", light=0.6, secret=True),
    "D": {"door": "fv_door"},
    "<": {"door": "fv_door", "remote": True, "tag": 4},
    "]": {"door": "fv_brick_m", "secret_door": True},
}
del L["b0"]

m = Map(70, 46, "%")

# --- start: a little lit cell, the gullet goes east from it
m.rect(2, 2, 9, 8, ".")
m.put(2, 2, "#"); m.put(9, 2, "#")
m.put(5, 1, "G")
# band 1, east, floor 0, with a pillared rib
m.rect(2, 9, 60, 11, ",")
m.rect(24, 6, 32, 14, ",")
m.rect(26, 8, 26, 8, "#"); m.rect(30, 8, 30, 8, "#"); m.rect(26, 12, 26, 12, "#"); m.rect(30, 12, 30, 12, "#")
# turn 1, down a step
m.rect(58, 12, 60, 15, ";")
# band 2, west, -0.5, with a rib
m.rect(6, 16, 60, 18, ";")
m.rect(30, 16, 40, 21, ";")
m.rect(34, 19, 35, 20, "#")
m.put(61, 17, "K")
# turn 2, down a step
m.rect(6, 19, 8, 22, ":")
# band 3, east, -1.0 then -1.5 then -2.0 at the stomach door
m.rect(6, 23, 24, 25, ":")
m.rect(25, 23, 32, 25, "7")
m.rect(33, 23, 40, 25, "8")
# secret: a sweaty niche off band 3
m.put(16, 22, "]")
m.rect(15, 20, 17, 21, "z")

# --- the stomach
m.rect(41, 22, 60, 40, "d")
m.rect(41, 23, 43, 25, "v")
m.rect(47, 28, 55, 35, "~")
m.rect(45, 26, 46, 27, "j"); m.rect(56, 26, 57, 27, "j"); m.rect(45, 36, 46, 37, "j"); m.rect(56, 36, 57, 37, "j")
for (x, y) in [(41, 22), (60, 22), (41, 40), (60, 40)]:
    m.put(x, y, "#")
m.vline(40, 26, 40, "n")
m.hline(41, 60, 41, "n")
for y in (30, 34):
    m.put(40, y, "H")
# closets in the east wall, bursting open when you come in
m.vline(61, 22, 40, "n")
m.rect(62, 25, 64, 28, "u")
m.vline(61, 26, 27, "<")
m.rect(62, 31, 64, 34, "u")
m.vline(61, 32, 33, "<")
# the way out: down the south-east corner
m.rect(57, 41, 59, 43, "d")
m.hline(56, 60, 44, "%")
m.put(60, 42, "D"); m.put(60, 43, "D")
m.rect(61, 41, 67, 44, "a")

# ================= entities
m.put(5, 5, "@")
m.put(8, 6, "c"); m.put(3, 7, "i"); m.put(7, 3, "+")
# band 1
m.put(14, 10, "g"); m.put(20, 10, "s"); m.put(28, 7, "y"); m.put(28, 13, "g"); m.put(31, 10, "C")
m.put(42, 10, "s"); m.put(50, 9, "g"); m.put(55, 11, "x"); m.put(59, 13, "c")
# band 2
m.put(52, 17, "y"); m.put(44, 16, "s"); m.put(35, 17, "3"); m.put(33, 20, "g"); m.put(38, 20, "y")
m.put(22, 17, "s"); m.put(14, 18, "g"); m.put(9, 17, "i"); m.put(7, 21, "h")
# secret niche
m.put(16, 20, "A"); m.put(15, 20, "O")
# band 3
m.put(12, 24, "y"); m.put(20, 24, "s"); m.put(28, 23, "p"); m.put(36, 25, "g"); m.put(30, 24, "c")
# stomach
m.put(44, 30, "g"); m.put(58, 30, "y"); m.put(50, 25, "s"); m.put(52, 38, "s"); m.put(45, 38, "r"); m.put(57, 24, "p")
m.put(45, 26, "C"); m.put(57, 37, "h"); m.put(56, 26, "5"); m.put(45, 37, "o"); m.put(46, 33, "i")
m.put(63, 26, "r"); m.put(63, 27, "y"); m.put(63, 32, "b"); m.put(63, 33, "g")
m.put(58, 42, "+")
m.put(65, 42, "X")
m.put(66, 43, "M")

emit("level8_throat", {
    "name": "THE MAGENTA THROAT",
    "music": "fever2", "ambience": "amb_dimension", "sky": "",
    "fog": Color(0.25, 0.0, 0.3, 0.45), "fog_start": 14.0, "fog_end": 60.0,
    "light_boost": 1.7, "diminish": 0.02,
    "start_angle": 180.0, "par": 120,
    "wall": "fv_brick_m", "side": "fv_sweat",
    "grade": [Color(0.22, 0.0, 0.3), Color(0.45, 1.0, 0.95), 0.55], "warp": 0.32,
    "wall_fish": 3,
    "test_views": [[5, 5, 180, 0], [28, 10, -90, 0], [36, 17, 90, 0], [20, 24, -90, 0], [43, 24, -90, -10], [51, 39, 0, 5]],
}, L, m)
