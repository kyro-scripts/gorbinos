"""Textures for the knife arm, the gutting finisher and the ammo beacons.

  knife_blade, knife_handle, sleeve       the offhand arm and its knife
  gore_wound                             the slit that opens in a gutted creature
  gore_guts, gore_organ                  what spills out of it
  beacon                                 ring / marker glow over ammo pickups

Run: python3 tools/gen_gore.py
"""
import os
import numpy as np
from PIL import Image, ImageFilter
from texlib import value_noise, worley, gradmap, rng, ROOT

OUT = os.path.join(ROOT, "assets", "textures")


def to_img(a):
    return Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))


def save(name, a):
    to_img(a).save(os.path.join(OUT, name + ".png"))
    print("wrote", name)


def knife():
    # blade: brushed steel along the length, bright cutting edge, a little rust
    W, H = 64, 16
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    streak = value_noise(64, 32, 701, 2)[:H, :] * 0.25
    base = 0.55 + streak + (yy / H) * 0.15
    a = np.stack([base * 0.92, base * 0.95, base], -1)
    a[yy < 2] = np.array([0.95, 0.97, 1.0])          # edge
    a[(yy >= 2) & (yy < 4)] *= 1.15
    rust = value_noise(64, 8, 702, 3)[:H, :] > 0.68
    a[rust] = a[rust] * 0.5 + np.array([0.35, 0.12, 0.05]) * 0.5
    save("knife_blade", a)
    # handle: dark cord wrap
    W, H = 32, 32
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    wrap = (np.sin((xx + yy * 0.6) * 1.1) * 0.5 + 0.5) ** 2
    a = gradmap(wrap, [(0, (12, 10, 10)), (0.7, (50, 40, 36)), (1, (95, 80, 70))])
    save("knife_handle", a)
    # sleeve: grimy olive canvas
    n = value_noise(64, 8, 703, 4)
    w1, w2, _ = worley(64, 30, 704)
    t = 0.5 + (n - 0.5) * 0.6 - ((w2 - w1) < 1.2) * 0.15
    a = gradmap(np.clip(t, 0, 1), [(0, (25, 28, 15)), (0.5, (58, 62, 34)), (1, (95, 95, 60))])
    yy = np.mgrid[0:64, 0:64][0]
    a[(yy % 16) == 0] *= 0.55                          # seams
    save("sleeve", a)


def wound():
    W, H = 64, 32
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    nx, ny = (xx - 31.5) / 31.5, (yy - 15.5) / 15.5
    n = value_noise(64, 10, 711, 3)[:H, :]
    d = np.hypot(nx, ny * (1.0 + 0.35 * np.abs(nx))) + (n - 0.5) * 0.35
    a = gradmap(np.clip(d, 0, 1.2) / 1.2, [(0, (10, 0, 2)), (0.35, (45, 0, 6)), (0.55, (150, 10, 20)),
                                            (0.7, (230, 70, 80)), (0.82, (120, 15, 25)), (1, (60, 5, 10))])
    # glistening flecks on the lips of the cut
    r = rng(712)
    glint = (r.random((H, W)) > 0.93) & (d > 0.5) & (d < 0.8)
    a[glint] = np.array([1.0, 0.8, 0.8])
    save("gore_wound", a)


def guts():
    W, H = 64, 32
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    n = value_noise(64, 12, 721, 4)[:H, :]
    folds = np.sin(xx * 0.55 + n * 4.0) * 0.5 + 0.5
    t = 0.35 + folds * 0.4 + (n - 0.5) * 0.3
    a = gradmap(np.clip(t, 0, 1), [(0, (90, 15, 30)), (0.45, (190, 70, 90)), (0.75, (235, 140, 150)), (1, (255, 205, 205))])
    # veins
    w1, w2, _ = worley(64, 18, 722)
    v = ((w2 - w1) < 1.0)[:H, :]
    a[v] = a[v] * 0.45 + np.array([0.35, 0.05, 0.25]) * 0.55
    save("gore_guts", a)
    n2 = value_noise(64, 6, 731, 4)
    w1, w2, _ = worley(64, 25, 732)
    t = 0.45 + (n2 - 0.5) * 0.6 - ((w2 - w1) < 1.5) * 0.2
    a = gradmap(np.clip(t, 0, 1), [(0, (35, 0, 10)), (0.5, (110, 10, 35)), (1, (190, 60, 80))])
    save("gore_organ", a)


def beacon():
    # soft ring for the floor under ammo; the shader's alpha cut keeps the edge crisp
    S = 64
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
    d = np.hypot(xx - 31.5, yy - 31.5) / 32.0
    ring = np.exp(-((d - 0.78) / 0.09) ** 2)
    a = np.stack([ring, ring, ring, (ring > 0.35).astype(np.float32)], -1)
    Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, "beacon.png"))
    print("wrote beacon")


if __name__ == "__main__":
    knife()
    wound()
    guts()
    beacon()
