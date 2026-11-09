"""Textures for the organ trader who turns up somewhere in every level.

  shop_face    heavy-lidded, bloodshot, stubbled, grinning
  shop_shirt   a loud shirt
  shop_sign    hand-painted ORGANS board for his stall
  shop_cloth   the grubby cloth over his table

Run: python3 tools/gen_shop.py
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from texlib import value_noise, worley, gradmap, rng, font, ROOT

OUT = os.path.join(ROOT, "assets", "textures")


def save(name, im):
    im.save(os.path.join(OUT, name + ".png"))
    print("wrote", name)


def crunch(im, seed, block=2, sat=1.5, grain=0.06):
    a = np.asarray(im).astype(np.float32) / 255.0
    g = a.mean(-1, keepdims=True)
    a = np.clip(g + (a - g) * sat, 0, 1)
    a = a + (rng(seed).random(a.shape[:2])[..., None] - 0.5) * grain
    im = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))
    w, h = im.size
    im = im.resize((w // block, h // block), Image.BILINEAR).resize((w, h), Image.NEAREST)
    return im.filter(ImageFilter.UnsharpMask(radius=1.0, percent=180, threshold=0))


def face():
    S = 64
    n = value_noise(S, 6, 1101, 4)
    skin = gradmap(np.clip(0.45 + (n - 0.5) * 0.5, 0, 1), [(0, (120, 130, 95)), (0.5, (175, 180, 140)), (1, (215, 210, 170))])
    im = Image.fromarray((skin * 255).astype(np.uint8))
    d = ImageDraw.Draw(im)
    # bags under the eyes
    for cx in (20, 44):
        d.ellipse([cx - 10, 26, cx + 10, 38], fill=(110, 95, 110))
    # bloodshot eyes, lids almost shut
    for cx in (20, 44):
        d.ellipse([cx - 9, 21, cx + 9, 33], fill=(235, 150, 140))
        d.ellipse([cx - 4, 24, cx + 4, 32], fill=(150, 30, 20))
        d.ellipse([cx - 2, 26, cx + 2, 30], fill=(15, 5, 5))
        d.rectangle([cx - 10, 17, cx + 10, 26], fill=(150, 150, 110))     # heavy lid
        d.line([cx - 10, 26, cx + 10, 26], fill=(60, 40, 40), width=1)
        d.line([cx - 8, 30, cx - 3, 28], fill=(200, 20, 20))
        d.line([cx + 8, 29, cx + 3, 31], fill=(200, 20, 20))
    # eyebrows, nose, lopsided grin with yellow teeth
    d.line([10, 15, 28, 18], fill=(50, 40, 30), width=2)
    d.line([36, 17, 54, 14], fill=(50, 40, 30), width=2)
    d.polygon([(30, 30), (36, 30), (38, 42), (28, 42)], fill=(160, 140, 105))
    d.line([18, 50, 30, 54, 48, 47], fill=(70, 20, 20), width=4)
    for x in range(22, 44, 4):
        d.rectangle([x, 50 - (x - 22) // 8, x + 2, 52 - (x - 22) // 8], fill=(220, 200, 90))
    # stubble
    a = np.asarray(im).astype(np.float32) / 255.0
    r = rng(1102)
    yy, xx = np.mgrid[0:S, 0:S]
    stub = (r.random((S, S)) > 0.55) & (yy > 44)
    a[stub] *= 0.6
    save("shop_face", crunch(Image.fromarray((a * 255).astype(np.uint8)), 1103))


def shirt():
    S = 64
    base = np.zeros((S, S, 3), np.float32) + np.array([0.35, 0.05, 0.45])
    im = Image.fromarray((base * 255).astype(np.uint8))
    d = ImageDraw.Draw(im)
    r = rng(1111)
    for k in range(14):
        cx, cy = r.integers(0, S), r.integers(0, S)
        col = [(255, 220, 0), (0, 255, 160), (255, 90, 0), (120, 255, 40)][k % 4]
        for j in range(5):
            a = j * 2 * np.pi / 5
            px, py = cx + np.cos(a) * 5, cy + np.sin(a) * 5
            d.ellipse([px - 3, py - 3, px + 3, py + 3], fill=col)
        d.ellipse([cx - 2, cy - 2, cx + 2, cy + 2], fill=(255, 0, 120))
    for k in range(6):
        x = r.integers(0, S)
        d.line([x, 0, x + r.integers(-20, 20), S], fill=(20, 120, 30), width=2)
    save("shop_shirt", crunch(im, 1112, block=1, sat=1.3))


def sign():
    W, H = 128, 32
    n = value_noise(128, 8, 1121, 3)[:H, :]
    wood = gradmap(np.clip(n, 0, 1), [(0, (60, 35, 15)), (1, (120, 80, 40))])
    im = Image.fromarray((wood * 255).astype(np.uint8))
    d = ImageDraw.Draw(im)
    f = font("Bungee-Regular.ttf", 22)
    d.text((8, 3), "ORGANS", font=f, fill=(230, 20, 30))
    d.text((7, 2), "ORGANS", font=f, fill=(250, 240, 210))
    for k in range(5):
        x = 10 + k * 24
        d.line([x, 26, x + 2, 31], fill=(150, 0, 0), width=2)       # drips
    save("shop_sign", crunch(im, 1122, block=1, sat=1.2))


def cloth():
    S = 64
    n = value_noise(S, 8, 1131, 4)
    w1, w2, _ = worley(S, 12, 1132)
    t = np.clip(0.5 + (n - 0.5) * 0.6, 0, 1)
    a = gradmap(t, [(0, (40, 60, 50)), (1, (90, 120, 100))])
    stain = (w1 < 7) & (n > 0.5)
    a[stain] = a[stain] * 0.4 + np.array([0.45, 0.02, 0.05]) * 0.6
    save("shop_cloth", crunch(Image.fromarray((a * 255).astype(np.uint8)), 1133))


if __name__ == "__main__":
    face()
    shirt()
    sign()
    cloth()
