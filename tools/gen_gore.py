"""Textures for the knife arm, the gutting finisher and the ammo beacons.

  sleeve                                 the offhand arm's sleeve
  gore_wound                             the slit that opens in a gutted creature
  gore_guts, gore_organ                  what spills out of it
  bali_blade, bali_handle, bali_eye      the butterfly knife: oily blade, fleshy
                                         skeleton handles with teeth, eyeball latch

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


def balisong():
    # blade: oily dark steel with an iridescent sheen, rust bloom and an etched eye
    W, H = 64, 16
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    n = value_noise(64, 16, 741, 3)[:H, :]
    base = 0.32 + n * 0.2
    hue = (xx / W * 1.7 + yy / H * 0.6 + n) % 1.0
    sheen = np.stack([0.5 + 0.5 * np.cos(2 * np.pi * (hue + k / 3.0)) for k in range(3)], -1)
    a = base[..., None] * (0.75 + 0.5 * sheen)
    a[yy < 2] = np.array([0.95, 0.95, 0.9])                 # honed edge
    rust = value_noise(64, 6, 742, 3)[:H, :] > 0.62
    a[rust] = a[rust] * 0.35 + np.array([0.45, 0.12, 0.04]) * 0.65
    ex, ey = 18.0, 8.0                                      # the etched eye
    d = np.hypot((xx - ex) / 6.0, (yy - ey) / 3.2)
    a[(d > 0.8) & (d < 1.05)] = np.array([0.08, 0.06, 0.06])
    a[np.hypot(xx - ex, yy - ey) < 1.6] = np.array([0.6, 0.0, 0.05])
    save("bali_blade", a)
    # handles: gunmetal skeleton, raw meat showing through three slots, teeth on the spine
    W, H = 64, 16
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    n = value_noise(64, 10, 751, 3)[:H, :]
    a = np.stack([0.16 + n * 0.1] * 3, -1)
    for cx in (12, 32, 52):
        d = np.hypot((xx - cx) / 7.0, (yy - 8.5) / 4.0)
        meat = d < 1.0
        a[meat] = np.stack([0.55 + n * 0.3, 0.12 + n * 0.1, 0.16 + n * 0.1], -1)[meat]
        a[(d >= 1.0) & (d < 1.2)] = np.array([0.05, 0.04, 0.04])
    teeth = (yy < 3) & ((xx.astype(int) % 6) < 3)
    a[teeth] = np.array([0.92, 0.88, 0.72])
    save("bali_handle", a)
    # eyeball latch
    S = 32
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
    d = np.hypot(xx - 15.5, yy - 15.5) / 16.0
    a = gradmap(np.clip(d, 0, 1), [(0, (20, 0, 0)), (0.18, (20, 0, 0)), (0.2, (150, 20, 10)), (0.38, (230, 140, 30)),
                                   (0.42, (240, 235, 220)), (0.9, (225, 205, 195)), (1, (180, 90, 90))])
    w1, w2, _ = worley(32, 10, 761)
    vein = ((w2 - w1) < 0.8) & (d > 0.5)
    a[vein] = np.array([0.7, 0.08, 0.1])
    a[np.hypot(xx - 11, yy - 11) < 2.2] = 1.0
    save("bali_eye", a)


if __name__ == "__main__":
    knife()
    wound()
    guts()
    balisong()
