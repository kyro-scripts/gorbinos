"""Episode 2, level 4: WHITE HEAT.

Three open arenas under a red fever sky, linked by tight, kinked corridors:
a pillared yard, a canyon of raised white platforms, and a last big
arena where stepping onto the centre throws open four closets. The exit is
up the steps at the far end. Graded to white and blood red.
"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from levelkit import Map, Color, emit


def out(floor, ftex="fv_tile_w", light=1.0, **kw):
    d = dict(floor=floor, ceil=14.0, ftex=ftex, ctex="SKY", light=light, side="fv_tile_r", upper="fv_tile_w")
    d.update(kw)
    return d


def ins(floor, ftex="fv_check", ceil=3.5, light=0.8, **kw):
    d = dict(floor=floor, ceil=floor + ceil, ftex=ftex, ctex="fv_ceil", light=light, side="fv_tile_r", upper="fv_tile_w")
    d.update(kw)
    return d


L = {
    "%": {"wall": "fv_tile_w"},
    "#": {"wall": "fv_glow_r"},
    "n": {"wall": "fv_tile_r"},
    "H": {"wall": "fv_stripe"},
    "G": {"wall": "fv_sign_run"},
    "K": {"wall": "fv_sign_down"},
    ".": out(0.0),
    ":": out(0.0, "fv_check"),
    ",": ins(0.0),
    ";": out(0.5, "fv_concrete"),
    "7": out(1.0, "fv_concrete"),
    "8": out(1.5, "fv_tile_r"),
    "9": out(-0.5, "fv_tile_w"),
    "0": out(-1.0, "fv_check"),
    "v": out(-1.0, "fv_check", trigger=8),
    "j": out(-0.5, "fv_tile_r"),
    "u": ins(-1.0, "fv_mesh", ceil=3.0, light=0.3, flicker=1),
    "1": ins(-0.5, ceil=3.5),
    "2b": None,
    "a": ins(0.0, "fv_tile_w", ceil=3.0, light=1.0),
    "d": ins(-0.5, "fv_tile_w", ceil=3.5, light=1.0),
    "z": ins(0.0, "fv_concrete", ceil=3.0, light=0.6, secret=True),
    "D": {"door": "fv_door"},
    "<": {"door": "fv_door", "remote": True, "tag": 8},
    "]": {"door": "fv_tile_w", "secret_door": True},
}
del L["2b"]

m = Map(80, 40, "%")

# --- arena 1: the pillared yard
m.rect(2, 12, 20, 27, ".")
m.rect(5, 15, 17, 24, ":")
for (x, y) in [(6, 16), (15, 16), (6, 22), (15, 22)]:
    m.rect(x, y, x + 1, y + 1, "#")
m.put(11, 11, "G")
# secret, off the yard's south side
m.put(11, 28, "]")
m.rect(9, 29, 13, 31, "z")
# --- corridor 1, kinked
m.rect(21, 18, 26, 20, ",")
m.rect(24, 21, 26, 25, ",")
m.rect(27, 23, 34, 25, ",")
m.put(27, 22, "H"); m.put(30, 22, "H")
# --- arena 2: a canyon of raised platforms
m.rect(35, 6, 52, 33, ".")
m.rect(38, 9, 42, 13, ";"); m.rect(39, 10, 41, 12, "7")
m.rect(45, 15, 50, 20, ";"); m.rect(46, 16, 49, 19, "7"); m.rect(47, 17, 48, 18, "8")
m.rect(38, 24, 43, 29, ";"); m.rect(39, 25, 42, 28, "7")
for (x, y) in [(35, 6), (52, 6), (35, 33), (52, 33)]:
    m.put(x, y, "#")
# --- corridor 2, kinked again, going down a step
m.rect(53, 27, 57, 29, ",")
m.rect(55, 30, 57, 32, "1")
m.rect(58, 30, 60, 32, "1")
m.put(58, 33, "K")
# --- arena 3: the last one, sunken, closets all round
m.rect(61, 6, 77, 34, "9")
m.rect(64, 10, 74, 30, "0")
m.rect(67, 18, 71, 22, "v")
for (x, y) in [(65, 11), (72, 11), (65, 28), (72, 28)]:
    m.rect(x, y, x + 1, y + 1, "n")
# closets: west wall pair (clear of the corridor in) and east wall pair
for cy in (10, 19):
    m.rect(57, cy, 59, cy + 3, "u")
    m.vline(60, cy, cy + 3, "%")
    m.vline(60, cy + 1, cy + 2, "<")
# east closets inset into the arena's east side
for cy in (10, 26):
    m.rect(75, cy, 77, cy + 3, "u")
    m.vline(74, cy, cy + 3, "%")
    m.vline(74, cy + 1, cy + 2, "<")
# the exit, up the north side
m.rect(67, 3, 71, 5, "d")
m.hline(67, 71, 5, "D")
m.rect(67, 1, 71, 4, "d")
m.put(66, 5, "#"); m.put(72, 5, "#")

# ================= entities
m.put(4, 20, "@")
m.put(3, 13, "c"); m.put(3, 26, "i"); m.put(19, 13, "+"); m.put(19, 26, "c")
m.put(9, 19, "g"); m.put(13, 21, "y"); m.put(12, 14, "s"); m.put(18, 24, "g"); m.put(17, 17, "r")
m.put(11, 30, "A"); m.put(10, 30, "C"); m.put(12, 30, "h")
m.put(25, 22, "s"); m.put(31, 24, "g"); m.put(23, 19, "i")
# arena 2
m.put(40, 11, "p"); m.put(47, 17, "k"); m.put(40, 26, "p"); m.put(37, 18, "y"); m.put(50, 10, "g"); m.put(50, 30, "r")
m.put(44, 22, "s"); m.put(36, 30, "g")
m.put(41, 10, "O"); m.put(48, 18, "M"); m.put(41, 27, "C"); m.put(37, 8, "h"); m.put(51, 25, "e")
# corridor 2
m.put(56, 31, "y"); m.put(55, 28, "i")
# arena 3
m.put(63, 8, "g"); m.put(75, 8, "g"); m.put(63, 32, "y"); m.put(75, 32, "y"); m.put(69, 14, "r"); m.put(69, 26, "r")
m.put(66, 20, "C"); m.put(72, 20, "E"); m.put(69, 20, "h")
m.put(58, 11, "k"); m.put(58, 12, "r"); m.put(58, 20, "b"); m.put(58, 21, "g")
m.put(76, 11, "k"); m.put(76, 12, "y"); m.put(76, 27, "b"); m.put(76, 28, "r")
m.put(69, 2, "X")
m.put(68, 3, "+"); m.put(70, 3, "+")

emit("level10_whiteheat", {
    "name": "WHITE HEAT",
    "music": "fever4", "ambience": "amb_industrial", "sky": "sky_fever",
    "fog": Color(0.85, 0.2, 0.15, 0.3), "fog_start": 25.0, "fog_end": 90.0,
    "light_boost": 1.5, "diminish": 0.015,
    "start_angle": -90.0, "par": 150,
    "wall": "fv_tile_w", "side": "fv_tile_r",
    "grade": [Color(0.5, 0.0, 0.05), Color(1.0, 0.98, 0.95), 0.55], "warp": 0.34,
    "wall_fish": 4,
    "test_views": [[4, 20, -90, 0], [24, 22, 180, 0], [36, 20, -90, 0], [47, 22, 0, 0], [62, 20, -90, 0], [69, 8, 0, 0]],
}, L, m)
