"""Level 3: THE GORBINO MINES."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from levelkit import Map, Color, emit


def cave(f, **kw):
    d = dict(floor=f, ceil=f + 4.5, ftex="m_dirt", ctex="m_rock2", light=0.38, side="m_rock", upper="m_rock")
    d.update(kw)
    return d


L = {
    "%": {"wall": "m_rock"},
    "#": {"wall": "m_rock2"},
    "&": {"wall": "m_crystal"},
    "|": {"wall": "m_beam"},
    "n": {"wall": "m_ore"},
    "K": {"wall": "m_sign"},
    "H": {"wall": "m_lantern"},
    "S": {"wall": "exit_panel", "use": "exit", "above": "m_rock"},
    ".": cave(0.0),
    ",": cave(0.0, ftex="m_rail", ceil=3.5, light=0.42),
    ":": cave(0.0, ftex="m_planks", ceil=4.0, light=0.5, ctex="m_planks"),
    "F": cave(0.0, ftex="m_planks", ceil=4.0, light=0.75, ctex="m_planks", flicker=2),
    ";": cave(0.0, ceil=7.0, light=0.5, flicker=2),
    "1": cave(0.5, ceil=7.0, light=0.5),
    "7": cave(1.0, ceil=7.0, light=0.5),
    "8": cave(1.5, ceil=7.0, light=0.55),
    "9": cave(2.0, ceil=7.0, light=0.6),
    "~": cave(-1.0, ceil=7.0, liquid="liq_magma", damage=10, light=0.9),
    "z": cave(0.0, ceil=7.0, secret=True, light=0.7),  # wade the magma and hop up
    "a": cave(0.0, ceil=3.0, secret=True, light=0.6, ftex="m_planks"),
    "_": cave(-0.5),
    "-": cave(-1.0),
    "v": cave(-1.5),
    "u": cave(-2.0, ceil=4.0),
    "J": cave(-1.5, ceil=4.0, ftex="m_planks", trigger=2, light=0.6),
    "j": cave(-2.0, ceil=2.0, light=0.25, flicker=1),
    "=": cave(-2.6, ceil=4.0, liquid="liq_magma", damage=10, light=0.9),
    "o": None,
    "d": cave(3.0, ceil=6.0, ftex="m_planks", ctex="m_planks", light=0.55),
    "P": cave(3.0, ceil=5.5, ftex="m_planks", ctex="m_planks", secret=True, light=0.8),
    "G": cave(0.0, ceil=6.0, ftex="m_planks", ctex="m_planks", light=0.45),
    "L": {"lift": True, "floor": 0.0, "top": 3.0, "ftex": "metal_floor", "side": "m_beam", "ceil": 6.0, "ctex": "m_planks", "light": 0.5},
    "N": {"lift": True, "floor": -2.0, "top": 0.0, "ftex": "metal_floor", "side": "m_beam", "ceil": 2.5, "ctex": "m_rock2", "light": 0.45},
    "D": {"door": "door_metal", "side": "m_beam"},
    "(": {"door": "door_red", "key": "red", "side": "m_beam"},
    ")": {"door": "door_yellow", "key": "yellow", "side": "m_beam"},
    "[": {"door": "m_rock", "secret_door": True, "side": "m_rock"},
    "<": {"door": "m_rock2", "remote": True, "tag": 2},
}
del L["o"]


def crystal_edges(m, floors, wall="&"):
    cells = [(x, y) for y in range(m.h) for x in range(m.w) if m.get(x, y) in floors]
    for (x, y) in cells:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 < nx < m.w - 1 and 0 < ny < m.h - 1 and m.get(nx, ny) in "%#":
                m.put(nx, ny, wall)


m = Map(60, 56, "%")
# ---- entrance hall (start)
m.box(1, 1, 13, 11, "#", ":")
m.rect(3, 5, 11, 7, "F")
for (x, y) in [(4, 1), (10, 1), (1, 6), (4, 11), (10, 11)]:
    m.put(x, y, "H")
for (x, y) in [(6, 3), (6, 9), (10, 3), (10, 9)]:
    m.put(x, y, "|")
m.put(13, 5, ","); m.put(13, 6, ",")
m.put(6, 11, "(")
# ---- rail tunnel A
m.rect(14, 5, 41, 6, ",")
for x in range(16, 41, 6):
    m.put(x, 4, "|"); m.put(x, 7, "|")
m.put(19, 4, "H"); m.put(31, 7, "H")
# secret rocket cave above the tunnel
m.rect(23, 1, 28, 3, "a")
m.put(25, 4, "[")
# ---- crystal cavern
m.rect(30, 7, 31, 11, ".")
m.rect(19, 12, 39, 28, ";")
m.rect(19, 12, 21, 14, "%"); m.rect(37, 12, 39, 13, "%")
m.rect(19, 26, 22, 28, "%"); m.rect(36, 27, 39, 28, "%")
m.rect(26, 17, 32, 23, "~")
m.rect(28, 19, 30, 21, "z")
m.rect(34, 14, 37, 17, "9")
m.rect(34, 18, 37, 18, "8"); m.rect(34, 19, 37, 19, "7"); m.rect(34, 20, 37, 20, "1")
m.rect(20, 18, 21, 22, "7")
crystal_edges(m, ";1789z~")
# ---- ore processing (north-east)
m.box(42, 1, 57, 20, "%", "G")
m.put(42, 5, "D"); m.put(41, 5, ","); m.put(41, 6, ",")
m.rect(46, 2, 56, 5, "d")
m.put(50, 6, "L")
m.put(57, 3, "[")
m.rect(58, 2, 58, 4, "P")
m.rect(44, 12, 46, 14, "n"); m.rect(52, 14, 54, 17, "n")
m.put(42, 10, "H"); m.put(57, 12, "H")
m.put(50, 20, "D")
# ---- rail tunnel B down to the yellow door
m.rect(50, 21, 51, 33, ",")
for y in (24, 29):
    m.put(49, y, "|"); m.put(52, y, "|")
m.put(50, 34, ")"); m.put(51, 34, ")")
# ---- deep shaft (behind the red door)
m.rect(3, 12, 10, 18, ".")
m.rect(3, 19, 10, 19, "_")
m.rect(3, 20, 10, 20, "-")
m.rect(3, 21, 10, 21, "v")
m.rect(3, 22, 16, 32, "u")
m.rect(11, 24, 12, 29, "=")
m.rect(4, 29, 7, 31, "J")
m.put(2, 16, "H"); m.put(11, 14, "H")
m.box(17, 23, 20, 31, "%", "j")
m.put(17, 25, "<"); m.put(17, 29, "<")
# lift shortcut and tunnel back east
m.rect(12, 33, 13, 40, "u")
m.put(12, 41, "N"); m.put(13, 41, "N")
m.rect(12, 42, 30, 43, ",")
m.rect(29, 30, 30, 41, ",")
m.rect(31, 30, 49, 31, ",")
m.rect(31, 28, 32, 29, ".")
for x in (18, 24, 36, 42):
    m.put(x, 41 if x < 29 else 29, "|")
# ---- exit cavern
m.rect(44, 35, 57, 53, ".")
m.rect(44, 35, 47, 38, "%"); m.rect(55, 35, 57, 37, "%")
m.rect(44, 48, 46, 53, "%"); m.rect(56, 50, 57, 53, "%")
m.rect(49, 41, 50, 42, "n"); m.rect(53, 45, 54, 47, "n")
m.put(50, 54, "S")
m.put(48, 54, "H"); m.put(52, 54, "H"); m.put(58, 44, "H")

# ================= entities
m.put(4, 6, "@")
m.put(3, 3, "i"); m.put(12, 9, "+")
# tunnel A
m.put(18, 6, "g"); m.put(27, 5, "s"); m.put(36, 6, "g"); m.put(39, 5, "s")
m.put(24, 2, "5"); m.put(26, 2, "o"); m.put(27, 3, "o")
m.put(33, 5, "c")
# crystal cavern
m.put(35, 15, "3"); m.put(36, 16, "c")
m.put(29, 20, "M")
m.put(24, 14, "p"); m.put(34, 25, "p")
m.put(22, 16, "g"); m.put(31, 14, "g"); m.put(24, 25, "r"); m.put(38, 23, "s"); m.put(28, 26, "s"); m.put(21, 20, "y")
m.put(23, 24, "h"); m.put(37, 22, "i"); m.put(32, 27, "+")
# ore processing
m.put(56, 3, "R")
m.put(48, 3, "y"); m.put(54, 4, "y")
m.put(45, 8, "g"); m.put(54, 9, "b"); m.put(48, 16, "g"); m.put(55, 18, "s"); m.put(44, 18, "r")
m.put(58, 3, "V")
m.put(43, 2, "C"); m.put(47, 19, "h"); m.put(56, 19, "x"); m.put(43, 16, "x")
# tunnel B
m.put(50, 25, "s"); m.put(51, 30, "g")
# deep shaft
m.put(5, 14, "g"); m.put(9, 16, "s"); m.put(4, 21, "r"); m.put(14, 23, "g"); m.put(15, 31, "y"); m.put(9, 27, "s")
m.put(5, 30, "Y")
m.put(18, 24, "r"); m.put(19, 26, "g"); m.put(18, 28, "r"); m.put(19, 30, "g")
m.put(14, 26, "h"); m.put(3, 23, "C"); m.put(8, 22, "+")
# shortcut tunnel
m.put(20, 42, "s"); m.put(29, 36, "g"); m.put(40, 30, "s"); m.put(46, 31, "y")
m.put(25, 43, "i"); m.put(30, 33, "+")
# exit cavern
m.put(51, 46, "k")
m.put(48, 40, "g"); m.put(55, 41, "g"); m.put(47, 45, "s"); m.put(54, 50, "s"); m.put(49, 51, "r")
m.put(56, 39, "o"); m.put(45, 41, "h"); m.put(52, 39, "C"); m.put(48, 50, "x"); m.put(55, 48, "x")

emit("level3_mines", {
    "name": "THE GORBINO MINES",
    "music": "mines", "ambience": "amb_mines", "sky": "",
    "fog": Color(0.05, 0.02, 0.06, 1.0), "fog_start": 8.0, "fog_end": 40.0,
    "light_boost": 1.7, "diminish": 0.04,
    "start_angle": -90.0, "par": 230,
    "wall": "m_rock", "side": "m_rock", "lamp_color": Color(1.0, 0.7, 0.3),
    "test_views": [[4, 6, -90, 0], [26, 13, 180, 0], [35, 21, 0, 10], [50, 8, 0, 15], [6, 20, 180, -10], [51, 42, 180, 0]],
}, L, m)
