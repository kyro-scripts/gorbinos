"""Episode 2, level 1: FEVER CORRIDORS.

Fast and linear: a hot yellow-tiled start room, a long corridor with side
alcoves, a pillar hall where stepping into the middle springs two closets,
a dog-leg corridor, a wide stair hall going down three metres, a red pit
room with a glowing grate floor, and the exit. Graded hard to red and
yellow, with the view bulging at speed.
"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from levelkit import Map, Color, emit


def room(floor, ceil, ftex, ctex="fv_ceil", light=0.85, **kw):
    d = dict(floor=floor, ceil=ceil, ftex=ftex, ctex=ctex, light=light, side="fv_tile_r", upper="fv_tile_y")
    d.update(kw)
    return d


L = {
    "%": {"wall": "fv_tile_y"},
    "#": {"wall": "fv_glow_y"},
    "n": {"wall": "fv_tile_r"},
    "H": {"wall": "fv_stripe"},
    "G": {"wall": "fv_sign_run"},
    "K": {"wall": "fv_sign_down"},
    "F": {"wall": "fv_glow_r"},
    ".": room(0.0, 4.0, "fv_concrete", light=0.9),
    ",": room(0.0, 3.5, "fv_check", light=0.75),
    ":": room(0.0, 7.0, "fv_concrete", light=0.95),
    "v": room(0.0, 7.0, "fv_concrete", light=0.95, trigger=2),
    "u": room(0.0, 3.5, "fv_mesh", light=0.35, flicker=1),
    "7": room(-0.5, 7.0, "fv_tile_w", light=0.85),
    "8": room(-1.0, 7.0, "fv_tile_w", light=0.85),
    "9": room(-1.5, 7.0, "fv_tile_w", light=0.85),
    "0": room(-2.0, 7.0, "fv_tile_w", light=0.85),
    "1": room(-2.5, 7.0, "fv_tile_w", light=0.85),
    "d": room(-3.0, 4.5, "fv_mesh", light=0.8, flicker=2),
    "j": room(-2.5, 4.5, "fv_tile_r", light=0.8),
    "a": room(-3.0, 1.5, "fv_tile_w", light=1.0),
    "z": room(0.0, 3.0, "fv_concrete", light=0.6, secret=True),
    "D": {"door": "fv_door"},
    "<": {"door": "fv_door", "remote": True, "tag": 2},
    "]": {"door": "fv_tile_y", "secret_door": True},
}

m = Map(72, 44, "%")

# --- start room
m.rect(2, 17, 11, 26, ".")
for (x, y) in [(2, 17), (11, 17), (2, 26), (11, 26)]:
    m.put(x, y, "#")
m.put(9, 16, "G")
# secret closet behind the north wall
m.put(5, 16, "]")
m.rect(4, 13, 7, 15, "z")

# --- corridor east, with alcoves both sides
m.rect(12, 20, 30, 22, ",")
for x0 in (16, 24):
    m.rect(x0, 17, x0 + 2, 19, "u")
    m.hline(x0, x0 + 2, 16, "F")
    m.rect(x0, 23, x0 + 2, 25, "u")
    m.hline(x0, x0 + 2, 26, "F")

# --- pillar hall, its middle a trigger, closets north and south
m.rect(31, 12, 48, 31, ":")
for (x, y) in [(34, 15), (44, 15), (34, 27), (44, 27)]:
    m.rect(x, y, x + 1, y + 1, "#")
m.rect(37, 19, 42, 24, "v")
m.rect(37, 8, 42, 10, "u")
m.hline(37, 42, 11, "%")
m.hline(38, 41, 11, "<")
m.rect(37, 33, 42, 35, "u")
m.hline(37, 42, 32, "%")
m.hline(38, 41, 32, "<")
m.put(31, 12, "H"); m.put(48, 12, "H"); m.put(31, 31, "H"); m.put(48, 31, "H")

# --- dog-leg corridor east then south
m.rect(49, 20, 57, 22, ",")
m.rect(55, 23, 57, 28, ",")
m.put(58, 21, "K")

# --- stair hall going down, then the red pit room
m.rect(50, 29, 60, 29, ",")
m.rect(50, 30, 60, 30, "7")
m.rect(50, 31, 60, 31, "8")
m.rect(50, 32, 60, 32, "9")
m.rect(50, 33, 60, 33, "0")
m.rect(50, 34, 60, 34, "1")
m.rect(44, 35, 65, 42, "d")
for x in range(44, 66, 3):
    m.put(x, 43, "n")
m.rect(49, 37, 51, 38, "j")
m.rect(58, 39, 60, 40, "j")
for (x, y) in [(44, 35), (65, 35), (44, 42), (65, 42)]:
    m.put(x, y, "F")
m.vline(43, 35, 42, "n")
# --- exit room
m.vline(66, 35, 42, "n")
m.put(66, 38, "D")
m.put(66, 39, "D")
m.rect(67, 37, 70, 40, "a")

# ================= entities
m.put(4, 21, "@")
m.put(9, 19, "c"); m.put(9, 24, "i"); m.put(3, 18, "+")
# secret closet: armor and shells
m.put(5, 14, "A"); m.put(6, 14, "C")
# corridor and alcoves
m.put(17, 18, "g"); m.put(25, 24, "g"); m.put(25, 18, "y"); m.put(17, 24, "s")
m.put(21, 21, "c"); m.put(29, 21, "x")
# pillar hall
m.put(33, 21, "g"); m.put(46, 18, "g"); m.put(46, 25, "y"); m.put(39, 14, "s"); m.put(39, 29, "s")
m.put(36, 21, "C"); m.put(43, 21, "h"); m.put(32, 13, "i"); m.put(47, 30, "+")
for (x, y) in [(33, 14), (46, 14), (33, 29), (46, 29)]:
    m.put(x, y, "l")
# closets spring open
m.put(38, 9, "r"); m.put(41, 9, "g"); m.put(39, 9, "y")
m.put(38, 34, "g"); m.put(41, 34, "r"); m.put(40, 34, "s")
# dog-leg
m.put(53, 21, "s"); m.put(56, 26, "y"); m.put(56, 24, "c")
# stairs and pit
m.put(52, 30, "p"); m.put(58, 31, "p")
m.put(47, 36, "g"); m.put(55, 37, "y"); m.put(62, 38, "b"); m.put(48, 41, "s"); m.put(63, 41, "g")
m.put(50, 37, "C"); m.put(59, 39, "M"); m.put(45, 40, "x"); m.put(64, 36, "i")
m.put(69, 38, "X")
m.put(68, 40, "+")

emit("level7_fever", {
    "name": "FEVER CORRIDORS",
    "music": "fever1", "ambience": "amb_facility", "sky": "",
    "fog": Color(0.45, 0.05, 0.02, 0.4), "fog_start": 18.0, "fog_end": 70.0,
    "light_boost": 1.6, "diminish": 0.02,
    "start_angle": -90.0, "par": 95,
    "wall": "fv_tile_y", "side": "fv_tile_r",
    "grade": [Color(0.42, 0.0, 0.04), Color(1.0, 0.9, 0.35), 0.55], "warp": 0.32,
    "wall_fish": 3,
    "test_views": [[4, 21, -90, 0], [32, 21, -90, 5], [39, 21, 0, 10], [55, 29, 180, -10], [55, 38, -90, 0], [68, 38, -90, 0]],
}, L, m)
