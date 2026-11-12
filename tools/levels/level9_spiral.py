"""Episode 2, level 3: SPIRAL OF TEETH.

A square spiral of a corridor, three wide, winding inward twice round and
stepping down half a metre every stretch, walled in bone with teeth at the
corners, until it lets out into a big sunken arena in the middle (pillars,
a raised altar, the exit). Graded to bile green and black.
"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from levelkit import Map, Color, emit

N = 46
RINGS = 2
m = Map(N, N, "%")
HCH = list(".,;:7890^-_=|/")


def room(floor, ftex="fv_tile_w", light=0.75, ceil_h=3.5, **kw):
    d = dict(floor=floor, ceil=floor + ceil_h, ftex=ftex, ctex="fv_ceil", light=light, side="d_teeth", upper="fv_bone")
    d.update(kw)
    return d


L = {
    "%": {"wall": "fv_bone"},
    "n": {"wall": "d_teeth"},
    "#": {"wall": "fv_glow_c"},
    "K": {"wall": "fv_sign_down"},
    "G": {"wall": "fv_sign_gorb"},
}
for i, ch in enumerate(HCH):
    L[ch] = room(-0.5 * i, "fv_tile_w" if i % 2 == 0 else "fv_check", 0.65 + 0.12 * (i % 3), flicker=2 if i % 4 == 3 else 0)

# the centre line of the spiral, ring by ring
path = []
x, y = 3, 3
for r in range(RINGS):
    lo, hi = 3 + 4 * r, N - 4 - 4 * r
    legs = [((1, 0), hi - x), ((0, 1), hi - y), ((-1, 0), None), ((0, -1), None)]
    for dx, dy in [(1, 0), (0, 1), (-1, 0), (0, -1)]:
        if (dx, dy) == (1, 0):
            n = hi - x
        elif (dx, dy) == (0, 1):
            n = hi - y
        elif (dx, dy) == (-1, 0):
            n = x - lo
        else:
            n = y - (lo + 4)
        for k in range(n):
            path.append((x, y))
            x += dx
            y += dy
path.append((x, y))

STRETCH = len(path) // (len(HCH) - 2) + 1
level_of = {}
for i, (px, py) in enumerate(path):
    lv = min(i // STRETCH, len(HCH) - 2)
    for oy in (-1, 0, 1):
        for ox in (-1, 0, 1):
            c = (px + ox, py + oy)
            level_of[c] = min(level_of.get(c, 99), lv)
for (cx, cy), lv in level_of.items():
    m.put(cx, cy, HCH[lv])
last_lv = level_of[path[-1]]

# the arena, one step below the end of the spiral, through a gap in the wall
alv = last_lv + 1
inner = 3 + 4 * RINGS          # centre line the next ring would have had
# the last ring's corridor ends 2 cells short of that line; one wall cell, then arena
ax0 = ay0 = inner - 1
ax1 = ay1 = N - inner
L["a"] = room(-0.5 * alv, "fv_check", 0.9, ceil_h=7.0)
L["j"] = room(-0.5 * alv + 0.5, "d_meat", 1.0, ceil_h=6.5)
L["v"] = dict(L["a"], trigger=6)
m.rect(ax0, ay0, ax1, ay1, "a")
ex, ey = path[-1]
for oy in (-1, 0, 1):
    m.put(ex + 2, ey + oy, HCH[last_lv])
assert m.get(ex + 3, ey) == "a", "arena gap doesn't reach the arena"
print("path", len(path), "stretch", STRETCH, "levels", last_lv, "arena", (ax0, ay0, ax1, ay1), "end", path[-1])

# teeth at every turn, lit panels and signs along the way
for i in range(1, len(path) - 1):
    (x0, y0), (x1, y1), (x2, y2) = path[i - 1], path[i], path[i + 1]
    if (x1 - x0, y1 - y0) != (x2 - x1, y2 - y1):
        ox = x1 + (x1 - x0) * 2 - (x2 - x1) * 2
        oy = y1 + (y1 - y0) * 2 - (y2 - y1) * 2
        if 0 < ox < N - 1 and 0 < oy < N - 1 and m.get(ox, oy) == "%":
            m.put(ox, oy, "n")
for k, i in enumerate(range(12, len(path) - 6, 19)):
    (x1, y1), (x2, y2) = path[i], path[i + 1]
    dx, dy = x2 - x1, y2 - y1
    for side in (1, -1):
        sx, sy = x1 - dy * 2 * side, y1 + dx * 2 * side
        if 0 < sx < N - 1 and 0 < sy < N - 1 and m.get(sx, sy) == "%":
            m.put(sx, sy, "K" if k % 4 == 1 and side == 1 else "#")
            break

# arena: four pillars, a raised altar in the middle that springs the trap
cx, cy = (ax0 + ax1) // 2, (ay0 + ay1) // 2
for (px, py) in [(ax0 + 4, ay0 + 4), (ax1 - 5, ay0 + 4), (ax0 + 4, ay1 - 5), (ax1 - 5, ay1 - 5)]:
    m.rect(px, py, px + 1, py + 1, "n")
m.rect(cx - 2, cy - 2, cx + 2, cy + 2, "j")
m.rect(cx - 1, cy - 1, cx + 1, cy + 1, "v")
L["v"] = dict(L["j"], trigger=6)

# ================= entities
m.put(3, 3, "@")
m.put(5, 2, "c"); m.put(5, 4, "i"); m.put(2, 4, "+")


def along(i):
    return path[min(max(i, 0), len(path) - 1)]


def put_at(i, ch, off=0):
    (x1, y1), (x2, y2) = along(i), along(i + 1)
    dx, dy = x2 - x1, y2 - y1
    px, py = x1 - dy * off, y1 + dx * off
    if m.get(px, py) in HCH:
        m.put(px, py, ch)


roster = "gysg$ygrsgyp$gsrgyk"
for k, i in enumerate(range(14, len(path) - 8, 11)):
    put_at(i, roster[k % len(roster)], [0, 1, -1][k % 3])
for k, i in enumerate(range(20, len(path) - 8, 27)):
    put_at(i, "cihc+iC"[k % 7], [1, -1][k % 2])
put_at(len(path) // 3, "6", 0)
put_at(len(path) * 2 // 3, "B", 1)
# the arena: a welcoming party, more on the altar trap
for (px, py, ch) in [(ax0 + 2, ay0 + 2, "r"), (ax1 - 2, ay0 + 2, "y"), (ax0 + 2, ay1 - 2, "g"), (ax1 - 2, ay1 - 2, "p"),
                     (cx, ay0 + 2, "s"), (cx, ay1 - 2, "k")]:
    m.put(px, py, ch)
m.put(cx, cy, "M")
m.put(ax0 + 1, cy, "C"); m.put(ax1 - 1, cy, "E")
m.put(ax1 - 1, ay1 - 1, "X")
m.put(ax1 - 2, ay1 - 1, "+")

emit("level9_spiral", {
    "name": "SPIRAL OF TEETH",
    "music": "fever3", "ambience": "amb_mines", "sky": "",
    "fog": Color(0.05, 0.18, 0.04, 0.5), "fog_start": 10.0, "fog_end": 48.0,
    "light_boost": 1.7, "diminish": 0.025,
    "start_angle": -90.0, "par": 130,
    "wall": "fv_bone", "side": "d_teeth",
    "grade": [Color(0.0, 0.07, 0.03), Color(0.85, 1.0, 0.45), 0.55], "warp": 0.3,
    "wall_fish": 4,
    "test_views": [[3, 3, -90, 0], [42, 20, 180, 0], [20, 42, 90, 0], [7, 20, 0, 0], [20, 7, -90, 0], [22, 22, 0, 0]],
}, L, m)
