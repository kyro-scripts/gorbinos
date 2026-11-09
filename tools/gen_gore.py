"""Textures for the gutting finisher and the butterfly knife.

  gore_wound                             the slit that opens in a gutted creature
  gore_guts, gore_organ                  what spills out of it
  cs_blade, cs_flesh, cs_tumor           the butterfly knife: crunchy over-processed
                                         chrome, lurid meat handles, a green growth

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


def photo(a, seed, grain=0.08, block=2, sat=1.6, sharpen=220):
    """Crude 'ripped photo' look: saturation pushed, grain, blocky
    compression smear and a harsh sharpen."""
    a = np.clip(np.asarray(a, np.float32), 0, 1)
    grey = a.mean(-1, keepdims=True)
    a = np.clip(grey + (a - grey) * sat, 0, 1)
    a = a + (rng(seed).random(a.shape[:2])[..., None] - 0.5) * grain
    im = to_img(a)
    w, h = im.size
    if block > 1:
        im = im.resize((max(1, w // block), max(1, h // block)), Image.BILINEAR).resize((w, h), Image.NEAREST)
    return im.filter(ImageFilter.UnsharpMask(radius=1.2, percent=sharpen, threshold=0))


def cs_knife():
    # blade: cheap chrome, teal-tinted, deep scratches, rust and old blood
    W, H = 64, 16
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    n = value_noise(64, 16, 771, 3)[:H, :]
    streak = value_noise(64, 32, 772, 2)[:H, :]
    t = np.clip(0.35 + streak * 0.5 + (yy / H - 0.5) * 0.4 + (n - 0.5) * 0.3, 0, 1)
    a = gradmap(t, [(0, (20, 45, 50)), (0.4, (90, 150, 150)), (0.7, (210, 235, 225)), (1, (255, 255, 200))])
    r = rng(773)
    for k in range(10):                                   # scratches
        x0 = r.integers(0, W)
        y0 = r.integers(0, H)
        ln = r.integers(6, 20)
        for j in range(ln):
            x = (x0 + j) % W
            y = int(np.clip(y0 + j * r.uniform(-0.3, 0.3), 0, H - 1))
            a[y, x] = np.array([0.05, 0.08, 0.08])
    rust = value_noise(64, 6, 774, 3)[:H, :] > 0.64
    a[rust] = a[rust] * 0.3 + np.array([0.6, 0.25, 0.05]) * 0.7
    blood = value_noise(64, 8, 775, 3)[:H, :] > 0.7
    a[blood & (yy > H * 0.4)] = np.array([0.45, 0.0, 0.03])
    a[yy < 2] = np.array([1.0, 1.0, 0.95])                # edge
    photo(a, 776, sat=1.5).save(os.path.join(OUT, "cs_blade.png"))
    print("wrote cs_blade")
    # handles: raw lurid meat, purple veins, yellow fat
    S = 32
    n = value_noise(S, 6, 781, 4)
    w1, w2, _ = worley(S, 14, 782)
    t = np.clip(0.45 + (n - 0.5) * 0.8, 0, 1)
    a = gradmap(t, [(0, (90, 0, 30)), (0.45, (230, 40, 90)), (0.75, (255, 120, 150)), (1, (255, 220, 120))])
    a[(w2 - w1) < 0.9] = np.array([0.35, 0.05, 0.4])
    photo(a, 783, sat=1.7).save(os.path.join(OUT, "cs_flesh.png"))
    print("wrote cs_flesh")
    # a growth on the pin: acid green with dark pocks
    n = value_noise(S, 5, 791, 4)
    w1, w2, _ = worley(S, 10, 792)
    a = gradmap(np.clip(n, 0, 1), [(0, (30, 80, 0)), (0.5, (150, 230, 20)), (1, (240, 255, 120))])
    a[w1 < 2.0] = np.array([0.1, 0.15, 0.0])
    photo(a, 793, sat=1.6).save(os.path.join(OUT, "cs_tumor.png"))
    print("wrote cs_tumor")


if __name__ == "__main__":
    wound()
    guts()
    cs_knife()
