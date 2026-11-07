"""Level 4: CONSUMER HEADQUARTERS."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from levelkit import Map, Color, emit


def room(f, c, **kw):
    d = dict(floor=f, ceil=c, ftex="h_carpet", ctex="h_ceiling", light=0.65, side="h_panel", upper="h_wallpaper")
    d.update(kw)
    return d


L = {
    "%": {"wall": "h_wallpaper"},
    "#": {"wall": "h_marble_wall"},
    "|": {"wall": "h_panel"},
    "n": {"wall": "h_computer"},
    "K": {"wall": "h_poster1"},
    "G": {"wall": "h_poster2"},
    "H": {"wall": "h_poster3"},
    "J": {"wall": "h_poster4"},
    "v": {"wall": "h_window"},
    "F": {"wall": "h_logo"},
    "&": {"wall": "h_elevator"},
    # lobby (floor 0)
    ".": room(0.0, 7.0, ftex="h_marble", light=0.75, upper="h_marble_wall"),
    ",": room(0.0, 7.0, ftex="h_carpet2", light=0.75, upper="h_marble_wall"),
    "'": room(0.0, 7.0, ftex="h_marble", ctex="h_ceilinglight", light=0.95, upper="h_marble_wall"),
    "u": room(1.0, 7.0, ftex="h_panel", side="h_panel", light=0.75),
    "0": room(0.0, 3.0, ftex="h_marble", ctex="h_ceilinglight", light=0.9, secret=True),
    "=": room(0.0, 4.0, ftex="h_carpet2", light=0.6),
    # cubicle farm (floor 6)
    ":": room(6.0, 10.0),
    ";": room(6.0, 10.0, ctex="h_ceilinglight", light=0.9),
    "1": room(7.5, 10.0, ftex="h_panel", side="h_panel"),
    "_": room(6.0, 9.0, ftex="metal_floor", ctex="i_ceiling", light=0.45, flicker=1),
    "z": room(6.0, 9.0, ftex="h_carpet2", secret=True, light=0.7),
    # executive wing (floor 6)
    "-": room(6.0, 9.5, ftex="h_carpet2", ctex="h_ceiling", light=0.6, upper="h_panel"),
    "j": room(6.0, 9.5, ftex="v_woodfloor", ctex="h_ceilinglight", light=0.8, upper="h_panel"),
    "?": room(6.0, 9.5, ftex="v_woodfloor", ctex="h_ceilinglight", light=0.8, trigger=2),
    "P": room(7.0, 9.5, ftex="h_panel", side="h_panel", light=0.8),
    "a": room(6.0, 9.0, ftex="h_carpet", light=0.25, flicker=1),
    # boardroom (floor 12) and roof
    "9": room(12.0, 17.0, ftex="h_carpet2", ctex="h_ceiling", light=0.55, upper="h_marble_wall"),
    "8": room(13.0, 17.0, ftex="v_woodfloor", side="h_panel", light=0.6),
    "d": room(12.0, 15.0, ftex="h_marble", ctex="h_ceilinglight", light=0.85, secret=True),
    "^": dict(floor=12.0, ceil=30.0, ftex="i_concrete", ctex="SKY", light=0.75, side="i_hazard"),
    "7": dict(floor=12.3, ceil=30.0, ftex="metal_floor", ctex="SKY", light=0.9, side="i_hazard"),
    "L": {"lift": True, "floor": 0.0, "top": 6.0, "ftex": "metal_floor", "side": "h_elevator", "ceil": 10.0, "ctex": "h_ceilinglight", "light": 0.8},
    "N": {"lift": True, "floor": 6.0, "top": 12.0, "ftex": "metal_floor", "side": "h_elevator", "ceil": 16.0, "ctex": "h_ceilinglight", "light": 0.8},
    "D": {"door": "door_metal", "side": "h_panel"},
    "(": {"door": "door_blue", "key": "blue", "side": "h_panel"},
    ")": {"door": "door_yellow", "key": "yellow", "side": "h_panel"},
    "[": {"door": "door_red", "key": "red", "side": "h_panel"},
    "{": {"door": "h_poster1", "secret_door": True, "side": "h_marble_wall"},
    "}": {"door": "h_logo", "secret_door": True, "side": "h_panel"},
    "]": {"door": "h_wallpaper", "secret_door": True, "side": "h_panel"},
    "<": {"door": "h_panel", "remote": True, "tag": 2},
}

m = Map(64, 56, "%")
# ---- lobby
m.box(4, 36, 34, 54, "#", ".")
m.rect(16, 37, 20, 53, ",")
for x in range(6, 33, 3):
    m.put(x, 54, "v")
for y in (41, 46, 51):
    m.rect(5, y, 33, y, "'")
m.rect(16, 41, 20, 41, "'")
for (x, y) in [(9, 40), (9, 49), (28, 40), (28, 49)]:
    m.put(x, y, "#")
m.rect(10, 44, 14, 45, "u"); m.rect(22, 44, 26, 45, "u")
m.put(4, 39, "K"); m.put(4, 50, "J"); m.put(34, 39, "H")
# vault secret behind the poster
m.box(0, 41, 4, 49, "#", "0")
m.vline(0, 41, 49, "#")
m.put(4, 45, "{")
# security office
m.box(34, 40, 46, 52, "%", "=")
m.put(34, 46, "D")
m.rect(36, 41, 38, 41, "n"); m.rect(41, 41, 44, 41, "n")
m.put(46, 45, "G")
# elevator lobby behind the yellow door
m.box(12, 29, 24, 36, "&", ".")
m.put(18, 36, ")")
m.rect(13, 32, 23, 32, "'")
m.put(18, 29, "L")
# ---- cubicle farm (floor 6)
m.box(2, 13, 40, 29, "%", ":")
m.put(18, 29, "L")
for y in (16, 21, 26):
    m.rect(3, y, 39, y, ";")
for cx in (5, 11, 23, 29, 35):
    for cy in (15, 22):
        if cx + 4 > 39:
            continue
        m.hline(cx, cx + 4, cy, "1")
        m.vline(cx, cy, cy + 3, "1")
        m.vline(cx + 4, cy, cy + 3, "1")
m.put(2, 20, "K"); m.put(2, 24, "J"); m.put(40, 27, "G")
# IT closet (rocket launcher) and the supply closet secret
m.box(2, 8, 9, 13, "%", "_")
m.put(6, 13, "D")
m.rect(3, 9, 3, 12, "n")
m.box(10, 8, 16, 13, "%", "z")
m.put(13, 13, "]")
# ---- executive wing (floor 6)
m.box(40, 13, 62, 34, "|", "-")
m.put(40, 20, "D")
m.rect(41, 18, 61, 18, "j")
m.put(40, 27, "G")
# CEO office + ambush closets
m.box(49, 24, 61, 33, "|", "j")
m.put(55, 24, "D")
m.rect(56, 29, 59, 30, "P")
m.put(57, 28, "?"); m.put(58, 28, "?")
m.put(61, 28, "F")
m.box(44, 26, 49, 33, "|", "a")
m.put(49, 28, "<"); m.put(49, 31, "<")
# break room
m.box(52, 14, 61, 20, "|", "j")
m.put(52, 17, "D")
# elevator to the boardroom behind the blue door
m.put(41, 14, "|"); m.put(43, 14, "|")
m.put(42, 14, "(")
m.put(42, 13, "N")
# ---- boardroom (floor 12)
m.box(20, 1, 44, 13, "#", "9")
m.put(42, 13, "N")
m.rect(26, 6, 38, 8, "8")
for x in range(22, 43, 4):
    m.put(x, 1, "v")
m.put(20, 9, "F")
m.box(15, 2, 20, 7, "#", "d")
m.put(20, 4, "}")
m.put(44, 6, "[")
# ---- roof (outdoor, floor 12)
m.rect(45, 2, 61, 11, "^")
m.rect(53, 4, 57, 8, "7")

# ================= entities
m.put(18, 52, "@")
m.put(7, 52, "i"); m.put(31, 52, "+"); m.put(12, 38, "c")
m.put(12, 47, "y"); m.put(24, 42, "y"); m.put(30, 50, "g"); m.put(7, 43, "g"); m.put(18, 39, "r")
m.put(1, 44, "M"); m.put(2, 47, "+"); m.put(3, 42, "+")
m.put(32, 37, "x"); m.put(6, 37, "x")
# security office
m.put(44, 50, "Y")
m.put(37, 48, "y"); m.put(42, 44, "y"); m.put(44, 47, "y"); m.put(39, 51, "r")
m.put(36, 50, "C"); m.put(45, 42, "A")
# elevator lobby
m.put(14, 34, "g"); m.put(22, 34, "g"); m.put(23, 30, "h")
# cubicle farm
for (x, y) in [(7, 17), (13, 24), (25, 17), (31, 24), (37, 17), (19, 20), (27, 27), (9, 27), (33, 19)]:
    m.put(x, y, "gysyrgbsg"[(x + y) % 9])
m.put(19, 15, "y"); m.put(3, 27, "s")
m.put(5, 10, "5"); m.put(7, 10, "O"); m.put(8, 12, "o")
m.put(12, 10, "B"); m.put(14, 11, "e"); m.put(14, 9, "+")
m.put(38, 28, "h"); m.put(21, 27, "i"); m.put(4, 14, "C")
# executive wing
m.put(45, 16, "b"); m.put(58, 22, "y"); m.put(46, 22, "g"); m.put(56, 16, "p")
m.put(57, 30, "U")
m.put(45, 28, "b"); m.put(47, 31, "r"); m.put(46, 30, "g")
m.put(51, 26, "y"); m.put(60, 32, "g")
m.put(55, 15, "+"); m.put(60, 15, "+"); m.put(54, 19, "h"); m.put(61, 21, "O")
# boardroom
m.put(32, 7, "R")
m.put(24, 4, "k"); m.put(40, 10, "k")
m.put(28, 10, "p"); m.put(36, 3, "p"); m.put(22, 11, "y"); m.put(42, 3, "y")
m.put(17, 4, "V"); m.put(18, 6, "h")
m.put(21, 2, "O"); m.put(43, 11, "C")
# roof
m.put(55, 6, "X")
m.put(48, 4, "f"); m.put(59, 10, "f"); m.put(50, 9, "f"); m.put(60, 3, "p")
m.put(46, 10, "h"); m.put(47, 3, "e")

emit("level4_hq", {
    "name": "CONSUMER HEADQUARTERS",
    "music": "hq", "ambience": "amb_hq", "sky": "sky_night",
    "fog": Color(0.08, 0.02, 0.12, 0.6), "fog_start": 18.0, "fog_end": 80.0,
    "light_boost": 1.45, "diminish": 0.024,
    "start_angle": 0.0, "par": 251,
    "wall": "h_wallpaper", "side": "h_panel",
    "test_views": [[18, 51, 0, 5], [40, 47, 90, 0], [18, 27, 0, 0], [30, 20, -90, -10], [55, 27, 180, 0], [32, 10, 0, 0], [50, 6, -90, 5]],
}, L, m)
