"""ENDLESS arena: THE GORB PIT.

A sunken pit in the middle, a wide ring round it, raised platforms in the
corners, pillars to duck behind, and four alcoves in the walls the waves come
out of. Open to a purple void sky.
"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from levelkit import Map, Color, emit


def out(f, **kw):
    d = dict(floor=f, ceil=26.0, ctex="SKY", ftex="d_checker", light=0.9, side="d_meat")
    d.update(kw)
    return d


L = {
    "%": {"wall": "d_flesh"},
    "#": {"wall": "d_glyph"},
    "n": {"wall": "d_eyes"},
    "G": {"wall": "d_snirbface"},
    ".": out(0.0),
    ",": out(-1.0, ftex="d_meat", light=0.8),
    "_": out(-0.5, ftex="d_teeth", light=0.85),
    "1": out(1.0, ftex="d_swirl", light=1.0),
    "u": out(0.5, ftex="d_checker", light=0.95),
    "a": dict(floor=0.0, ceil=4.0, ftex="d_ooze", ctex="d_flesh", light=1.0, flicker=2, side="d_meat", upper="d_flesh"),
}

W = H = 36
m = Map(W, H, "%")
m.rect(4, 4, 31, 31, ".")
# the pit
m.rect(11, 11, 24, 24, "_")
m.rect(12, 12, 23, 23, ",")
# raised corner platforms, stepped on their inner sides
for (x, y, sx, sy) in [(4, 4, 1, 1), (28, 4, -1, 1), (4, 28, 1, -1), (28, 28, -1, -1)]:
    m.rect(x, y, x + 3, y + 3, "1")
    ex = x + 4 if sx > 0 else x - 1
    ey = y + 4 if sy > 0 else y - 1
    m.rect(min(x, x + 3), ey, max(x, x + 3), ey, "u")
    m.rect(ex, min(y, y + 3), ex, max(y, y + 3), "u")
    m.put(ex, ey, "u")
# pillars on the ring, and a couple of slabs in the pit
for (x, y) in [(8, 13), (26, 21), (13, 8), (21, 26)]:
    m.rect(x, y, x + 1, y + 1, "#")
for (x, y) in [(15, 15), (20, 20)]:
    m.put(x, y, "n")
# decorations on the outer walls
for x in range(6, 30, 6):
    m.put(x, 3, "G")
    m.put(x, 32, "G")
# the four alcoves the waves pour out of
m.rect(16, 1, 19, 3, "a")
m.rect(16, 32, 19, 34, "a")
m.rect(1, 16, 3, 19, "a")
m.rect(32, 16, 34, 19, "a")

m.put(17, 28, "@")

emit("endless_pit", {
    "name": "THE GORB PIT",
    "music": "boss", "ambience": "amb_dimension", "sky": "sky_void",
    "fog": Color(0.4, 0.0, 0.45, 0.35), "fog_start": 22.0, "fog_end": 90.0,
    "light_boost": 1.4, "diminish": 0.012,
    "start_angle": 0.0, "par": 0,
    "wall": "d_flesh", "side": "d_meat", "tree_tex": "d_flesh",
    "endless": True,
    "endless_spawns": [[17, 2], [18, 33], [2, 17], [33, 18], [6, 6], [29, 6], [6, 29], [29, 29]],
    "test_views": [[17, 28, 0, 0]],
}, L, m)
