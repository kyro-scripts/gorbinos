"""Menu art.

  assets/ui/menu_pit.png   a seamless tile in the style of THE GORB PIT:
                           wavy bands of purple and magenta flesh with lime
                           streaks, and eyeballs staring out of it (scrolls
                           behind the title screen)
  assets/ui/fish_tile.png  a seamless tile of pale, glossy trout skin (the
                           menu buttons are cut from it)

Run: python3 tools/gen_menu.py
"""
import os
import math
import numpy as np
from PIL import Image
from texlib import ROOT
from gen_hyperreal import smooth, mix, normals, light

UI_OUT = os.path.join(ROOT, "assets", "ui")


def periodic_noise(n, seed, terms=10, max_f=4):
    """Smooth noise that wraps seamlessly on an n x n tile."""
    r = np.random.default_rng(seed)
    y, x = np.mgrid[0:n, 0:n].astype(np.float32) / n * math.tau
    out = np.zeros((n, n), np.float32)
    for _ in range(terms):
        fx, fy = r.integers(-max_f, max_f + 1, 2)
        if fx == 0 and fy == 0:
            fx = 1
        out += math.sqrt(1.0 / (fx * fx + fy * fy)) * np.sin(fx * x + fy * y + r.uniform(0, math.tau))
    out -= out.min()
    return out / (out.max() + 1e-6)


def pit_tile(seed=3):
    N = 128
    y, x = np.mgrid[0:N, 0:N].astype(np.float32) / N * math.tau
    # wavy diagonal bands, warped
    f = np.sin(2 * x + y + 1.3 * np.sin(2 * y + 0.5) + 0.8 * np.sin(3 * (x - y)))
    f += 0.35 * (periodic_noise(N, seed, 12, 5) - 0.5)
    palette = [
        (-1.0, (0.16, 0.03, 0.26)),
        (-0.45, (0.42, 0.08, 0.5)),
        (-0.05, (0.72, 0.14, 0.58)),
        (0.3, (0.5, 0.18, 0.72)),
        (0.62, (0.85, 0.95, 0.22)),     # the lime streak
        (0.72, (0.3, 0.06, 0.42)),
    ]
    rgb = np.zeros((N, N, 3), np.float32)
    for th, col in palette:
        rgb[f >= th] = col
    # a little dither speckle, like the level textures
    sp = np.random.default_rng(seed + 1).random((N, N))
    rgb *= (0.92 + 0.12 * (sp > 0.5))[..., None]
    # eyeballs, wrapping round the tile edges
    r = np.random.default_rng(seed + 2)
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
    eyes = [(18, 22, 7), (78, 14, 6), (50, 58, 8), (108, 70, 6), (22, 96, 6), (86, 108, 7)]
    for ex, ey, rad in eyes:
        dx = (xx - ex + N / 2) % N - N / 2
        dy = (yy - ey + N / 2) % N - N / 2
        d = np.sqrt(dx * dx + dy * dy)
        look = (r.uniform(-1.5, 1.5), r.uniform(-1.5, 1.5))
        di = np.sqrt((dx - look[0]) ** 2 + (dy - look[1]) ** 2)
        rgb[d < rad + 1.2] = (0.12, 0.02, 0.1)                 # dark lid line
        rgb[d < rad] = (0.96, 0.93, 0.8)                        # the white
        rgb[(d < rad) & (d > rad - 1.2) & (dy > 1)] = (0.85, 0.72, 0.68)
        rgb[di < rad * 0.55] = (0.15, 0.62, 0.45)               # green iris
        rgb[di < rad * 0.25] = (0.03, 0.02, 0.03)               # pupil
        rgb[(np.abs(dx - look[0] + rad * 0.2) < 1) & (np.abs(dy - look[1] + rad * 0.2) < 1)] = (1, 1, 1)
    img = Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8), "RGB")
    img.save(os.path.join(UI_OUT, "menu_pit.png"))
    print("wrote menu_pit", img.size)


def fish_tile(seed=9):
    N = 512                 # rendered at 2x, saved at 256
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
    # overlapping round scales on a staggered grid (period divides the tile)
    sc = 32.0
    i0 = np.floor(xx / sc)
    arc = np.full((N, N), 2.0, np.float32)
    for ic in (i0 + 1, i0):
        off = np.mod(ic, 2) * 0.5
        jc = np.round(yy / sc - off)
        dmin = np.full((N, N), 9.0, np.float32)
        for dj in (-1, 0, 1):
            cy = (jc + dj + off) * sc
            dmin = np.minimum(dmin, np.sqrt((xx - ic * sc) ** 2 + (yy - cy) ** 2) / (sc * 0.82))
        arc = np.where(arc < 1.0, arc, dmin)
    pn = periodic_noise(N, seed, 14, 6)
    hf = np.clip(1 - arc, 0, 1) ** 0.7 * 2.4 + 1.0 * pn
    n = normals(hf, 1.0, 1.0)
    # pale trout skin: silver and pearl, washes of pink, a hint of olive
    field = periodic_noise(N, seed + 1, 8, 2)
    alb = mix(np.array([0.8, 0.82, 0.78]), np.array([0.93, 0.92, 0.88]), pn)
    alb = mix(alb, np.array([0.88, 0.5, 0.56]), smooth(0.55, 0.85, field) * 0.6)
    alb = mix(alb, np.array([0.55, 0.6, 0.42]), smooth(0.25, 0.05, field) * 0.5)
    alb = mix(alb, alb * 0.8, smooth(0.75, 1.0, arc) * 0.45)
    r = np.random.default_rng(seed + 2)
    spots = np.zeros((N, N), np.float32)
    for _ in range(36):
        sx, sy, rad = r.uniform(0, N), r.uniform(0, N), r.uniform(5, 10)
        dx = (xx - sx + N / 2) % N - N / 2
        dy = (yy - sy + N / 2) % N - N / 2
        spots = np.maximum(spots, smooth(rad, rad * 0.5, np.sqrt(dx * dx + dy * dy)))
    alb = mix(alb, np.array([0.08, 0.07, 0.07]), spots * 0.85)
    rgb = light(n, alb, wrap=0.3, ambient=0.3, spec=0.7, power=26, spec_map=0.5 + 0.6 * periodic_noise(N, seed + 3, 16, 12))
    hue = np.stack([0.5 + 0.5 * np.sin(xx / N * math.tau * 2 + 0), 0.5 + 0.5 * np.sin(xx / N * math.tau * 2 + 2),
                    0.5 + 0.5 * np.sin(xx / N * math.tau * 2 + 4)], -1)
    rgb = rgb + (hue - 0.5) * 0.06
    img = Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8), "RGB").resize((256, 256), Image.LANCZOS)
    img.save(os.path.join(UI_OUT, "fish_tile.png"))
    print("wrote fish_tile", img.size)


if __name__ == "__main__":
    pit_tile()
    fish_tile()
