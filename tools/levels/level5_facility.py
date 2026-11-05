"""Level 5: THE ENDLESS GORBINO FACILITY."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from levelkit import Map, Color, emit


def lab(f, c, **kw):
    d = dict(floor=f, ceil=c, ftex="f_floor", ctex="f_ceiling", light=0.7, side="f_alert", upper="f_tile")
    d.update(kw)
    return d


L = {
    "%": {"wall": "f_tile"},
    "#": {"wall": "f_tile_green"},
    "|": {"wall": "f_pipe"},
    "n": {"wall": "f_vat"},
    "K": {"wall": "f_stencil0"},
    "G": {"wall": "f_stencil1"},
    "H": {"wall": "f_stencil2"},
    "j": {"wall": "f_stencil3"},
    "&": {"wall": "f_lab"},
    "F": {"wall": "f_alert"},
    "v": {"wall": "f_dark"},
    "S": {"wall": "exit_panel", "use": "exit", "above": "f_dark"},
    "N": {"wall": "switch_off", "use": "switch", "tag": 3, "above": "f_stencil1", "msg": "OVERFLOW LAB UNSEALED."},
    ".": lab(0.0, 7.0, light=0.75),
    ",": lab(0.0, 3.5, ftex="f_tile", light=0.72),
    "'": lab(0.0, 3.5, ftex="f_tile", ctex="f_glow", light=0.85),
    ":": lab(0.0, 6.0, ftex="f_tile_green", light=0.5, flicker=2),
    "~": lab(-0.6, 6.0, liquid="liq_sludge", damage=5, light=0.8),
    "_": lab(0.0, 3.5, ftex="f_tile", light=0.6),
    "1": lab(0.5, 6.0, light=0.55),
    "7": lab(1.0, 6.0, light=0.55),
    "8": lab(1.5, 6.0, light=0.6),
    "9": lab(2.0, 6.0, light=0.65),
    "J": lab(2.0, 6.0, light=0.8, trigger=2, flicker=3),
    "a": lab(0.0, 3.0, light=0.2, flicker=1, ftex="f_tile_green"),
    "z": lab(0.0, 3.0, light=0.9, secret=True, ctex="f_glow"),
    "d": lab(0.0, 3.5, light=0.85, secret=True, ctex="f_glow", ftex="f_tile"),
    # north wing at floor 2
    "u": lab(0.5, 4.0, ftex="f_floor"),
    "-": lab(1.0, 4.5, ftex="f_floor"),
    "=": lab(1.5, 5.0, ftex="f_floor"),
    ";": lab(2.0, 7.0, ftex="i_conveyor", ctex="f_ceiling", light=0.6, side="f_alert"),
    "^": lab(2.0, 7.0, ftex="f_floor", light=0.6),
    "?": lab(3.0, 7.0, ftex="crate", side="crate", light=0.6),
    "P": lab(4.0, 7.0, ftex="crate", side="crate", light=0.8, secret=True),
    "0": lab(2.0, 5.0, ftex="metal_floor", ctex="f_glow", light=0.9, flicker=3),
    # overflow lab
    "/": lab(0.0, 5.0, ftex="f_tile_green", light=0.45, flicker=1),
    "`": lab(1.0, 5.0, ftex="metal_floor", light=0.55),
    "D": {"door": "door_metal", "side": "f_dark"},
    "(": {"door": "door_blue", "key": "blue", "side": "f_dark"},
    ")": {"door": "door_yellow", "key": "yellow", "side": "f_dark"},
    "[": {"door": "f_vat", "secret_door": True, "side": "f_tile_green"},
    "]": {"door": "f_stencil2", "secret_door": True, "side": "f_tile"},
    "<": {"door": "f_vat", "remote": True, "tag": 2},
    ">": {"door": "f_alert", "remote": True, "tag": 3},
}

m = Map(64, 58, "%")
# ---- airlock (start)
m.box(26, 48, 36, 56, "%", ",")
m.rect(27, 52, 35, 52, "'")
m.put(31, 48, "D")
# ---- hub
m.box(20, 32, 42, 48, "#", ".")
m.put(31, 48, "D")
m.rect(29, 38, 33, 42, "n")
m.rect(30, 39, 32, 41, "n")
for (x, y) in [(20, 35), (20, 45), (42, 34), (42, 44), (24, 32), (38, 32), (24, 48), (38, 48)]:
    m.put(x, y, "|")
m.put(31, 32, "(")
m.put(20, 40, "D")
m.put(42, 38, "D")
# ---- west vat hall
m.box(2, 26, 20, 48, "%", ":")
m.put(20, 40, "D")
for x in (4, 8, 12, 16):
    m.rect(x, 29, x + 1, 30, "n")
    m.rect(x, 46, x + 1, 47, "n")
m.rect(3, 34, 19, 35, "~")
m.rect(11, 34, 12, 35, ":")
m.rect(8, 38, 14, 40, "9")
m.rect(10, 38, 12, 40, "J")
m.rect(8, 41, 14, 41, "8"); m.rect(8, 42, 14, 42, "7"); m.rect(8, 43, 14, 43, "1")
# vat hatches (monster closets)
m.box(3, 22, 19, 26, "%", "a")
for x in (7, 11, 15):
    m.vline(x, 22, 26, "%")
for x in (5, 9, 13, 17):
    m.put(x, 26, "<")
# secret behind a vat panel
m.box(7, 48, 13, 53, "#", "z")
m.put(10, 48, "[")
# ---- the endless corridor
m.rect(43, 37, 60, 39, ",")
m.rect(43, 38, 60, 38, "'")
m.put(42, 38, "D")
m.vline(61, 36, 40, "K")
for y in (37, 38, 39):
    m.put(60, y, "q")
m.put(44, 38, "Q")
for i, x0 in enumerate((44, 50, 56)):
    m.box(x0, 30, x0 + 5, 36, "%", "_")
    m.put(x0 + 2, 36, "D")
    m.put(x0 + 2, 30, "KGj"[i])
m.put(52, 30, "N")
m.box(61, 30, 63, 36, "%", "d")
m.vline(63, 30, 36, "%")
m.put(61, 33, "]")
for x in range(45, 60, 4):
    m.put(x, 40, "KGHj"[(x // 4) % 4])
# ---- overflow lab (behind the switch door)
m.box(43, 40, 61, 56, "%", "/")
m.put(51, 40, ">")
m.rect(46, 44, 49, 47, "`"); m.rect(55, 49, 58, 52, "`")
m.rect(52, 43, 53, 44, "n"); m.rect(46, 51, 47, 52, "n")
# ---- north wing: stairs up from the blue door
m.rect(30, 21, 32, 31, "^")
m.rect(30, 31, 32, 31, "u"); m.rect(30, 30, 32, 30, "-"); m.rect(30, 29, 32, 29, "=")
m.put(29, 25, "|"); m.put(33, 25, "|")
m.box(16, 6, 46, 21, "&", ";")
m.put(31, 21, "^")
m.rect(17, 11, 45, 11, "^"); m.rect(17, 16, 45, 16, "^")
for x in range(19, 44, 6):
    m.rect(x, 13, x + 2, 14, "&")
for (x, y) in [(16, 10), (16, 17), (46, 10), (46, 17)]:
    m.put(x, y, "F")
m.rect(19, 8, 21, 9, "?")
m.rect(17, 7, 18, 9, "P")
# exit: core shutdown room
m.box(26, 1, 36, 6, "v", "0")
m.put(31, 6, ")")
m.put(31, 1, "S")

# ================= entities
m.put(31, 54, "@")
m.put(28, 50, "e"); m.put(34, 50, "+"); m.put(30, 55, "i")
# hub
m.put(24, 36, "g"); m.put(38, 44, "g"); m.put(24, 44, "y"); m.put(38, 36, "p"); m.put(35, 46, "s"); m.put(27, 34, "s")
m.put(22, 46, "x"); m.put(40, 34, "x"); m.put(36, 34, "C"); m.put(22, 34, "h")
# vat hall
m.put(11, 39, "U")
m.put(5, 32, "g"); m.put(17, 32, "g"); m.put(6, 44, "b"); m.put(18, 42, "y"); m.put(4, 38, "s"); m.put(16, 38, "r")
for x in (5, 9, 13, 17):
    m.put(x, 24, "g")
m.put(9, 23, "r"); m.put(13, 23, "g"); m.put(5, 23, "r")
m.put(3, 27, "c"); m.put(19, 45, "e"); m.put(14, 27, "h")
m.put(10, 51, "M"); m.put(8, 49, "+"); m.put(12, 49, "+")
# corridor & unit rooms
m.put(50, 37, "g"); m.put(56, 39, "y"); m.put(47, 39, "s")
m.put(46, 33, "g"); m.put(53, 33, "b"); m.put(58, 33, "g"); m.put(59, 31, "s")
m.put(47, 31, "e"); m.put(51, 34, "+"); m.put(57, 34, "c")
m.put(62, 31, "V"); m.put(62, 35, "E")
# overflow lab
m.put(48, 46, "6"); m.put(47, 45, "E")
m.put(57, 50, "Y")
m.put(55, 45, "p"); m.put(45, 54, "p"); m.put(52, 49, "b"); m.put(58, 43, "k"); m.put(50, 54, "s"); m.put(59, 54, "s"); m.put(44, 42, "g")
m.put(60, 41, "h"); m.put(44, 49, "C"); m.put(53, 55, "O")
# north wing
m.put(31, 26, "g"); m.put(31, 23, "s")
m.put(20, 18, "k"); m.put(42, 8, "b"); m.put(25, 9, "p"); m.put(38, 19, "p"); m.put(34, 12, "g"); m.put(22, 15, "y")
m.put(44, 15, "y"); m.put(28, 18, "s"); m.put(40, 12, "s"); m.put(27, 7, "r")
m.put(17, 8, "B"); m.put(18, 7, "O")
m.put(45, 7, "h"); m.put(45, 20, "e"); m.put(18, 20, "C")
m.put(28, 3, "h"); m.put(34, 3, "E")

emit("level5_facility", {
    "name": "THE ENDLESS GORBINO FACILITY",
    "music": "facility", "ambience": "amb_facility", "sky": "",
    "fog": Color(0.55, 0.85, 0.65, 0.35), "fog_start": 10.0, "fog_end": 60.0,
    "light_boost": 1.45, "diminish": 0.026,
    "start_angle": 0.0, "par": 420,
    "wall": "f_tile", "side": "f_alert",
    "test_views": [[31, 50, 0, 0], [31, 44, 0, 0], [11, 44, 0, 10], [47, 38, -90, 0], [52, 34, 0, 10], [31, 19, 0, 0], [50, 48, -90, 0]],
}, L, m)
