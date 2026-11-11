"""Menu art.

  assets/ui/menu_pit.png   a seamless tile in the style of THE GORB PIT:
                           wavy bands of purple and magenta flesh with lime
                           streaks, and eyeballs staring out of it (scrolls
                           behind the title screen)

Run: python3 tools/gen_menu.py
"""
import os
import math
import numpy as np
from PIL import Image
from texlib import ROOT

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


if __name__ == "__main__":
    pit_tile()
