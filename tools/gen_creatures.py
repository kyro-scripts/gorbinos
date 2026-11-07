"""Creature textures: grotesque, photo-collage style skins, eyes and mouths
for the Gorbino (orange octopus thing) and the Snirby (pink snotty blob).

Run: python3 tools/gen_creatures.py -> assets/textures/cr_*.png
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from texlib import value_noise, worley, gradmap, rng, ROOT

OUT = os.path.join(ROOT, "assets", "textures")


def to_img(a):
    return Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))


def photo(img, seed, grain=0.06, block=4, sat=1.25):
    """Make a painted texture read like a crude, over-processed photo:
    saturation push, grain, slight blockiness, sharpening."""
    a = np.asarray(img).astype(np.float32) / 255.0
    grey = a[..., :3].mean(-1, keepdims=True)
    a[..., :3] = np.clip(grey + (a[..., :3] - grey) * sat, 0, 1)
    r = rng(seed)
    a[..., :3] += (r.random(a.shape[:2])[..., None] - 0.5) * grain
    im = to_img(a)
    im = im.filter(ImageFilter.UnsharpMask(radius=1.5, percent=160, threshold=1))
    if block > 1:
        w, h = im.size
        im = im.resize((w // block * 2, h // block * 2), Image.BILINEAR).resize((w, h), Image.NEAREST)
    return im


def skin_field(w, h, seed, cells):
    n1 = value_noise(max(w, h), 8, seed, 5)[:h, :w]
    n2 = value_noise(max(w, h), 32, seed + 1, 3)[:h, :w]
    d1, d2, _ = worley(max(w, h), cells, seed + 2)
    d1 = d1[:h, :w]
    return n1, n2, d1


# ------------------------------------------------------------------ GORBINO
def gorbino_skin():
    """Neutral (tintable) octopus skin: mottling, suckers, veins, wet glints."""
    W, H = 256, 128
    n1, n2, d1 = skin_field(W, H, 9100, 60)
    base = 0.62 + n1 * 0.35 - (d1 < 3.2) * 0.25 + n2 * 0.12
    img = np.stack([base, base * 0.93, base * 0.86], -1)
    # dark freckles
    fr = (value_noise(256, 64, 9103, 2)[:H, :W] > 0.76)
    img[fr] *= 0.78
    # veins: thin dark lines from noise level sets
    vn = value_noise(256, 6, 9104, 4)[:H, :W]
    veins = np.abs(vn - 0.5) < 0.012
    img[veins] = img[veins] * np.array([0.55, 0.25, 0.3])
    # pale sucker rings on the lower half (underside / tentacle roots)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    r = rng(9105)
    for _ in range(70):
        cx, cy = r.uniform(0, W), r.uniform(H * 0.55, H)
        rad = r.uniform(2.0, 4.5)
        d = np.hypot(xx - cx, yy - cy)
        ring = (d < rad) & (d > rad * 0.55)
        img[ring] = np.array([1.0, 0.92, 0.85])
        img[d <= rad * 0.55] *= 0.6
    # wet glints
    gl = r.random((H, W)) > 0.992
    img[gl] = 1.0
    photo(Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)), 9106, block=2).save(os.path.join(OUT, "cr_gorbino_skin.png"))


def eye(path, size, iris_stops, pupil="slit", seed=0, lid_color=None):
    """Bloodshot eyeball with a goat/octopus slit or a round pupil."""
    S = size
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
    c = (S - 1) / 2
    d = np.hypot(xx - c, yy - c) / (S / 2)
    sclera = gradmap(np.clip(d, 0, 1), [(0, (250, 244, 225)), (0.7, (235, 215, 190)), (1, (190, 120, 110))])
    r = rng(seed)
    img = sclera
    # blood vessels: random walks from the rim inward
    ves = np.zeros((S, S), np.float32)
    for _ in range(26):
        a = r.uniform(0, 2 * np.pi)
        x, y = c + np.cos(a) * S * 0.48, c + np.sin(a) * S * 0.48
        ang = a + np.pi
        for k in range(int(S * 0.35)):
            ang += r.normal(0, 0.35)
            x += np.cos(ang)
            y += np.sin(ang)
            if 0 <= int(x) < S and 0 <= int(y) < S:
                ves[int(y), int(x)] = 1.0
    ves = np.asarray(Image.fromarray((ves * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6))).astype(np.float32) / 255
    img = img * (1 - ves[..., None] * 0.8) + np.array([0.75, 0.05, 0.05]) * ves[..., None] * 0.8
    # iris
    ir = 0.42
    ang = np.arctan2(yy - c, xx - c)
    stri = 0.5 + 0.5 * np.sin(ang * 23 + value_noise(S, 8, seed + 3, 3) * 9)
    iris = gradmap(np.clip(d / ir, 0, 1) * 0.7 + stri * 0.3, iris_stops)
    m = d < ir
    img[m] = iris[m]
    img[(d < ir + 0.03) & (d >= ir)] *= 0.35
    # pupil
    if pupil == "slit":
        pm = (np.abs(yy - c) < S * 0.07) & (np.abs(xx - c) < S * 0.3) | (np.hypot((xx - c) / 1.0, (yy - c) / 0.45) < S * 0.12)
    else:
        pm = d < 0.2
    img[pm] = np.array([0.02, 0.01, 0.02])
    # wet highlight
    hl = np.hypot(xx - c * 0.7, yy - c * 0.65) < S * 0.07
    img[hl] = 1.0
    hl2 = np.hypot(xx - c * 1.25, yy - c * 1.3) < S * 0.03
    img[hl2] = 0.9
    photo(to_img(img), seed + 9, grain=0.05, block=1).save(path)


def gorbino_mouth():
    """Human lips with crooked yellow teeth on dark gums."""
    W, H = 128, 64
    im = Image.new("RGB", (W, H), (60, 8, 18))
    d = ImageDraw.Draw(im)
    d.ellipse([4, 6, W - 4, H - 6], fill=(150, 40, 50))
    d.ellipse([14, 16, W - 14, H - 16], fill=(25, 0, 6))
    r = rng(9200)
    x = 20
    while x < W - 26:
        tw = int(r.integers(7, 12))
        th = int(r.integers(8, 14))
        col = tuple(int(c) for c in (np.array([235, 220, 160]) * r.uniform(0.7, 1.0)))
        d.rectangle([x, 17, x + tw, 17 + th], fill=col, outline=(90, 70, 40))
        if r.random() < 0.8:
            bh = int(r.integers(6, 11))
            d.rectangle([x + 2, H - 17 - bh, x + tw + 1, H - 17], fill=col, outline=(90, 70, 40))
        x += tw + int(r.integers(0, 3))
    # lip shine and wrinkles
    for k in range(12):
        xx = int(r.integers(10, W - 10))
        d.line([xx, 6, xx + int(r.integers(-3, 3)), 12], fill=(110, 25, 35))
    d.arc([10, 4, W - 10, 30], 200, 340, fill=(230, 140, 140), width=2)
    photo(im, 9201, grain=0.08, block=1).save(os.path.join(OUT, "cr_gorbino_mouth.png"))


# ------------------------------------------------------------------ SNIRBY
def snirby_skin():
    """Pink, pored, blotchy skin with a few hairs; cheeks painted on the
    front (u = 0.5)."""
    W, H = 256, 128
    n1, n2, d1 = skin_field(W, H, 9300, 90)
    t = 0.55 + n1 * 0.35 + n2 * 0.1
    img = gradmap(np.clip(t, 0, 1), [(0, (150, 50, 70)), (0.5, (225, 125, 140)), (1, (250, 195, 185))])
    yel = np.clip((value_noise(256, 12, 9307, 3)[:H, :W] - 0.55) * 4, 0, 1)
    img = img * (1 - yel[..., None] * 0.35) + np.array([0.85, 0.75, 0.35]) * yel[..., None] * 0.35
    pores = (d1 < 1.5)
    img[pores] *= 0.6
    blot = value_noise(256, 6, 9303, 4)[:H, :W]
    img = img * (1 - np.clip((blot - 0.6) * 3, 0, 1)[..., None] * 0.35) + np.array([0.6, 0.05, 0.12]) * np.clip((blot - 0.6) * 3, 0, 1)[..., None] * 0.35
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    # cheeks (rashy blush) either side of the face centre
    for cx in (W * 0.5 - 30, W * 0.5 + 30):
        dd = np.hypot((xx - cx) / 14, (yy - H * 0.56) / 9)
        k = np.clip(1 - dd, 0, 1) ** 0.7
        spots = value_noise(256, 32, 9304, 2)[:H, :W] > 0.5
        img = img * (1 - k[..., None] * 0.6) + np.array([0.85, 0.12, 0.2]) * (k * (0.7 + 0.3 * spots))[..., None] * 0.6
    # wrinkles under the eyes
    for cx in (W * 0.5 - 13, W * 0.5 + 13):
        for k in range(3):
            yv = H * 0.47 + k * 2.5
            m = (np.abs(yy - yv - 0.02 * (xx - cx) ** 2) < 0.6) & (np.abs(xx - cx) < 9)
            img[m] *= 0.6
    # stray hairs
    im = to_img(img)
    d = ImageDraw.Draw(im)
    r = rng(9305)
    for _ in range(40):
        x, y = r.uniform(0, W), r.uniform(0, H)
        a = r.uniform(0, np.pi * 2)
        L = r.uniform(3, 7)
        d.line([x, y, x + np.cos(a) * L, y + np.sin(a) * L], fill=(60, 30, 30), width=1)
    photo(im, 9306, grain=0.07, block=2, sat=1.15).save(os.path.join(OUT, "cr_snirby_skin.png"))


def snirby_eye():
    """Tall glossy black eye, slightly bloodshot rim, big wet highlight."""
    W, H = 32, 64
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    d = np.hypot((xx - 15.5) / 15.5, (yy - 31.5) / 31.5)
    img = gradmap(np.clip(d, 0, 1), [(0, (40, 20, 30)), (0.7, (10, 4, 10)), (0.9, (120, 20, 30)), (1, (200, 90, 100))])
    yy2 = (yy - 20) / 9
    hl = np.hypot((xx - 11) / 5, yy2) < 1
    img[hl] = np.array([1, 1, 1])
    img[np.hypot((xx - 19) / 3, (yy - 44) / 4) < 1] = np.array([0.6, 0.6, 0.7])
    # a hint of a blue-ish iris at the bottom like the cartoon it was copied from
    img[(np.hypot((xx - 15.5) / 9, (yy - 46) / 10) < 1) & ~hl] = img[(np.hypot((xx - 15.5) / 9, (yy - 46) / 10) < 1) & ~hl] * 0.4 + np.array([0.1, 0.2, 0.6]) * 0.6
    photo(to_img(img), 9400, grain=0.05, block=1).save(os.path.join(OUT, "cr_snirby_eye.png"))


def snirby_foot():
    W = 64
    n1, n2, d1 = skin_field(W, W, 9500, 30)
    img = gradmap(np.clip(0.5 + n1 * 0.4 - (d1 < 2) * 0.2, 0, 1), [(0, (60, 0, 15)), (1, (200, 40, 60))])
    yy = np.mgrid[0:W, 0:W][0]
    img[(yy % 9) == 0] *= 0.6
    photo(to_img(img), 9501, block=1).save(os.path.join(OUT, "cr_snirby_foot.png"))


def snot():
    W = 32
    n = value_noise(W, 4, 9600, 3)
    img = gradmap(n, [(0, (60, 120, 10)), (0.6, (150, 220, 40)), (1, (230, 255, 150))])
    to_img(img).save(os.path.join(OUT, "cr_snot.png"))


if __name__ == "__main__":
    gorbino_skin()
    eye(os.path.join(OUT, "cr_gorbino_eye.png"), 64, [(0, (40, 20, 0)), (0.5, (230, 150, 10)), (1, (255, 230, 80))], "slit", 9150)
    eye(os.path.join(OUT, "cr_snirby_eye_h.png"), 64, [(0, (20, 40, 20)), (0.5, (110, 150, 80)), (1, (200, 220, 150))], "round", 9170)
    eye(os.path.join(OUT, "cr_snirby_eye_red.png"), 64, [(0, (60, 0, 0)), (0.5, (255, 30, 20)), (1, (255, 200, 120))], "round", 9180)
    eye(os.path.join(OUT, "cr_gorbino_eye_red.png"), 64, [(0, (40, 0, 0)), (0.5, (255, 20, 10)), (1, (255, 150, 90))], "slit", 9160)
    gorbino_mouth()
    snirby_skin()
    snirby_eye()
    snirby_foot()
    snot()
    print("creature textures written")
